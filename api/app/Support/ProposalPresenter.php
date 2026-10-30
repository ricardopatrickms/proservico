<?php

namespace App\Support;

use App\Models\ServicePayment;
use App\Models\ServiceProposal;
use App\Models\User;
use Illuminate\Support\Collection;

final class ProposalPresenter
{
    public static function apply(ServiceProposal $proposal, ?User $viewer = null): ServiceProposal
    {
        $fee = PlatformFee::fromProfessionalAmount($proposal->getRawOriginal('amount') ?? $proposal->amount);

        $proposal->setAttribute('professional_amount', $fee['professional_amount']);
        $proposal->setAttribute('platform_fee', $fee['platform_fee']);
        $proposal->setAttribute('client_amount', $fee['total_amount']);
        $proposal->setAttribute('platform_fee_percent', $fee['percent']);

        // Cliente/admin veem o valor com taxa; profissional vê o valor que propôs.
        if ($viewer === null || $viewer->isClient() || $viewer->isAdmin()) {
            $proposal->setAttribute('amount', $fee['total_amount']);
        } else {
            $proposal->setAttribute('amount', $fee['professional_amount']);
        }

        $payment = null;
        if ($proposal->relationLoaded('activePayment')) {
            $payment = $proposal->activePayment;
        } elseif ($proposal->relationLoaded('payments')) {
            $payment = $proposal->payments
                ->whereIn('status', ['pending', 'paid'])
                ->sortByDesc('id')
                ->first();
        }

        if ($payment instanceof ServicePayment) {
            $proposal->setAttribute('payment', [
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
            ]);
        }

        // Evita serializar a relação crua junto com o payload formatado.
        $proposal->makeHidden(['activePayment', 'payments']);

        return $proposal;
    }

    /**
     * @param  Collection<int, ServiceProposal>|iterable<ServiceProposal>  $proposals
     * @return Collection<int, ServiceProposal>
     */
    public static function collection(iterable $proposals, ?User $viewer = null): Collection
    {
        return collect($proposals)
            ->map(fn (ServiceProposal $proposal) => self::apply($proposal, $viewer))
            ->values();
    }
}
