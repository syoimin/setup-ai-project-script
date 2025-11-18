# Laravel + React SPA AI駆動開発プロジェクト

Laravel RESTful API + React SPA + AWS Lambda構成のAI駆動開発テンプレート。

## 特徴

- ✅ 堅牢なアーキテクチャ（レイヤードアーキテクチャ）
- ✅ 型安全性（PHP 8.2 + TypeScript strict mode）
- ✅ AWS Lambdaでサーバーレス運用
- ✅ RDS PostgreSQLで信頼性の高いDB
- ✅ React Query + Zodで型安全なフロントエンド
- ✅ 明確な実装パターン（Claude Code対応）
- ✅ 受託開発に適した構造

## 技術スタック

### バックエンド
- **Framework**: Laravel 11
- **Database**: AWS RDS PostgreSQL
- **Runtime**: AWS Lambda (PHP 8.2)
- **Cache**: File Cache (/tmp)
- **Session**: Database (PostgreSQL)
- **Queue**: AWS SQS
- **Storage**: AWS S3

### フロントエンド
- **Framework**: React 18 + TypeScript
- **Build**: Vite
- **State**: TanStack Query (React Query)
- **Routing**: React Router
- **Validation**: Zod
- **HTTP**: Axios
- **Hosting**: AWS S3 + CloudFront

## プロジェクト構造

```
project/
├── backend/              # Laravel API
│   ├── app/
│   │   ├── Models/
│   │   ├── Services/
│   │   ├── Repositories/
│   │   ├── Http/
│   │   │   ├── Controllers/
│   │   │   ├── Requests/
│   │   │   └── Resources/
│   │   └── Exceptions/
│   ├── database/
│   ├── routes/
│   ├── tests/
│   └── serverless.yml
│
├── frontend/             # React SPA
│   ├── src/
│   │   ├── features/
│   │   ├── shared/
│   │   ├── lib/
│   │   ├── pages/
│   │   └── App.tsx
│   └── vite.config.ts
│
├── .claude/
│   └── skills/
│       ├── laravel-project-rules.md
│       └── react-project-rules.md
│
├── docs/
│   └── for-ai/
│
└── .github/
    └── workflows/
        └── ci.yml
```

## セットアップ

### 前提条件

- PHP 8.2+
- Composer
- Node.js 20+
- PostgreSQL 15+（ローカル開発用）
- AWS CLI（デプロイ用）

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd <project-name>
```

### 2. バックエンドセットアップ

```bash
cd backend

# 依存関係インストール
composer install

# 環境変数設定
cp .env.example .env
# .envを編集してDB接続情報を設定

# アプリケーションキー生成
php artisan key:generate

# マイグレーション実行
php artisan migrate

# 開発サーバー起動
php artisan serve
```

バックエンドAPI: http://localhost:8000

### 3. フロントエンドセットアップ

```bash
cd frontend

# 依存関係インストール
npm install

# 環境変数設定
cp .env.example .env
# .envを編集してAPI URLを設定

# 開発サーバー起動
npm run dev
```

フロントエンド: http://localhost:5173

## 開発コマンド

### バックエンド

```bash
cd backend

# 開発サーバー
php artisan serve

# マイグレーション
php artisan migrate

# マイグレーションロールバック
php artisan migrate:rollback

# テスト
php artisan test

# コードスタイル
./vendor/bin/pint

# 静的解析
./vendor/bin/phpstan analyse

# 全チェック
./vendor/bin/pint && ./vendor/bin/phpstan analyse && php artisan test
```

### フロントエンド

```bash
cd frontend

# 開発サーバー
npm run dev

# ビルド
npm run build

# プレビュー
npm run preview

# Lint
npm run lint

# 型チェック
npm run type-check

# テスト
npm run test

# 全チェック
npm run lint && npm run type-check && npm run test
```

## Claude Codeでの開発

### 初回設定

Claude Codeは`.claude/skills/`のスキル定義を自動読み込みします。

### バックエンド機能実装の例

```bash
# Claude Codeを起動
claude-code

# プロンプト例
「注文管理APIを実装してください。

要件:
- RESTful API（CRUD）
- 注文作成、取得、更新、キャンセル
- ユーザーIDとの紐付け
- ステータス管理（pending, confirmed, shipped, delivered, cancelled）

プロジェクトルールに従って実装してください。」
```

Claude Codeが自動的に:
1. マイグレーション作成
2. Model作成
3. Repository作成
4. Service作成
5. Request作成
6. Resource作成
7. Controller作成
8. ルート定義
9. テスト作成

### フロントエンド機能実装の例

```
「注文管理画面を実装してください。

要件:
- 注文一覧（ページネーション付き）
- 注文詳細表示
- 注文作成フォーム
- ステータス更新

プロジェクトルールに従って、React Query + Zodで実装してください。」
```

## AWS Lambdaへのデプロイ

### 前提条件

```bash
# Serverless Frameworkのインストール
npm install -g serverless

# Brefのインストール（backendディレクトリで）
cd backend
composer require bref/bref bref/laravel-bridge
```

### 環境変数設定

```bash
# 必要な環境変数をエクスポート
export APP_KEY="your-app-key"
export DB_HOST="your-rds-endpoint"
export DB_DATABASE="your-database"
export DB_USERNAME="your-username"
export DB_PASSWORD="your-password"
export SECURITY_GROUP_ID="sg-xxxxx"
export SUBNET_ID_1="subnet-xxxxx"
export SUBNET_ID_2="subnet-xxxxx"
```

### デプロイ実行

```bash
cd backend

# 開発環境にデプロイ
serverless deploy --stage dev

# 本番環境にデプロイ
serverless deploy --stage production

# マイグレーション実行
serverless invoke -f artisan --data '{"cli":"migrate --force"}'
```

### フロントエンドのデプロイ

```bash
cd frontend

# ビルド
npm run build

# S3にアップロード
aws s3 sync dist/ s3://your-frontend-bucket/ --delete

# CloudFrontキャッシュ無効化
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/*"
```

## インフラ構成

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  CloudFront     │ (CDN)
│  + S3           │ (React SPA)
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│  API Gateway    │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│  Lambda         │ (Laravel)
│  + VPC          │
└──────┬──────────┘
       │
       ├─────────────────┐
       │                 │
       ▼                 ▼
┌─────────────┐   ┌─────────────┐
│  RDS        │   │  S3         │
│  PostgreSQL │   │  (Storage)  │
│  (DB/Cache/ │   └─────────────┘
│   Session)  │
└─────────────┘
       │
       ▼
┌─────────────┐
│  SQS        │ (Queue)
└─────────────┘
       │
       ▼
┌─────────────┐
│  Lambda     │ (Queue Worker)
└─────────────┘
```

## テスト

### バックエンドテスト

```bash
cd backend

# 全テスト実行
php artisan test

# 特定のテスト
php artisan test --filter UserServiceTest

# カバレッジ
php artisan test --coverage
```

### フロントエンドテスト

```bash
cd frontend

# 全テスト実行
npm run test

# ウォッチモード
npm run test:watch

# カバレッジ
npm run test:coverage
```

## トラブルシューティング

### Laravel

**マイグレーションエラー**

```bash
# マイグレーションをリセット（開発環境のみ）
php artisan migrate:fresh

# 特定のマイグレーションをロールバック
php artisan migrate:rollback --step=1
```

**キャッシュクリア**

```bash
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear
```

### React

**依存関係の問題**

```bash
cd frontend
rm -rf node_modules package-lock.json
npm install
```

**ビルドエラー**

```bash
# 型チェック
npm run type-check

# Lint
npm run lint
```

## ドキュメント

- [Laravel プロジェクトルール](.claude/skills/laravel-project-rules.md)
- [React プロジェクトルール](.claude/skills/react-project-rules.md)
- [API仕様書](docs/api/)
- [アーキテクチャ設計](docs/architecture.md)

## ライセンス

MIT