// frontend/src/lib/react-query.ts
import { QueryClient, DefaultOptions } from '@tanstack/react-query';

/**
 * React Queryのデフォルト設定
 */
const queryConfig: DefaultOptions = {
  queries: {
    // データの有効期限: 5分
    staleTime: 5 * 60 * 1000,
    
    // キャッシュの保持期間: 10分
    gcTime: 10 * 60 * 1000,
    
    // エラー時の再試行設定
    retry: (failureCount, error) => {
      // 認証エラー（401）、権限エラー（403）、NotFound（404）は再試行しない
      if (error instanceof Error) {
        const statusMatch = error.message.match(/status code (\d+)/);
        if (statusMatch) {
          const status = parseInt(statusMatch[1], 10);
          if ([401, 403, 404].includes(status)) {
            return false;
          }
        }
      }
      // 3回まで再試行
      return failureCount < 3;
    },
    
    // 再試行時の遅延（ミリ秒）
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
    
    // ウィンドウフォーカス時の自動再取得を無効化
    refetchOnWindowFocus: false,
    
    // マウント時の自動再取得を有効化
    refetchOnMount: true,
  },
  mutations: {
    // ミューテーションのエラー時の再試行を無効化
    retry: false,
  },
};

/**
 * QueryClientインスタンス
 */
export const queryClient = new QueryClient({
  defaultOptions: queryConfig,
});

/**
 * クエリキーのファクトリー
 * 一貫したクエリキーを生成するためのヘルパー
 */
export const queryKeys = {
  // ユーザー関連
  users: {
    all: ['users'] as const,
    lists: () => [...queryKeys.users.all, 'list'] as const,
    list: (filters: Record<string, unknown>) =>
      [...queryKeys.users.lists(), { filters }] as const,
    details: () => [...queryKeys.users.all, 'detail'] as const,
    detail: (id: string) => [...queryKeys.users.details(), id] as const,
  },
  
  // 他のリソースも同様に追加
  // 例: orders, products, etc.
} as const;

/**
 * エラーハンドリングの共通化
 */
export function handleQueryError(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return '予期しないエラーが発生しました';
}