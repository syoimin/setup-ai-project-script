<?php

declare(strict_types=1);

namespace App\Exceptions;

use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Throwable;

class Handler extends ExceptionHandler
{
    /**
     * 例外をHTTPレスポンスに変換
     */
    public function render($request, Throwable $e): JsonResponse
    {
        // API リクエストの場合は常にJSON返却
        if ($request->is('api/*')) {
            return $this->renderApiException($e);
        }

        return parent::render($request, $e);
    }

    /**
     * API例外をJSONレスポンスに変換
     */
    private function renderApiException(Throwable $e): JsonResponse
    {
        // カスタム例外
        if ($e instanceof AppException) {
            return response()->json($e->toArray(), $e->getStatusCode());
        }

        // Laravelのバリデーション例外
        if ($e instanceof ValidationException) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => '入力データが不正です',
                    'errors' => $e->errors(),
                ],
            ], 422);
        }

        // HTTPException
        if ($e instanceof HttpException) {
            return response()->json([
                'error' => [
                    'code' => 'HTTP_ERROR',
                    'message' => $e->getMessage() ?: 'エラーが発生しました',
                ],
            ], $e->getStatusCode());
        }

        // その他の例外（本番環境では詳細を隠す）
        $statusCode = 500;
        $message = config('app.debug')
            ? $e->getMessage()
            : '予期しないエラーが発生しました';

        // ログに記録
        $this->report($e);

        return response()->json([
            'error' => [
                'code' => 'INTERNAL_ERROR',
                'message' => $message,
            ],
        ], $statusCode);
    }

    /**
     * 報告すべき例外の型
     */
    protected $dontReport = [
        AppException::class,
        ValidationException::class,
    ];
}