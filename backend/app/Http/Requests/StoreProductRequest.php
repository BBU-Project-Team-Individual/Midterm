<?php

namespace App\Http\Requests;

use App\Models\Category;
use App\Models\Product;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, array<int, mixed>> */
    public function rules(): array
    {
        $barcode = Rule::unique(Product::class, 'Barcode');

        if ($this->route('product') instanceof Product) {
            $barcode->ignore($this->route('product'));
        }

        return [
            'ProductName' => ['required', 'string', 'max:100'],
            'Description' => ['nullable', 'string', 'max:255'],
            'CategoryID' => ['required', 'integer', Rule::exists(Category::class, 'category_id')],
            'Barcode' => ['nullable', 'string', 'max:255', $barcode],
            'Expiredate' => ['nullable', 'date_format:Y-m-d'],
            'Qty' => ['sometimes', 'required', 'integer', 'min:0', 'max:2147483647'],
            'UnitPriceIn' => ['sometimes', 'required', 'numeric', 'decimal:0,2', 'min:0', 'max:99999999.99'],
            'UnitPriceOut' => ['sometimes', 'required', 'numeric', 'decimal:0,2', 'min:0', 'max:99999999.99'],
            'ProductImage' => ['nullable', 'string', 'max:255'],
            'ProductID' => ['prohibited'],
            'isDeleted' => ['prohibited'],
        ];
    }
}
