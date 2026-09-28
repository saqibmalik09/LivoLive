# docker-compose.edge-secrets.yml is not here

That override file contains **live private keys** — the Google Play IAP service-account JSON
(including its private key), the Orbit tenant API key, and an RSA signing keypair used by the
edge functions.

It is kept at `secrets/coolify/docker-compose.edge-secrets.yml`, outside version control.

On the server it lives at
`/data/coolify/services/mnq3vesx0syflb0m0bot3oa2/docker-compose.edge-secrets.yml`.
