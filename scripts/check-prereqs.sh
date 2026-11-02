#!/usr/bin/env bash
# Checks that the local tools needed for the lab are installed and running.
set -u

ok=0
for tool in docker k3d kubectl curl; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  [ok]      %s\n' "$tool"
  else
    printf '  [missing] %s\n' "$tool"
    ok=1
  fi
done

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    printf '  [ok]      docker daemon is running\n'
  else
    printf '  [missing] docker daemon is not running (start OrbStack)\n'
    ok=1
  fi
fi

if [ "$ok" -ne 0 ]; then
  echo
  echo "Install missing tools with: brew install orbstack k3d kubectl"
  exit 1
fi
echo "All prerequisites are in place."
