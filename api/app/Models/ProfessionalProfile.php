<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

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
    protected $appends = [
        'id_document_url',
        'certificate_url',
        'criminal_record_url',
        'profile_photo_url',
    ];

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

    public function getIdDocumentUrlAttribute(): ?string
    {
        return $this->publicUrl($this->id_document);
    }

    public function getCertificateUrlAttribute(): ?string
    {
        return $this->publicUrl($this->certificate);
    }

    public function getCriminalRecordUrlAttribute(): ?string
    {
        return $this->publicUrl($this->criminal_record);
    }

    public function getProfilePhotoUrlAttribute(): ?string
    {
        return $this->publicUrl($this->profile_photo);
    }

    protected function publicUrl(?string $path): ?string
    {
        if (! $path) {
            return null;
        }

        return Storage::disk('public')->url($path);
    }
}
