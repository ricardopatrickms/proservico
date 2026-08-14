<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'user_id',
    'category',
    'profession',
    'experience',
    'region',
    'bank',
    'agency',
    'account',
    'account_type',
    'pix_type',
    'pix_key',
    'id_document',
    'certificate',
    'criminal_record',
    'profile_photo',
    'service_areas',
])]
class ProfessionalProfile extends Model
{
    protected function casts(): array
    {
        return [
            'service_areas' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
