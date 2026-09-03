<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'user_id',
    'label',
    'details',
    'address',
    'number',
    'city',
    'state',
    'cep',
    'reference_point',
    'latitude',
    'longitude',
])]
class UserAddress extends Model
{
    protected function casts(): array
    {
        return [
            'latitude' => 'decimal:7',
            'longitude' => 'decimal:7',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public static function composeDetails(
        ?string $address,
        ?string $number,
        ?string $city,
        ?string $state,
        ?string $cep,
        ?string $referencePoint = null,
    ): string {
        $street = collect([$address, $number])
            ->filter(fn ($v) => filled(trim((string) $v)))
            ->implode(', ');

        $parts = collect([
            $street,
            $city,
            $state,
            $cep,
            filled($referencePoint) ? 'Ref: '.$referencePoint : null,
        ])->filter(fn ($v) => filled(trim((string) $v)))->values();

        return $parts->implode(' - ');
    }
}
