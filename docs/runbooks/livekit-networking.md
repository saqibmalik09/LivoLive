# LiveKit: high CPU, packet loss and cutting audio

**Symptom** Audio-only rooms with a handful of users. `livekit-trzes9cwliufu1bgylhjqp59`
sits at ~122% CPU and 317 MiB against a **1 GiB** limit on a 23 GiB host.
`packetLostPercentage` 9.5 (35% on one track), `jitter` 2112 with `maxJitter`
260426, `rtt` up to 5186, `connectTime` 2.5–5.1s, and repeated
`could not add packet to bucket ... received packet too old`. That last line is
the breaking/cutting sound users report.

**Diagnosis** Two separate networking faults, both visible in the container log.

1. **LiveKit advertises container-internal ICE candidates.** Local candidates
   include `10.0.2.3`, the container's own bridge address. A phone on the
   internet cannot route to it, so ICE wastes time failing those candidates
   before settling — that is the 2.5–5.1s `connectTime`.
2. **Inbound media is relayed by Docker's userland proxy.** The selected ICE
   pair repeatedly switches away from the real client address to `10.0.1.1`,
   the host's Docker bridge gateway. Every client's source address being
   rewritten to the bridge gateway is the signature of `docker-proxy` relaying
   the UDP flow: each packet is copied into and out of user space instead of
   being forwarded by the kernel. That is the CPU burn, the loss, and the
   late-packet errors.

Neither is an application bug. Nothing in the gateway or the app will fix them.

---

## Before you change anything: capture the current state

Record the output of all of these. Stage 3 cannot be planned without the first
two, and rollback needs the rest.

```bash
# How the container is attached, and its memory cap
sudo docker inspect livekit-trzes9cwliufu1bgylhjqp59 \
  --format '{{.HostConfig.NetworkMode}} mem={{.HostConfig.Memory}}'
sudo docker inspect livekit-trzes9cwliufu1bgylhjqp59 \
  --format '{{json .HostConfig.PortBindings}}'

# Its config: file-based or env-based
sudo docker exec livekit-trzes9cwliufu1bgylhjqp59 sh -c \
  'cat /etc/livekit.yaml 2>/dev/null || cat /livekit.yaml 2>/dev/null || echo NO_CONFIG_FILE'
sudo docker inspect livekit-trzes9cwliufu1bgylhjqp59 \
  --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -i -E 'livekit|redis|rtc|ip'

# Where Coolify keeps the compose for this resource
sudo ls -la /data/coolify/services/trzes9cwliufu1bgylhjqp59/ 2>/dev/null \
  || sudo ls -la /data/coolify/applications/trzes9cwliufu1bgylhjqp59/ 2>/dev/null

# Who the proxy thinks serves the voice domain
sudo docker inspect livekit-trzes9cwliufu1bgylhjqp59 \
  --format '{{json .Config.Labels}}' | tr ',' '\n' | grep -i -E 'traefik|caddy|host'
```

> Edit configuration through the **Coolify UI** for this resource, not by hand in
> `/data/coolify/...`. Coolify regenerates compose files from its database on
> redeploy, so hand edits are silently reverted. Use the UI's compose/env
> editor, then Redeploy.

---

## Stage 1 — raise the memory cap, and fix the advertised IP

Cheapest change, and it addresses fault 1 on its own. Restarting LiveKit drops
everyone currently live, so pick a quiet hour. Nothing else on the box is
touched: no proxy route changes, no Redis changes, no Docker daemon restart.

**1a. Memory.** 1 GiB is too low for an SFU that also holds jitter buffers for
every track. Raise the limit to **4 GiB**. On a 23 GiB host this is not
contended, and an SFU that hits its cgroup limit stalls media rather than
failing cleanly.

**1b. Tell LiveKit its real address.** This is what stops it offering
`10.0.2.3` to phones.

If it uses `livekit.yaml`:

```yaml
rtc:
  use_external_ip: true
```

If it is configured by environment variables:

```
LIVEKIT_RTC_USE_EXTERNAL_IP=true
```

`use_external_ip` makes LiveKit resolve and advertise the host's public address
(`13.140.57.228`) instead of its container address. If the host cannot reach an
external STUN service, pin it instead:

```yaml
rtc:
  use_external_ip: true
  node_ip: 13.140.57.228
```

**Verify after redeploy** — connect one phone, take the mic, then:

```bash
sudo docker logs --tail 200 livekit-trzes9cwliufu1bgylhjqp59 | grep -i -E 'candidate|selected|ICE'
sudo docker stats --no-stream livekit-trzes9cwliufu1bgylhjqp59
```

Expect `connectTime` to drop toward well under a second and the advertised
candidates to show the public IP. **CPU will still be high** if fault 2 is
present — that is Stage 2.

---

## Stage 2 — stop the userland proxy relaying media

This addresses fault 2, which is the CPU and the cutting audio.

Prefer this over host networking: it is one line, it needs no change to the
proxy route or to Redis, and it is trivially reversible. The cost is that
restarting Docker restarts **every** container on the box — a few minutes of
full outage including Supabase and the panels, so schedule it.

```bash
sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak 2>/dev/null || true
cat /etc/docker/daemon.json 2>/dev/null   # merge, do not overwrite existing keys
```

Set `userland-proxy` to false, preserving anything already in the file:

```json
{
  "userland-proxy": false
}
```

```bash
sudo systemctl restart docker
```

Docker then publishes ports with kernel iptables DNAT instead of a
`docker-proxy` process per port. The client's real source address survives, so
ICE stops flipping to `10.0.1.1` and media is no longer copied through user
space.

**Verify** — with one phone publishing:

```bash
sudo docker stats --no-stream livekit-trzes9cwliufu1bgylhjqp59
sudo docker logs --tail 300 livekit-trzes9cwliufu1bgylhjqp59 \
  | grep -i -E 'selected|10\.0\.1\.1|packet too old'
```

Expect: no `10.0.1.1` in the selected pair, no `received packet too old`, and
CPU in the low tens of percent rather than >100%.

**Rollback** — restore `daemon.json.bak` (or remove the key) and
`sudo systemctl restart docker`.

> Also check the published UDP range from the capture step. If LiveKit publishes
> a wide ICE range such as `50000-60000/udp`, that is 10,000 port bindings and
> is worth narrowing regardless. Set `rtc.port_range_start`/`port_range_end` to
> a few hundred ports, or switch to single-port mode with `rtc.udp_port`, and
> publish only that. A narrower range means fewer iptables rules and much
> faster container start.

---

## Stage 3 — host networking (only if Stages 1 and 2 are not enough)

This is LiveKit's own recommended production topology and removes port
translation entirely. It is listed last because it breaks two things that must
be fixed in the same change:

1. **The proxy route.** With `network_mode: host` the container leaves the
   Docker network, so `coolify-proxy` can no longer reach it by container name
   and `wss://voice.skliveparty.online` stops resolving to it. The proxy must
   target the host instead — `host.docker.internal:7880` with
   `extra_hosts: ["host.docker.internal:host-gateway"]` on the proxy, or the
   host's private address. Confirm which router Coolify runs (Traefik or Caddy)
   from the labels captured above before touching this.
2. **Redis.** LiveKit's Redis URL almost certainly uses the Redis container's
   DNS name, which will not resolve from the host network namespace. It must
   become `127.0.0.1:<port>`, and the Redis container must publish that port to
   the host.

Do not attempt Stage 3 without the capture output in hand, and take a Coolify
configuration backup of the resource first.

---

## What this does not change

- No application code. The gateway and the app are unaffected; no APK needed.
- Supabase, the panels and the gateway containers are not reconfigured.
  Stage 2 restarts them only as a side effect of restarting Docker.
- LiveKit stays the media engine. `livekit_url`, `livekit_api_key` and the
  rest of the `system_settings` rows stay as they are.
