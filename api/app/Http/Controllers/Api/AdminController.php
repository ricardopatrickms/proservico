<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserStatus;
use App\Http\Controllers\Controller;
use App\Models\ProfessionalPayout;
use App\Models\ServicePayment;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
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
            $user->setAttribute(
                'service_requests',
                ServiceRequest::query()
                    ->where('professional_id', $user->id)
                    ->whereIn('status', ['in_progress', 'completed'])
                    ->with(['client:id,name,email'])
                    ->orderByRaw("CASE WHEN status = 'in_progress' THEN 0 ELSE 1 END")
                    ->orderByDesc('updated_at')
                    ->limit(50)
                    ->get()
                    ->map(fn (ServiceRequest $sr) => $this->presentAssignedService($sr))
                    ->values()
                    ->all()
            );
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

        $requests = ServiceRequest::with(['client:id,name,email', 'professional:id,name,email'])
            ->latest()
            ->get()
            ->map(fn (ServiceRequest $sr) => $this->presentAssignedService($sr))
            ->values();

        return response()->json($requests);
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

    /**
     * @return array<string, mixed>
     */
    protected function presentAssignedService(ServiceRequest $sr): array
    {
        $started = $sr->started_at !== null;
        $completed = (string) $sr->status === 'completed';

        $progressLabel = match (true) {
            $completed => 'Concluído',
            $started => 'Em andamento',
            default => 'Aceito',
        };

        return [
            ...$this->presentServiceSummary($sr),
            'started_at' => $sr->started_at?->toIso8601String(),
            'completed_at' => $sr->completed_at?->toIso8601String(),
            'progress_label' => $progressLabel,
            'has_started' => $started,
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

    public function payouts(Request $request): JsonResponse
    {
        $this->ensureAdmin();

        $status = $request->query('status');
        $month = $request->query('month');

        $query = ProfessionalPayout::query()
            ->with([
                'serviceRequest:id,title,category,city,status,completed_at,client_id',
                'serviceRequest.client:id,name,email',
                'professional:id,name,email,phone',
                'professional.professionalProfile:id,user_id,pix_type,pix_key,bank,agency,account,account_type',
                'servicePayment:id,total_amount,professional_amount,platform_fee,billing_type,status',
            ])
            ->latest('id');

        $summaryQuery = ProfessionalPayout::query();

        if (is_string($month) && preg_match('/^\d{4}-\d{2}$/', $month)) {
            $start = \Carbon\Carbon::createFromFormat('Y-m', $month)->startOfMonth();
            $end = $start->copy()->endOfMonth();
            $query->whereBetween('created_at', [$start, $end]);
            $summaryQuery->whereBetween('created_at', [$start, $end]);
        }

        if (is_string($status) && in_array($status, ['pending', 'paid', 'cancelled'], true)) {
            $query->where('status', $status);
        }

        $items = $query->limit(100)->get()->map(fn (ProfessionalPayout $payout) => $this->presentPayout($payout));

        return response()->json([
            'pending_count' => (clone $summaryQuery)->where('status', 'pending')->count(),
            'pending_amount' => (float) (clone $summaryQuery)->where('status', 'pending')->sum('amount'),
            'paid_count' => (clone $summaryQuery)->where('status', 'paid')->count(),
            'paid_amount' => (float) (clone $summaryQuery)->where('status', 'paid')->sum('amount'),
            'items' => $items,
        ]);
    }

    public function showPayout(ProfessionalPayout $payout): JsonResponse
    {
        $this->ensureAdmin();

        $payout->load($this->payoutDetailRelations());

        return response()->json($this->presentPayout($payout, detailed: true));
    }

    public function updatePayout(Request $request, ProfessionalPayout $payout): JsonResponse
    {
        $this->ensureAdmin();

        $requiresReceipt = $request->input('status') === 'paid' && ! $payout->receipt_path;

        $data = $request->validate([
            'status' => ['required', Rule::in(['paid', 'cancelled', 'pending'])],
            'admin_notes' => ['nullable', 'string', 'max:2000'],
            'receipt' => [
                Rule::requiredIf($requiresReceipt),
                'nullable',
                'file',
                'mimes:jpg,jpeg,png,webp,pdf',
                'max:5120',
            ],
        ], [
            'receipt.required' => 'O comprovante da transferência é obrigatório.',
            'receipt.mimes' => 'O comprovante deve ser uma imagem (JPG, PNG, WEBP) ou PDF.',
            'receipt.max' => 'O comprovante deve ter no máximo 5MB.',
        ]);

        $admin = Auth::guard('api')->user();
        $receiptPath = $payout->receipt_path;

        if ($request->hasFile('receipt')) {
            if ($receiptPath) {
                Storage::disk('public')->delete($receiptPath);
            }
            $receiptPath = $request->file('receipt')->store(
                'payouts/'.$payout->id.'/receipts',
                'public'
            );
        }

        if ($data['status'] === 'paid') {
            if (! $receiptPath) {
                return response()->json([
                    'message' => 'O comprovante da transferência é obrigatório.',
                    'errors' => ['receipt' => ['O comprovante da transferência é obrigatório.']],
                ], 422);
            }
            $payout->markPaid($admin, $data['admin_notes'] ?? null, $receiptPath);
        } else {
            $payout->forceFill([
                'status' => $data['status'],
                'admin_notes' => $data['admin_notes'] ?? $payout->admin_notes,
                'receipt_path' => $receiptPath,
                'paid_at' => $data['status'] === 'paid' ? ($payout->paid_at ?? now()) : null,
                'paid_by' => $data['status'] === 'paid' ? $admin->id : null,
            ])->save();
        }

        return response()->json(
            $this->presentPayout(
                $payout->fresh()->load($this->payoutDetailRelations()),
                detailed: true,
            )
        );
    }

    /**
     * @return list<string>
     */
    protected function payoutDetailRelations(): array
    {
        return [
            'serviceRequest.client:id,name,email,phone',
            'professional:id,name,email,phone',
            'professional.professionalProfile:id,user_id,pix_type,pix_key,bank,agency,account,account_type',
            'servicePayment:id,total_amount,professional_amount,platform_fee,billing_type,status',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    protected function presentPayout(ProfessionalPayout $payout, bool $detailed = false): array
    {
        $profile = $payout->professional?->professionalProfile;
        $service = $payout->serviceRequest;

        $servicePayload = null;
        if ($service) {
            $servicePayload = [
                'id' => $service->id,
                'title' => $service->title,
                'category' => $service->category,
                'city' => $service->city,
                'completed_at' => $service->completed_at?->toIso8601String(),
                'client' => $service->client ? [
                    'id' => $service->client->id,
                    'name' => $service->client->name,
                    'email' => $service->client->email,
                    'phone' => $service->client->phone,
                ] : null,
            ];

            if ($detailed) {
                $raw = is_array($service->completion_checklist) ? $service->completion_checklist : [];
                $labels = [
                    'service_done' => 'Serviço concluído conforme combinado',
                    'site_ok' => 'Local deixado em ordem',
                    'client_informed' => 'Cliente informado da conclusão',
                    'materials_used' => 'Materiais utilizados',
                ];

                $checklist = [];
                foreach ($labels as $key => $label) {
                    if (! array_key_exists($key, $raw)) {
                        continue;
                    }
                    $checklist[] = [
                        'key' => $key,
                        'label' => $label,
                        'checked' => (bool) $raw[$key],
                    ];
                }

                $servicePayload = [
                    ...$servicePayload,
                    'description' => $service->description,
                    'address' => $service->address,
                    'number' => $service->number,
                    'state' => $service->state,
                    'cep' => $service->cep,
                    'status' => $service->status,
                    'status_label' => $this->statusLabel((string) $service->status),
                    'scheduled_at' => $service->scheduled_at?->toIso8601String(),
                    'started_at' => $service->started_at?->toIso8601String(),
                    'completion_checklist' => $checklist,
                    'materials_list' => isset($raw['materials_list']) ? (string) $raw['materials_list'] : null,
                    'completion_notes' => $service->completion_notes,
                    'completion_photo_urls' => $service->completion_photo_urls,
                    'photo_urls' => $service->photo_urls,
                ];
            }
        }

        return [
            'id' => $payout->id,
            'status' => $payout->status,
            'status_label' => match ($payout->status) {
                'paid' => 'Pago',
                'cancelled' => 'Cancelado',
                default => 'Pendente',
            },
            'amount' => (float) $payout->amount,
            'pix_type' => $payout->pix_type ?: $profile?->pix_type,
            'pix_key' => $payout->pix_key ?: $profile?->pix_key,
            'bank' => $payout->bank ?: $profile?->bank,
            'agency' => $payout->agency ?: $profile?->agency,
            'account' => $payout->account ?: $profile?->account,
            'account_type' => $payout->account_type ?: $profile?->account_type,
            'admin_notes' => $payout->admin_notes,
            'receipt_path' => $payout->receipt_path,
            'receipt_url' => $payout->receipt_url,
            'paid_at' => $payout->paid_at?->toIso8601String(),
            'created_at' => $payout->created_at?->toIso8601String(),
            'service_request' => $servicePayload,
            'professional' => $payout->professional ? [
                'id' => $payout->professional->id,
                'name' => $payout->professional->name,
                'email' => $payout->professional->email,
                'phone' => $payout->professional->phone,
            ] : null,
            'service_payment' => $payout->servicePayment ? [
                'id' => $payout->servicePayment->id,
                'total_amount' => (float) $payout->servicePayment->total_amount,
                'professional_amount' => (float) $payout->servicePayment->professional_amount,
                'platform_fee' => (float) $payout->servicePayment->platform_fee,
                'billing_type' => $payout->servicePayment->billing_type,
            ] : null,
        ];
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
