#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec php \
  -d upload_max_filesize=32M \
  -d post_max_size=40M \
  artisan serve --host=0.0.0.0 --port=8000 "$@"
