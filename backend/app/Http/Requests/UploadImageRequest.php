<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UploadImageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, array<int, string>> */
    public function rules(): array
    {
        return [
            'image' => ['bail', 'required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ];
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        return [
            'image.required' => 'Please choose an image.',
            'image.image' => 'Choose a JPG, PNG, or WebP image.',
            'image.mimes' => 'Choose a JPG, PNG, or WebP image.',
            'image.max' => 'Choose an image no larger than 5 MB.',
        ];
    }
}
