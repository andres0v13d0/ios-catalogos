#!/usr/bin/env bash
# Build de release (App Bundle) del flavor prod, firmado con
# android/key.properties (ver tarea de firma de release; falla si no existe).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

flutter build appbundle --release --flavor prod --dart-define-from-file=env/prod.json
