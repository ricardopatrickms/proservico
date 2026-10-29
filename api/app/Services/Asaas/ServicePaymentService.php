<?php

namespace App\Services\Asaas;

use App\Models\ServicePayment;
use App\Models\ServiceProposal;
use App\Models\ServiceRequest;
use App\Models\User;
use App\Support\PlatformFee;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class ServicePaymentService
{
    public const BILLING_PIX = 'PIX';

    public const BILLING_CREDIT_CARD = 'CREDIT_CARD';

    public function __construct(private readonly AsaasClient $asaas) {}

    /**
     * Cria cobrança PIX ou cartão (dados do cartão no app, sem redirect Asaas).
     *
     * @param  array<string, mixed>|null  $creditCard
     */
    public function createForAcceptedProposal(
        ServiceRequest $serviceRequest,
        ServiceProposal $proposal,
        User $client,
        string $billingType = self::BILLING_PIX,
        ?array $creditCard = null,
        ?string $remoteIp = null,
    ): ServicePayment {
        $billingType = strtoupper($billingType);
        if (! in_array($billingType, [self::BILLING_PIX, self::BILLING_CREDIT_CARD], true)) {
            throw new AsaasException('Forma de pagamento inválida.');
        }

        if ($billingType === self::BILLING_CREDIT_CARD && empty($creditCard)) {
            throw new AsaasException('Dados do cartão são obrigatórios.');
        }

        $existing = ServicePayment::query()
            ->where('service_proposal_id', $proposal->id)
            ->whereIn('status', ['pending', 'paid'])
            ->latest('id')
            ->first();

        if ($existing?->isPaid()) {
            return $existing;
        }

        if (
            $existing
            && filled($existing->asaas_payment_id)
            && $existing->status === 'pending'
            && strtoupper((string) $existing->billing_type) === self::BILLING_PIX
            && $billingType === self::BILLING_PIX
        ) {
            return $this->refreshPixData($existing);
        }

        $fee = PlatformFee::fromProfessionalAmount($proposal->getRawOriginal('amount') ?? $proposal->amount);
        $customerId = $this->asaas->ensureCustomer($client);

        $payload = [
            'customer' => $customerId,
            'billingType' => $billingType,
            'value' => $fee['total_amount'],
            'dueDate' => now()->addDays(1)->toDateString(),
            'description' => 'ProServiço #'.$serviceRequest->id.' — '.$serviceRequest->title,
            'externalReference' => 'proposal:'.$proposal->id,
        ];

        if ($billingType === self::BILLING_CREDIT_CARD) {
            $payload['creditCard'] = [
                'holderName' => (string) ($creditCard['holder_name'] ?? ''),
                'number' => preg_replace('/\D+/', '', (string) ($creditCard['number'] ?? '')),
                'expiryMonth' => str_pad((string) ($creditCard['expiry_month'] ?? ''), 2, '0', STR_PAD_LEFT),
                'expiryYear' => (string) ($creditCard['expiry_year'] ?? ''),
                'ccv' => (string) ($creditCard['ccv'] ?? ''),
            ];
            $payload['creditCardHolderInfo'] = [
                'name' => (string) ($creditCard['holder_name'] ?? $client->name),
                'email' => (string) ($creditCard['email'] ?? $client->email),
                'cpfCnpj' => preg_replace('/\D+/', '', (string) ($creditCard['cpf'] ?? $client->cpf ?? '')),
                'postalCode' => preg_replace('/\D+/', '', (string) ($creditCard['postal_code'] ?? $serviceRequest->cep ?? '')),
                'addressNumber' => (string) ($creditCard['address_number'] ?? $serviceRequest->number ?? 'S/N'),
                'phone' => preg_replace('/\D+/', '', (string) ($creditCard['phone'] ?? $client->phone ?? '')),
            ];
            $payload['remoteIp'] = $remoteIp ?: request()->ip() ?: '127.0.0.1';
        }

        $payment = $this->asaas->post('/payments', $payload);

        $asaasPaymentId = $payment['id'] ?? null;
        if (! is_string($asaasPaymentId) || $asaasPaymentId === '') {
            throw new AsaasException('Asaas não retornou id da cobrança.', response: $payment);
        }

        $pixCopy = null;
        $pixQr = null;
        if ($billingType === self::BILLING_PIX) {
            $pix = $this->fetchPixQrCode($asaasPaymentId);
            $pixCopy = $pix['payload'] ?? null;
            $pixQr = $pix['encodedImage'] ?? null;
        }

        $asaasStatus = strtoupper((string) ($payment['status'] ?? 'PENDING'));
        $isPaidNow = in_array($asaasStatus, ['CONFIRMED', 'RECEIVED'], true);

        $record = ServicePayment::create([
            'service_request_id' => $serviceRequest->id,
            'service_proposal_id' => $proposal->id,
            'client_id' => $client->id,
            'professional_id' => $proposal->professional_id,
            'professional_amount' => $fee['professional_amount'],
            'platform_fee' => $fee['platform_fee'],
            'total_amount' => $fee['total_amount'],
            'status' => $isPaidNow ? 'paid' : 'pending',
            'billing_type' => $billingType,
            'asaas_payment_id' => $asaasPaymentId,
            'asaas_status' => $payment['status'] ?? 'PENDING',
            'pix_copy_paste' => $pixCopy,
            'pix_qr_code_base64' => $pixQr,
            'invoice_url' => $payment['invoiceUrl'] ?? null,
            'paid_at' => $isPaidNow ? now() : null,
        ]);

        if ($isPaidNow) {
            $serviceRequest->forceFill([
                'professional_id' => $proposal->professional_id,
                'status' => 'in_progress',
            ])->save();
        }

        return $record;
    }

    public function refreshPixData(ServicePayment $payment): ServicePayment
    {
        if (! filled($payment->asaas_payment_id)) {
            return $payment;
        }

        if (strtoupper((string) $payment->billing_type) !== self::BILLING_PIX) {
            return $payment;
        }

        try {
            $pix = $this->fetchPixQrCode((string) $payment->asaas_payment_id);
            $payment->forceFill([
                'pix_copy_paste' => $pix['payload'] ?? $payment->pix_copy_paste,
                'pix_qr_code_base64' => $pix['encodedImage'] ?? $payment->pix_qr_code_base64,
            ])->save();
        } catch (AsaasException $e) {
            Log::warning('Asaas: falha ao atualizar QR PIX', [
                'payment_id' => $payment->id,
                'message' => $e->getMessage(),
            ]);
        }

        return $payment->fresh();
    }

    public function handleWebhookEvent(?string $event, ?string $asaasPaymentId, array $payload): void
    {
        if ($asaasPaymentId === null || $asaasPaymentId === '') {
            return;
        }

        $payment = ServicePayment::query()
            ->where('asaas_payment_id', $asaasPaymentId)
            ->first();

        if (! $payment) {
            return;
        }

        $asaasStatus = data_get($payload, 'payment.status');
        if (is_string($asaasStatus)) {
            $payment->asaas_status = $asaasStatus;
            $payment->save();
        }

        $isPaidEvent = in_array($event, ['PAYMENT_RECEIVED', 'PAYMENT_CONFIRMED'], true)
            || in_array(strtoupper((string) $asaasStatus), ['RECEIVED', 'CONFIRMED'], true);

        if (! $isPaidEvent) {
            return;
        }

        DB::transaction(function () use ($payment, $asaasStatus) {
            $payment = ServicePayment::query()->lockForUpdate()->find($payment->id);
            if (! $payment || $payment->isPaid()) {
                return;
            }

            $payment->markPaid(is_string($asaasStatus) ? $asaasStatus : null);

            $serviceRequest = ServiceRequest::query()->lockForUpdate()->find($payment->service_request_id);
            if (! $serviceRequest) {
                return;
            }

            $serviceRequest->forceFill([
                'professional_id' => $payment->professional_id,
                'status' => 'in_progress',
            ])->save();
        });
    }

    /**
     * @return array<string, mixed>
     */
    protected function fetchPixQrCode(string $asaasPaymentId): array
    {
        return $this->asaas->get('/payments/'.$asaasPaymentId.'/pixQrCode');
    }
}
