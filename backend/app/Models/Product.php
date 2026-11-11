<?php

namespace App\Models;

use Database\Factories\ProductFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['ProductName', 'Description', 'CategoryID', 'Barcode', 'Expiredate', 'Qty', 'UnitPriceIn', 'UnitPriceOut', 'ProductImage'])]
class Product extends Model
{
    /** @use HasFactory<ProductFactory> */
    use HasFactory;

    protected $primaryKey = 'ProductID';

    public $timestamps = false;

    protected static function booted(): void
    {
        static::addGlobalScope('not_deleted', function (Builder $query): void {
            $query->where($query->qualifyColumn('isDeleted'), false);
        });
    }

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'CategoryID' => 'integer',
            'Expiredate' => 'date:Y-m-d',
            'Qty' => 'integer',
            'UnitPriceIn' => 'decimal:2',
            'UnitPriceOut' => 'decimal:2',
            'isDeleted' => 'boolean',
        ];
    }

    /** @return BelongsTo<Category, $this> */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'CategoryID', 'category_id');
    }
}
