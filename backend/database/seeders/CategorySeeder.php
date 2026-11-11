<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

class CategorySeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        foreach (['Beverages', 'Food', 'Household'] as $name) {
            Category::firstOrCreate(['category_name' => $name], [
                'description' => $name.' products',
                'image' => 'https://placehold.co/600x400/png?text='.rawurlencode($name),
            ]);
        }
    }
}
