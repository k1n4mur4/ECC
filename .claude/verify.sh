#!/usr/bin/env bash
# Project verification for the Review Kit Stop hook (rk-stop-verify.py).
# Budget ~2 minutes: lint, content validators, and the JS tests related to
# changed files. CI runs the full `npm test`; run it locally with
#   ECC_VERIFY_FULL=1 bash .claude/verify.sh
# Kept compatible with macOS /bin/bash 3.2 (no arrays under set -u).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [ ! -d node_modules ]; then
  echo "[verify] node_modules is missing: run 'corepack yarn install --immutable'" >&2
  exit 1
fi

# package.json pins yarn 4 via "packageManager"; a global yarn 1 refuses to
# run, so go through Corepack.
echo "[verify] lint: corepack yarn lint"
corepack yarn lint

echo "[verify] content validators: npm run test:validators"
npm run -s test:validators

if [ "${ECC_VERIFY_FULL:-0}" = "1" ]; then
  echo "[verify] full JS suite"
  ECC_TEST_JOBS=4 node tests/run-all.js
  exit 0
fi

# Changed = modified/staged vs HEAD plus untracked, not ignored.
changed=$({ git diff --name-only HEAD; git ls-files --others --exclude-standard; } | sort -u)

# A changed test file runs itself; a changed script runs every test file whose
# path contains the script's base name (tests/run-all.js ECC_TEST_ONLY).
patterns=""
py_changed=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    tests/*.test.js) p="${f#tests/}" ;;
    scripts/*.js|scripts/*.mjs|scripts/*.sh|skills/*.js|skills/*.sh|hooks/*.js)
      p="${f##*/}"; p="${p%.*}" ;;
    *.py) py_changed=1; continue ;;
    *) continue ;;
  esac
  patterns="${patterns}${patterns:+,}${p}"
done <<EOF
$changed
EOF

if [ -n "$patterns" ]; then
  echo "[verify] JS tests matching: $patterns"
  ECC_TEST_JOBS=4 ECC_TEST_ONLY="$patterns" node tests/run-all.js
else
  echo "[verify] JS tests: skipped (no changed scripts or tests)"
fi

if [ "$py_changed" = "1" ]; then
  if python3 -c 'import pytest' >/dev/null 2>&1; then
    echo "[verify] python: python3 -m pytest tests/ -q -m 'not integration'"
    python3 -m pytest tests/ -q -m "not integration"
  else
    echo "[verify] python: NOT RUN (pytest is not installed for python3)" >&2
  fi
fi
