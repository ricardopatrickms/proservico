<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Storage;

#[Fillable([
    'client_id',
    'professional_id',
    'title',
    'category',
    'description',
    'location',
    'address',
    'city',
    'state',
    'cep',
    'reference_point',
    'scheduled_at',
    'preferred_period',
    'budget',
    'budget_min',
    'budget_max',
    'accepts_negotiation',
    'needs_materials',
    'materials_responsible',
    'materials_details',
    'urgency',
    'preferences',
    'prefers_good_ratings',
    'gender_preference',
    'photo_labels',
    'photos',
    'status',
])]
class ServiceRequest extends Model
{
    protected $appends = [
        'photo_urls',
    ];

    protected function casts(): array
    {
        return [
            'scheduled_at' => 'datetime',
            'budget' => 'decimal:2',
            'budget_min' => 'decimal:2',
            'budget_max' => 'decimal:2',
            'accepts_negotiation' => 'boolean',
            'needs_materials' => 'boolean',
            'prefers_good_ratings' => 'boolean',
            'photo_labels' => 'array',
            'photos' => 'array',
        ];
    }

    public function getPhotoUrlsAttribute(): array
    {
        return collect($this->photos ?? [])
            ->filter()
            ->map(fn (string $path) => Storage::disk('public')->url($path))
            ->values()
            ->all();
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(User::class, 'client_id');
    }

    public function professional(): BelongsTo
    {
        return $this->belongsTo(User::class, 'professional_id');
    }

    public function proposals(): HasMany
    {
        return $this->hasMany(ServiceProposal::class);
    }
}
