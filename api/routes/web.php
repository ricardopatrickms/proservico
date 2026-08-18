<?php

use App\Http\Controllers\Api\AuthController;
use App\Models\User;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

/**
 * Password reset — clicar no link do e-mail cai aqui.
 * O middleware `signed` valida assinatura e expiração.
 * Após validar o hash do e-mail, gera um token de uso único (30min) para
 * o form consumir no POST /api/auth/reset-password.
 */
Route::get('/password/reset/{id}/{hash}', function (string $id, string $hash) {
    $user = User::find($id);

    if (! $user || ! hash_equals(sha1((string) $user->email), $hash)) {
        return view('auth.reset-password', [
            'token' => null,
            'error' => 'Link inválido ou expirado. Solicite um novo.',
        ]);
    }

    $token = AuthController::issueResetToken((string) $user->id);

    return view('auth.reset-password', [
        'token' => $token,
        'email' => $user->email,
        'error' => null,
    ]);
})
    ->middleware('signed')
    ->name('password.reset');
