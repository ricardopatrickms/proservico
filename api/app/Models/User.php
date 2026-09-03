<?php

namespace App\Models;

use App\Enums\UserStatus;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tymon\JWTAuth\Contracts\JWTSubject;

#[Fillable([
    'name',
    'email',
    'phone',
    'type',
    'city',
    'bio',
    'cpf',
    'status',
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
        'approved',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'status' => UserStatus::class,
        ];
    }

    public function getApprovedAttribute(): bool
    {
        return $this->isActive();
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

    public function isActive(): bool
    {
        return $this->status === UserStatus::Ativo;
    }

    public function isPending(): bool
    {
        return $this->status === UserStatus::Pendente;
    }

    /**
     * Profissional só atende pedidos da mesma cidade (perfil, região ou endereços salvos).
     */
    public function servesCity(?string $city): bool
    {
        $target = static::normalizeCityName($city);
        if ($target === null) {
            return false;
        }

        return in_array($target, $this->servingCities(), true);
    }

    /**
     * @return list<string>
     */
    public function servingCities(): array
    {
        $this->loadMissing(['addresses', 'professionalProfile']);

        $cities = collect([
            $this->city,
            $this->professionalProfile?->region,
            ...$this->addresses->pluck('city')->all(),
        ])
            ->map(fn ($city) => static::normalizeCityName(is_string($city) ? $city : null))
            ->filter()
            ->unique()
            ->values()
            ->all();

        return $cities;
    }

    public static function normalizeCityName(?string $city): ?string
    {
        $value = trim((string) $city);
        if ($value === '') {
            return null;
        }

        $value = Str::ascii($value);
        $value = preg_replace('/[\s]*[\/,.\-–—][\s]*[A-Za-z]{2}$/', '', $value) ?? $value;
        $value = Str::lower(trim(preg_replace('/\s+/', ' ', $value) ?? $value));

        return $value === '' ? null : $value;
    }

    public function isBlockedFromAccess(): bool
    {
        return in_array($this->status, [
            UserStatus::Inativo,
            UserStatus::Excluido,
            UserStatus::Rejeitado,
        ], true);
    }

    public function accessDeniedMessage(): string
    {
        return match ($this->status) {
            UserStatus::Rejeitado => 'Cadastro profissional rejeitado',
            UserStatus::Excluido => 'Cadastro excluído',
            UserStatus::Inativo => 'Conta inativa',
            default => 'Acesso não permitido',
        };
    }

    public static function normalizeCpf(?string $cpf): ?string
    {
        $digits = preg_replace('/\D+/', '', (string) $cpf);

        return $digits === '' ? null : $digits;
    }

    /**
     * @param  Builder<User>  $query
     * @return Builder<User>
     */
    public function scopeWithCpf(Builder $query, string $cpf): Builder
    {
        $digits = static::normalizeCpf($cpf);
        if ($digits === null) {
            return $query->whereRaw('1 = 0');
        }

        return $query->whereRaw(
            "REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(cpf, ''), '.', ''), '-', ''), '/', ''), ' ', '') = ?",
            [$digits]
        );
    }

    public static function findByCpf(string $cpf): ?self
    {
        return static::query()->withCpf($cpf)->first();
    }

    public static function emailTaken(string $email, ?int $ignoreUserId = null): bool
    {
        return static::query()
            ->where('email', $email)
            ->when($ignoreUserId, fn (Builder $query) => $query->where('id', '!=', $ignoreUserId))
            ->whereNotIn('status', [UserStatus::Rejeitado, UserStatus::Excluido])
            ->exists();
    }

    public static function cpfTaken(string $cpf, ?int $ignoreUserId = null): bool
    {
        return static::query()
            ->withCpf($cpf)
            ->when($ignoreUserId, fn (Builder $query) => $query->where('id', '!=', $ignoreUserId))
            ->whereNotIn('status', [UserStatus::Rejeitado, UserStatus::Excluido])
            ->exists();
    }

    protected function cpf(): Attribute
    {
        return Attribute::make(
            set: fn (?string $value) => static::normalizeCpf($value),
        );
    }
}
