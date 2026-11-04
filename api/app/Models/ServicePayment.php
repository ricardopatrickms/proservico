<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'service_request_id',
    'service_proposal_id',
    'client_id',
    'professional_id',
    'professional_amount',
    'platform_fee',
    'total_amount',
    'status',
    'billing_type',
    'asaas_payment_id',
    'asaas_status',
    'pix_copy_paste',
    'pix_qr_code_base64',
    'invoice_url',
    'paid_at',
])]
class ServicePayment extends Model
{
    protected function casts(): array
    {
        return [
            'professional_amount' => 'decimal:2',
            'platform_fee' => 'decimal:2',
            'total_amount' => 'decimal:2',
            'paid_at' => 'datetime',
        ];
    }

    public function serviceRequest(): BelongsTo
    {
        return $this->belongsTo(ServiceRequest::class);
    }

    public function proposal(): BelongsTo
    {
        return $this->belongsTo(ServiceProposal::class, 'service_proposal_id');
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(User::class, 'client_id');
    }

    public function professional(): BelongsTo
    {
        return $this->belongsTo(User::class, 'professional_id');
    }

    public function isPaid(): bool
    {
        return $this->status === 'paid';
    }

    public function markPaid(?string $asaasStatus = null): void
    {
        if ($this->isPaid()) {
            return;
        }

        $this->forceFill([
            'status' => 'paid',
            'asaas_status' => $asaasStatus ?? $this->asaas_status,
            'paid_at' => now(),
        ])->save();
    }
}
