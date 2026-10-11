#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/versions.sh"
printf '%s/%s/%s/local\n' "${FLINTELL_BUILD_ROOT:-$HOME/.cache/flintell}" "$FLINT_VERSION" "${1:-native}"
