# Week 3 (stage 1.2 pinned images, attacker pod, rate limiting, branch `feat/rate-limit`)

## Done
- Checked the WAF image configuration against its sources: removed the non-existent `PROXY`
  variable, replaced the deprecated `PARANOIA` with `BLOCKING_PARANOIA` and `DETECTION_PARANOIA`
- Images pinned to digests (`make pin`), so experiments always run on the same images
- Attacker pod inside the cluster (`k8s/attacker/`); `make attack` runs from it, the WAF sees a
  real client IP (the pod IP) instead of the node IP. `make attack-local` keeps the old way
- nginx rate limiting on `/rest/user/login`: 10 requests per minute per IP, burst of 5, then HTTP 429
  (`k8s/waf/rate-limit.yaml`)
- Brute force case in `attack-demo.sh`

## Results
`make attack` (from the attacker pod):

| Request | Direct | Through WAF |
|---|---|---|
| SQL injection | | |
| XSS | | |
| Path traversal | | |
| Normal request | | |
| socket.io polling | | |
| Brute force (12 logins) | | |

(fill in from `make attack`; screenshot to `docs/img/`)

Client IP seen by the WAF: (paste a line from `make logs` or `kubectl logs deploy/waf`)

## Why rate limiting is a separate layer from CRS
CRS looks at the content of one request. A password guessing attack consists of many requests
that each look normal, so no rule matches. Only counting requests per client over time can stop it,
and that needs a stable client IP, which is why the attacker pod comes first.

## Problems and how they were solved
-

## Next
- Stage 1.3: Loki + Grafana, WAF dashboard