// frontend/src/shared/api/client.ts
import axios, { AxiosError, InternalAxiosRequestConfig } from 'axios';

/**
 * APIエラーレスポンスの型定義
 */
export interface ApiErrorResponse {
  error: {
    code: string;
    message: string;
    errors?: Record<string, string[]>;
  };
}

/**
 * Axiosクライアントの設定
 */
export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:8000/api',
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
  timeout: 30000,
});

/**
 * リクエストインターセプター
 * 認証トークンを自動的に付与
 */
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = localStorage.getItem('auth_token');
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

/**
 * レスポンスインターセプター
 * エラーハンドリングの統一
 */
apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError<ApiErrorResponse>) => {
    // 認証エラー（401）の場合はログアウト
    if (error.response?.status === 401) {
      localStorage.removeItem('auth_token');
      window.location.href = '/login';
      return Promise.reject(new Error('認証が必要です'));
    }

    // APIから返されたエラーメッセージを使用
    if (error.response?.data?.error) {
      const apiError = error.response.data.error;
      
      // バリデーションエラーの場合
      if (apiError.errors) {
        const errorMessages = Object.values(apiError.errors)
          .flat()
          .join(', ');
        return Promise.reject(new Error(errorMessages));
      }

      // 通常のエラー
      return Promise.reject(new Error(apiError.message));
    }

    // ネットワークエラー
    if (error.message === 'Network Error') {
      return Promise.reject(
        new Error('ネットワークエラーが発生しました。接続を確認してください。')
      );
    }

    // タイムアウト
    if (error.code === 'ECONNABORTED') {
      return Promise.reject(new Error('リクエストがタイムアウトしました'));
    }

    // その他のエラー
    return Promise.reject(
      new Error(error.message || '予期しないエラーが発生しました')
    );
  }
);

/**
 * 認証トークンを設定
 */
export function setAuthToken(token: string): void {
  localStorage.setItem('auth_token', token);
}

/**
 * 認証トークンを削除
 */
export function clearAuthToken(): void {
  localStorage.removeItem('auth_token');
}

/**
 * 認証トークンを取得
 */
export function getAuthToken(): string | null {
  return localStorage.getItem('auth_token');
}