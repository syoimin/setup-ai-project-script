<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Article extends Model {
    /**
     * 一括割り当て可能な属性。
     * @var array
     */
    protected $fillable = ['title', 'body'];
}