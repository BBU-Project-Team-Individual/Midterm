<?php

use App\Models\Category;
use App\Models\Product;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;

uses(LazilyRefreshDatabase::class);

describe('category reads', function () {
    test('lists categories alphabetically with pagination', function () {
        Category::factory()->create(['category_name' => 'Food']);
        $beverages = Category::factory()->create(['category_name' => 'Beverages']);

        $this->getJson('/api/v1/categories?per_page=1')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.category_id', $beverages->getKey())
            ->assertJsonPath('meta.total', 2)
            ->assertJsonPath('meta.last_page', 2);
    });

    test('shows a category using its custom primary key', function () {
        $category = Category::factory()->create();

        $this->getJson('/api/v1/categories/'.$category->getKey())
            ->assertOk()
            ->assertJsonPath('data.category_id', $category->getKey())
            ->assertJsonPath('data.category_name', $category->category_name);
    });

    test('returns 422 for invalid pagination', function (string $query) {
        $this->getJson('/api/v1/categories?'.$query)->assertUnprocessable();
    })->with(['per_page=0', 'per_page=101', 'per_page=abc', 'page=0']);

    test('returns 404 JSON for a missing category', function () {
        $this->get('/api/v1/categories/999')->assertNotFound()->assertJsonStructure(['message']);
    });
});

describe('category writes', function () {
    test('creates a category with Khmer text and returns 201', function () {
        $payload = [
            'category_name' => 'ភេសជ្ជៈ',
            'description' => 'ភេសជ្ជៈគ្រប់ប្រភេទ',
            'image' => 'https://example.com/drinks.png',
        ];

        $response = $this->postJson('/api/v1/categories', $payload)
            ->assertCreated()
            ->assertJsonPath('data.category_name', 'ភេសជ្ជៈ');

        $this->assertDatabaseHas('categories', [
            ...$payload,
            'category_id' => $response->json('data.category_id'),
        ]);
    });

    test('returns 422 JSON when required category fields are missing', function () {
        $this->post('/api/v1/categories', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['category_name']);

        $this->assertDatabaseCount('categories', 0);
    });

    test('returns 422 without saving invalid category fields', function (string $field, mixed $value) {
        $payload = ['category_name' => 'Food', 'image' => 'food.png', $field => $value];

        $this->postJson('/api/v1/categories', $payload)
            ->assertUnprocessable()->assertJsonValidationErrors($field);

        $this->assertDatabaseCount('categories', 0);
    })->with([
        'name length' => ['category_name', str_repeat('a', 51)],
        'name type' => ['category_name', 123],
        'description length' => ['description', str_repeat('a', 256)],
        'description type' => ['description', []],
        'image length' => ['image', str_repeat('a', 256)],
        'image type' => ['image', []],
        'protected ID' => ['category_id', 10],
        'protected creation time' => ['created_at', '2026-01-01'],
        'protected update time' => ['updated_at', '2026-01-01'],
    ]);

    test('updates category fields and preserves omitted fields', function (string $method) {
        $category = Category::factory()->create(['description' => 'Old description']);

        $this->{$method}('/api/v1/categories/'.$category->getKey(), [
            'category_name' => 'Updated name',
            'description' => null,
        ])->assertOk()->assertJsonPath('data.category_name', 'Updated name');

        $this->assertDatabaseHas('categories', [
            'category_id' => $category->getKey(),
            'category_name' => 'Updated name',
            'description' => null,
            'image' => $category->image,
        ]);
    })->with(['putJson', 'patchJson']);

    test('returns 422 and keeps the category when an update clears a required field', function (string $field) {
        $category = Category::factory()->create();

        $this->patchJson('/api/v1/categories/'.$category->getKey(), [$field => null])
            ->assertUnprocessable()->assertJsonValidationErrors($field);

        $this->assertDatabaseHas('categories', [
            'category_id' => $category->getKey(), $field => $category->getAttribute($field),
        ]);
    })->with(['category_name']);

    test('deletes an unused category', function () {
        $category = Category::factory()->create();

        $this->deleteJson('/api/v1/categories/'.$category->getKey())->assertNoContent();

        $this->assertModelMissing($category);
    });

    test('returns 409 when deleting a category referenced by a product', function (bool $deleted) {
        $category = Category::factory()->create();
        $product = Product::factory()->for($category, 'category')->create(['isDeleted' => $deleted]);

        $this->deleteJson('/api/v1/categories/'.$category->getKey())
            ->assertConflict()
            ->assertJsonPath('message', 'Cannot delete a category that has products, including deleted products.');

        $this->assertModelExists($category);
        $this->assertDatabaseHas('products', ['ProductID' => $product->getKey(), 'isDeleted' => $deleted]);
    })->with(['active product' => [false], 'deleted product' => [true]]);
});

test('creates a category without an image and returns null for the default placeholder', function (array $image) {
    $response = $this->postJson('/api/v1/categories', ['category_name' => 'No image', ...$image])
        ->assertCreated()->assertJsonPath('data.image', null);

    $this->assertDatabaseHas('categories', [
        'category_id' => $response->json('data.category_id'), 'image' => null,
    ]);
})->with([
    'omitted' => [[]],
    'null' => [['image' => null]],
    'blank' => [['image' => '']],
]);

test('clears a category image to use the default placeholder', function () {
    $category = Category::factory()->create();

    $this->patchJson('/api/v1/categories/'.$category->getKey(), ['image' => null])
        ->assertOk()->assertJsonPath('data.image', null);

    $this->assertDatabaseHas('categories', ['category_id' => $category->getKey(), 'image' => null]);
});
