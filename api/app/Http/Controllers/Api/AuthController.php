<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ProfessionalProfile;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

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

        $isProfessional = $request->input('type') === 'professional';

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'min:10', 'max:15'],
            'password' => ['required', 'confirmed', Password::defaults()],
            'type' => ['required', Rule::in(['client', 'professional'])],
            'city' => ['nullable', 'string', 'max:255'],
            'cpf' => [
                Rule::requiredIf($isProfessional),
                'nullable',
                'string',
                'size:11',
                'unique:users,cpf',
            ],
            'bio' => ['nullable', 'string'],
            'category' => [Rule::requiredIf($isProfessional), 'nullable', 'string', 'max:255'],
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
        ]);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'],
            'password' => $data['password'],
            'type' => $data['type'],
            'city' => $data['city'] ?? null,
            'cpf' => $data['cpf'] ?? null,
            'bio' => $data['bio'] ?? null,
            'approved' => $data['type'] === 'client',
        ]);

        if ($user->isProfessional()) {
            try {
                $folder = 'professionals/'.$user->id;

                ProfessionalProfile::create([
                    'user_id' => $user->id,
                    'category' => $data['category'] ?? null,
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
            } catch (\Throwable $e) {
                $user->delete();

                throw $e;
            }
        }

        $token = Auth::guard('api')->login($user);

        return response()->json([
            'message' => 'Cadastro realizado com sucesso',
            'access_token' => $token,
            'token_type' => 'bearer',
            'expires_in' => Auth::guard('api')->factory()->getTTL() * 60,
            'user' => $user->load('professionalProfile'),
            'pending_approval' => $user->isProfessional() && ! $user->approved,
        ], 201);
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

        if ($user->isProfessional() && ! $user->approved) {
            Auth::guard('api')->logout();

            return response()->json([
                'message' => 'Cadastro profissional aguardando aprovação',
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
        $token = Auth::guard('api')->refresh();

        /** @var User $user */
        $user = Auth::guard('api')->user();

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

        if ($request->has('service_areas') && is_string($request->input('service_areas'))) {
            $decoded = json_decode($request->input('service_areas'), true);
            if (is_array($decoded)) {
                $request->merge(['service_areas' => $decoded]);
            }
        }

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'email' => ['sometimes', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'phone' => ['sometimes', 'string', 'min:10', 'max:15'],
            'city' => ['nullable', 'string', 'max:255'],
            'bio' => ['nullable', 'string'],
            'password' => ['nullable', 'confirmed', Password::defaults()],
            'profile_photo' => ['nullable', 'file', 'mimes:jpg,jpeg,png', 'max:2048'],
            'service_areas' => ['nullable', 'array'],
            'service_areas.*' => ['string', 'max:255'],
        ], [
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

        $serviceAreas = $data['service_areas'] ?? null;
        unset($data['service_areas']);

        $user->update($data);

        if ($user->isProfessional() && $serviceAreas !== null) {
            $user->professionalProfile?->update(['service_areas' => array_values($serviceAreas)]);
        }

        return response()->json([
            'message' => 'Perfil atualizado com sucesso',
            'user' => $user->fresh()->load(['professionalProfile', 'addresses']),
        ]);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'email', 'exists:users,email'],
        ]);

        // Placeholder: integração de e-mail pode ser adicionada depois.
        return response()->json([
            'message' => 'Se o e-mail existir, enviaremos instruções de recuperação',
        ]);
    }

    protected function respondWithToken(string $token, User $user): JsonResponse
    {
        return response()->json([
            'access_token' => $token,
            'token_type' => 'bearer',
            'expires_in' => Auth::guard('api')->factory()->getTTL() * 60,
            'user' => $user,
        ]);
    }
}
