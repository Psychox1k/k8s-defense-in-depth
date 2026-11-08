cat > docs/progress/week-02.md <<'EOF'
# Week 2 (stage 1.1 WAF tuning, branch `feat/waf-tuning`)

## Done
- Rule exclusion for the week 1 false positive: CRS rule 920420 is disabled only for `/socket.io/`
  (`k8s/waf/exclusions.yaml`, mounted as `REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf`)
- `attack-demo.sh`: new control case "socket.io polling" (legitimate traffic that used to be blocked)
- `make stop` / `make start` (pause the lab without deleting it), `make waf-reload`
- `waf-log.sh` reports an error when the WAF log cannot be read instead of "no matches"

## Results
| Request | Before exclusion (through WAF) | After exclusion (through WAF) |
|---|---|---|
| socket.io polling | | |
| SQL injection | | |
| XSS | | |
| Path traversal | | |

(fill in from `make attack`; screenshots to `docs/img/`)

## Why a narrow exclusion
Disabling 920420 globally would let any request with an unexpected Content-Type through.
The exclusion removes one rule for one path, all other rules still inspect socket.io traffic.

## Problems and how they were solved
-

## Next
- Pin image versions
- Check which image env variables apply, compare paranoia levels 1 and 2
EOF