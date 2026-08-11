# ProServico

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

Endpoint da API: `API_BASE_URL` em `.env` (veja `.env.example`).

Na tela inicial: criar conta, login ou acesso administrativo.
