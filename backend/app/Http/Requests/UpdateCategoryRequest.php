<?php

namespace App\Http\Requests;

class UpdateCategoryRequest extends StoreCategoryRequest
{
    /** @return array<string, array<int, string>> */
    public function rules(): array
    {
        return array_replace(parent::rules(), [
            'category_name' => ['sometimes', 'required', 'string', 'max:50'],
            'image' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);
    }
}
