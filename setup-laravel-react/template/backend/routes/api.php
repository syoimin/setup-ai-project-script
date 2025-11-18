<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ArticleController;

// 'articles'というリソースに対して、RESTfulなCRUD操作に対応するルートを一括定義
Route::apiResource('articles', ArticleController::class);