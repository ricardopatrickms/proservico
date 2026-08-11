# Pro Serviço

Front básico do **Módulo 1** da Plataforma de Prestação de Serviços (Flutter).

## Escopo coberto

- Autenticação (cliente/profissional, login, cadastro, recuperação de senha)
- Área do cliente (dashboard, solicitar serviço, meus serviços, perfil, configurações)
- Área do profissional (dashboard, cadastro/gestão de serviços, perfil, configurações)
- Painel administrativo básico (clientes, profissionais, aprovações, serviços, dashboard)

Dados em memória (mock) — sem backend nesta etapa.

## Como rodar

```bash
cp .env.example .env   # se ainda não existir
flutter pub get
flutter run
```

Endpoints da API ficam em `.env` (`API_BASE_URL`).
Para device físico ou emulador Android, use o IP da sua máquina (ex.: `http://192.168.0.10:8000/api`).

Override pontual:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000/api
```

Na tela inicial: criar conta, login ou acesso administrativo.
