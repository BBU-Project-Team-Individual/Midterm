<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\UploadImageRequest;
use Illuminate\Http\JsonResponse;

class ImageUploadController extends Controller
{
    public function store(UploadImageRequest $request): JsonResponse
    {
        $path = $request->file('image')->store('catalog', 'public');

        if ($path === false) {
            return response()->json([
                'message' => 'Image could not be stored. Please try again.',
            ], 500);
        }

        return response()->json([
            'data' => ['path' => '/storage/'.$path],
        ], 201);
    }
}
