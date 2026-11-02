#!/usr/bin/env bash
# Layer 1 demo: the same attacks are sent twice.
#   1) directly to the vulnerable app (no protection)
#   2) through nginx + ModSecurity + OWASP CRS
#
set -u

DIRECT="${DIRECT_URL:-http://localhost:8081}"
WAF="${WAF_URL:-http://localhost:8080}"

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

# Each attack function prints the HTTP status code.
sqli_login() {
  curl -s -o /dev/null -w '%{http_code}' -X POST "$1/rest/user/login" \
    -H 'Content-Type: application/json' \
    --data '{"email":"'"' OR 1=1--"'","password":"x"}'
}

xss_search() {
  curl -s -o /dev/null -w '%{http_code}' -G "$1/rest/products/search" \
    --data-urlencode 'q=<script>alert(1)</script>'
}

path_traversal() {
  curl -s -o /dev/null -w '%{http_code}' -G "$1/" \
    --data-urlencode 'file=../../../../etc/passwd'
}

benign() {
  curl -s -o /dev/null -w '%{http_code}' -G "$1/rest/products/search" \
    --data-urlencode 'q=apple'
}

# Is the target reachable at all?
reachable() {
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$1/")
  [ "$code" != "000" ]
}

for target in "$DIRECT" "$WAF"; do
  if ! reachable "$target"; then
    echo "${RED}Cannot reach $target.${RESET} Did you run 'make up'?"
    exit 1
  fi
done

verdict() {
  # $1 = http code, $2 = "attack" or "normal"
  case "$2:$1" in
    attack:403) printf '%sBLOCKED (%s)%s' "$GREEN" "$1" "$RESET" ;;
    attack:*)   printf '%sPASSED THROUGH (%s)%s' "$RED" "$1" "$RESET" ;;
    normal:2*)  printf '%sallowed (%s)%s' "$GREEN" "$1" "$RESET" ;;
    normal:*)   printf '%sFALSE POSITIVE? (%s)%s' "$YELLOW" "$1" "$RESET" ;;
  esac
}

run_case() {
  # $1 = label, $2 = function, $3 = attack|normal
  d=$($2 "$DIRECT")
  w=$($2 "$WAF")
  printf '%-26s direct: %-34s via WAF: %s\n' "$1" "$(verdict "$d" "$3")" "$(verdict "$w" "$3")"
}

echo "${BOLD}Direct: $DIRECT    Through WAF: $WAF${RESET}"
echo
run_case "SQL injection (login)"   sqli_login     attack
run_case "XSS (product search)"    xss_search     attack
run_case "Path traversal"          path_traversal attack
run_case "Normal request"          benign         normal
echo
echo "Matched rules: run 'make logs'"
