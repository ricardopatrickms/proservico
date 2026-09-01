<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAccountIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user('api');

        if (! $user instanceof User || $user->isAdmin()) {
            return $next($request);
        }

        if ($user->isBlockedFromAccess()) {
            return response()->json([
                'message' => $user->accessDeniedMessage(),
                'error' => 'account_inactive',
            ], 403);
        }

        return $next($request);
    }
}
