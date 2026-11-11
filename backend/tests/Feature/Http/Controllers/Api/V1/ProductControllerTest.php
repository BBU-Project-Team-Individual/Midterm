<?php

use App\Models\Category;
use App\Models\Product;
use Database\Seeders\ProductSeeder;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;

uses(LazilyRefreshDatabase::class);

describe('product reads', function () {
    test('lists active products newest first with categories and pagination', function () {
        $category = Category::factory()->create();
        Product::factory()->for($category, 'category')->create();
        $newest = Product::factory()->for($category, 'category')->create();
        Product::factory()->for($category, 'category')->create(['isDeleted' => true]);

        $this->getJson('/api/v1/products?per_page=1')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.ProductID', $newest->getKey())
            ->assertJsonPath('data.0.category.category_id', $category->getKey())
            ->assertJsonPath('meta.total', 2);
    });

    test('filters products by category', function () {
        $product = Product::factory()->create();
        Product::factory()->create();

        $this->getJson('/api/v1/products?CategoryID='.$product->CategoryID)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.ProductID', $product->getKey());
    });

    test('shows all product fields with date and decimal values', function () {
        $product = Product::factory()->create(['Expiredate' => '2027-12-31']);

        $this->getJson('/api/v1/products/'.$product->getKey())
            ->assertOk()
            ->assertJsonPath('data.ProductID', $product->getKey())
            ->assertJsonPath('data.Expiredate', '2027-12-31')
            ->assertJsonPath('data.UnitPriceIn', '1.50')
            ->assertJsonPath('data.UnitPriceOut', '2.00')
            ->assertJsonPath('data.Qty', 10)
            ->assertJsonPath('data.isDeleted', false)
            ->assertJsonPath('data.category.category_id', $product->CategoryID);
    });

    test('returns 422 for invalid list parameters', function (string $query, string $field) {
        $this->getJson('/api/v1/products?'.$query)
            ->assertUnprocessable()->assertJsonValidationErrors($field);
    })->with([
        ['page=0', 'page'], ['per_page=0', 'per_page'],
        ['per_page=101', 'per_page'], ['per_page=abc', 'per_page'],
        ['CategoryID=999', 'CategoryID'], ['CategoryID=abc', 'CategoryID'],
    ]);

    test('returns 404 JSON for missing products on every member endpoint', function (string $method) {
        $this->{$method}('/api/v1/products/999')
            ->assertNotFound()->assertJsonStructure(['message']);
    })->with(['get', 'putJson', 'patchJson', 'deleteJson']);
});

describe('product writes', function () {
    test('creates a product with all editable fields', function () {
        $category = Category::factory()->create();
        $payload = [
            'ProductName' => 'ទឹកសុទ្ធ', 'Description' => 'Mineral water',
            'CategoryID' => $category->getKey(), 'Barcode' => '1234567890',
            'Expiredate' => '2027-12-31', 'Qty' => 24,
            'UnitPriceIn' => '0.25', 'UnitPriceOut' => '0.50',
            'ProductImage' => 'https://example.com/water.png',
        ];

        $response = $this->postJson('/api/v1/products', $payload)
            ->assertCreated()
            ->assertJsonPath('data.ProductName', 'ទឹកសុទ្ធ')
            ->assertJsonPath('data.category.category_id', $category->getKey());

        $this->assertDatabaseHas('products', [
            ...$payload, 'ProductID' => $response->json('data.ProductID'), 'isDeleted' => false,
        ]);
    });

    test('applies database defaults when optional fields are omitted', function () {
        $category = Category::factory()->create();

        $this->postJson('/api/v1/products', [
            'ProductName' => 'Water', 'CategoryID' => $category->getKey(),
        ])->assertCreated()
            ->assertJsonPath('data.Qty', 0)
            ->assertJsonPath('data.UnitPriceIn', '0.00')
            ->assertJsonPath('data.UnitPriceOut', '0.00')
            ->assertJsonPath('data.isDeleted', false)
            ->assertJsonPath('data.Expiredate', null);

        $this->assertDatabaseHas('products', ['ProductName' => 'Water', 'Qty' => 0, 'UnitPriceIn' => 0]);
    });

    test('returns 422 when required product fields are missing', function () {
        $this->postJson('/api/v1/products', [])
            ->assertUnprocessable()->assertJsonValidationErrors(['ProductName', 'CategoryID']);

        $this->assertDatabaseCount('products', 0);
    });

    test('returns 422 without saving invalid product fields', function (string $field, mixed $value) {
        $category = Category::factory()->create();
        $payload = ['ProductName' => 'Water', 'CategoryID' => $category->getKey(), $field => $value];

        $this->postJson('/api/v1/products', $payload)
            ->assertUnprocessable()->assertJsonValidationErrors($field);

        $this->assertDatabaseCount('products', 0);
    })->with([
        'name length' => ['ProductName', str_repeat('a', 101)],
        'name type' => ['ProductName', 123],
        'missing category' => ['CategoryID', 999],
        'category type' => ['CategoryID', 'abc'],
        'description length' => ['Description', str_repeat('a', 256)],
        'barcode type' => ['Barcode', 12345],
        'barcode length' => ['Barcode', str_repeat('a', 256)],
        'invalid date' => ['Expiredate', '2027-02-30'],
        'wrong date format' => ['Expiredate', '31/12/2027'],
        'negative quantity' => ['Qty', -1],
        'fractional quantity' => ['Qty', 1.5],
        'quantity overflow' => ['Qty', 2147483648],
        'null quantity' => ['Qty', null],
        'negative cost' => ['UnitPriceIn', -1],
        'cost overflow' => ['UnitPriceIn', '100000000.00'],
        'cost precision' => ['UnitPriceIn', '1.001'],
        'negative price' => ['UnitPriceOut', -1],
        'price overflow' => ['UnitPriceOut', '100000000.00'],
        'price precision' => ['UnitPriceOut', '1.001'],
        'null price' => ['UnitPriceOut', null],
        'image length' => ['ProductImage', str_repeat('a', 256)],
        'image type' => ['ProductImage', []],
        'protected ID' => ['ProductID', 10],
        'protected deletion flag' => ['isDeleted', true],
    ]);

    test('returns 422 for a duplicate barcode including deleted products', function (bool $deleted) {
        $existing = Product::factory()->create(['isDeleted' => $deleted]);

        $this->postJson('/api/v1/products', [
            'ProductName' => 'Duplicate', 'CategoryID' => $existing->CategoryID,
            'Barcode' => $existing->Barcode,
        ])->assertUnprocessable()->assertJsonValidationErrors('Barcode');

        $this->assertDatabaseCount('products', 1);
    })->with([false, true]);

    test('updates a product and its category while retaining its barcode', function (string $method) {
        $product = Product::factory()->create();
        $newCategory = Category::factory()->create();

        $this->{$method}('/api/v1/products/'.$product->getKey(), [
            'ProductName' => 'Updated water', 'CategoryID' => $newCategory->getKey(),
            'Qty' => 12, 'Barcode' => $product->Barcode,
        ])->assertOk()
            ->assertJsonPath('data.ProductName', 'Updated water')
            ->assertJsonPath('data.category.category_id', $newCategory->getKey());

        $this->assertDatabaseHas('products', [
            'ProductID' => $product->getKey(), 'ProductName' => 'Updated water',
            'CategoryID' => $newCategory->getKey(), 'Qty' => 12, 'Barcode' => $product->Barcode,
        ]);
    })->with(['putJson', 'patchJson']);

    test('clears nullable fields and preserves omitted fields on a partial update', function () {
        $product = Product::factory()->create(['Expiredate' => '2027-01-01']);

        $this->patchJson('/api/v1/products/'.$product->getKey(), [
            'Description' => null, 'Barcode' => null, 'Expiredate' => null, 'ProductImage' => null,
        ])->assertOk()->assertJsonPath('data.Expiredate', null);

        $this->assertDatabaseHas('products', [
            'ProductID' => $product->getKey(), 'ProductName' => $product->ProductName,
            'Description' => null, 'Barcode' => null, 'Expiredate' => null, 'ProductImage' => null,
        ]);
    });

    test('returns 422 and keeps product data when an update is invalid', function (string $field, mixed $value) {
        $product = Product::factory()->create();

        $this->patchJson('/api/v1/products/'.$product->getKey(), [$field => $value])
            ->assertUnprocessable()->assertJsonValidationErrors($field);

        $this->assertDatabaseHas('products', [
            'ProductID' => $product->getKey(), $field => $product->getAttribute($field),
        ]);
    })->with([
        ['ProductName', null], ['CategoryID', null], ['Qty', -1], ['isDeleted', true],
    ]);

    test('returns 422 without changing a barcode to one used by another product', function () {
        $product = Product::factory()->create();
        $other = Product::factory()->create();

        $this->patchJson('/api/v1/products/'.$product->getKey(), ['Barcode' => $other->Barcode])
            ->assertUnprocessable()->assertJsonValidationErrors('Barcode');

        $this->assertDatabaseHas('products', ['ProductID' => $product->getKey(), 'Barcode' => $product->Barcode]);
    });

    test('soft deletes a product using isDeleted', function () {
        $product = Product::factory()->create();

        $this->deleteJson('/api/v1/products/'.$product->getKey())->assertNoContent();

        $this->assertDatabaseHas('products', ['ProductID' => $product->getKey(), 'isDeleted' => true]);
    });

    test('returns 404 when accessing a deleted product', function (string $method) {
        $product = Product::factory()->create(['isDeleted' => true]);

        $this->{$method}('/api/v1/products/'.$product->getKey())
            ->assertNotFound()->assertJsonStructure(['message']);
    })->with(['getJson', 'putJson', 'patchJson', 'deleteJson']);

    test('seeds repeatable sample categories and products', function () {
        $this->seed(ProductSeeder::class);
        $this->seed(ProductSeeder::class);

        $this->assertDatabaseCount('categories', 3);
        $this->assertDatabaseCount('products', 3);
        $this->assertDatabaseHas('products', ['ProductName' => 'Mineral Water', 'Qty' => 20]);
    });
});
