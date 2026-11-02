# Week 1 (27.10.2026)

## Done
- Repository and project structure
- Local Kubernetes cluster (k3d on OrbStack)
- OWASP Juice Shop as the vulnerable target
- Layer 1: nginx + ModSecurity + OWASP CRS as a reverse proxy
- Demo script: the same attacks sent directly and through the WAF

## Results
| Attack | Direct | Through WAF |
|---|---|---|
| SQL injection (login) | | |
| XSS (product search) | | |
| Path traversal | | |
| Normal request | | |

(fill in after running `make attack`, add screenshots to `docs/img/`)

## Problems and how they were solved
-

## Next week
- Tune CRS (paranoia levels), measure false positives
- Rate limiting in nginx against brute force
- JSON logs to Loki + Grafana
