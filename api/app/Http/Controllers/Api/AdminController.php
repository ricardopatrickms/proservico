<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserStatus;
use App\Http\Controllers\Controller;
use App\Models\ServicePayment;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
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
                'awaiting_payment' => ServiceRequest::where('status', 'awaiting_payment')->count(),
                'in_progress' => ServiceRequest::where('status', 'in_progress')->count(),
                'completed' => ServiceRequest::where('status', 'completed')->count(),
                'cancelled' => ServiceRequest::where('status', 'cancelled')->count(),
            ],
        ]);
    }

    public function analytics(): JsonResponse
    {
        $this->ensureAdmin();

        $paidQuery = ServicePayment::query()->where('status', 'paid');

        $revenue = (float) (clone $paidQuery)->sum('professional_amount');
        $volume = (float) (clone $paidQuery)->sum('total_amount');
        $platformFee = (float) (clone $paidQuery)->sum('platform_fee');
        $paidCount = (int) (clone $paidQuery)->count();

        $byStatus = [
            'pending' => ServiceRequest::where('status', 'pending')->count(),
            'awaiting_payment' => ServiceRequest::where('status', 'awaiting_payment')->count(),
            'in_progress' => ServiceRequest::where('status', 'in_progress')->count(),
            'completed' => ServiceRequest::where('status', 'completed')->count(),
            'cancelled' => ServiceRequest::where('status', 'cancelled')->count(),
        ];

        $serviceSummaries = fn ($query) => $query
            ->with(['client:id,name,email', 'professional:id,name,email'])
            ->latest()
            ->limit(30)
            ->get()
            ->map(fn (ServiceRequest $sr) => $this->presentServiceSummary($sr));

        $inProgress = $serviceSummaries(
            ServiceRequest::query()->where('status', 'in_progress')
        );

        $active = $serviceSummaries(
            ServiceRequest::query()->whereIn('status', ['pending', 'awaiting_payment', 'in_progress'])
        );

        $topCategories = ServiceRequest::query()
            ->select('category', DB::raw('COUNT(*) as total'))
            ->whereNotNull('category')
            ->where('category', '!=', '')
            ->groupBy('category')
            ->orderByDesc('total')
            ->limit(10)
            ->get()
            ->map(fn ($row) => [
                'name' => (string) $row->category,
                'total' => (int) $row->total,
            ])
            ->values();

        $neighborhoods = [];
        $cities = [];

        ServiceRequest::query()
            ->select(['id', 'address', 'city', 'status'])
            ->orderByDesc('id')
            ->limit(2000)
            ->get()
            ->each(function (ServiceRequest $sr) use (&$neighborhoods, &$cities) {
                $city = trim((string) ($sr->city ?: 'Não informado'));
                $cities[$city] = ($cities[$city] ?? 0) + 1;

                $neighborhood = $this->extractNeighborhood($sr->address, $sr->city);
                $key = mb_strtolower($neighborhood.'|'.$city);
                if (! isset($neighborhoods[$key])) {
                    $neighborhoods[$key] = [
                        'name' => $neighborhood,
                        'city' => $city,
                        'total' => 0,
                    ];
                }
                $neighborhoods[$key]['total']++;
            });

        $topNeighborhoods = collect($neighborhoods)
            ->sortByDesc('total')
            ->take(10)
            ->values()
            ->all();

        $topCities = collect($cities)
            ->map(fn ($total, $name) => ['name' => $name, 'total' => (int) $total])
            ->sortByDesc('total')
            ->take(10)
            ->values()
            ->all();

        $monthly = ServicePayment::query()
            ->where('status', 'paid')
            ->where('paid_at', '>=', now()->subMonths(11)->startOfMonth())
            ->selectRaw("DATE_FORMAT(paid_at, '%Y-%m') as month")
            ->selectRaw('SUM(professional_amount) as revenue')
            ->selectRaw('SUM(total_amount) as volume')
            ->selectRaw('COUNT(*) as services')
            ->groupBy('month')
            ->orderBy('month')
            ->get()
            ->keyBy('month');

        $monthLabels = [
            1 => 'jan', 2 => 'fev', 3 => 'mar', 4 => 'abr', 5 => 'mai', 6 => 'jun',
            7 => 'jul', 8 => 'ago', 9 => 'set', 10 => 'out', 11 => 'nov', 12 => 'dez',
        ];

        $monthlyVolume = [];
        for ($i = 11; $i >= 0; $i--) {
            $date = now()->subMonths($i);
            $month = $date->format('Y-m');
            $row = $monthly->get($month);
            $monthlyVolume[] = [
                'month' => $month,
                'label' => ($monthLabels[(int) $date->format('n')] ?? $date->format('M')).'/'.$date->format('y'),
                'revenue' => (float) ($row->revenue ?? 0),
                'volume' => (float) ($row->volume ?? 0),
                'services' => (int) ($row->services ?? 0),
            ];
        }

        $statusChart = collect($byStatus)
            ->map(fn ($total, $status) => [
                'status' => $status,
                'label' => $this->statusLabel((string) $status),
                'total' => (int) $total,
            ])
            ->values()
            ->all();

        return response()->json([
            'metrics' => [
                'revenue_total' => $revenue,
                'volume_total' => $volume,
                'platform_fee_total' => $platformFee,
                'paid_services' => $paidCount,
                'services_total' => array_sum($byStatus),
                'services_in_progress' => $byStatus['in_progress'],
                'services_pending' => $byStatus['pending'],
                'services_awaiting_payment' => $byStatus['awaiting_payment'],
                'services_completed' => $byStatus['completed'],
                'services_cancelled' => $byStatus['cancelled'],
                'services_active' => $byStatus['pending'] + $byStatus['awaiting_payment'] + $byStatus['in_progress'],
            ],
            'by_status' => $byStatus,
            'status_chart' => $statusChart,
            'top_categories' => $topCategories,
            'top_neighborhoods' => $topNeighborhoods,
            'top_cities' => $topCities,
            'monthly_volume' => $monthlyVolume,
            'in_progress' => $inProgress,
            'active_services' => $active,
        ]);
    }

    public function billing(): JsonResponse
    {
        $this->ensureAdmin();

        $paidQuery = ServicePayment::query()->where('status', 'paid');
        $pendingQuery = ServicePayment::query()->where('status', 'pending');
        $cancelledQuery = ServicePayment::query()->where('status', 'cancelled');

        $paidVolume = (float) (clone $paidQuery)->sum('total_amount');
        $paidRevenue = (float) (clone $paidQuery)->sum('professional_amount');
        $paidFee = (float) (clone $paidQuery)->sum('platform_fee');
        $paidCount = (int) (clone $paidQuery)->count();

        $pendingVolume = (float) (clone $pendingQuery)->sum('total_amount');
        $pendingRevenue = (float) (clone $pendingQuery)->sum('professional_amount');
        $pendingFee = (float) (clone $pendingQuery)->sum('platform_fee');
        $pendingCount = (int) (clone $pendingQuery)->count();

        $cancelledVolume = (float) (clone $cancelledQuery)->sum('total_amount');
        $cancelledCount = (int) (clone $cancelledQuery)->count();

        $awaitingPaymentServices = ServiceRequest::where('status', 'awaiting_payment')->count();

        $byBillingType = ServicePayment::query()
            ->select('billing_type')
            ->selectRaw("SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END) as paid_volume")
            ->selectRaw("SUM(CASE WHEN status = 'pending' THEN total_amount ELSE 0 END) as pending_volume")
            ->selectRaw("SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) as paid_count")
            ->selectRaw("SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_count")
            ->groupBy('billing_type')
            ->orderBy('billing_type')
            ->get()
            ->map(fn ($row) => [
                'billing_type' => (string) ($row->billing_type ?: 'OUTRO'),
                'label' => $this->billingTypeLabel((string) ($row->billing_type ?: '')),
                'paid_volume' => (float) $row->paid_volume,
                'pending_volume' => (float) $row->pending_volume,
                'paid_count' => (int) $row->paid_count,
                'pending_count' => (int) $row->pending_count,
            ])
            ->values();

        $monthLabels = [
            1 => 'jan', 2 => 'fev', 3 => 'mar', 4 => 'abr', 5 => 'mai', 6 => 'jun',
            7 => 'jul', 8 => 'ago', 9 => 'set', 10 => 'out', 11 => 'nov', 12 => 'dez',
        ];

        $monthlyPaid = ServicePayment::query()
            ->where('status', 'paid')
            ->where('paid_at', '>=', now()->subMonths(11)->startOfMonth())
            ->selectRaw("DATE_FORMAT(paid_at, '%Y-%m') as month")
            ->selectRaw('SUM(total_amount) as volume')
            ->selectRaw('SUM(professional_amount) as revenue')
            ->selectRaw('SUM(platform_fee) as fee')
            ->selectRaw('COUNT(*) as services')
            ->groupBy('month')
            ->orderBy('month')
            ->get()
            ->keyBy('month');

        $monthlyVolume = [];
        for ($i = 11; $i >= 0; $i--) {
            $date = now()->subMonths($i);
            $month = $date->format('Y-m');
            $row = $monthlyPaid->get($month);
            $monthlyVolume[] = [
                'month' => $month,
                'label' => ($monthLabels[(int) $date->format('n')] ?? $date->format('M')).'/'.$date->format('y'),
                'volume' => (float) ($row->volume ?? 0),
                'revenue' => (float) ($row->revenue ?? 0),
                'fee' => (float) ($row->fee ?? 0),
                'services' => (int) ($row->services ?? 0),
            ];
        }

        $presentPayment = fn (ServicePayment $payment) => [
            'id' => $payment->id,
            'status' => $payment->status,
            'status_label' => $this->paymentStatusLabel((string) $payment->status),
            'billing_type' => $payment->billing_type,
            'billing_type_label' => $this->billingTypeLabel((string) $payment->billing_type),
            'professional_amount' => (float) $payment->professional_amount,
            'platform_fee' => (float) $payment->platform_fee,
            'total_amount' => (float) $payment->total_amount,
            'paid_at' => $payment->paid_at?->toIso8601String(),
            'created_at' => $payment->created_at?->toIso8601String(),
            'service_request' => $payment->serviceRequest ? [
                'id' => $payment->serviceRequest->id,
                'title' => $payment->serviceRequest->title,
                'category' => $payment->serviceRequest->category,
            ] : null,
            'client' => $payment->client ? [
                'id' => $payment->client->id,
                'name' => $payment->client->name,
            ] : null,
            'professional' => $payment->professional ? [
                'id' => $payment->professional->id,
                'name' => $payment->professional->name,
            ] : null,
        ];

        $relations = [
            'serviceRequest:id,title,category',
            'client:id,name',
            'professional:id,name',
        ];

        $paidPayments = ServicePayment::query()
            ->with($relations)
            ->where('status', 'paid')
            ->latest('paid_at')
            ->latest('id')
            ->limit(40)
            ->get()
            ->map($presentPayment)
            ->values();

        $pendingPayments = ServicePayment::query()
            ->with($relations)
            ->where('status', 'pending')
            ->latest('id')
            ->limit(40)
            ->get()
            ->map($presentPayment)
            ->values();

        return response()->json([
            'metrics' => [
                'moved_total' => round($paidVolume + $pendingVolume, 2),
                'paid_volume' => round($paidVolume, 2),
                'paid_revenue' => round($paidRevenue, 2),
                'paid_fee' => round($paidFee, 2),
                'paid_count' => $paidCount,
                'pending_volume' => round($pendingVolume, 2),
                'pending_revenue' => round($pendingRevenue, 2),
                'pending_fee' => round($pendingFee, 2),
                'pending_count' => $pendingCount,
                'cancelled_volume' => round($cancelledVolume, 2),
                'cancelled_count' => $cancelledCount,
                'awaiting_payment_services' => $awaitingPaymentServices,
            ],
            'by_billing_type' => $byBillingType,
            'monthly_volume' => $monthlyVolume,
            'paid_payments' => $paidPayments,
            'pending_payments' => $pendingPayments,
        ]);
    }

    public function users(Request $request): JsonResponse
    {
        $this->ensureAdmin();

        $query = User::with(['professionalProfile', 'addresses'])
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

        if ($request->input('type') === 'professional' || ! $request->filled('type')) {
            $query
                ->withSum([
                    'professionalPayments as production_revenue' => fn ($q) => $q->where('status', 'paid'),
                ], 'professional_amount')
                ->withSum([
                    'professionalPayments as production_volume' => fn ($q) => $q->where('status', 'paid'),
                ], 'total_amount')
                ->withCount([
                    'professionalPayments as paid_services_count' => fn ($q) => $q->where('status', 'paid'),
                ])
                ->withCount([
                    'assignedServices as in_progress_services_count' => fn ($q) => $q->where('status', 'in_progress'),
                ])
                ->withCount([
                    'assignedServices as completed_services_count' => fn ($q) => $q->where('status', 'completed'),
                ]);
        }

        $users = $query->get()->map(function (User $user) {
            if ($user->isProfessional()) {
                $user->setAttribute('production', $this->productionPayload($user));
            }

            return $user;
        });

        return response()->json($users);
    }

    public function showUser(User $user): JsonResponse
    {
        $this->ensureAdmin();

        if ($user->isAdmin()) {
            return response()->json(['message' => 'Usuário não encontrado'], 404);
        }

        if ($user->isProfessional()) {
            $user->load(['professionalProfile', 'addresses'])
                ->loadCount(['serviceRequests', 'professionalServices', 'assignedServices'])
                ->loadSum([
                    'professionalPayments as production_revenue' => fn ($q) => $q->where('status', 'paid'),
                ], 'professional_amount')
                ->loadSum([
                    'professionalPayments as production_volume' => fn ($q) => $q->where('status', 'paid'),
                ], 'total_amount')
                ->loadCount([
                    'professionalPayments as paid_services_count' => fn ($q) => $q->where('status', 'paid'),
                ])
                ->loadCount([
                    'assignedServices as in_progress_services_count' => fn ($q) => $q->where('status', 'in_progress'),
                ])
                ->loadCount([
                    'assignedServices as completed_services_count' => fn ($q) => $q->where('status', 'completed'),
                ]);

            $user->setAttribute('production', $this->productionPayload($user));
        } else {
            $user->load('addresses')->loadCount(['serviceRequests']);
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

    protected function productionPayload(User $user): array
    {
        return [
            'revenue' => round((float) ($user->production_revenue ?? 0), 2),
            'volume' => round((float) ($user->production_volume ?? 0), 2),
            'paid_services' => (int) ($user->paid_services_count ?? 0),
            'in_progress_services' => (int) ($user->in_progress_services_count ?? 0),
            'completed_services' => (int) ($user->completed_services_count ?? 0),
        ];
    }

    protected function presentServiceSummary(ServiceRequest $sr): array
    {
        return [
            'id' => $sr->id,
            'title' => $sr->title,
            'category' => $sr->category,
            'status' => $sr->status,
            'status_label' => $this->statusLabel((string) $sr->status),
            'city' => $sr->city,
            'neighborhood' => $this->extractNeighborhood($sr->address, $sr->city),
            'client' => $sr->client ? [
                'id' => $sr->client->id,
                'name' => $sr->client->name,
            ] : null,
            'professional' => $sr->professional ? [
                'id' => $sr->professional->id,
                'name' => $sr->professional->name,
            ] : null,
            'scheduled_at' => $sr->scheduled_at?->toIso8601String(),
            'created_at' => $sr->created_at?->toIso8601String(),
            'updated_at' => $sr->updated_at?->toIso8601String(),
        ];
    }

    protected function extractNeighborhood(?string $address, ?string $city): string
    {
        $address = trim((string) $address);
        $city = trim((string) $city);

        if ($address !== '') {
            $parts = array_values(array_filter(
                array_map('trim', explode(',', $address)),
                fn ($part) => $part !== ''
            ));

            if (count($parts) >= 2) {
                $candidate = $parts[count($parts) - 1];
                if (preg_match('/^\d+[A-Za-z\/\-]*$/', $candidate) && count($parts) >= 3) {
                    $candidate = $parts[count($parts) - 2];
                }

                if ($candidate !== '' && ! preg_match('/^\d+[A-Za-z\/\-]*$/', $candidate)) {
                    return $candidate;
                }
            }
        }

        return $city !== '' ? $city : 'Não informado';
    }

    protected function statusLabel(string $status): string
    {
        return match ($status) {
            'pending' => 'Pendente',
            'awaiting_payment' => 'Aguardando pagamento',
            'in_progress' => 'Em andamento',
            'completed' => 'Concluído',
            'cancelled' => 'Cancelado',
            default => $status,
        };
    }

    protected function paymentStatusLabel(string $status): string
    {
        return match (strtolower($status)) {
            'paid' => 'Pago',
            'pending' => 'Pendente',
            'cancelled' => 'Cancelado',
            default => $status,
        };
    }

    protected function billingTypeLabel(string $type): string
    {
        return match (strtoupper($type)) {
            'PIX' => 'PIX',
            'CREDIT_CARD', 'CREDITCARD' => 'Cartão',
            '' => 'Outro',
            default => $type,
        };
    }

    protected function ensureAdmin(): void
    {
        $user = Auth::guard('api')->user();

        if (! $user || ! $user->isAdmin()) {
            abort(403, 'Acesso restrito a administradores');
        }
    }
}
