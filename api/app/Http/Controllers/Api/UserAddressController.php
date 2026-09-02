<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserAddress;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class UserAddressController extends Controller
{
    public function index(): JsonResponse
    {
        $user = Auth::guard('api')->user();

        return response()->json(
            $user->addresses()->latest()->get()
        );
    }

    public function store(Request $request): JsonResponse
    {
        $user = Auth::guard('api')->user();

        $data = $this->validatedAddress($request);
        $address = $user->addresses()->create($data);

        return response()->json([
            'message' => 'Endereço adicionado com sucesso',
            'address' => $address,
        ], 201);
    }

    public function update(Request $request, UserAddress $userAddress): JsonResponse
    {
        $this->ensureOwner($userAddress);

        $data = $this->validatedAddress($request);
        $userAddress->update($data);

        return response()->json([
            'message' => 'Endereço atualizado com sucesso',
            'address' => $userAddress->fresh(),
        ]);
    }

    public function destroy(UserAddress $userAddress): JsonResponse
    {
        $this->ensureOwner($userAddress);

        $userAddress->delete();

        return response()->json([
            'message' => 'Endereço removido com sucesso',
        ]);
    }

    protected function validatedAddress(Request $request): array
    {
        $data = $request->validate([
            'label' => ['required', 'string', 'max:100'],
            'address' => ['required', 'string', 'max:255'],
            'city' => ['required', 'string', 'max:255'],
            'state' => ['required', 'string', 'max:2'],
            'cep' => ['required', 'string', 'max:12'],
            'reference_point' => ['nullable', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            // legado: aceita details se ainda vier, mas prioriza campos estruturados
            'details' => ['nullable', 'string', 'max:1000'],
        ]);

        $data['state'] = strtoupper($data['state']);
        $data['details'] = UserAddress::composeDetails(
            $data['address'],
            $data['city'],
            $data['state'],
            $data['cep'],
            $data['reference_point'] ?? null,
        );

        return $data;
    }

    protected function ensureOwner(UserAddress $userAddress): void
    {
        $user = Auth::guard('api')->user();

        if (! $user || $userAddress->user_id !== $user->id) {
            abort(403, 'Acesso negado');
        }
    }
}
