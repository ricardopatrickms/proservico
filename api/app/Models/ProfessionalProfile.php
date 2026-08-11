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
])]
class ProfessionalProfile extends Model
{
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
