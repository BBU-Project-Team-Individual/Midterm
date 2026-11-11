<?php

namespace App\Http\Requests;

class UpdateProductRequest extends StoreProductRequest
{
    /** @return array<string, array<int, mixed>> */
    public function rules(): array
    {
        $rules = parent::rules();
        array_unshift($rules['ProductName'], 'sometimes');
        array_unshift($rules['CategoryID'], 'sometimes');

        return $rules;
    }
}
