<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ServiceCategory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ServiceCategoryController extends Controller
{
    public function catalog(): JsonResponse
    {
        $items = ServiceCategory::query()
            ->active()
            ->whereNull('parent_id')
            ->with(['children' => fn ($q) => $q->active()])
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        return response()->json($items);
    }

    public function index(): JsonResponse
    {
        $this->ensureAdmin();

        $items = ServiceCategory::query()
            ->orderByRaw('parent_id is not null')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        return response()->json($items);
    }

    public function store(Request $request): JsonResponse
    {
        $this->ensureAdmin();

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'parent_id' => ['nullable', 'exists:service_categories,id'],
            'active' => ['nullable', 'boolean'],
        ]);

        if (! empty($data['parent_id'])) {
            $parent = ServiceCategory::find($data['parent_id']);
            if ($parent?->parent_id) {
                return response()->json(['message' => 'Subcategoria não pode ter outra subcategoria'], 422);
            }
        }

        $maxOrder = ServiceCategory::query()
            ->where('parent_id', $data['parent_id'] ?? null)
            ->max('sort_order');

        $category = ServiceCategory::create([
            'name' => $data['name'],
            'parent_id' => $data['parent_id'] ?? null,
            'active' => $data['active'] ?? true,
            'sort_order' => ($maxOrder ?? 0) + 1,
        ]);

        return response()->json($category, 201);
    }

    public function update(Request $request, ServiceCategory $serviceCategory): JsonResponse
    {
        $this->ensureAdmin();

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'active' => ['sometimes', 'boolean'],
        ]);

        $serviceCategory->update($data);

        return response()->json($serviceCategory->fresh());
    }

    public function destroy(ServiceCategory $serviceCategory): JsonResponse
    {
        $this->ensureAdmin();

        $serviceCategory->delete();

        return response()->json(['message' => 'Categoria removida']);
    }

    protected function ensureAdmin(): void
    {
        $user = Auth::guard('api')->user();

        if (! $user || ! $user->isAdmin()) {
            abort(403, 'Acesso restrito a administradores');
        }
    }
}
