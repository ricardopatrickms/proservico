<?php

use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ProfessionalServiceController;
use App\Http\Controllers\Api\ServiceProposalController;
use App\Http\Controllers\Api\ServiceRequestController;
use App\Http\Controllers\Api\UserAddressController;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->group(function () {
    Route::post('register', [AuthController::class, 'register']);
    Route::post('login', [AuthController::class, 'login']);
    Route::post('forgot-password', [AuthController::class, 'forgotPassword']);

    Route::middleware('auth:api')->group(function () {
        Route::get('me', [AuthController::class, 'me']);
        Route::put('profile', [AuthController::class, 'updateProfile']);
        Route::post('logout', [AuthController::class, 'logout']);
        Route::post('refresh', [AuthController::class, 'refresh']);
    });
});

Route::middleware('auth:api')->group(function () {
    Route::get('service-requests', [ServiceRequestController::class, 'index']);
    Route::post('service-requests', [ServiceRequestController::class, 'store']);
    Route::get('service-requests/{serviceRequest}', [ServiceRequestController::class, 'show']);
    Route::put('service-requests/{serviceRequest}', [ServiceRequestController::class, 'update']);
    Route::patch('service-requests/{serviceRequest}/status', [ServiceRequestController::class, 'updateStatus']);

    Route::get('service-requests/{serviceRequest}/proposals', [ServiceProposalController::class, 'index']);
    Route::post('service-requests/{serviceRequest}/proposals', [ServiceProposalController::class, 'store']);
    Route::patch('service-requests/{serviceRequest}/proposals/{proposal}/status', [ServiceProposalController::class, 'updateStatus']);

    Route::get('user-addresses', [UserAddressController::class, 'index']);
    Route::post('user-addresses', [UserAddressController::class, 'store']);
    Route::put('user-addresses/{userAddress}', [UserAddressController::class, 'update']);
    Route::delete('user-addresses/{userAddress}', [UserAddressController::class, 'destroy']);

    Route::get('professional-services', [ProfessionalServiceController::class, 'index']);
    Route::post('professional-services', [ProfessionalServiceController::class, 'store']);
    Route::put('professional-services/{professionalService}', [ProfessionalServiceController::class, 'update']);
    Route::delete('professional-services/{professionalService}', [ProfessionalServiceController::class, 'destroy']);

    Route::prefix('admin')->group(function () {
        Route::get('dashboard', [AdminController::class, 'dashboard']);
        Route::get('users', [AdminController::class, 'users']);
        Route::patch('users/{user}/approval', [AdminController::class, 'setApproval']);
        Route::get('service-requests', [AdminController::class, 'serviceRequests']);
    });
});
