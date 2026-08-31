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

# Espera o MySQL aceitar conexões antes de qualquer artisan que toque no banco.
if [ "${WAIT_FOR_DB:-false}" = "true" ]; then
  echo ">> Aguardando MySQL em ${DB_HOST}:${DB_PORT}..."
  tries=0
  until php -r 'exit(@fsockopen(getenv("DB_HOST"), (int) getenv("DB_PORT"), $e, $s, 2) ? 0 : 1);' 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -ge 60 ]; then
      echo ">> MySQL não respondeu em ~2min; seguindo mesmo assim."
      break
    fi
    sleep 2
  done
fi

# Chaves obrigatórias (APP_KEY e JWT_SECRET) — geradas só na primeira subida.
if ! grep -q '^APP_KEY=base64:' .env 2>/dev/null; then
  echo ">> Gerando APP_KEY..."
  php artisan key:generate --force
fi

if ! grep -q '^JWT_SECRET=..*' .env 2>/dev/null; then
  echo ">> Gerando JWT_SECRET..."
  php artisan jwt:secret --force
fi

# Migrations automáticas (só quando pedido explicitamente, ex.: docker compose).
if [ "${AUTO_MIGRATE:-false}" = "true" ]; then
  if php artisan migrate:status >/dev/null 2>&1; then
    echo ">> Rodando migrations..."
    php artisan migrate --force
  else
    echo ">> Banco vazio: migrations + seed..."
    php artisan migrate --force --seed
  fi
fi

php artisan config:clear --quiet 2>/dev/null || true

exec "$@"
