<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreProductRequest;
use App\Http\Requests\UpdateProductRequest;
use App\Http\Resources\ProductResource;
use App\Models\Category;
use App\Models\Product;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Validation\Rule;

class ProductController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate([
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
            'CategoryID' => ['sometimes', 'integer', Rule::exists(Category::class, 'category_id')],
        ]);

        return ProductResource::collection(
            Product::query()->with('category')
                ->when($request->filled('CategoryID'), function (Builder $query) use ($request): void {
                    $query->where('CategoryID', $request->integer('CategoryID'));
                })
                ->orderByDesc('ProductID')
                ->paginate($request->integer('per_page', 15))->withQueryString()
        );
    }

    public function store(StoreProductRequest $request): JsonResponse
    {
        $product = Product::create($request->validated());

        return (new ProductResource($product->refresh()->load('category')))->response()->setStatusCode(201);
    }

    public function show(Product $product): ProductResource
    {
        return new ProductResource($product->load('category'));
    }

    public function update(UpdateProductRequest $request, Product $product): ProductResource
    {
        $product->update($request->validated());

        return new ProductResource($product->refresh()->load('category'));
    }

    public function destroy(Product $product): Response
    {
        $product->isDeleted = true;
        $product->save();

        return response()->noContent();
    }
}
