<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Redefinir senha - ProServiço</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #F5F7FA;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
        }
        .card {
            background: #fff;
            border-radius: 16px;
            padding: 40px 32px;
            max-width: 420px;
            width: 100%;
            box-shadow: 0 4px 24px rgba(0,0,0,0.08);
        }
        h1 {
            color: #1A2332;
            font-size: 24px;
            font-weight: 700;
            margin-bottom: 8px;
        }
        p.subtitle {
            color: #6B7280;
            font-size: 14px;
            margin-bottom: 28px;
        }
        label {
            display: block;
            color: #1A2332;
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 6px;
        }
        input {
            width: 100%;
            padding: 12px 16px;
            border: 1px solid #E5E7EB;
            border-radius: 10px;
            font-size: 15px;
            margin-bottom: 16px;
            outline: none;
            transition: border-color 0.2s;
        }
        input:focus { border-color: #3B9EFF; }
        input[readonly] {
            background: #F5F7FA;
            color: #6B7280;
        }
        button {
            width: 100%;
            padding: 14px;
            background: #3B9EFF;
            color: #fff;
            border: none;
            border-radius: 10px;
            font-size: 15px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 8px;
            transition: opacity 0.2s;
        }
        button:hover { opacity: 0.9; }
        button:disabled { opacity: 0.6; cursor: not-allowed; }
        .error {
            background: #FEE2E2;
            color: #991B1B;
            padding: 10px 14px;
            border-radius: 8px;
            font-size: 13px;
            margin-bottom: 16px;
        }
        .success {
            background: #D1FAE5;
            color: #065F46;
            padding: 10px 14px;
            border-radius: 8px;
            font-size: 13px;
            margin-bottom: 16px;
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>Redefinir senha</h1>
        <p class="subtitle">Informe a nova senha abaixo.</p>

        <div id="message">
            @if(!empty($error))
                <div class="error">{{ $error }}</div>
            @endif
        </div>

        @if(!empty($token))
        <form id="resetForm">
            <input type="hidden" name="token" value="{{ $token }}">

            @isset($email)
            <label for="email">E-mail</label>
            <input type="email" id="email" value="{{ $email }}" readonly>
            @endisset

            <label for="password">Nova senha</label>
            <input type="password" id="password" name="password" placeholder="Mínimo de 8 caracteres" required minlength="8">

            <label for="password_confirmation">Confirmar senha</label>
            <input type="password" id="password_confirmation" name="password_confirmation" placeholder="Repita a senha" required minlength="8">

            <button type="submit" id="submitBtn">Redefinir senha</button>
        </form>
        @endif
    </div>

    <script>
        const form = document.getElementById('resetForm');
        if (form) {
            const msg = document.getElementById('message');
            const btn = document.getElementById('submitBtn');

            form.addEventListener('submit', async (e) => {
                e.preventDefault();
                msg.innerHTML = '';
                btn.disabled = true;
                btn.textContent = 'Redefinindo...';

                const body = {
                    token: form.token.value,
                    password: form.password.value,
                    password_confirmation: form.password_confirmation.value,
                };

                try {
                    const res = await fetch('/api/auth/reset-password', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
                        body: JSON.stringify(body),
                    });
                    const data = await res.json();

                    if (res.ok) {
                        msg.innerHTML = '<div class="success">Senha redefinida com sucesso! Você já pode entrar no app com a nova senha.</div>';
                        form.style.display = 'none';
                    } else {
                        msg.innerHTML = '<div class="error">' + (data.message || 'Não foi possível redefinir a senha.') + '</div>';
                        btn.disabled = false;
                        btn.textContent = 'Redefinir senha';
                    }
                } catch {
                    msg.innerHTML = '<div class="error">Erro de conexão. Tente novamente.</div>';
                    btn.disabled = false;
                    btn.textContent = 'Redefinir senha';
                }
            });
        }
    </script>
</body>
</html>
