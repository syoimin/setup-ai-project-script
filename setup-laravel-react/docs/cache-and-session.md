# キャッシュとセッションの設定

## 設定概要

本プロジェクトでは、シンプルで保守性の高い構成を採用しています。

- **キャッシュ**: ファイルキャッシュ（Lambda の /tmp ディレクトリ）
- **セッション**: データベース（PostgreSQL）

## キャッシュ設定

### ファイルキャッシュ（Lambda /tmp）

```php
// config/cache.php
'default' => env('CACHE_DRIVER', 'file'),

'stores' => [
    'file' => [
        'driver' => 'file',
        'path' => storage_path('framework/cache/data'),
    ],
],
```

### Lambda環境での注意点

Lambda の `/tmp` ディレクトリは：
- 512MB まで利用可能
- 実行環境が再利用される間は永続化
- コールドスタート時にクリア

```bash
# .env
CACHE_DRIVER=file
```

### キャッシュの使用例

```php
use Illuminate\Support\Facades\Cache;

// キャッシュに保存（5分間）
Cache::put('key', 'value', now()->addMinutes(5));

// キャッシュから取得
$value = Cache::get('key');

// キャッシュがなければ実行して保存
$users = Cache::remember('users', 3600, function () {
    return User::all();
});
```

## セッション設定

### データベースセッション

```php
// config/session.php
'driver' => env('SESSION_DRIVER', 'database'),
'lifetime' => env('SESSION_LIFETIME', 120),
'expire_on_close' => false,
```

### マイグレーション

セッションテーブルは以下のマイグレーションで作成されます：

```php
// database/migrations/2024_01_01_000000_create_sessions_table.php
Schema::create('sessions', function (Blueprint $table) {
    $table->string('id')->primary();
    $table->foreignId('user_id')->nullable()->index();
    $table->string('ip_address', 45)->nullable();
    $table->text('user_agent')->nullable();
    $table->longText('payload');
    $table->integer('last_activity')->index();
});
```

### セットアップ

```bash
# マイグレーション実行
php artisan migrate

# Lambdaの場合
serverless invoke -f artisan --data '{"cli":"migrate --force"}'
```

### セッションの使用例（API認証）

```php
// コントローラー
use Illuminate\Support\Facades\Session;

public function login(LoginRequest $request)
{
    $credentials = $request->validated();
    
    if (Auth::attempt($credentials)) {
        $request->session()->regenerate();
        
        return response()->json([
            'data' => [
                'user' => Auth::user(),
                'session_id' => session()->getId(),
            ],
        ]);
    }
    
    throw new UnauthorizedException();
}
```

## API認証の推奨パターン

SPAの場合、セッションよりも**Laravel Sanctumのトークン認証**を推奨します。

### Sanctumのインストール

```bash
composer require laravel/sanctum
php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider"
php artisan migrate
```

### トークン認証の実装

```php
// app/Http/Controllers/Auth/LoginController.php
public function login(LoginRequest $request)
{
    $credentials = $request->validated();
    
    if (Auth::attempt($credentials)) {
        $user = Auth::user();
        $token = $user->createToken('api-token')->plainTextToken;
        
        return response()->json([
            'data' => [
                'user' => new UserResource($user),
                'token' => $token,
            ],
        ]);
    }
    
    throw new UnauthorizedException();
}

// 保護されたルート
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', [UserController::class, 'show']);
    Route::put('/user', [UserController::class, 'update']);
});
```

### フロントエンドでの使用

```typescript
// frontend/src/shared/api/client.ts
import axios from 'axios';

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
});

// トークンをインターセプターで自動付与
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('auth_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});
```

## パフォーマンス考慮事項

### ファイルキャッシュの制限

Lambda環境では：
- キャッシュは同一実行環境内でのみ有効
- 複数のLambdaインスタンス間で共有されない
- 頻繁にアクセスされるデータには適さない

### データベースセッションの制限

- セッション読み書きで毎回DBアクセス
- 高トラフィック時はDB負荷が増加

### スケールアップ時の選択肢

トラフィックが増えた場合の選択肢：

1. **Redis/ElastiCache**（推奨）
   ```bash
   # .env
   CACHE_DRIVER=redis
   SESSION_DRIVER=redis
   REDIS_HOST=your-elasticache-endpoint
   ```

2. **Memcached**
   ```bash
   # .env
   CACHE_DRIVER=memcached
   SESSION_DRIVER=memcached
   ```

3. **DynamoDB**（AWS特化）
   ```bash
   composer require aws/aws-sdk-php-laravel
   
   # .env
   CACHE_DRIVER=dynamodb
   SESSION_DRIVER=dynamodb
   DYNAMODB_CACHE_TABLE=laravel-cache
   ```

## まとめ

**開発初期〜中規模サービス**:
- ✅ ファイルキャッシュ
- ✅ データベースセッション
- ✅ Sanctumトークン認証（推奨）

**大規模サービス**:
- ✅ Redis/ElastiCache
- ✅ トークン認証

シンプルな構成から始め、必要に応じてスケールアップする戦略を推奨します。