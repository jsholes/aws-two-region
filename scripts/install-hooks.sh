#!/usr/bin/env bash
# Point git at the tracked hooks directory. Run once per clone.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .githooks
echo "hooks installed - .githooks/pre-commit will run the audit on every commit"
