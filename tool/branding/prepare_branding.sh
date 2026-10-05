#!/usr/bin/env bash
# Wrapper fino sobre prepare_branding.py (Pillow). Ver README.md en este
# mismo directorio para el detalle de que hace y como regenerar los assets.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/prepare_branding.py" "$@"
