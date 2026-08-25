# ProServico

Front básico do **Módulo 1** da Plataforma de Prestação de Serviços (Flutter).

## Escopo coberto

- Autenticação (cliente/profissional, login, cadastro, recuperação de senha)
- Área do cliente (dashboard, solicitar serviço, meus serviços, perfil, configurações)
- Área do profissional (dashboard, cadastro/gestão de serviços, perfil, configurações)
- Painel administrativo básico (clientes, profissionais, aprovações, serviços, dashboard)

Dados em memória (mock) — sem backend nesta etapa.

## Como rodar

O projeto usa **Flutter 3.29.3** via [FVM](https://fvm.app/).

```bash
# uma vez
brew install fvm   # ou: dart pub global activate fvm
cd app
fvm install
fvm use

cp .env.example .env   # se ainda não existir
fvm flutter pub get
fvm flutter run
```

Endpoint da API: `API_BASE_URL` em `.env` (veja `.env.example`).

Na tela inicial: criar conta, login ou acesso administrativo.