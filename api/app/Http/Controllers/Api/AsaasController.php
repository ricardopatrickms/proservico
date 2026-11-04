<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Asaas\AsaasClient;
use App\Services\Asaas\AsaasException;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

class AsaasController extends Controller
{
    public function syncCustomer(AsaasClient $asaas): JsonResponse
    {
        $user = Auth::guard('api')->user();

        try {
            $customerId = $asaas->ensureCustomer($user->fresh());
        } catch (AsaasException $e) {
            return response()->json([
                'message' => 'Não foi possível sincronizar o cliente no Asaas.',
            ], 502);
        }

        return response()->json([
            'message' => 'Customer Asaas sincronizado',
            'asaas_customer_id' => $customerId,
        ]);
    }
}
