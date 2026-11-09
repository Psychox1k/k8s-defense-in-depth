#!/usr/bin/env bash
# Layer 1 demo: the same attacks are sent twice.
#   1) directly to the vulnerable app (no protection)
#   2) through nginx + ModSecurity + OWASP CRS
#
# Usage:  scripts/attack-demo.sh
# Env:    MODE        cluster (default): requests are sent from the "attacker" pod inside
#                     the cluster, so the WAF sees a real client IP (needed for rate limiting)
#                     local: requests are sent from this machine through the port-forwards
#         NAMESPACE   Kubernetes namespace (default: defense-lab)
#         DIRECT_URL, WAF_URL  override the target URLs
#
# Lab use only. Run this against your own local cluster.
set -u

MODE="${MODE:-cluster}"
NAMESPACE="${NAMESPACE:-defense-lab}"

if [ "$MODE" = "cluster" ]; then
  DIRECT="${DIRECT_URL:-http://juiceshop:3000}"
  WAF="${WAF_URL:-http://waf}"
else
  DIRECT="${DIRECT_URL:-http://localhost:8081}"
  WAF="${WAF_URL:-http://localhost:8080}"
fi

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

# All requests go through this wrapper: curl from the attacker pod, or from this machine.
c() {
  if [ "$MODE" = "cluster" ]; then
    kubectl -n "$NAMESPACE" exec deploy/attacker -- curl "$@" 2>/dev/null
  else
    curl "$@"
  fi
}

# Each attack function prints the HTTP status code (brute_force prints one code per line).
sqli_login() {
  c -s -o /dev/null -w '%{http_code}' -X POST "$1/rest/user/login" \
    -H 'Content-Type: application/json' \
    --data '{"email":"'"' OR 1=1--"'","password":"x"}'
}

xss_search() {
  c -s -o /dev/null -w '%{http_code}' -G "$1/rest/products/search" \
    --data-urlencode 'q=<script>alert(1)</script>'
}

path_traversal() {
  c -s -o /dev/null -w '%{http_code}' -G "$1/" \
    --data-urlencode 'file=../../../../etc/passwd'
}

benign() {
  c -s -o /dev/null -w '%{http_code}' -G "$1/rest/products/search" \
    --data-urlencode 'q=apple'
}

# Legitimate Juice Shop traffic that CRS rule 920420 used to block (week 1 finding).
# Without a valid session id the app itself answers 400; what matters is that the WAF
# does not answer 403.
socketio_poll() {
  c -s -o /dev/null -w '%{http_code}' -X POST \
    "$1/socket.io/?EIO=4&transport=polling&t=demo" \
    -H 'Content-Type: text/plain;charset=UTF-8' --data '40'
}

# Password guessing: 12 wrong logins in a row. The app answers 401 each time; nginx rate
# limiting answers 429 once the allowed burst is used up.
BRUTE_ATTEMPTS=12
brute_force() {
  i=1
  while [ "$i" -le "$BRUTE_ATTEMPTS" ]; do
    c -s -o /dev/null -w '%{http_code}\n' -X POST "$1/rest/user/login" \
      -H 'Content-Type: application/json' \
      --data '{"email":"admin@juice-sh.op","password":"wrong-'"$i"'"}'
    i=$((i + 1))
  done
}

# Is the target reachable at all?
reachable() {
  code=$(c -s -o /dev/null -w '%{http_code}' --max-time 5 "$1/")
  [ -n "$code" ] && [ "$code" != "000" ]
}

if [ "$MODE" = "cluster" ]; then
  if ! kubectl -n "$NAMESPACE" get deploy/attacker >/dev/null 2>&1; then
    echo "${RED}The attacker pod does not exist.${RESET} Did you run 'make up'?"
    exit 1
  fi
fi

for target in "$DIRECT" "$WAF"; do
  if ! reachable "$target"; then
    echo "${RED}Cannot reach $target (mode: $MODE).${RESET} Did you run 'make up'?"
    exit 1
  fi
done

verdict() {
  # $1 = http code, $2 = "attack" or "normal"
  case "$2:$1" in
    attack:403) printf '%sBLOCKED (%s)%s' "$GREEN" "$1" "$RESET" ;;
    attack:*)   printf '%sPASSED THROUGH (%s)%s' "$RED" "$1" "$RESET" ;;
    normal:403) printf '%sFALSE POSITIVE (%s)%s' "$YELLOW" "$1" "$RESET" ;;
    normal:*)   printf '%snot blocked (%s)%s' "$GREEN" "$1" "$RESET" ;;
  esac
}

# $1 = the list of status codes, one per line. Prints e.g. "401x6 429x6".
code_summary() {
  printf '%s\n' "$1" | sort | uniq -c | awk '{printf "%s%sx%s", sep, $2, $1; sep=" "}'
}

verdict_brute() {
  summary=$(code_summary "$1")
  if printf '%s\n' "$1" | grep -qx '429'; then
    printf '%sTHROTTLED (%s)%s' "$GREEN" "$summary" "$RESET"
  else
    printf '%sNOT THROTTLED (%s)%s' "$RED" "$summary" "$RESET"
  fi
}

run_case() {
  # $1 = label, $2 = function, $3 = attack|normal
  d=$($2 "$DIRECT")
  w=$($2 "$WAF")
  printf '%-26s direct: %-34s via WAF: %s\n' "$1" "$(verdict "$d" "$3")" "$(verdict "$w" "$3")"
}

run_brute_case() {
  d=$(brute_force "$DIRECT")
  w=$(brute_force "$WAF")
  printf '%-26s direct: %-34s via WAF: %s\n' "Brute force ($BRUTE_ATTEMPTS logins)" \
    "$(verdict_brute "$d")" "$(verdict_brute "$w")"
}

echo "${BOLD}Mode: $MODE    Direct: $DIRECT    Through WAF: $WAF${RESET}"
echo
run_case "SQL injection (login)"   sqli_login     attack
run_case "XSS (product search)"    xss_search     attack
run_case "Path traversal"          path_traversal attack
run_case "Normal request"          benign         normal
run_case "socket.io polling"       socketio_poll  normal
# Last, because the login limiter keeps counting for about a minute afterwards.
run_brute_case
echo
echo "Matched rules: run 'make logs'"