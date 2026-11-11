<?php

use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\ImageUploadController;
use App\Http\Controllers\Api\V1\ProductController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->name('api.v1.')->group(function (): void {
    Route::post('uploads', [ImageUploadController::class, 'store'])->middleware('throttle:30,1')->name('uploads.store');
    Route::apiResource('categories', CategoryController::class);
    Route::apiResource('products', ProductController::class);
});
