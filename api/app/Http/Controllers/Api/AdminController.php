<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AdminController extends Controller
{
    public function dashboard(): JsonResponse
    {
        $this->ensureAdmin();

        return response()->json([
            'clients' => User::where('type', 'client')->count(),
            'professionals' => User::where('type', 'professional')->count(),
            'pending_approvals' => User::where('type', 'professional')->where('approved', false)->count(),
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

        $query = User::with('professionalProfile')->latest();

        if ($request->filled('type')) {
            $query->where('type', $request->string('type'));
        }

        if ($request->has('approved')) {
            $query->where('approved', filter_var($request->input('approved'), FILTER_VALIDATE_BOOLEAN));
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
            'approved' => ['required', 'boolean'],
        ]);

        $user->update(['approved' => $data['approved']]);

        return response()->json([
            'message' => $data['approved'] ? 'Profissional aprovado' : 'Profissional reprovado',
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
