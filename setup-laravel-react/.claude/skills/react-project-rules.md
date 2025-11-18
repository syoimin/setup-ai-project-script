# React SPA プロジェクトルール

このファイルは Claude Code が常に参照する React プロジェクトの基本ルールです。

## アーキテクチャ

### ディレクトリ構造（厳守）

```
src/
├── features/              # 機能別モジュール
│   └── {feature}/
│       ├── api/          # API呼び出し
│       ├── components/   # 機能固有のコンポーネント
│       ├── hooks/        # カスタムフック
│       ├── types/        # 型定義
│       └── schemas/      # Zodスキーマ
│
├── shared/               # 共通コード
│   ├── components/       # 再利用可能なUI
│   ├── hooks/            # 共通フック
│   ├── utils/            # ユーティリティ
│   ├── types/            # 共通型定義
│   └── api/              # API基盤
│
├── lib/                  # 外部ライブラリ設定
│   ├── axios.ts          # Axios設定
│   └── react-query.ts    # React Query設定
│
├── pages/                # ルーティング対応ページ
├── App.tsx               # アプリケーションルート
└── main.tsx              # エントリーポイント
```

### レイヤー構造と責務

#### 1. Components Layer
- **責務**: UI表示、ユーザー入力受付
- **禁止**: 直接のAPI呼び出し、複雑なビジネスロジック
- **許可**: カスタムフックの使用、状態管理

```typescript
// ✅ 良い例
export function UserProfile() {
  const { data: user, isLoading } = useUser();
  
  if (isLoading) return <Spinner />;
  if (!user) return <NotFound />;
  
  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
    </div>
  );
}

// ❌ 悪い例
export function UserProfile() {
  const [user, setUser] = useState(null);
  
  useEffect(() => {
    axios.get('/api/users/1').then(setUser); // 直接API呼び出し
  }, []);
  
  return <div>{user?.name}</div>;
}
```

#### 2. Hooks Layer (features/*/hooks/, shared/hooks/)
- **責務**: ビジネスロジック、状態管理、API呼び出しの抽象化
- **禁止**: JSX、UIロジック
- **許可**: React Query、カスタムフック

```typescript
// ✅ 良い例
export function useUser(id: string) {
  return useQuery({
    queryKey: ['user', id],
    queryFn: () => userApi.getUser(id),
  });
}

export function useCreateUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (data: CreateUserInput) => userApi.createUser(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
}
```

#### 3. API Layer (features/*/api/, shared/api/)
- **責務**: HTTPリクエスト、レスポンス処理
- **禁止**: ビジネスロジック、状態管理
- **許可**: Axios、型定義

```typescript
// shared/api/client.ts
import axios from 'axios';

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// features/user/api/user.api.ts
import { apiClient } from '@/shared/api/client';
import type { User, CreateUserInput } from '../types/user.types';

export const userApi = {
  async getUser(id: string): Promise<User> {
    const { data } = await apiClient.get(`/users/${id}`);
    return data.data;
  },

  async createUser(input: CreateUserInput): Promise<User> {
    const { data } = await apiClient.post('/users', input);
    return data.data;
  },

  async updateUser(id: string, input: Partial<CreateUserInput>): Promise<User> {
    const { data } = await apiClient.put(`/users/${id}`, input);
    return data.data;
  },

  async deleteUser(id: string): Promise<void> {
    await apiClient.delete(`/users/${id}`);
  },
};
```

#### 4. Schema Layer (features/*/schemas/)
- **責務**: バリデーション、型定義
- **使用**: Zod

```typescript
import { z } from 'zod';

export const createUserSchema = z.object({
  name: z.string().min(1, '名前は必須です').max(255),
  email: z.string().email('有効なメールアドレスを入力してください'),
  password: z
    .string()
    .min(8, 'パスワードは8文字以上である必要があります')
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
      'パスワードは英大文字、英小文字、数字を含む必要があります'
    ),
});

export type CreateUserInput = z.infer<typeof createUserSchema>;
```

## コーディング規約

### TypeScript

```typescript
// ✅ 必須
- strict mode有効
- any型の禁止（unknownを使用）
- すべての関数に戻り値の型を明示
- Zodスキーマからz.inferで型生成

// ❌ 禁止
- any型の使用
- 暗黙的なany
- @ts-ignoreの乱用
```

### 命名規則

```typescript
// コンポーネント: PascalCase
export function UserProfile() {}

// フック: use + PascalCase
export function useUser() {}
export function useCreateUser() {}

// 関数: camelCase
function formatDate() {}

// 定数: UPPER_SNAKE_CASE
const API_TIMEOUT = 5000;

// 型/インターフェース: PascalCase
type User = {};
interface UserProps {}
```

### コンポーネント設計

```typescript
// ✅ 良い例: Props型を明示
interface UserCardProps {
  user: User;
  onEdit?: (user: User) => void;
}

export function UserCard({ user, onEdit }: UserCardProps) {
  return (
    <div>
      <h2>{user.name}</h2>
      {onEdit && <button onClick={() => onEdit(user)}>編集</button>}
    </div>
  );
}

// ❌ 悪い例: 型がない
export function UserCard({ user, onEdit }) {
  // ...
}
```

### React Query使用パターン

```typescript
// ✅ 良い例: queryKeyを配列で管理
export function useUser(id: string) {
  return useQuery({
    queryKey: ['user', id],
    queryFn: () => userApi.getUser(id),
    staleTime: 5 * 60 * 1000, // 5分
  });
}

// ✅ 良い例: mutationの適切な処理
export function useCreateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: userApi.createUser,
    onSuccess: (newUser) => {
      // キャッシュを更新
      queryClient.invalidateQueries({ queryKey: ['users'] });
      // 新しいユーザーをキャッシュに追加
      queryClient.setQueryData(['user', newUser.id], newUser);
    },
    onError: (error) => {
      // エラーハンドリング
      console.error('User creation failed:', error);
    },
  });
}
```

### エラーハンドリング

```typescript
// shared/api/client.ts
import axios, { AxiosError } from 'axios';

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
});

// レスポンスインターセプター
apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError<{ error: { code: string; message: string } }>) => {
    // エラーメッセージの統一処理
    if (error.response?.data?.error) {
      throw new Error(error.response.data.error.message);
    }
    throw new Error('予期しないエラーが発生しました');
  }
);

// 認証トークンの自動付与
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});
```

### フォームバリデーション

```typescript
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { createUserSchema, type CreateUserInput } from './schemas/user.schema';

export function CreateUserForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<CreateUserInput>({
    resolver: zodResolver(createUserSchema),
  });

  const createUser = useCreateUser();

  const onSubmit = async (data: CreateUserInput) => {
    try {
      await createUser.mutateAsync(data);
      alert('ユーザーを作成しました');
    } catch (error) {
      alert(error instanceof Error ? error.message : '作成に失敗しました');
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div>
        <label>名前</label>
        <input {...register('name')} />
        {errors.name && <span>{errors.name.message}</span>}
      </div>

      <div>
        <label>メールアドレス</label>
        <input {...register('email')} type="email" />
        {errors.email && <span>{errors.email.message}</span>}
      </div>

      <div>
        <label>パスワード</label>
        <input {...register('password')} type="password" />
        {errors.password && <span>{errors.password.message}</span>}
      </div>

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? '作成中...' : '作成'}
      </button>
    </form>
  );
}
```

## 実装パターン

### 新機能実装の手順

1. **型定義** (`features/{feature}/types/`)
2. **Zodスキーマ** (`features/{feature}/schemas/`)
3. **API関数** (`features/{feature}/api/`)
4. **カスタムフック** (`features/{feature}/hooks/`)
5. **コンポーネント** (`features/{feature}/components/`)
6. **ページ** (`pages/`)

## Claude Codeでの開発フロー

### 機能実装時のプロンプト例

```
新しく「ユーザー管理」機能を実装してください。

要件:
- ユーザー一覧表示（ページネーション付き）
- ユーザー詳細表示
- ユーザー作成フォーム
- ユーザー編集フォーム
- ユーザー削除

制約:
- React Queryを使用
- Zodでバリデーション
- 型安全性を保つ
- エラーハンドリング必須

まず、型定義とスキーマから実装してください。
```

## 禁止事項

### 絶対にやってはいけないこと

1. **any型の使用**
2. **直接のfetch/axios呼び出し（API層を経由）**
3. **グローバル状態の乱用（Contextは最小限に）**
4. **useEffectでのデータフェッチ（React Queryを使用）**
5. **XSS脆弱性（dangerouslySetInnerHTML）**

## パフォーマンス最適化

```typescript
// ✅ 良い例: React.memoで不要な再レンダリング防止
export const UserCard = React.memo(function UserCard({ user }: UserCardProps) {
  return <div>{user.name}</div>;
});

// ✅ 良い例: useCallbackでコールバック最適化
export function UserList() {
  const handleEdit = useCallback((user: User) => {
    // ...
  }, []);

  return <UserCard user={user} onEdit={handleEdit} />;
}

// ✅ 良い例: Code Splitting
const UserProfile = lazy(() => import('./features/user/components/UserProfile'));

export function App() {
  return (
    <Suspense fallback={<Loading />}>
      <UserProfile />
    </Suspense>
  );
}
```

## テスト

```typescript
// features/user/components/__tests__/UserCard.test.tsx
import { render, screen } from '@testing-library/react';
import { UserCard } from '../UserCard';

describe('UserCard', () => {
  it('ユーザー名を表示する', () => {
    const user = { id: '1', name: 'Test User', email: 'test@example.com' };
    render(<UserCard user={user} />);
    expect(screen.getByText('Test User')).toBeInTheDocument();
  });
});
```

## 環境変数

```typescript
// vite-env.d.ts
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string;
  readonly VITE_APP_ENV: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

## 参考資料

- React公式ドキュメント: https://react.dev
- TanStack Query: https://tanstack.com/query/latest
- Zod: https://zod.dev