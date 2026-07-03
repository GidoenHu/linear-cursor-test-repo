#!/usr/bin/env bash
# Quick sanity check for Cloud Agent environment readiness.

set -euo pipefail

cd /workspace

python3 --version | grep -qE 'Python 3\.(1[2-9]|[2-9][0-9])' \
  || { echo "ERROR: Python 3.12+ required"; exit 1; }

node --version | grep -qE 'v(1[89]|[2-9][0-9])' \
  || { echo "ERROR: Node.js 18+ required"; exit 1; }

bash scripts/cloud-install.sh

if [[ -f hello.py ]]; then
  python3 hello.py
fi

echo "Environment verification passed."
