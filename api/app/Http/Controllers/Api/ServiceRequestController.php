<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ServiceRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;

class ServiceRequestController extends Controller
{
    public function index(): JsonResponse
    {
        $user = Auth::guard('api')->user();

        $query = ServiceRequest::with([
            'client:id,name,email,phone',
            'professional:id,name,email,phone',
            'proposals.professional:id,name,email,phone',
        ]);

        if ($user->isClient()) {
            $query->where('client_id', $user->id);
        } elseif ($user->isProfessional()) {
            $query->where(function ($q) use ($user) {
                $q->where('professional_id', $user->id)
                    ->orWhere(function ($pending) {
                        $pending->whereNull('professional_id')->where('status', 'pending');
                    });
            });
        }

        return response()->json($query->latest()->get());
    }

    public function store(Request $request): JsonResponse
    {
        $user = Auth::guard('api')->user();

        if (! $user->isClient() && ! $user->isAdmin()) {
            return response()->json(['message' => 'Apenas clientes podem solicitar serviços'], 403);
        }

        $data = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'category' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'location' => ['required', 'string', 'max:255'],
            'address' => ['required', 'string', 'max:255'],
            'city' => ['required', 'string', 'max:255'],
            'state' => ['required', 'string', 'max:2'],
            'cep' => ['required', 'string', 'max:12'],
            'reference_point' => ['nullable', 'string', 'max:255'],
            'scheduled_at' => ['required', 'date'],
            'preferred_period' => ['required', Rule::in(['morning', 'afternoon', 'evening', 'business'])],
            'budget' => ['nullable', 'numeric', 'min:0'],
            'budget_min' => ['nullable', 'numeric', 'min:0'],
            'budget_max' => ['nullable', 'numeric', 'min:0'],
            'accepts_negotiation' => ['nullable', 'boolean'],
            'needs_materials' => ['nullable', 'boolean'],
            'materials_responsible' => ['required', 'string', 'max:255'],
            'materials_details' => ['nullable', 'string'],
            'urgency' => ['nullable', Rule::in(['normal', 'urgent', 'emergency'])],
            'preferences' => ['nullable', 'string'],
            'prefers_good_ratings' => ['nullable', 'boolean'],
            'gender_preference' => ['nullable', Rule::in(['any', 'male', 'female'])],
            'photo_labels' => ['nullable', 'array'],
            'photo_labels.*' => ['string'],
            'photos' => ['required', 'array', 'min:2'],
            'photos.*' => ['required', 'image', 'mimes:jpeg,jpg,png,webp', 'max:5120'],
        ]);

        $budget = $data['budget'] ?? $data['budget_max'] ?? $data['budget_min'] ?? null;

        $folder = 'service-requests/'.$user->id.'/'.now()->format('YmdHis');
        $storedPhotos = [];
        $photoLabels = $data['photo_labels'] ?? [];

        foreach ($request->file('photos') as $index => $photo) {
            $storedPhotos[] = $photo->store($folder, 'public');
            $photoLabels[$index] ??= $photo->getClientOriginalName();
        }

        $service = ServiceRequest::create([
            ...collect($data)->except(['photos'])->all(),
            'client_id' => $user->id,
            'budget' => $budget,
            'urgency' => $data['urgency'] ?? 'normal',
            'needs_materials' => ($data['materials_responsible'] ?? '') !== 'client',
            'accepts_negotiation' => $data['accepts_negotiation'] ?? true,
            'photos' => $storedPhotos,
            'photo_labels' => array_values($photoLabels),
            'status' => 'pending',
        ]);

        return response()->json($service->load(['client', 'professional']), 201);
    }

    public function show(ServiceRequest $serviceRequest): JsonResponse
    {
        $this->authorizeView($serviceRequest);

        return response()->json($serviceRequest->load([
            'client',
            'professional',
            'proposals.professional:id,name,email,phone',
        ]));
    }

    public function update(Request $request, ServiceRequest $serviceRequest): JsonResponse
    {
        $user = Auth::guard('api')->user();

        if (! $user->isClient() || $serviceRequest->client_id !== $user->id) {
            return response()->json(['message' => 'Apenas o cliente dono pode editar esta solicitação'], 403);
        }

        if (! in_array($serviceRequest->status, ['pending', 'in_progress'], true)) {
            return response()->json(['message' => 'Só é possível editar serviços ativos'], 422);
        }

        $data = $request->validate([
            'category' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'address' => ['required', 'string', 'max:255'],
            'city' => ['required', 'string', 'max:255'],
            'state' => ['required', 'string', 'max:2'],
            'cep' => ['required', 'string', 'max:12'],
        ]);

        $location = collect([
            $data['address'],
            $data['city'],
            $data['state'],
            $data['cep'],
        ])->filter(fn ($v) => filled(trim((string) $v)))->implode(' - ');

        $serviceRequest->update([
            ...$data,
            'location' => $location,
        ]);

        return response()->json($serviceRequest->fresh()->load([
            'client',
            'professional',
            'proposals.professional:id,name,email,phone',
        ]));
    }

    public function updateStatus(Request $request, ServiceRequest $serviceRequest): JsonResponse
    {
        $user = Auth::guard('api')->user();

        $data = $request->validate([
            'status' => ['required', Rule::in(['pending', 'in_progress', 'completed', 'cancelled'])],
            'professional_id' => ['nullable', 'exists:users,id'],
        ]);

        if ($user->isProfessional() && $serviceRequest->professional_id === null && $data['status'] === 'in_progress') {
            $serviceRequest->professional_id = $user->id;
        }

        if ($user->isAdmin() && isset($data['professional_id'])) {
            $serviceRequest->professional_id = $data['professional_id'];
        }

        $serviceRequest->status = $data['status'];
        $serviceRequest->save();

        return response()->json($serviceRequest->fresh()->load(['client', 'professional']));
    }

    protected function authorizeView(ServiceRequest $serviceRequest): void
    {
        $user = Auth::guard('api')->user();

        if ($user->isAdmin()) {
            return;
        }

        if ($user->isClient() && $serviceRequest->client_id === $user->id) {
            return;
        }

        if ($user->isProfessional() && (
            $serviceRequest->professional_id === $user->id
            || ($serviceRequest->professional_id === null && $serviceRequest->status === 'pending')
        )) {
            return;
        }

        abort(403, 'Acesso negado');
    }
}
