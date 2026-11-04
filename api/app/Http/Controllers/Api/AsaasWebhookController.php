<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AsaasWebhookEvent;
use App\Services\Asaas\ServicePaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class AsaasWebhookController extends Controller
{
    public function __invoke(Request $request, ServicePaymentService $payments): JsonResponse
    {
        if (! $this->tokenIsValid($request)) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        $payload = $request->all();
        $event = is_string($payload['event'] ?? null) ? $payload['event'] : null;
        $paymentId = data_get($payload, 'payment.id');
        if (! is_string($paymentId) || $paymentId === '') {
            $paymentId = data_get($payload, 'id');
            $paymentId = is_string($paymentId) ? $paymentId : null;
        }

        $webhookEvent = AsaasWebhookEvent::create([
            'event' => $event,
            'asaas_payment_id' => $paymentId,
            'payload' => $payload,
        ]);

        try {
            $payments->handleWebhookEvent($event, $paymentId, $payload);
            $webhookEvent->forceFill(['processed_at' => now()])->save();
        } catch (\Throwable $e) {
            Log::error('Asaas webhook: falha ao processar', [
                'event' => $event,
                'asaas_payment_id' => $paymentId,
                'message' => $e->getMessage(),
            ]);
        }

        return response()->json(['received' => true]);
    }

    protected function tokenIsValid(Request $request): bool
    {
        $expected = (string) config('asaas.webhook_token');
        if ($expected === '') {
            return false;
        }

        $provided = $request->query('token')
            ?? $request->header('X-Asaas-Webhook-Token')
            ?? $request->header('asaas-access-token');

        return is_string($provided) && hash_equals($expected, $provided);
    }
}
