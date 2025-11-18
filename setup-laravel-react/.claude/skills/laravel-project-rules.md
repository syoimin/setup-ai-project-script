# Laravel API プロジェクトルール

このファイルは Claude Code が常に参照する Laravel プロジェクトの基本ルールです。

## アーキテクチャ

### ディレクトリ構造（厳守）

```
app/
├── Models/              # Eloquent Models（データ構造）
├── Repositories/        # データアクセス層
├── Services/            # ビジネスロジック
├── Http/
│   ├── Controllers/     # リクエスト/レスポンス制御
│   ├── Requests/        # バリデーション
│   ├── Resources/       # API レスポンス整形
│   └── Middleware/      # ミドルウェア
├── Exceptions/          # カスタム例外
└── Providers/           # サービスプロバイダー

database/
├── migrations/          # DBマイグレーション
├── factories/           # テストデータ生成
└── seeders/             # 初期データ投入

tests/
├── Feature/             # 機能テスト（API）
└── Unit/                # 単体テスト
```

### レイヤー構造と責務

#### 1. Controller Layer (Http/Controllers/)
- **責務**: HTTPリクエストの受付、レスポンス返却
- **禁止**: ビジネスロジック、直接のDB操作
- **許可**: Serviceの呼び出し、Resourceでの整形

```php
// 良い例
public function store(CreateUserRequest $request)
{
    $result = $this->userService->createUser($request->validated());
    return new UserResource($result);
}

// 悪い例
public function store(Request $request)
{
    // バリデーションがない
    User::create($request->all()); // 直接DB操作
    // ビジネスロジックがController内にある
}
```

#### 2. Service Layer (Services/)
- **責務**: ビジネスロジック、複数Repositoryの調整、トランザクション管理
- **禁止**: HTTPレスポンス処理、直接のEloquent操作
- **許可**: Repository経由のDB操作、外部API呼び出し

```php
// 良い例
class UserService
{
    public function __construct(
        private UserRepository $userRepository,
        private MailService $mailService
    ) {}

    public function createUser(array $data): User
    {
        DB::beginTransaction();
        try {
            // ビジネスルール: メール重複チェック
            if ($this->userRepository->existsByEmail($data['email'])) {
                throw new DuplicateEmailException();
            }

            $user = $this->userRepository->create($data);
            $this->mailService->sendWelcomeEmail($user);
            
            DB::commit();
            return $user;
        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }
}
```

#### 3. Repository Layer (Repositories/)
- **責務**: データアクセスの抽象化、Eloquentクエリ
- **禁止**: ビジネスロジック、トランザクション管理
- **許可**: Eloquent操作、クエリビルダー

```php
// 良い例
class UserRepository
{
    public function __construct(private User $model) {}

    public function create(array $data): User
    {
        return $this->model->create($data);
    }

    public function findById(int $id): ?User
    {
        return $this->model->find($id);
    }

    public function existsByEmail(string $email): bool
    {
        return $this->model->where('email', $email)->exists();
    }
}
```

#### 4. Request Layer (Http/Requests/)
- **責務**: バリデーション、認可チェック
- **使用**: Laravel Form Request

```php
class CreateUserRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // または適切な認可ロジック
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ];
    }

    public function messages(): array
    {
        return [
            'email.unique' => 'このメールアドレスは既に使用されています。',
            'password.min' => 'パスワードは8文字以上である必要があります。',
        ];
    }
}
```

#### 5. Resource Layer (Http/Resources/)
- **責務**: APIレスポンスの整形、データ変換
- **禁止**: ビジネスロジック

```php
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'created_at' => $this->created_at->toIso8601String(),
            'updated_at' => $this->updated_at->toIso8601String(),
            // passwordは含めない
        ];
    }
}
```

## コーディング規約

### PSR-12準拠

```php
<?php

declare(strict_types=1);

namespace App\Services;

use App\Repositories\UserRepository;
use Illuminate\Support\Facades\Hash;

class UserService
{
    // 型宣言必須
    public function __construct(
        private UserRepository $userRepository
    ) {}

    // 戻り値の型宣言必須
    public function createUser(array $data): User
    {
        $data['password'] = Hash::make($data['password']);
        return $this->userRepository->create($data);
    }
}
```

### 命名規則

```php
// クラス名: PascalCase
class UserService {}
class UserRepository {}

// メソッド名: camelCase
public function createUser() {}
public function findById() {}

// 変数名: camelCase
$userData = [];
$userId = 1;

// 定数: UPPER_SNAKE_CASE
const MAX_LOGIN_ATTEMPTS = 5;

// データベーステーブル: snake_case（複数形）
users, orders, order_items

// モデル: PascalCase（単数形）
User, Order, OrderItem
```

### 型宣言必須

```php
// ✅ 必須
public function createUser(array $data): User
{
    // ...
}

// ❌ 禁止
public function createUser($data)
{
    // 型がない
}
```

### Eloquentのベストプラクティス

```php
// ✅ 良い例: Eager Loading
$users = User::with('orders')->get();

// ❌ 悪い例: N+1問題
$users = User::all();
foreach ($users as $user) {
    $user->orders; // N+1クエリ発生
}

// ✅ 良い例: チャンク処理
User::chunk(100, function ($users) {
    foreach ($users as $user) {
        // 処理
    }
});

// ❌ 悪い例: 全件取得
$users = User::all(); // メモリ不足の可能性
```

## 実装パターン

### 新機能実装の手順

1. **マイグレーション作成** (`database/migrations/`)
2. **モデル作成** (`app/Models/`)
3. **Repository作成** (`app/Repositories/`)
4. **Service作成** (`app/Services/`)
5. **Request作成** (`app/Http/Requests/`)
6. **Resource作成** (`app/Http/Resources/`)
7. **Controller作成** (`app/Http/Controllers/`)
8. **ルート定義** (`routes/api.php`)
9. **テスト作成** (`tests/Feature/`, `tests/Unit/`)

### テンプレート

#### Migration

```php
// database/migrations/xxxx_create_users_table.php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('password');
            $table->text('bio')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
```

#### Model

```php
// app/Models/User.php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class User extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'name',
        'email',
        'password',
        'bio',
    ];

    protected $hidden = [
        'password',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
    ];
}
```

#### Repository

```php
// app/Repositories/UserRepository.php
namespace App\Repositories;

use App\Models\User;
use Illuminate\Database\Eloquent\Collection;

class UserRepository
{
    public function __construct(private User $model) {}

    public function create(array $data): User
    {
        return $this->model->create($data);
    }

    public function findById(int $id): ?User
    {
        return $this->model->find($id);
    }

    public function findByEmail(string $email): ?User
    {
        return $this->model->where('email', $email)->first();
    }

    public function update(User $user, array $data): User
    {
        $user->update($data);
        return $user->fresh();
    }

    public function delete(User $user): bool
    {
        return $user->delete();
    }

    public function existsByEmail(string $email): bool
    {
        return $this->model->where('email', $email)->exists();
    }

    public function paginate(int $perPage = 15): \Illuminate\Pagination\LengthAwarePaginator
    {
        return $this->model->paginate($perPage);
    }
}
```

#### Service

```php
// app/Services/UserService.php
namespace App\Services;

use App\Repositories\UserRepository;
use App\Models\User;
use App\Exceptions\DuplicateEmailException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class UserService
{
    public function __construct(
        private UserRepository $userRepository
    ) {}

    public function createUser(array $data): User
    {
        return DB::transaction(function () use ($data) {
            // ビジネスルール: メール重複チェック
            if ($this->userRepository->existsByEmail($data['email'])) {
                throw new DuplicateEmailException('このメールアドレスは既に使用されています。');
            }

            // パスワードハッシュ化
            $data['password'] = Hash::make($data['password']);

            $user = $this->userRepository->create($data);

            // TODO: ウェルカムメール送信

            return $user;
        });
    }

    public function updateUser(User $user, array $data): User
    {
        return DB::transaction(function () use ($user, $data) {
            // メールアドレス変更時の重複チェック
            if (
                isset($data['email']) &&
                $data['email'] !== $user->email &&
                $this->userRepository->existsByEmail($data['email'])
            ) {
                throw new DuplicateEmailException('このメールアドレスは既に使用されています。');
            }

            return $this->userRepository->update($user, $data);
        });
    }

    public function deleteUser(User $user): bool
    {
        return DB::transaction(function () use ($user) {
            // TODO: 関連データの削除処理
            return $this->userRepository->delete($user);
        });
    }
}
```

#### Controller

```php
// app/Http/Controllers/Api/UserController.php
namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\CreateUserRequest;
use App\Http\Requests\UpdateUserRequest;
use App\Http\Resources\UserResource;
use App\Services\UserService;
use App\Models\User;
use Illuminate\Http\JsonResponse;

class UserController extends Controller
{
    public function __construct(
        private UserService $userService
    ) {}

    public function index(): JsonResponse
    {
        $users = User::paginate();
        return response()->json([
            'data' => UserResource::collection($users->items()),
            'meta' => [
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'per_page' => $users->perPage(),
                'total' => $users->total(),
            ],
        ]);
    }

    public function store(CreateUserRequest $request): JsonResponse
    {
        $user = $this->userService->createUser($request->validated());
        return response()->json(new UserResource($user), 201);
    }

    public function show(User $user): JsonResponse
    {
        return response()->json(new UserResource($user));
    }

    public function update(UpdateUserRequest $request, User $user): JsonResponse
    {
        $user = $this->userService->updateUser($user, $request->validated());
        return response()->json(new UserResource($user));
    }

    public function destroy(User $user): JsonResponse
    {
        $this->userService->deleteUser($user);
        return response()->json(null, 204);
    }
}
```

## Claude Codeでの開発フロー

### 機能実装時のプロンプト例

```
新しく「注文管理」機能を実装してください。

要件:
- 注文の作成、取得、更新、キャンセル
- ユーザーIDとの紐付け
- ステータス管理（pending, confirmed, shipped, delivered, cancelled）
- 金額計算

制約:
- 上記のレイヤー構造に厳密に従う
- 型宣言必須
- トランザクション使用
- テストも作成

まず、マイグレーションから段階的に実装してください。
```

## 禁止事項

### 絶対にやってはいけないこと

1. **レイヤーの責務違反**
   - Controllerにビジネスロジック
   - Repositoryにビジネスロジック
   - ServiceでEloquent直接操作

2. **型安全性の破壊**
   - 型宣言なしの関数
   - mixed型の乱用

3. **セキュリティリスク**
   - SQLインジェクション
   - Mass Assignment脆弱性
   - 認証なしのエンドポイント

4. **パフォーマンス問題**
   - N+1クエリ
   - 全件取得
   - トランザクションなしのデータ変更

## AWS Lambda対応

### serverless.yml設定

```yaml
service: laravel-api

provider:
  name: aws
  region: ap-northeast-1
  runtime: php-82
  environment:
    APP_ENV: production
    DB_CONNECTION: pgsql
    DB_HOST: ${env:DB_HOST}
    CACHE_DRIVER: dynamodb
    QUEUE_CONNECTION: sqs

functions:
  web:
    handler: public/index.php
    timeout: 28
    layers:
      - ${bref:layer.php-82-fpm}
    events:
      - httpApi: '*'

  artisan:
    handler: artisan
    timeout: 120
    layers:
      - ${bref:layer.php-82}
      - ${bref:layer.console}

plugins:
  - ./vendor/bref/bref
```

## テスト

### Feature Test例

```php
// tests/Feature/Api/UserControllerTest.php
namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_can_create_user(): void
    {
        $response = $this->postJson('/api/users', [
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(201)
            ->assertJsonStructure([
                'data' => ['id', 'name', 'email', 'created_at'],
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'test@example.com',
        ]);
    }

    public function test_cannot_create_user_with_duplicate_email(): void
    {
        User::factory()->create(['email' => 'test@example.com']);

        $response = $this->postJson('/api/users', [
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(422);
    }
}
```

## 参考資料

- Laravel公式ドキュメント: https://laravel.com/docs
- Bref for Laravel: https://bref.sh/docs/frameworks/laravel.html
- PSR-12: https://www.php-fig.org/psr/psr-12/