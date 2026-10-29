<?php

namespace App\Services\Asaas;

use App\Models\User;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class AsaasClient
{
    public function get(string $path, array $query = []): array
    {
        return $this->request('get', $path, query: $query);
    }

    public function post(string $path, array $payload = []): array
    {
        return $this->request('post', $path, payload: $payload);
    }

    public function put(string $path, array $payload = []): array
    {
        return $this->request('put', $path, payload: $payload);
    }

    /**
     * Garante customer Asaas para o usuário e persiste `asaas_customer_id`.
     * Exige CPF/CNPJ — obrigatório para criar cobrança no Asaas.
     */
    public function ensureCustomer(User $user): string
    {
        $cpf = User::normalizeCpf($user->cpf);
        if ($cpf === null) {
            throw new AsaasException('Informe o CPF para criar a cobrança.');
        }

        if (filled($user->asaas_customer_id)) {
            $this->syncCustomerCpf((string) $user->asaas_customer_id, $user);

            return (string) $user->asaas_customer_id;
        }

        $existingId = $this->findCustomerId($user);
        if ($existingId !== null) {
            $this->syncCustomerCpf($existingId, $user);
            $user->forceFill(['asaas_customer_id' => $existingId])->save();

            return $existingId;
        }

        $payload = $this->customerPayload($user);
        $created = $this->post('/customers', $payload);
        $id = $created['id'] ?? null;

        if (! is_string($id) || $id === '') {
            throw new AsaasException('Resposta Asaas sem id de customer.', response: $created);
        }

        $user->forceFill(['asaas_customer_id' => $id])->save();

        return $id;
    }

    /**
     * Atualiza o customer Asaas com CPF (e dados básicos) quando já existe.
     */
    protected function syncCustomerCpf(string $customerId, User $user): void
    {
        $this->put('/customers/'.$customerId, $this->customerPayload($user));
    }

    /**
     * Tenta sincronizar sem interromper o fluxo do app.
     */
    public function tryEnsureCustomer(User $user): ?string
    {
        try {
            return $this->ensureCustomer($user);
        } catch (AsaasException $e) {
            Log::warning('Asaas: falha ao sincronizar customer', [
                'user_id' => $user->id,
                'message' => $e->getMessage(),
                'status' => $e->status,
            ]);

            return null;
        } catch (\Throwable $e) {
            Log::warning('Asaas: erro inesperado ao sincronizar customer', [
                'user_id' => $user->id,
                'message' => $e->getMessage(),
            ]);

            return null;
        }
    }

    protected function findCustomerId(User $user): ?string
    {
        $cpf = User::normalizeCpf($user->cpf);
        if ($cpf !== null) {
            $byCpf = $this->get('/customers', ['cpfCnpj' => $cpf]);
            $id = $byCpf['data'][0]['id'] ?? null;
            if (is_string($id) && $id !== '') {
                return $id;
            }
        }

        if (filled($user->email)) {
            $byEmail = $this->get('/customers', ['email' => $user->email]);
            $id = $byEmail['data'][0]['id'] ?? null;
            if (is_string($id) && $id !== '') {
                return $id;
            }
        }

        return null;
    }

    /**
     * @return array<string, mixed>
     */
    protected function customerPayload(User $user): array
    {
        $payload = [
            'name' => $user->name,
            'email' => $user->email,
            'externalReference' => (string) $user->id,
            'notificationDisabled' => true,
        ];

        $cpf = User::normalizeCpf($user->cpf);
        if ($cpf !== null) {
            $payload['cpfCnpj'] = $cpf;
        } else {
            throw new AsaasException('Informe o CPF para criar a cobrança.');
        }

        $phone = preg_replace('/\D+/', '', (string) $user->phone);
        if (is_string($phone) && strlen($phone) >= 10) {
            $payload['mobilePhone'] = $phone;
            $payload['phone'] = $phone;
        }

        return $payload;
    }

    /**
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $query
     * @return array<string, mixed>
     */
    protected function request(string $method, string $path, array $payload = [], array $query = []): array
    {
        $apiKey = config('asaas.api_key');
        if (! filled($apiKey)) {
            throw new AsaasException('ASAAS_API_KEY não configurada.');
        }

        $url = rtrim((string) config('asaas.base_url'), '/').'/'.ltrim($path, '/');

        /** @var Response $response */
        $response = $this->http()->{$method}($url, $method === 'get' ? $query : $payload);

        $json = $response->json();
        $body = is_array($json) ? $json : [];

        if ($response->failed()) {
            $message = $this->errorMessage($body) ?? 'Falha na comunicação com o Asaas.';

            Log::error('Asaas API error', [
                'method' => strtoupper($method),
                'path' => $path,
                'status' => $response->status(),
                'errors' => $body['errors'] ?? null,
            ]);

            throw new AsaasException($message, $response->status(), $body);
        }

        return $body;
    }

    protected function http(): PendingRequest
    {
        return Http::withHeaders([
            'access_token' => (string) config('asaas.api_key'),
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
        ])
            ->timeout(20)
            ->acceptJson();
    }

    /**
     * @param  array<string, mixed>  $body
     */
    protected function errorMessage(array $body): ?string
    {
        $errors = $body['errors'] ?? null;
        if (! is_array($errors) || $errors === []) {
            return is_string($body['message'] ?? null) ? $body['message'] : null;
        }

        $first = $errors[0] ?? null;
        if (is_array($first) && is_string($first['description'] ?? null)) {
            return $first['description'];
        }

        return 'Falha na comunicação com o Asaas.';
    }
}
