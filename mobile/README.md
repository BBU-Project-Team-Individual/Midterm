# Product inventory

Flutter product CRUD connected to the Laravel project at
`/Users/ingvanly/projects/midterm`. Includes a paginated product list, category
filter, add/edit forms, category management, Laravel validation errors, and delete confirmation.

## Run

Start the backend if it is not already running:

```sh
cd /Users/ingvanly/projects/midterm
./serve-api.sh
```

Run Flutter from this directory:

```sh
flutter pub get
flutter run
```

The default API URL is `http://127.0.0.1:8001/api/v1` on web, desktop, and the
iOS simulator. Android uses `http://10.0.2.2:8001/api/v1` to reach the host.
Port 8001 is used because another local project occupies port 8000.
The backend launcher sets PHP's upload limit to 5 MB and its request limit to
6 MB for multipart overhead, without changing your global PHP configuration.

For a physical device or a different server, supply the full API base URL:

```sh
flutter run --dart-define=API_BASE_URL=http://YOUR_MAC_LAN_IP:8001/api/v1
```

Rebuild/restart after changing `API_BASE_URL`. Android debug/profile builds
allow local HTTP; use HTTPS for Android release builds. Apple targets allow
local networking. Web clients require the API to permit the app's origin with
CORS; use HTTPS for both the app and API when hosting over HTTPS.

## Categories and sample data

Open **Categories → New** to create a category in the app. Enter its
name, plus an optional image and
description. Product forms select an existing category using the same compact
menu style as the product filter. Create new categories on the Categories page.

Category cards provide edit and delete actions. The API prevents deleting a
category that has products, including soft-deleted products, and the app displays
that explanation.

The category dropdown reads every page of `/categories`. A category must exist
before creating a product. If you want sample data, the backend already provides
an optional seeder:

```sh
cd /Users/ingvanly/projects/midterm
php artisan db:seed --class=ProductSeeder
```

This writes sample categories and products to the backend database. Refresh the
app after seeding.

## Image uploads

Product and category forms use **Choose image** to open your device's file
picker. Select a JPG, PNG, or WebP image up to 5 MB. The form shows a preview;
**Change image** replaces it and **Remove** clears it. Images are optional for
both products and categories. A gray default image is shown when
no image is chosen, while a remote image is loading, or if an image cannot load.
Uploads start when you save.

The server uploads the file first, then the form saves the returned reference
with the product/category. A validation retry reuses the uploaded file. Relative
storage paths resolve against `API_BASE_URL`, including Android's host address.

The Laravel backend provides `POST /api/v1/uploads`, validates image content and
the 5 MB limit, stores generated filenames in `storage/app/public/catalog`, and
returns `data.path` as `/storage/catalog/...`. The `public/storage` link serves
the images. Its rate limit is 30 requests per minute. Uploaded images are
publicly accessible, consistent with the current unauthenticated product and
category API. The database keeps the path in `ProductImage` or `image`; the file
stays in Laravel's storage folder.

After adding the new native file-picker plugin, fully stop the Flutter app and
run `flutter run` again; hot reload cannot register a new plugin. macOS debug and
release entitlements include read access to user-selected files.

## API contract

All requests use `/api/v1` and accept JSON. Product/category writes send JSON;
the upload endpoint accepts a multipart `image` file:

- `GET /products?page=1&per_page=15`, optionally with `CategoryID`.
- `GET /categories?page=1&per_page=100`, following all category pages.
- `POST /products` to create, `PUT /products/{id}` to update.
- `DELETE /products/{id}` accepts an empty 204 response. Laravel handles soft deletion.
- `POST /categories` and `PUT /categories/{id}` send `category_name`, `description`, and `image`.
- `DELETE /categories/{id}` accepts 204 and displays Laravel's 409 conflict message when a category is in use.
- `POST /uploads` returns 201 with `data.path` for the uploaded image.

Forms send `ProductName`, `Description`, `CategoryID`, `Barcode`, `Expiredate`,
`Qty`, `UnitPriceIn`, `UnitPriceOut`, and `ProductImage`. Blank nullable fields
are sent as JSON null so edits can clear values. Prices remain decimal strings;
dates use `YYYY-MM-DD`. `ProductImage` is a URL/path reference, matching the API's
string field and is populated automatically from the image upload. `ProductID`
and `isDeleted` are never sent.

## Verify

```sh
flutter analyze
flutter test
flutter build web
```

Tests exercise the API contract, pagination, category filtering, create/edit
flows, 422 errors, delete confirmation, and retry behavior with a mock HTTP client.
