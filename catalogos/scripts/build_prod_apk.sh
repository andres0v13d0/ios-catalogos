#!/usr/bin/env bash
# Build de release (APK) del flavor prod, firmado con android/key.properties
# (ver tarea de firma de release; falla si no existe).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

flutter build apk --release --flavor prod --dart-define-from-file=env/prod.json
