# Pro Serviço API

API Laravel do app **Pro Serviço**, com autenticação **JWT** (`tymon/jwt-auth`) e MySQL.

## Requisitos

- PHP 8.2+
- Composer
- MySQL

## Configuração

1. Crie o banco:

```sql
CREATE DATABASE proservico CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

2. Ajuste o `.env` (já preparado para MySQL):

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=proservico
DB_USERNAME=root
DB_PASSWORD=
```

3. Instale e prepare:

```bash
composer install
php artisan key:generate
php artisan jwt:secret
php artisan migrate --seed
php artisan serve
```

API em `http://127.0.0.1:8000/api`.

## Autenticação JWT

Envie o token no header:

```http
Authorization: Bearer {access_token}
```

### Endpoints de auth

| Método | Rota | Descrição |
|--------|------|-----------|
| POST | `/api/auth/register` | Cadastro (cliente/profissional) |
| POST | `/api/auth/login` | Login |
| POST | `/api/auth/forgot-password` | Recuperação de senha |
| GET | `/api/auth/me` | Usuário autenticado |
| PUT | `/api/auth/profile` | Atualizar perfil |
| POST | `/api/auth/logout` | Logout |
| POST | `/api/auth/refresh` | Renovar token |

### Usuários seed (senha: `password`)

- Admin: `admin@proservico.com`
- Cliente: `maria@email.com`
- Profissional: `carlos@email.com`
