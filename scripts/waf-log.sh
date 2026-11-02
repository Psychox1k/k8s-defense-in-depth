#!/usr/bin/env bash
# Prints requests that ModSecurity matched, in a readable form: time, status,
# request, anomaly score and the CRS rules that fired.
#
# Usage:  scripts/waf-log.sh [entries]        (default: 20 latest entries)
# Env:    EXCLUDE       regex of URI paths to hide (default: ^/socket\.io/)
#         NAMESPACE     Kubernetes namespace (default: defense-lab)
#         TAIL          how many log lines to read from the pod (default: 3000)
#         WAF_LOG_FILE  read a saved log file instead of calling kubectl
set -u

NAMESPACE="${NAMESPACE:-defense-lab}"
LIMIT="${1:-20}"
EXCLUDE="${EXCLUDE:-^/socket\\.io/}"

read_log() {
  if [ -n "${WAF_LOG_FILE:-}" ]; then
    cat "$WAF_LOG_FILE"
  else
    kubectl -n "$NAMESPACE" logs deploy/waf --tail="${TAIL:-3000}"
  fi
}

read_log | python3 -I -c '
import json, re, sys

limit = int(sys.argv[1])
exclude = re.compile(sys.argv[2])

rows, hidden = [], 0
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{\"transaction\""):
        continue
    try:
        d = json.loads(line)
    except ValueError:
        continue
    t = d.get("transaction", {})
    req = t.get("request", {})
    uri = req.get("uri", "")
    if exclude.search(uri.split("?", 1)[0]):
        hidden += 1
        continue
    score, rules = "", []
    for m in t.get("messages", []):
        rid = m.get("details", {}).get("ruleId", "?")
        msg = m.get("message", "")
        if rid == "949110":  # generic "anomaly score exceeded" blocking rule
            found = re.search(r"Total Score: (\d+)", msg)
            score = found.group(1) if found else ""
            continue
        rules.append((rid, msg))
    clock = (t.get("time_stamp", "").split() or ["", "", "", ""])[3:4] or [""]
    rows.append((clock[0], t.get("response", {}).get("http_code", "-"),
                 req.get("method", ""), uri, score, rules))

for clock, status, method, uri, score, rules in rows[-limit:]:
    uri = uri if len(uri) <= 80 else uri[:77] + "..."
    extra = f"  score={score}" if score else ""
    print(f"{clock}  {status}  {method} {uri}{extra}")
    for rid, msg in rules:
        print(f"            rule {rid}: {msg}")

if not rows:
    print("No matched requests found (or all hidden by EXCLUDE).")
if hidden:
    print(f"\n({hidden} matched requests hidden by EXCLUDE; "
          "use EXCLUDE=\"^\\$\" to show everything)")
' "$LIMIT" "$EXCLUDE"