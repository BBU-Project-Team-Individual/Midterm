<?php

use Illuminate\Filesystem\FilesystemAdapter;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

uses(LazilyRefreshDatabase::class);

function catalogPng(): string
{
    return base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=');
}

test('uploads an image to public storage with a generated name and returns 201', function () {
    Storage::fake('public');

    $response = $this->post('/api/v1/uploads', [
        'image' => UploadedFile::fake()->createWithContent('my-photo.png', catalogPng()),
    ], ['Accept' => 'application/json'])->assertCreated();

    $path = $response->json('data.path');
    expect($path)->toStartWith('/storage/catalog/')->toEndWith('.png')->not->toContain('my-photo');
    $stored = substr($path, strlen('/storage/'));
    Storage::disk('public')->assertExists($stored);
    expect(Storage::disk('public')->get($stored))->toBe(catalogPng());
});

test('returns 422 with an image message when the file is missing', function () {
    Storage::fake('public');

    $this->postJson('/api/v1/uploads', [])
        ->assertUnprocessable()->assertJsonValidationErrors('image')
        ->assertJsonPath('errors.image.0', 'Please choose an image.');

    Storage::disk('public')->assertDirectoryEmpty('catalog');
});

test('returns 422 without storing unsafe or unsupported file content', function (string $name, string $contents) {
    Storage::fake('public');
    $file = UploadedFile::fake()->createWithContent($name, $contents);
    $upload = new UploadedFile($file->getPathname(), $name, test: true);

    $this->post('/api/v1/uploads', [
        'image' => $upload,
    ], ['Accept' => 'application/json'])
        ->assertUnprocessable()->assertJsonValidationErrors('image')
        ->assertJsonPath('errors.image.0', 'Choose a JPG, PNG, or WebP image.');

    Storage::disk('public')->assertDirectoryEmpty('catalog');
})->with([
    'disguised script' => ['photo.jpg', '<?php echo "unsafe";'],
    'SVG' => ['photo.svg', '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><script>alert(1)</script></svg>'],
    'GIF' => ['photo.gif', base64_decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7')],
]);

test('returns 422 without storing an image above five megabytes', function () {
    Storage::fake('public');

    $this->post('/api/v1/uploads', [
        'image' => UploadedFile::fake()->createWithContent('large.png', catalogPng())->size(5121),
    ], ['Accept' => 'application/json'])
        ->assertUnprocessable()->assertJsonValidationErrors('image')
        ->assertJsonPath('errors.image.0', 'Choose an image no larger than 5 MB.');

    Storage::disk('public')->assertDirectoryEmpty('catalog');
});

test('returns 500 with a retry message when storage fails', function () {
    $disk = Mockery::mock(FilesystemAdapter::class);
    $disk->shouldReceive('putFileAs')->once()->andReturn(false);
    Storage::shouldReceive('disk')->with('public')->once()->andReturn($disk);

    $this->post('/api/v1/uploads', [
        'image' => UploadedFile::fake()->createWithContent('photo.png', catalogPng()),
    ], ['Accept' => 'application/json'])->assertInternalServerError()
        ->assertJsonPath('message', 'Image could not be stored. Please try again.');
});

test('uses the uploaded image in category and product records', function () {
    Storage::fake('public');
    $path = $this->post('/api/v1/uploads', [
        'image' => UploadedFile::fake()->createWithContent('photo.png', catalogPng()),
    ], ['Accept' => 'application/json'])->assertCreated()->json('data.path');

    $category = $this->postJson('/api/v1/categories', [
        'category_name' => 'Photos', 'image' => $path,
    ])->assertCreated()->assertJsonPath('data.image', $path)->json('data.category_id');
    $product = $this->postJson('/api/v1/products', [
        'ProductName' => 'Photo product', 'CategoryID' => $category, 'ProductImage' => $path,
    ])->assertCreated()->assertJsonPath('data.ProductImage', $path)->json('data.ProductID');

    $this->assertDatabaseHas('categories', ['category_id' => $category, 'image' => $path]);
    $this->assertDatabaseHas('products', ['ProductID' => $product, 'ProductImage' => $path]);
    Storage::disk('public')->assertExists(substr($path, strlen('/storage/')));
});
