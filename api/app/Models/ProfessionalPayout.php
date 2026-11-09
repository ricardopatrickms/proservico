<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'service_request_id',
    'service_payment_id',
    'professional_id',
    'amount',
    'status',
    'pix_type',
    'pix_key',
    'bank',
    'agency',
    'account',
    'account_type',
    'admin_notes',
    'paid_by',
    'paid_at',
])]
class ProfessionalPayout extends Model
{
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'paid_at' => 'datetime',
        ];
    }

    public function serviceRequest(): BelongsTo
    {
        return $this->belongsTo(ServiceRequest::class);
    }

    public function servicePayment(): BelongsTo
    {
        return $this->belongsTo(ServicePayment::class);
    }

    public function professional(): BelongsTo
    {
        return $this->belongsTo(User::class, 'professional_id');
    }

    public function paidByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'paid_by');
    }

    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    public function isPaid(): bool
    {
        return $this->status === 'paid';
    }

    public function markPaid(User $admin, ?string $notes = null): void
    {
        if ($this->isPaid()) {
            return;
        }

        $this->forceFill([
            'status' => 'paid',
            'paid_by' => $admin->id,
            'paid_at' => now(),
            'admin_notes' => $notes ?? $this->admin_notes,
        ])->save();
    }
}
