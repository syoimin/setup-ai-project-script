<?php

declare(strict_types=1);

namespace App\Exceptions;

use Exception;

/**
 * アプリケーション基底例外クラス
 */
abstract class AppException extends Exception
{
    public function __construct(
        string $message = '',
        protected int $statusCode = 500,
        protected string $errorCode = 'INTERNAL_ERROR',
        ?\Throwable $previous = null
    ) {
        parent::__construct($message, 0, $previous);
    }

    public function getStatusCode(): int
    {
        return $this->statusCode;
    }

    public function getErrorCode(): string
    {
        return $this->errorCode;
    }

    /**
     * JSON APIレスポンスに変換
     */
    public function toArray(): array
    {
        return [
            'error' => [
                'code' => $this->errorCode,
                'message' => $this->message,
            ],
        ];
    }
}

/**
 * バリデーションエラー
 */
class ValidationException extends AppException
{
    public function __construct(
        string $message = '入力データが不正です',
        private array $errors = []
    ) {
        parent::__construct($message, 422, 'VALIDATION_ERROR');
    }

    public function getErrors(): array
    {
        return $this->errors;
    }

    public function toArray(): array
    {
        return [
            'error' => [
                'code' => $this->errorCode,
                'message' => $this->message,
                'errors' => $this->errors,
            ],
        ];
    }
}

/**
 * 重複エラー（例: メールアドレスの重複）
 */
class DuplicateEmailException extends AppException
{
    public function __construct(string $message = 'このメールアドレスは既に使用されています')
    {
        parent::__construct($message, 409, 'DUPLICATE_EMAIL');
    }
}

/**
 * 未認証エラー
 */
class UnauthorizedException extends AppException
{
    public function __construct(string $message = '認証が必要です')
    {
        parent::__construct($message, 401, 'UNAUTHORIZED');
    }
}

/**
 * 権限エラー
 */
class ForbiddenException extends AppException
{
    public function __construct(string $message = 'アクセス権限がありません')
    {
        parent::__construct($message, 403, 'FORBIDDEN');
    }
}

/**
 * リソースが見つからないエラー
 */
class NotFoundException extends AppException
{
    public function __construct(string $message = 'リソースが見つかりません')
    {
        parent::__construct($message, 404, 'NOT_FOUND');
    }
}

/**
 * 競合エラー（例: 楽観的ロックの失敗）
 */
class ConflictException extends AppException
{
    public function __construct(string $message = 'データの競合が発生しました')
    {
        parent::__construct($message, 409, 'CONFLICT');
    }
}

/**
 * レート制限エラー
 */
class RateLimitException extends AppException
{
    public function __construct(string $message = 'リクエスト数が上限を超えました')
    {
        parent::__construct($message, 429, 'RATE_LIMIT_EXCEEDED');
    }
}

/**
 * 外部サービスエラー
 */
class ExternalServiceException extends AppException
{
    public function __construct(
        string $message,
        private string $serviceName
    ) {
        parent::__construct($message, 502, 'EXTERNAL_SERVICE_ERROR');
    }

    public function getServiceName(): string
    {
        return $this->serviceName;
    }

    public function toArray(): array
    {
        return [
            'error' => [
                'code' => $this->errorCode,
                'message' => $this->message,
                'service' => $this->serviceName,
            ],
        ];
    }
}