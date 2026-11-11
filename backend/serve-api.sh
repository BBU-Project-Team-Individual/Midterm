#!/bin/sh
set -eu
cd "$(dirname "$0")/public"
exec php -d upload_max_filesize=5M -d post_max_size=6M \
  -S "${API_BIND_ADDRESS:-0.0.0.0}:${API_PORT:-8001}" \
  ../vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php
