<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\Storage;
use Tymon\JWTAuth\Contracts\JWTSubject;

#[Fillable([
    'name',
    'email',
    'phone',
    'type',
    'city',
    'bio',
    'cpf',
    'approved',
    'password',
    'profile_photo',
])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable implements JWTSubject
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable;

    protected $appends = [
        'profile_photo_url',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'approved' => 'boolean',
        ];
    }

    public function getJWTIdentifier(): mixed
    {
        return $this->getKey();
    }

    public function getJWTCustomClaims(): array
    {
        return [
            'type' => $this->type,
        ];
    }

    public function professionalProfile(): HasOne
    {
        return $this->hasOne(ProfessionalProfile::class);
    }

    public function professionalServices(): HasMany
    {
        return $this->hasMany(ProfessionalService::class);
    }

    public function serviceRequests(): HasMany
    {
        return $this->hasMany(ServiceRequest::class, 'client_id');
    }

    public function assignedServices(): HasMany
    {
        return $this->hasMany(ServiceRequest::class, 'professional_id');
    }

    public function addresses(): HasMany
    {
        return $this->hasMany(UserAddress::class);
    }

    public function getProfilePhotoUrlAttribute(): ?string
    {
        if ($this->profile_photo) {
            return Storage::disk('public')->url($this->profile_photo);
        }

        $professionalPhoto = $this->relationLoaded('professionalProfile')
            ? $this->professionalProfile?->profile_photo
            : null;

        if ($professionalPhoto) {
            return Storage::disk('public')->url($professionalPhoto);
        }

        return null;
    }

    public function isClient(): bool
    {
        return $this->type === 'client';
    }

    public function isProfessional(): bool
    {
        return $this->type === 'professional';
    }

    public function isAdmin(): bool
    {
        return $this->type === 'admin';
    }
}
