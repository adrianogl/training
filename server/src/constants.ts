export const RECORD_KINDS = ['race', 'decision'] as const
export const TOKEN_BYTES = 32
export const MAX_ID_LENGTH = 128
export const MAX_PAYLOAD_CHARS = 1024 * 1024
export const MAX_BODY_BYTES = 4 * 1024 * 1024
export const MAX_PUSH_RECORDS = 100
export const PULL_PAGE_SIZE = 500
export const ACCOUNT_CREATION_LIMIT = 10
export const ACCOUNT_CREATION_WINDOW_MS = 60 * 60 * 1000
export const LOG_ACCOUNT_PREFIX_LENGTH = 8
export const UPDATED_AT_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
export const SINCE_PATTERN = /^\d{1,15}$/
export const TOKEN_PATTERN = /^Bearer ([A-Za-z0-9_-]+)$/
export const REQUEST_LOG_RETENTION_DAYS = 7
export const ADMIN_PATH = '/admin'
export const ADMIN_SESSION_COOKIE = 'admin_session'
export const ADMIN_SESSION_CONTEXT = 'training-sync-admin-session'
export const ADMIN_SESSION_MAX_AGE_SECONDS = 7 * 24 * 60 * 60
export const ADMIN_MAX_FORM_BYTES = 4096
export const ADMIN_RECENT_LIMIT = 20
export const ADMIN_HOURS = 24
export const ADMIN_TIME_ZONE = 'America/Sao_Paulo'
export const ADMIN_HEADERS = {
  'content-type': 'text/html; charset=utf-8',
  'cache-control': 'no-store',
  'x-robots-tag': 'noindex',
  'referrer-policy': 'no-referrer',
  'content-security-policy':
    "default-src 'none'; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
} as const
export const DEFAULT_MAX_ACCOUNTS = 3
export const DEFAULT_MAX_ACCOUNT_BYTES = 50 * 1024 * 1024
export const MAX_PULL_PAGE_BYTES = 3 * 1024 * 1024
export const POSITIVE_INT_PATTERN = /^[1-9]\d{0,15}$/
export const ACCOUNT_CREATION_LOCK_KEY = 'account_creation'
export const ADMIN_MIN_TOKEN_LENGTH = 32
export const UNLOGGED_STATUSES: readonly number[] = [401, 429]
export const WATCH_TOKEN_HASH_PATTERN = /^[0-9a-f]{64}$/
export const READINESS_DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/
export const READINESS_MIN_SCORE = 0
export const READINESS_MAX_SCORE = 100
export const READINESS_MAX_VERDICT_LENGTH = 24
export const WATCH_READINESS_ROUTE = 'watch/readiness'
export const WATCH_TOKEN_ROUTE = 'watch/token'
