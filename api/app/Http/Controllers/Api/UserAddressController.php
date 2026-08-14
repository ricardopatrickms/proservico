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

        $data = $request->validate([
            'label' => ['required', 'string', 'max:100'],
            'details' => ['required', 'string', 'max:1000'],
        ]);

        $address = $user->addresses()->create($data);

        return response()->json([
            'message' => 'Endereço adicionado com sucesso',
            'address' => $address,
        ], 201);
    }

    public function update(Request $request, UserAddress $userAddress): JsonResponse
    {
        $this->ensureOwner($userAddress);

        $data = $request->validate([
            'label' => ['required', 'string', 'max:100'],
            'details' => ['required', 'string', 'max:1000'],
        ]);

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

    protected function ensureOwner(UserAddress $userAddress): void
    {
        $user = Auth::guard('api')->user();

        if (! $user || $userAddress->user_id !== $user->id) {
            abort(403, 'Acesso negado');
        }
    }
}
