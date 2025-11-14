#!/bin/zsh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
export PATH="$HOME/flutter/bin:$PATH"
flutter build ios --config-only --release
