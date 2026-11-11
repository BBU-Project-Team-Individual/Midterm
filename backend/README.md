# Midterm API

A Laravel 13 application (PHP 8.3+) providing a versioned REST API for **categories**, **products**, and **image uploads**.

## Requirements

- PHP 8.3+ and [Composer](https://getcomposer.org)
- Node.js and npm
- SQLite (default database)

## Getting Started

```bash
git clone <your-repository-url> midterm
cd midterm

composer setup
```

`composer setup` installs dependencies, creates `.env` from `.env.example`, generates the app key, runs migrations, and builds the frontend assets.

Manual alternative:

```bash
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite   # if it does not exist
php artisan migrate
npm install && npm run build
```

## Running the App

```bash
composer dev          # app + dev tooling
./serve-api.sh        # API only, on port 8001 (override with API_PORT / API_BIND_ADDRESS)
```

## API Endpoints (`/api/v1`)

| Method | Endpoint | Description |
| --- | --- | --- |
| GET, POST | `/categories` | List / create categories |
| GET, PUT/PATCH, DELETE | `/categories/{category}` | Show / update / delete a category |
| GET, POST | `/products` | List / create products |
| GET, PUT/PATCH, DELETE | `/products/{product}` | Show / update / delete a product |
| POST | `/uploads` | Upload an image (max 5 MB) |

Run `php artisan route:list --path=api` for the full list.

## Testing

```bash
composer test
```

## License

Open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
