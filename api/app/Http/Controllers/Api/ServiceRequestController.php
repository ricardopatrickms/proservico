<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ServiceRequest;
use App\Models\User;
use App\Support\ProposalPresenter;
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
            'proposals.activePayment',
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

        $requests = $query->latest()->get()
            ->map(fn (ServiceRequest $request) => $this->presentFor($user, $request))
            ->values();

        if ($user->isProfessional()) {
            $requests = $requests
                ->filter(function (ServiceRequest $request) use ($user) {
                    if ((int) $request->professional_id === (int) $user->id) {
                        return true;
                    }

                    return $user->servesCity($request->city);
                })
                ->values();
        }

        return response()->json($requests);
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
            'location' => ['nullable', 'string', 'max:255'],
            'address' => ['required', 'string', 'max:255'],
            'number' => ['required', 'string', 'max:20'],
            'city' => ['required', 'string', 'max:255'],
            'state' => ['required', 'string', 'max:2'],
            'cep' => ['required', 'string', 'max:12'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
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
        $location = $this->composeLocation(
            $data['address'],
            $data['number'],
            $data['city'],
            $data['state'],
            $data['cep'],
        );

        $folder = 'service-requests/'.$user->id.'/'.now()->format('YmdHis');
        $storedPhotos = [];
        $photoLabels = $data['photo_labels'] ?? [];

        foreach ($request->file('photos') as $index => $photo) {
            $storedPhotos[] = $photo->store($folder, 'public');
            $photoLabels[$index] ??= $photo->getClientOriginalName();
        }

        $service = ServiceRequest::create([
            ...collect($data)->except(['photos', 'location'])->all(),
            'client_id' => $user->id,
            'location' => $location,
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

        $serviceRequest->load([
            'client',
            'professional',
            'proposals.professional:id,name,email,phone',
            'proposals.activePayment',
        ]);

        return response()->json(
            $this->presentFor(Auth::guard('api')->user(), $serviceRequest)
        );
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
            'title' => ['required', 'string', 'max:255'],
            'category' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'address' => ['required', 'string', 'max:255'],
            'number' => ['required', 'string', 'max:20'],
            'city' => ['required', 'string', 'max:255'],
            'state' => ['required', 'string', 'max:2'],
            'cep' => ['required', 'string', 'max:12'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
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
            'keep_photos' => ['nullable', 'array'],
            'keep_photos.*' => ['string', 'max:500'],
            'photos' => ['nullable', 'array'],
            'photos.*' => ['required', 'image', 'mimes:jpeg,jpg,png,webp', 'max:5120'],
            'photos_edited' => ['nullable', 'boolean'],
        ]);

        $budget = $data['budget'] ?? $data['budget_max'] ?? $data['budget_min'] ?? null;
        $location = $this->composeLocation(
            $data['address'],
            $data['number'],
            $data['city'],
            $data['state'],
            $data['cep'],
        );

        $payload = collect($data)->except([
            'photos',
            'photo_labels',
            'keep_photos',
            'photos_edited',
            'location',
        ])->all();
        $payload['location'] = $location;
        $payload['budget'] = $budget;
        $payload['urgency'] = $data['urgency'] ?? $serviceRequest->urgency ?? 'normal';
        $payload['needs_materials'] = ($data['materials_responsible'] ?? '') !== 'client';
        $payload['accepts_negotiation'] = $data['accepts_negotiation']
            ?? $serviceRequest->accepts_negotiation
            ?? true;

        $photosEdited = $request->boolean('photos_edited')
            || $request->has('keep_photos')
            || $request->hasFile('photos');

        if ($photosEdited) {
            $current = collect($serviceRequest->photos ?? [])
                ->filter()
                ->values()
                ->all();

            $keep = collect($data['keep_photos'] ?? [])
                ->map(fn ($path) => (string) $path)
                ->filter(fn ($path) => in_array($path, $current, true))
                ->values()
                ->all();

            $storedPhotos = [];
            $photoLabels = $data['photo_labels'] ?? [];
            if ($request->hasFile('photos')) {
                $folder = 'service-requests/'.$user->id.'/'.now()->format('YmdHis');
                foreach ($request->file('photos') as $index => $photo) {
                    $storedPhotos[] = $photo->store($folder, 'public');
                    $photoLabels[$index] ??= $photo->getClientOriginalName();
                }
            }

            $finalPhotos = array_values(array_merge($keep, $storedPhotos));
            if (count($finalPhotos) < 2) {
                return response()->json([
                    'message' => 'É necessário manter no mínimo 2 fotos do problema.',
                    'errors' => [
                        'photos' => ['Envie ou mantenha no mínimo 2 fotos.'],
                    ],
                ], 422);
            }

            $payload['photos'] = $finalPhotos;
            if (! empty($photoLabels)) {
                $payload['photo_labels'] = array_values($photoLabels);
            }
        }

        $serviceRequest->update($payload);

        $fresh = $serviceRequest->fresh()->load([
            'client',
            'professional',
            'proposals.professional:id,name,email,phone',
            'proposals.activePayment',
        ]);

        return response()->json(
            $this->presentFor(Auth::guard('api')->user(), $fresh)
        );
    }

    public function updateStatus(Request $request, ServiceRequest $serviceRequest): JsonResponse
    {
        $user = Auth::guard('api')->user();

        $data = $request->validate([
            'status' => ['required', Rule::in(['pending', 'awaiting_payment', 'in_progress', 'completed', 'cancelled'])],
            'professional_id' => ['nullable', 'exists:users,id'],
        ]);

        if ($user->isProfessional() && $serviceRequest->professional_id === null && $data['status'] === 'in_progress') {
            if (! $user->servesCity($serviceRequest->city)) {
                return response()->json([
                    'message' => 'Você só pode atender solicitações da mesma cidade do seu cadastro.',
                ], 422);
            }
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
            || (
                $serviceRequest->professional_id === null
                && $serviceRequest->status === 'pending'
                && $user->servesCity($serviceRequest->city)
            )
        )) {
            return;
        }

        abort(403, 'Acesso negado');
    }

    /**
     * Profissional só vê endereço completo e contato do cliente depois de contratado,
     * e nunca vê propostas de outros profissionais.
     */
    protected function presentFor(User $user, ServiceRequest $serviceRequest): ServiceRequest
    {
        if ($serviceRequest->relationLoaded('proposals')) {
            $proposals = $serviceRequest->proposals;
            if ($user->isProfessional()) {
                $proposals = $proposals->where('professional_id', $user->id)->values();
            }
            $serviceRequest->setRelation(
                'proposals',
                ProposalPresenter::collection($proposals, $user)
            );
        }

        if (! $user->isProfessional()) {
            return $serviceRequest;
        }

        if ((int) $serviceRequest->professional_id === (int) $user->id) {
            return $serviceRequest;
        }

        $serviceRequest->makeHidden([
            'address',
            'number',
            'cep',
            'latitude',
            'longitude',
            'reference_point',
        ]);
        $serviceRequest->setAttribute(
            'location',
            collect([$serviceRequest->city, $serviceRequest->state])
                ->map(fn ($v) => trim((string) $v))
                ->filter()
                ->implode(' - ')
        );

        if ($serviceRequest->relationLoaded('client') && $serviceRequest->client) {
            $serviceRequest->client->setVisible(['id', 'name']);
        }

        return $serviceRequest;
    }

    protected function composeLocation(
        string $address,
        string $number,
        string $city,
        string $state,
        string $cep,
    ): string {
        $street = trim($address);
        $num = trim($number);
        if ($num !== '') {
            $street = $street === '' ? $num : "{$street}, {$num}";
        }

        return collect([$street, $city, $state, $cep])
            ->map(fn ($v) => trim((string) $v))
            ->filter(fn ($v) => $v !== '')
            ->implode(' - ');
    }
}
