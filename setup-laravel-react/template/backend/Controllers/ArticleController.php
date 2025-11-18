<?php

namespace App\Http\Controllers;

use App\Models\Article;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class ArticleController extends Controller {
    public function index(): JsonResponse {
        // $articles = Article::all();
        // return response()->json($articles);
        return response()->json(["message" => "This is a placeholder for the index method."]);
    }

    public function store(Request $request): JsonResponse {
        // $validated = $request->validate([
        //     'title' => 'required|string|max:255',
        //     'body' => 'required|string',
        // ]);

        // $article = Article::create($validated);

        // return response()->json($article, 201);
    }

    public function show(int $id): JsonResponse {
        // $article = Article::find($id);

        // if (!$article) {
        //     return response()->json(['error' => 'Article not found'], 404);
        // }

        // return response()->json($article);
    }

    public function update(Request $request, int $id): JsonResponse {
        // $article = Article::find($id);

        // if (!$article) {
        //     return response()->json(['error' => 'Article not found'], 404);
        // }

        // $validated = $request->validate([
        //     'title' => 'sometimes|required|string|max:255',
        //     'body' => 'sometimes|required|string',
        // ]);

        // $article->update($validated);

        // creturn response()->json($article);
    }

    public function destroy(int $id): JsonResponse {
        // $article = Article::find($id);

        // if (!$article) {
        //     return response()->json(['error' => 'Article not found'], 404);
        // }

        // $article->delete();

        return response()->json(['message' => 'Deleted successfully']);
    }
}