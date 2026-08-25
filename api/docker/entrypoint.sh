#!/bin/sh
set -e

cd /var/www/html

if [ ! -f vendor/autoload.php ]; then
  echo ">> Instalando dependências Composer..."
  composer install --prefer-dist --no-interaction
fi

if [ ! -f .env ] && [ -f .env.example ]; then
  cp .env.example .env
fi

# O volume monta o .env do Mac (DB_HOST=127.0.0.1). Dentro do container isso
# aponta para o próprio container, não para o MySQL do host.
# `php artisan serve` (sem --no-reload) NÃO repassa DB_* ao subprocesso PHP e
# o .env do disco volta a valer — por isso forçamos aqui e usamos --no-reload.
if [ -f /.dockerenv ]; then
  export DB_HOST="${DB_HOST_DOCKER:-host.docker.internal}"
  export DB_PORT="${DB_PORT:-3306}"
  echo ">> DB_HOST=${DB_HOST} (MySQL no host via Docker)"
fi

php artisan config:clear --quiet 2>/dev/null || true

exec "$@"
