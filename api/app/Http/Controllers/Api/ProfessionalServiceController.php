<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ProfessionalService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ProfessionalServiceController extends Controller
{
    public function index(): JsonResponse
    {
        $user = Auth::guard('api')->user();

        $services = ProfessionalService::query()
            ->when($user->isProfessional(), fn ($q) => $q->where('user_id', $user->id))
            ->when($user->isClient(), fn ($q) => $q->where('active', true))
            ->with('user:id,name,city,phone')
            ->latest()
            ->get();

        return response()->json($services);
    }

    public function store(Request $request): JsonResponse
    {
        $user = Auth::guard('api')->user();

        if (! $user->isProfessional()) {
            return response()->json(['message' => 'Apenas profissionais podem cadastrar serviços'], 403);
        }

        $data = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'category' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'price_from' => ['required', 'numeric', 'min:0'],
            'active' => ['boolean'],
        ]);

        $service = ProfessionalService::create([
            ...$data,
            'user_id' => $user->id,
            'active' => $data['active'] ?? true,
        ]);

        return response()->json($service, 201);
    }

    public function update(Request $request, ProfessionalService $professionalService): JsonResponse
    {
        $this->authorizeOwner($professionalService);

        $data = $request->validate([
            'title' => ['sometimes', 'string', 'max:255'],
            'category' => ['sometimes', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'price_from' => ['sometimes', 'numeric', 'min:0'],
            'active' => ['boolean'],
        ]);

        $professionalService->update($data);

        return response()->json($professionalService);
    }

    public function destroy(ProfessionalService $professionalService): JsonResponse
    {
        $this->authorizeOwner($professionalService);
        $professionalService->delete();

        return response()->json(['message' => 'Serviço removido com sucesso']);
    }

    protected function authorizeOwner(ProfessionalService $service): void
    {
        $user = Auth::guard('api')->user();

        if ($user->isAdmin() || $service->user_id === $user->id) {
            return;
        }

        abort(403, 'Acesso negado');
    }
}
