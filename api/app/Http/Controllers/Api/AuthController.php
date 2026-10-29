<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserStatus;
use App\Http\Controllers\Controller;
use App\Models\ProfessionalProfile;
use App\Models\User;
use App\Notifications\ResetPassword;
use App\Services\Asaas\AsaasClient;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Exists;
use Illuminate\Validation\Rules\Password;
use Tymon\JWTAuth\Exceptions\JWTException;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $request->merge([
            'phone' => preg_replace('/\D+/', '', (string) $request->input('phone', '')),
            'cpf' => filled($request->input('cpf'))
                ? preg_replace('/\D+/', '', (string) $request->input('cpf'))
                : null,
        ]);
        $this->decodeServiceCategoryIds($request);

        $isProfessional = $request->input('type') === 'professional';

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => [
                'required',
                'email',
                'max:255',
                Rule::unique('users', 'email')->whereNotIn('status', [
                    UserStatus::Rejeitado->value,
                    UserStatus::Excluido->value,
                ]),
            ],
            'phone' => ['required', 'string', 'min:10', 'max:15'],
            'password' => ['required', 'confirmed', Password::defaults()],
            'type' => ['required', Rule::in(['client', 'professional'])],
            'city' => ['nullable', 'string', 'max:255'],
            'cpf' => [
                Rule::requiredIf($isProfessional),
                'nullable',
                'string',
                'size:11',
                function (string $attribute, mixed $value, \Closure $fail): void {
                    if (! is_string($value) || $value === '') {
                        return;
                    }

                    if (User::cpfTaken($value)) {
                        $fail('Este CPF já está cadastrado.');
                    }
                },
            ],
            'bio' => ['nullable', 'string'],
            'service_category_ids' => [Rule::requiredIf($isProfessional), 'nullable', 'array', 'min:1'],
            'service_category_ids.*' => ['integer', $this->rootCategoryExists()],
            'profession' => [Rule::requiredIf($isProfessional), 'nullable', 'string', 'max:255'],
            'experience' => [Rule::requiredIf($isProfessional), 'nullable', 'string', 'max:255'],
            'region' => [Rule::requiredIf($isProfessional), 'nullable', 'string', 'max:255'],
            'bank' => [Rule::requiredIf($isProfessional), 'nullable', 'string', 'max:255'],
            'agency' => [Rule::requiredIf($isProfessional), 'nullable', 'string', 'max:50'],
            'account' => [Rule::requiredIf($isProfessional), 'nullable', 'string', 'max:50'],
            'account_type' => [Rule::requiredIf($isProfessional), 'nullable', 'string', 'max:50'],
            'pix_type' => ['nullable', 'string', 'max:50'],
            'pix_key' => ['nullable', 'string', 'max:255'],
            'id_document' => [
                Rule::requiredIf($isProfessional),
                'nullable',
                'file',
                'mimes:pdf,jpg,jpeg,png',
                'max:5120',
            ],
            'certificate' => [
                Rule::requiredIf($isProfessional),
                'nullable',
                'file',
                'mimes:pdf,jpg,jpeg,png',
                'max:5120',
            ],
            'criminal_record' => [
                Rule::requiredIf($isProfessional),
                'nullable',
                'file',
                'mimes:pdf,jpg,jpeg,png',
                'max:5120',
            ],
            'profile_photo' => [
                Rule::requiredIf($isProfessional),
                'nullable',
                'file',
                'mimes:jpg,jpeg,png',
                'max:2048',
            ],
        ], [
            'email.unique' => 'Este e-mail já está cadastrado.',
            'cpf.unique' => 'Este CPF já está cadastrado.',
            'cpf.size' => 'Informe um CPF válido com 11 dígitos.',
            'cpf.required' => 'O CPF é obrigatório.',
            'phone.min' => 'Informe um telefone válido.',
            'phone.max' => 'Informe um telefone válido.',
            'password.confirmed' => 'A confirmação da senha não confere.',
            'id_document.required' => 'O documento de identidade é obrigatório.',
            'certificate.required' => 'O certificado profissional é obrigatório.',
            'criminal_record.required' => 'A certidão de antecedentes criminais é obrigatória.',
            'profile_photo.required' => 'A foto de perfil é obrigatória.',
            'service_category_ids.required' => 'Selecione ao menos uma categoria.',
            'service_category_ids.min' => 'Selecione ao menos uma categoria.',
            'service_category_ids.*.exists' => 'Categoria inválida.',
        ]);

        $existing = isset($data['cpf'])
            ? User::query()
                ->withCpf($data['cpf'])
                ->whereIn('status', [UserStatus::Rejeitado, UserStatus::Excluido])
                ->first()
            : null;

        $payload = [
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'],
            'password' => $data['password'],
            'type' => $data['type'],
            'city' => $data['city'] ?? null,
            'cpf' => $data['cpf'] ?? null,
            'bio' => $data['bio'] ?? null,
            'status' => $data['type'] === 'professional' ? UserStatus::Pendente : UserStatus::Ativo,
        ];

        if ($existing) {
            $existing->professionalProfile()->delete();
            $existing->professionalServices()->delete();
            $existing->fill($payload);
            $existing->save();
            $user = $existing->fresh();
        } else {
            $user = User::create($payload);
        }

        if ($user->isProfessional()) {
            try {
                $folder = 'professionals/'.$user->id;

                $profile = ProfessionalProfile::create([
                    'user_id' => $user->id,
                    'profession' => $data['profession'] ?? null,
                    'experience' => $data['experience'] ?? null,
                    'region' => $data['region'] ?? null,
                    'bank' => $data['bank'] ?? null,
                    'agency' => $data['agency'] ?? null,
                    'account' => $data['account'] ?? null,
                    'account_type' => $data['account_type'] ?? null,
                    'pix_type' => $data['pix_type'] ?? null,
                    'pix_key' => $data['pix_key'] ?? null,
                    'id_document' => $request->file('id_document')->store($folder.'/documents', 'public'),
                    'certificate' => $request->file('certificate')->store($folder.'/documents', 'public'),
                    'criminal_record' => $request->file('criminal_record')->store($folder.'/documents', 'public'),
                    'profile_photo' => $request->file('profile_photo')->store($folder.'/photos', 'public'),
                ]);
                $profile->serviceCategories()->sync($data['service_category_ids']);
            } catch (\Throwable $e) {
                $user->delete();

                throw $e;
            }
        }

        app(AsaasClient::class)->tryEnsureCustomer($user->fresh());

        $token = Auth::guard('api')->login($user);
        $pendingApproval = $user->isProfessional() && $user->isPending();

        return response()->json([
            'message' => $pendingApproval
                ? 'Cadastro enviado com sucesso. Aguarde a aprovação.'
                : 'Cadastro realizado com sucesso',
            'access_token' => $token,
            'token_type' => 'bearer',
            'expires_in' => Auth::guard('api')->factory()->getTTL() * 60,
            'user' => $user->fresh()->load('professionalProfile'),
            'pending_approval' => $pendingApproval,
        ], 201);
    }

    public function checkAccount(Request $request): JsonResponse
    {
        $request->merge([
            'cpf' => filled($request->input('cpf'))
                ? preg_replace('/\D+/', '', (string) $request->input('cpf'))
                : null,
        ]);

        $data = $request->validate([
            'email' => ['required', 'email', 'max:255'],
            'cpf' => ['nullable', 'string', 'size:11'],
        ], [
            'cpf.size' => 'Informe um CPF válido com 11 dígitos.',
        ]);

        return response()->json([
            'email_taken' => User::emailTaken($data['email']),
            'cpf_taken' => ! empty($data['cpf']) && User::cpfTaken($data['cpf']),
        ]);
    }

    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        if (! $token = Auth::guard('api')->attempt($credentials)) {
            return response()->json(['message' => 'E-mail ou senha inválidos'], 401);
        }

        /** @var User $user */
        $user = Auth::guard('api')->user();

        if ($user->isBlockedFromAccess()) {
            Auth::guard('api')->logout();

            return response()->json([
                'message' => $user->accessDeniedMessage(),
                'error' => 'account_inactive',
            ], 403);
        }

        return $this->respondWithToken($token, $user->load('professionalProfile'));
    }

    public function me(): JsonResponse
    {
        /** @var User $user */
        $user = Auth::guard('api')->user();

        return response()->json($user->load(['professionalProfile', 'addresses']));
    }

    public function logout(): JsonResponse
    {
        Auth::guard('api')->logout();

        return response()->json(['message' => 'Logout realizado com sucesso']);
    }

    public function refresh(): JsonResponse
    {
        $guard = Auth::guard('api');

        try {
            $token = $guard->refresh();
        } catch (JWTException) {
            return response()->json(['message' => 'Token expirado. Faça login novamente.'], 401);
        }

        $user = $guard->setToken($token)->user();

        if (! $user instanceof User) {
            return response()->json(['message' => 'Token inválido. Faça login novamente.'], 401);
        }

        if (! $user->isAdmin() && $user->isBlockedFromAccess()) {
            $guard->invalidate();

            return response()->json([
                'message' => $user->accessDeniedMessage(),
                'error' => 'account_inactive',
            ], 403);
        }

        return $this->respondWithToken($token, $user->load('professionalProfile'));
    }

    public function updateProfile(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = Auth::guard('api')->user();

        if ($request->filled('phone')) {
            $request->merge([
                'phone' => preg_replace('/\D+/', '', (string) $request->input('phone')),
            ]);
        }

        $this->decodeServiceCategoryIds($request);

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'email' => ['sometimes', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'phone' => ['sometimes', 'string', 'min:10', 'max:15'],
            'city' => ['nullable', 'string', 'max:255'],
            'bio' => ['nullable', 'string'],
            'password' => ['nullable', 'confirmed', Password::defaults()],
            'profile_photo' => ['nullable', 'file', 'mimes:jpg,jpeg,png', 'max:2048'],
            'service_category_ids' => ['sometimes', 'array', 'min:1'],
            'service_category_ids.*' => ['integer', $this->rootCategoryExists()],
        ], [
            'service_category_ids.min' => 'Selecione ao menos uma categoria.',
            'service_category_ids.*.exists' => 'Categoria inválida.',
            'email.unique' => 'Este e-mail já está cadastrado.',
            'phone.min' => 'Informe um telefone válido.',
            'phone.max' => 'Informe um telefone válido.',
            'profile_photo.max' => 'A foto deve ter no máximo 2MB.',
        ]);

        if (empty($data['password'])) {
            unset($data['password']);
        }

        if ($request->hasFile('profile_photo')) {
            if ($user->profile_photo) {
                Storage::disk('public')->delete($user->profile_photo);
            }

            $folder = match ($user->type) {
                'professional' => 'professionals/'.$user->id,
                default => 'clients/'.$user->id,
            };

            $storedPhoto = $request->file('profile_photo')->store($folder.'/photos', 'public');
            $data['profile_photo'] = $storedPhoto;

            if ($user->isProfessional() && $user->professionalProfile) {
                if ($user->professionalProfile->profile_photo) {
                    Storage::disk('public')->delete($user->professionalProfile->profile_photo);
                }
                $user->professionalProfile->update(['profile_photo' => $storedPhoto]);
            }
        }

        $categoryIds = $data['service_category_ids'] ?? null;
        unset($data['service_category_ids']);

        $user->update($data);

        if ($user->isProfessional() && $categoryIds !== null) {
            $user->professionalProfile?->serviceCategories()->sync($categoryIds);
        }

        return response()->json([
            'message' => 'Perfil atualizado com sucesso',
            'user' => $user->fresh()->load(['professionalProfile', 'addresses']),
        ]);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
        ]);

        $user = User::where('email', $data['email'])->first();
        if (! $user) {
            return response()->json([
                'message' => 'E-mail não cadastrado.',
            ], 404);
        }

        $user->notify(new ResetPassword);

        return response()->json([
            'message' => 'Enviamos um link de recuperação para o seu e-mail.',
        ]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string'],
            'password' => ['required', 'confirmed', Password::defaults()],
        ], [
            'password.confirmed' => 'A confirmação da senha não confere.',
        ]);

        $cacheKey = 'pwreset:'.$data['token'];
        $userId = Cache::get($cacheKey);

        if (! $userId) {
            return response()->json([
                'message' => 'Link inválido ou expirado. Solicite um novo.',
            ], 422);
        }

        $user = User::find($userId);
        if (! $user) {
            Cache::forget($cacheKey);

            return response()->json([
                'message' => 'Link inválido ou expirado. Solicite um novo.',
            ], 422);
        }

        $user->update(['password' => $data['password']]);
        Cache::forget($cacheKey);

        return response()->json([
            'message' => 'Senha redefinida com sucesso.',
        ]);
    }

    /**
     * Gera um token de uso único (cache 30min) para o form de reset.
     * Chamado pelo handler web da rota `password.reset` após validar o signed URL.
     */
    public static function issueResetToken(string $userId): string
    {
        $token = Str::random(60);
        Cache::put('pwreset:'.$token, $userId, now()->addMinutes(30));

        return $token;
    }

    protected function respondWithToken(string $token, User $user): JsonResponse
    {
        return response()->json([
            'access_token' => $token,
            'token_type' => 'bearer',
            'expires_in' => Auth::guard('api')->factory()->getTTL() * 60,
            'user' => $user,
            'pending_approval' => $user->isProfessional() && $user->isPending(),
        ]);
    }

    /**
     * Requisições multipart enviam `service_category_ids` como string JSON.
     */
    protected function decodeServiceCategoryIds(Request $request): void
    {
        $raw = $request->input('service_category_ids');
        if (! is_string($raw)) {
            return;
        }

        $decoded = json_decode($raw, true);
        if (is_array($decoded)) {
            $request->merge(['service_category_ids' => array_values(array_unique($decoded))]);
        }
    }

    protected function rootCategoryExists(): Exists
    {
        return Rule::exists('service_categories', 'id')->whereNull('parent_id');
    }
}
