<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Product;
use Illuminate\Database\Seeder;

class ProductSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $this->call(CategorySeeder::class);

        foreach ([
            ['Beverages', 'Mineral Water', '100000000001', '0.25', '0.50'],
            ['Food', 'Instant Noodles', '100000000002', '0.40', '0.75'],
            ['Household', 'Hand Soap', '100000000003', '1.00', '1.50'],
        ] as [$category, $name, $barcode, $cost, $price]) {
            Product::withoutGlobalScope('not_deleted')->firstOrCreate(['Barcode' => $barcode], [
                'ProductName' => $name,
                'Description' => $name,
                'CategoryID' => Category::where('category_name', $category)->firstOrFail()->getKey(),
                'Qty' => 20,
                'UnitPriceIn' => $cost,
                'UnitPriceOut' => $price,
                'ProductImage' => 'https://placehold.co/600x400/png?text='.rawurlencode($name),
            ]);
        }
    }
}
