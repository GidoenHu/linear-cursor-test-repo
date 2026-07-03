#!/usr/bin/env bash
# Idempotent install script for Cloud Agent sessions.
# Runs on every session boot (see .cursor/environment.json "install").

set -euo pipefail

cd /workspace

echo "==> Python: $(python3 --version)"
echo "==> Node:   $(node --version)"

# Python dependencies
if [[ -f requirements.txt ]] && grep -qvE '^\s*(#|$)' requirements.txt; then
  echo "==> Installing Python dependencies..."
  python3 -m pip install --upgrade pip
  python3 -m pip install -r requirements.txt
else
  echo "==> No Python dependencies (requirements.txt empty or missing)."
fi

# Node dependencies
if [[ -f package.json ]]; then
  if [[ -f pnpm-lock.yaml ]]; then
    echo "==> Installing Node dependencies (pnpm)..."
    pnpm install --frozen-lockfile 2>/dev/null || pnpm install
  elif [[ -f package-lock.json ]]; then
    echo "==> Installing Node dependencies (npm)..."
    npm ci 2>/dev/null || npm install
  else
    echo "==> Installing Node dependencies (npm)..."
    npm install
  fi
else
  echo "==> No Node dependencies (package.json missing)."
fi

echo "==> Cloud install complete."
