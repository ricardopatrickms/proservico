<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ServiceProposal;
use App\Models\ServiceRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ServiceProposalController extends Controller
{
    public function index(ServiceRequest $serviceRequest): JsonResponse
    {
        $this->authorizeView($serviceRequest);

        $proposals = $serviceRequest->proposals()
            ->with('professional:id,name,email,phone')
            ->latest()
            ->get();

        return response()->json($proposals);
    }

    public function store(Request $request, ServiceRequest $serviceRequest): JsonResponse
    {
        $user = Auth::guard('api')->user();

        if (! $user->isProfessional()) {
            return response()->json(['message' => 'Apenas profissionais podem enviar propostas'], 403);
        }

        if ($serviceRequest->status !== 'pending' || $serviceRequest->professional_id !== null) {
            return response()->json(['message' => 'Esta solicitação não está disponível para propostas'], 422);
        }

        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01'],
            'message' => ['required', 'string', 'min:10', 'max:2000'],
        ]);

        $proposal = ServiceProposal::updateOrCreate(
            [
                'service_request_id' => $serviceRequest->id,
                'professional_id' => $user->id,
            ],
            [
                'amount' => $data['amount'],
                'message' => $data['message'],
                'status' => 'pending',
            ]
        );

        return response()->json(
            $proposal->load('professional:id,name,email,phone'),
            201
        );
    }

    public function updateStatus(
        Request $request,
        ServiceRequest $serviceRequest,
        ServiceProposal $proposal,
    ): JsonResponse {
        $user = Auth::guard('api')->user();

        if (! $user->isClient() || $serviceRequest->client_id !== $user->id) {
            return response()->json(['message' => 'Apenas o cliente da solicitação pode responder propostas'], 403);
        }

        if ($proposal->service_request_id !== $serviceRequest->id) {
            return response()->json(['message' => 'Proposta inválida para esta solicitação'], 422);
        }

        $data = $request->validate([
            'status' => ['required', 'in:accepted,rejected'],
        ]);

        if ($proposal->status !== 'pending') {
            return response()->json(['message' => 'Esta proposta já foi respondida'], 422);
        }

        if ($data['status'] === 'accepted') {
            $proposal->status = 'accepted';
            $proposal->save();

            // Recusa as demais pendentes e atribui o profissional.
            ServiceProposal::query()
                ->where('service_request_id', $serviceRequest->id)
                ->where('id', '!=', $proposal->id)
                ->where('status', 'pending')
                ->update(['status' => 'rejected']);

            $serviceRequest->professional_id = $proposal->professional_id;
            $serviceRequest->status = 'in_progress';
            $serviceRequest->save();
        } else {
            $proposal->status = 'rejected';
            $proposal->save();
        }

        return response()->json(
            $proposal->fresh()->load('professional:id,name,email,phone')
        );
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
