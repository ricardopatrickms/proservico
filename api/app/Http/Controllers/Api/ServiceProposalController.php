<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ServicePayment;
use App\Models\ServiceProposal;
use App\Models\ServiceRequest;
use App\Models\User;
use App\Services\Asaas\AsaasException;
use App\Services\Asaas\ServicePaymentService;
use App\Support\ProposalPresenter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class ServiceProposalController extends Controller
{
    public function index(ServiceRequest $serviceRequest): JsonResponse
    {
        $this->authorizeView($serviceRequest);

        $user = Auth::guard('api')->user();

        $proposals = $serviceRequest->proposals()
            ->when($user->isProfessional(), fn ($q) => $q->where('professional_id', $user->id))
            ->with('professional:id,name,email,phone')
            ->latest()
            ->get();

        return response()->json(
            ProposalPresenter::collection($proposals, $user)
        );
    }

    public function store(Request $request, ServiceRequest $serviceRequest): JsonResponse
    {
        $user = Auth::guard('api')->user();

        if (! $user->isProfessional()) {
            return response()->json(['message' => 'Apenas profissionais podem enviar propostas'], 403);
        }

        if ($serviceRequest->status !== 'pending' || $serviceRequest->professional_id !== null) {
            return response()->json(['message' => 'Esta solicitação não está disponível para propostas'], 422);
        }

        if (! $user->servesCity($serviceRequest->city)) {
            return response()->json([
                'message' => 'Você só pode enviar propostas para solicitações da mesma cidade do seu cadastro.',
            ], 422);
        }

        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01'],
            'message' => ['nullable', 'string', 'max:2000'],
        ]);

        $proposal = ServiceProposal::updateOrCreate(
            [
                'service_request_id' => $serviceRequest->id,
                'professional_id' => $user->id,
            ],
            [
                'amount' => $data['amount'],
                'message' => $data['message'] ?? '',
                'status' => 'pending',
            ]
        );

        $proposal->load('professional:id,name,email,phone');

        return response()->json(
            ProposalPresenter::apply($proposal, $user),
            201
        );
    }

    public function updateStatus(
        Request $request,
        ServiceRequest $serviceRequest,
        ServiceProposal $proposal,
        ServicePaymentService $payments,
    ): JsonResponse {
        $user = Auth::guard('api')->user();

        if (! $user->isClient() || $serviceRequest->client_id !== $user->id) {
            return response()->json(['message' => 'Apenas o cliente da solicitação pode responder propostas'], 403);
        }

        if ($proposal->service_request_id !== $serviceRequest->id) {
            return response()->json(['message' => 'Proposta inválida para esta solicitação'], 422);
        }

        $data = $request->validate([
            'status' => ['required', 'in:accepted,rejected'],
            'billing_type' => ['nullable', 'in:PIX,CREDIT_CARD'],
            'cpf' => ['nullable', 'string', 'max:14'],
            'credit_card' => ['nullable', 'array'],
            'credit_card.holder_name' => ['required_with:credit_card', 'string', 'max:120'],
            'credit_card.number' => ['required_with:credit_card', 'string', 'min:13', 'max:19'],
            'credit_card.expiry_month' => ['required_with:credit_card', 'string', 'max:2'],
            'credit_card.expiry_year' => ['required_with:credit_card', 'string', 'max:4'],
            'credit_card.ccv' => ['required_with:credit_card', 'string', 'min:3', 'max:4'],
            'credit_card.cpf' => ['required_with:credit_card', 'string', 'max:14'],
            'credit_card.postal_code' => ['nullable', 'string', 'max:12'],
            'credit_card.address_number' => ['nullable', 'string', 'max:20'],
            'credit_card.phone' => ['nullable', 'string', 'max:20'],
            'credit_card.email' => ['nullable', 'email', 'max:255'],
        ]);

        if ($proposal->status !== 'pending') {
            return response()->json(['message' => 'Esta proposta já foi respondida'], 422);
        }

        if ($data['status'] === 'rejected') {
            $proposal->status = 'rejected';
            $proposal->save();

            return response()->json(
                ProposalPresenter::apply(
                    $proposal->fresh()->load('professional:id,name,email,phone'),
                    $user
                )
            );
        }

        $billingType = $data['billing_type'] ?? ServicePaymentService::BILLING_PIX;
        if ($billingType === ServicePaymentService::BILLING_CREDIT_CARD && empty($data['credit_card'])) {
            return response()->json([
                'message' => 'Informe os dados do cartão para concluir o pagamento.',
            ], 422);
        }

        $cpf = User::normalizeCpf($data['cpf'] ?? null)
            ?? User::normalizeCpf($data['credit_card']['cpf'] ?? null)
            ?? User::normalizeCpf($user->cpf);

        if ($cpf === null) {
            return response()->json([
                'message' => 'Informe o CPF para criar a cobrança.',
            ], 422);
        }

        if (User::cpfTaken($cpf, $user->id)) {
            throw ValidationException::withMessages([
                'cpf' => ['Este CPF já está cadastrado.'],
            ]);
        }

        if (User::normalizeCpf($user->cpf) !== $cpf) {
            $user->forceFill(['cpf' => $cpf])->save();
        }

        DB::transaction(function () use ($serviceRequest, $proposal) {
            $proposal->status = 'accepted';
            $proposal->save();

            ServiceProposal::query()
                ->where('service_request_id', $serviceRequest->id)
                ->where('id', '!=', $proposal->id)
                ->where('status', 'pending')
                ->update(['status' => 'rejected']);

            // Aguarda pagamento confirmado (webhook ou cartão aprovado na hora).
            $serviceRequest->forceFill([
                'professional_id' => $proposal->professional_id,
                'status' => 'awaiting_payment',
            ])->save();
        });

        try {
            $payment = $payments->createForAcceptedProposal(
                $serviceRequest->fresh(),
                $proposal->fresh(),
                $user->fresh(),
                $billingType,
                $data['credit_card'] ?? null,
                $request->ip(),
            );
        } catch (AsaasException $e) {
            Log::error('Asaas: falha ao criar cobrança no aceite', [
                'proposal_id' => $proposal->id,
                'billing_type' => $billingType,
                'message' => $e->getMessage(),
                'status' => $e->status,
            ]);

            DB::transaction(function () use ($serviceRequest, $proposal) {
                $proposal->status = 'pending';
                $proposal->save();

                $serviceRequest->forceFill([
                    'professional_id' => null,
                    'status' => 'pending',
                ])->save();

                ServiceProposal::query()
                    ->where('service_request_id', $serviceRequest->id)
                    ->where('id', '!=', $proposal->id)
                    ->where('status', 'rejected')
                    ->update(['status' => 'pending']);
            });

            return response()->json([
                'message' => $e->getMessage() !== ''
                    ? $e->getMessage()
                    : 'Não foi possível gerar o pagamento. Tente novamente.',
            ], 502);
        }

        $presented = ProposalPresenter::apply(
            $proposal->fresh()->load('professional:id,name,email,phone'),
            $user
        );

        return response()->json([
            ...$presented->toArray(),
            'payment' => $this->presentPayment($payment),
        ]);
    }

    public function payment(
        Request $request,
        ServiceRequest $serviceRequest,
        ServiceProposal $proposal,
        ServicePaymentService $payments,
    ): JsonResponse {
        $user = Auth::guard('api')->user();

        if (! $user->isClient() || $serviceRequest->client_id !== $user->id) {
            return response()->json(['message' => 'Acesso negado'], 403);
        }

        if ($proposal->service_request_id !== $serviceRequest->id) {
            return response()->json(['message' => 'Proposta inválida'], 422);
        }

        $forceRenew = $request->boolean('renew');

        $paid = ServicePayment::query()
            ->where('service_proposal_id', $proposal->id)
            ->where('status', 'paid')
            ->latest('id')
            ->first();

        if ($paid) {
            return response()->json($this->presentPayment($paid));
        }

        $pending = ServicePayment::query()
            ->where('service_proposal_id', $proposal->id)
            ->where('status', 'pending')
            ->latest('id')
            ->first();

        try {
            if (
                $forceRenew
                || ! $pending
                || strtoupper((string) ($pending->billing_type ?? '')) === 'PIX'
            ) {
                $payment = $payments->ensureActivePixPayment(
                    $serviceRequest->fresh(),
                    $proposal->fresh(),
                    $user->fresh(),
                    $forceRenew,
                    $request->ip(),
                );
            } else {
                $payment = $payments->syncStatusFromAsaas($pending);
            }
        } catch (AsaasException $e) {
            return response()->json([
                'message' => $e->getMessage() !== ''
                    ? $e->getMessage()
                    : 'Não foi possível obter o pagamento.',
            ], 502);
        }

        return response()->json($this->presentPayment($payment));
    }

    /**
     * @return array<string, mixed>
     */
    protected function presentPayment(ServicePayment $payment): array
    {
        return [
            'id' => $payment->id,
            'status' => $payment->status,
            'billing_type' => $payment->billing_type,
            'professional_amount' => (float) $payment->professional_amount,
            'platform_fee' => (float) $payment->platform_fee,
            'total_amount' => (float) $payment->total_amount,
            'asaas_payment_id' => $payment->asaas_payment_id,
            'asaas_status' => $payment->asaas_status,
            'pix_copy_paste' => $payment->pix_copy_paste,
            'pix_qr_code_base64' => $payment->pix_qr_code_base64,
            'invoice_url' => $payment->invoice_url,
            'paid_at' => $payment->paid_at?->toIso8601String(),
        ];
    }

    protected function authorizeView(ServiceRequest $serviceRequest): void
    {
        $user = Auth::guard('api')->user();

        if ($user->isAdmin()) {
            return;
        }

        if ($user->isClient() && $serviceRequest->client_id === $user->id) {
            return;
        }

        if ($user->isProfessional() && (
            $serviceRequest->professional_id === $user->id
            || (
                $serviceRequest->professional_id === null
                && $serviceRequest->status === 'pending'
                && $user->servesCity($serviceRequest->city)
            )
        )) {
            return;
        }

        abort(403, 'Acesso negado');
    }
}
