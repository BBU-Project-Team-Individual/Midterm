# Midterm

Product inventory app with a Laravel REST API and a Flutter mobile client.

| Folder | Description |
| --- | --- |
| [`backend/`](backend/README.md) | Laravel 13 API: categories, products, image uploads (`/api/v1`) |
| [`mobile/`](mobile/README.md) | Flutter app: product list, category filter, add/edit/delete |

## Quick start

```bash
# 1. Backend
cd backend
composer setup
./serve-api.sh          # serves the API on http://127.0.0.1:8001

# 2. Mobile (in another terminal)
cd mobile
flutter pub get
flutter run
```

See each folder's README for configuration and API details.
