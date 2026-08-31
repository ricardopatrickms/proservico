<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserStatus;
use App\Http\Controllers\Controller;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;

class AdminController extends Controller
{
    public function dashboard(): JsonResponse
    {
        $this->ensureAdmin();

        return response()->json([
            'clients' => User::where('type', 'client')->count(),
            'professionals' => User::where('type', 'professional')->where('status', UserStatus::Ativo)->count(),
            'pending_approvals' => User::where('type', 'professional')
                ->where('status', UserStatus::Pendente)
                ->count(),
            'service_requests' => ServiceRequest::count(),
            'by_status' => [
                'pending' => ServiceRequest::where('status', 'pending')->count(),
                'in_progress' => ServiceRequest::where('status', 'in_progress')->count(),
                'completed' => ServiceRequest::where('status', 'completed')->count(),
                'cancelled' => ServiceRequest::where('status', 'cancelled')->count(),
            ],
        ]);
    }

    public function users(Request $request): JsonResponse
    {
        $this->ensureAdmin();

        $query = User::with('professionalProfile')
            ->withCount(['serviceRequests', 'professionalServices', 'assignedServices'])
            ->latest();

        if ($request->filled('type')) {
            $query->where('type', $request->string('type'));
        }

        if ($request->filled('status')) {
            $status = UserStatus::tryFrom(strtoupper((string) $request->input('status')));
            if ($status) {
                $query->where('status', $status);
            }
        } elseif ($request->has('approved')) {
            $approved = filter_var($request->input('approved'), FILTER_VALIDATE_BOOLEAN);
            $query->where('status', $approved ? UserStatus::Ativo : UserStatus::Pendente);
        }

        return response()->json($query->get());
    }

    public function showUser(User $user): JsonResponse
    {
        $this->ensureAdmin();

        if ($user->isAdmin()) {
            return response()->json(['message' => 'Usuário não encontrado'], 404);
        }

        if ($user->isProfessional()) {
            $user->load('professionalProfile')
                ->loadCount(['serviceRequests', 'professionalServices', 'assignedServices']);
        } else {
            $user->loadCount(['serviceRequests']);
        }

        return response()->json($user);
    }

    public function setApproval(Request $request, User $user): JsonResponse
    {
        $this->ensureAdmin();

        if ($user->isAdmin()) {
            return response()->json(['message' => 'Não é possível alterar status de administrador'], 422);
        }

        if ($request->filled('status') && is_string($request->input('status'))) {
            $request->merge(['status' => strtoupper($request->string('status')->toString())]);
        }

        $data = $request->validate([
            'status' => ['required_without:approved', Rule::enum(UserStatus::class)],
            'approved' => ['required_without:status', 'boolean'],
        ]);

        $status = $data['status'] ?? ($data['approved'] ? UserStatus::Ativo : UserStatus::Rejeitado);
        if (! $status instanceof UserStatus) {
            $status = UserStatus::from(strtoupper((string) $status));
        }

        if ($user->isClient() && ! in_array($status, [UserStatus::Ativo, UserStatus::Inativo], true)) {
            return response()->json(['message' => 'Status inválido para cliente'], 422);
        }

        $user->update(['status' => $status]);

        $message = match ($status) {
            UserStatus::Ativo => $user->isProfessional() ? 'Profissional aprovado' : 'Cliente reativado',
            UserStatus::Inativo => $user->isProfessional() ? 'Profissional inativado' : 'Cliente inativado',
            UserStatus::Pendente => 'Profissional marcado como pendente',
            UserStatus::Excluido => 'Profissional excluído',
            UserStatus::Rejeitado => 'Profissional rejeitado',
        };

        $user = $user->fresh();
        if ($user->isProfessional()) {
            $user->load('professionalProfile');
        }

        return response()->json([
            'message' => $message,
            'user' => $user,
        ]);
    }

    public function serviceRequests(): JsonResponse
    {
        $this->ensureAdmin();

        return response()->json(
            ServiceRequest::with(['client:id,name,email', 'professional:id,name,email'])->latest()->get()
        );
    }

    protected function ensureAdmin(): void
    {
        $user = Auth::guard('api')->user();

        if (! $user || ! $user->isAdmin()) {
            abort(403, 'Acesso restrito a administradores');
        }
    }
}
