# Service operations

All commands run from the VPS as `ubuntu` (passwordless sudo). Docker needs `sudo`.

## Container names

| Service | Container |
|---|---|
| Admin panel | `sklive-admin` |
| Master panel | `sklive-master-panel` |
| Super admin | `sklive-super-admin` |
| Events | `sklive-events` |
| Landing | `sklive-landing` |
| Room gateway | `sklive-gateway` (+ `sklive-gateway-redis`) |
| Voice | `livekit-rr1rnq2qirqyr2yinczwpsse` |
| Database | `supabase-db-mnq3vesx0syflb0m0bot3oa2` |
| API gateway | `supabase-kong-mnq3vesx0syflb0m0bot3oa2` |
| Proxy | `coolify-proxy` (Traefik v3.6) |

## Common tasks

```bash
sudo docker ps --format '{{.Names}}|{{.Status}}' | sort      # health sweep
sudo docker logs --tail 200 -f sklive-gateway                # tail a service
sudo docker restart sklive-admin                             # restart one service
sudo docker exec -it supabase-db-mnq3vesx0syflb0m0bot3oa2 \
     psql -U postgres -d postgres                            # database shell
```

## Rebuild and redeploy a web service

Source lives in `/opt/sklive-<service>`, built into a `:local` image — **not** pulled from git by
Coolify. To deploy a fix: edit in `/opt/sklive-<service>`, then

```bash
cd /opt/sklive-<service>
sudo docker compose -f docker-compose.coolify.yml up -d --build
```

> **Before editing anything, copy the current folder aside** — there is no git history and no
> rollback. `sudo cp -a /opt/sklive-admin /opt/sklive-admin.bak-$(date +%F)`

## Health checks from outside

```bash
for h in api gateway admin master events super voice; do
  curl -s -o /dev/null -w "%{http_code} $h\n" "https://$h.skliveparty.online/"
done
```

Healthy baseline: `api` 401, `admin`/`master` 307 (redirect to login), `gateway` 404 on `/`.
