<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\Product;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Product>
 */
class ProductFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'ProductName' => fake()->words(3, true),
            'Description' => fake()->sentence(),
            'CategoryID' => Category::factory(),
            'Barcode' => fake()->unique()->ean13(),
            'Expiredate' => null,
            'Qty' => 10,
            'UnitPriceIn' => '1.50',
            'UnitPriceOut' => '2.00',
            'ProductImage' => null,
            'isDeleted' => false,
        ];
    }
}
