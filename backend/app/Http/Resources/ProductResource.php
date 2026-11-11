<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'ProductID' => $this->ProductID,
            'ProductName' => $this->ProductName,
            'Description' => $this->Description,
            'CategoryID' => $this->CategoryID,
            'Barcode' => $this->Barcode,
            'Expiredate' => $this->Expiredate?->format('Y-m-d'),
            'Qty' => $this->Qty,
            'UnitPriceIn' => $this->UnitPriceIn,
            'UnitPriceOut' => $this->UnitPriceOut,
            'ProductImage' => $this->ProductImage,
            'isDeleted' => $this->isDeleted,
            'category' => new CategoryResource($this->whenLoaded('category')),
        ];
    }
}
