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
            $query->where('status', $request->string('status'));
        } elseif ($request->has('approved')) {
            $approved = filter_var($request->input('approved'), FILTER_VALIDATE_BOOLEAN);
            $query->where('status', $approved ? UserStatus::Ativo : UserStatus::Pendente);
        }

        return response()->json($query->get());
    }

    public function setApproval(Request $request, User $user): JsonResponse
    {
        $this->ensureAdmin();

        if (! $user->isProfessional()) {
            return response()->json(['message' => 'Apenas profissionais precisam de aprovação'], 422);
        }

        $data = $request->validate([
            'status' => ['required_without:approved', Rule::enum(UserStatus::class)],
            'approved' => ['required_without:status', 'boolean'],
        ]);

        $status = $data['status'] ?? ($data['approved'] ? UserStatus::Ativo : UserStatus::Rejeitado);
        if (! $status instanceof UserStatus) {
            $status = UserStatus::from((string) $status);
        }

        $user->update(['status' => $status]);

        $message = match ($status) {
            UserStatus::Ativo => 'Profissional aprovado',
            UserStatus::Inativo => 'Profissional inativado',
            UserStatus::Pendente => 'Profissional marcado como pendente',
            UserStatus::Excluido => 'Profissional excluído',
            UserStatus::Rejeitado => 'Profissional rejeitado',
        };

        return response()->json([
            'message' => $message,
            'user' => $user->fresh()->load('professionalProfile'),
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
