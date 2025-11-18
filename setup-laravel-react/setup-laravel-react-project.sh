#!/bin/bash

# Laravel (Docker) + React (Host) AI駆動開発プロジェクトの自動セットアップ

set -e

PROJECT_NAME=$1
if [ -z "$PROJECT_NAME" ]; then
  echo "使用方法: ./setup-laravel-react-project.sh <project-name>"
  exit 1
fi

echo "🚀 Laravel (Docker) + React (Host) AI駆動開発プロジェクトをセットアップします: $PROJECT_NAME"
echo ""

# 前提条件チェック
echo "🔍 前提条件をチェック中..."
if ! command -v docker &> /dev/null; then
    echo "❌ Dockerがインストールされていません"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Composeがインストールされていません"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "❌ Node.jsがインストールされていません"
    exit 1
fi

echo "✅ 前提条件OK"
echo ""

# 1. プロジェクトディレクトリ作成
echo ""
echo "📁 Step 1/10: プロジェクトディレクトリを作成中..."
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# 2. ディレクトリ構造作成
echo ""
echo "📁 Step 2/10: ディレクトリ構造を作成中..."
mkdir -p backend
mkdir -p dockerfiles
mkdir -p frontend
mkdir -p .claude/skills
mkdir -p docs/for-ai/examples
mkdir -p docs/customer
mkdir -p .github/workflows

# 3. Docker設定ファイル作成
echo ""
echo "🐳 Step 3/10: Docker設定を作成中..."

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    build:
      context: ./backend
      dockerfile: ../dockerfiles/Dockerfile.php82
    container_name: laravel-app
    ports:
      - "8080:9000"
    working_dir: /var/www
    volumes:
      - ./backend:/var/www
      - ./backend/storage:/var/www/storage
    networks:
      - laravel
    environment:
      - APP_ENV=local
      - APP_DEBUG=true
    depends_on:
      - db

  db:
    image: postgres:15-alpine
    container_name: laravel-db
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: laravel
      POSTGRES_USER: laravel
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - laravel

networks:
  laravel:
    driver: bridge

volumes:
  postgres_data:
EOF

# 4. Dockerfile作成
cat > dockerfiles/Dockerfile.php82 << 'EOF'
FROM php:8.2-fpm-alpine

# 作業ディレクトリ
WORKDIR /var/www

# システム依存関係
RUN apk add --no-cache \
    git \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    zip \
    unzip \
    postgresql-dev \
    nodejs \
    npm

# PHP拡張機能
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_pgsql \
        gd \
        zip \
        bcmath

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# アプリケーションファイル
COPY . /var/www

# 権限設定
RUN chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage

USER www-data

EXPOSE 9000

CMD ["php-fpm"]
EOF

# 6. Laravelプロジェクト作成（Docker内）
echo ""
echo "🐘 Step 4/10: Laravelプロジェクトを作成中（Docker内）..."

# 一時的なComposerコンテナでLaravelを作成
docker run --rm -v $(pwd)/backend:/app composer:latest create-project laravel/laravel . --ignore-platform-reqs

# Laravel依存関係追加
echo ""
echo "📦 Step 5/10: Laravel依存関係をインストール中（Docker内）..."
docker run --rm -v $(pwd)/backend:/app composer:latest require bref/bref bref/laravel-bridge --ignore-platform-reqs
docker run --rm -v $(pwd)/backend:/app composer:latest require --dev laravel/pint phpstan/phpstan nunomaduro/larastan --ignore-platform-reqs

# ディレクトリ構造作成と権限設定を1つのコマンドで実行
docker run --rm \
    -v $(pwd)/backend:/var/www \
    -w /var/www \
    -u root \
    composer:latest \
    bash -c "
    # ディレクトリ構造作成
    mkdir -p app/Services app/Repositories app/Exceptions
    mkdir -p app/Http/Resources
    mkdir -p tests/Feature/Api
    mkdir -p tests/Unit/Services tests/Unit/Repositories
    
    # 権限設定（全ディレクトリとファイル）
    chown -R $(id -u):$(id -g) /var/www
    chmod -R 755 /var/www/storage
    chmod -R 755 /var/www/bootstrap/cache
    "

# 7. Laravel環境変数設定
echo ""
echo "🔐 Step 6/10: Laravel環境変数を設定中..."

cat > backend/.env << 'EOF'
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:8000

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=pgsql
DB_HOST=db
DB_PORT=5432
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret

CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=database
SESSION_LIFETIME=120

BREF_BINARY_RESPONSES=1
EOF

# .env.example（本番用）
cat > backend/.env.example << 'EOF'
APP_NAME=Laravel
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://api.example.com

DB_CONNECTION=pgsql
DB_HOST=your-rds-endpoint.rds.amazonaws.com
DB_PORT=5432
DB_DATABASE=your_database
DB_USERNAME=your_username
DB_PASSWORD=your_password

CACHE_DRIVER=file
QUEUE_CONNECTION=sqs
SESSION_DRIVER=database
SESSION_LIFETIME=120

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=ap-northeast-1
AWS_BUCKET=

BREF_BINARY_RESPONSES=1
EOF

# 8. React SPA作成（ホスト上）
echo ""
echo "⚛️  Step 7/10: React SPAプロジェクトを作成中（ホスト）..."
npm create vite@latest frontend -- --template react-ts

cd frontend
npm install

# React依存関係追加
echo ""
echo "📦 Step 8/10: React依存関係をインストール中..."
npm install axios zod @tanstack/react-query react-router-dom @hookform/resolvers react-hook-form
npm install -D @types/node vitest @vitest/ui @testing-library/react @testing-library/jest-dom happy-dom

# package.jsonにスクリプト追加
npm pkg set scripts.type-check="tsc --noEmit"
npm pkg set scripts.test="vitest"

# ディレクトリ作成
mkdir -p src/features
mkdir -p src/shared/{components,hooks,utils,types,api}
mkdir -p src/lib
mkdir -p src/pages

# React環境変数設定
cat > .env << 'EOF'
VITE_API_URL=http://localhost:8000/api
VITE_APP_ENV=development
EOF

cat > .env.example << 'EOF'
VITE_API_URL=https://api.example.com/api
VITE_APP_ENV=production
EOF

cd ..

# 9. Docker起動とLaravel初期化
echo ""
echo "🐳 Step 9/10: Dockerコンテナを起動中..."
docker-compose up -d

# コンテナが起動するまで待機
echo "⏳ コンテナの起動を待機中..."
sleep 10

# Laravelアプリケーションキー生成
echo "🔑 アプリケーションキーを生成中..."
docker-compose exec -T app php artisan key:generate

# ストレージリンク
docker-compose exec -T app php artisan storage:link

# マイグレーション実行
echo "🗄️  マイグレーションを実行中..."
docker-compose exec -T app php artisan migrate --force

# 10. Git初期化
echo ""
echo "🔧 Step 10/10: Gitリポジトリを初期化中..."

cat > .gitignore << 'EOF'
# Backend (Laravel)
/backend/vendor/
/backend/node_modules/
/backend/.env
/backend/.env.backup
/backend/.phpunit.result.cache
/backend/Homestead.json
/backend/Homestead.yaml
/backend/auth.json
/backend/npm-debug.log
/backend/yarn-error.log
/backend/.fleet
/backend/.idea
/backend/.vscode

# Frontend (React)
/frontend/node_modules/
/frontend/dist/
/frontend/.env
/frontend/.env.local
/frontend/.env.production.local
/frontend/.env.development.local

# Docker
/postgres_data/

# OS
.DS_Store
Thumbs.db
EOF


echo "git init"
echo "git add ."
echo "git commit -m 'Initial commit: Laravel (Docker) + React (Host) AI-driven development setup'

echo ""
echo "✅ セットアップ完了！"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 セットアップ成功！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 起動済みサービス:"
echo "  ✅ Laravel API (Docker):    http://localhost:8000"
echo "  ✅ PostgreSQL (Docker):     localhost:5432"
echo ""
echo "🚀 次のステップ:"
echo ""
echo "1. フロントエンド開発サーバー起動:"
echo "   cd $PROJECT_NAME/frontend"
echo "   npm run dev"
echo "   → http://localhost:5173"
echo ""
echo "2. Dockerコンテナの操作:"
echo "   docker-compose ps              # コンテナ状態確認"
echo "   docker-compose logs -f app     # ログ確認"
echo "   docker-compose exec app bash   # コンテナ内シェル"
echo "   docker-compose down            # コンテナ停止"
echo "   docker-compose up -d           # コンテナ起動"
echo ""
echo "3. Laravel操作（Docker内）:"
echo "   docker-compose exec app php artisan migrate"
echo "   docker-compose exec app php artisan tinker"
echo "   docker-compose exec app php artisan test"
echo ""
echo "4. Composer操作（Docker内）:"
echo "   docker-compose exec app composer install"
echo "   docker-compose exec app composer require パッケージ名"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📚 ドキュメント:"
echo "  - .claude/skills/laravel-project-rules.md"
echo "  - .claude/skills/react-project-rules.md"
echo "  - README.md"
echo ""
echo "Happy coding! 🚀"
