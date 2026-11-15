export const RECORD_KINDS = ['race', 'decision', 'goal', 'trainer'] as const
export const RECORD_FORMATS = ['sealed', 'plain'] as const
export const RECORD_CONTEXT_PREFIX = 'record'
export const PLAIN_LIMITS = { name: 200, priority: 16, city: 200, decision: 32, maxDistance: 1_000_000, maxSeconds: 7 * 24 * 3600 } as const
export const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/
export const BASE64_PATTERN = /^[A-Za-z0-9+/]*={0,2}$/
export const TOKEN_BYTES = 32
export const MAX_ID_LENGTH = 128
export const TRAINER_RECORD_ID = 'plan'
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
export const FACE_MAX_TEXT_LENGTH = 40
export const FACE_MAX_SHAPE_STEPS = 24
export const FACE_MAX_SHAPE_WEIGHT = 100
export const FACE_MAX_ZONE = 5
export const FACE_MAX_VO2_DELTA = 20
export const FACE_MAX_WEEK_KM = 1000
export const FACE_MAX_RACE_SECONDS = 2 * 24 * 60 * 60
export const WATCH_READINESS_ROUTE = 'watch/readiness'
export const WATCH_TOKEN_ROUTE = 'watch/token'
export const AUTH_ROUTE = 'auth'
export const PASSWORD_MIN_LENGTH = 10
export const PASSWORD_MAX_LENGTH = 200
export const NAME_MAX_LENGTH = 80
export const EMAIL_MAX_LENGTH = 254
export const DEVICE_MAX_LENGTH = 60
export const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
export const SCRYPT_COST = 16384
export const SCRYPT_BLOCK_SIZE = 8
export const SCRYPT_PARALLELISM = 1
export const SCRYPT_KEY_LENGTH = 64
export const SCRYPT_SALT_BYTES = 16
export const SCRYPT_MAX_MEMORY = 64 * 1024 * 1024
export const PASSWORD_HASH_PREFIX = 'scrypt'
export const SESSION_IDLE_DAYS = 90
export const VERIFY_TOKEN_HOURS = 24
export const RESET_TOKEN_MINUTES = 30
export const LOGIN_ATTEMPT_LIMIT = 10
export const LOGIN_ATTEMPT_WINDOW_MS = 15 * 60 * 1000
export const RESEND_URL = 'https://api.resend.com/emails'
export const VERIFY_PATH = '/confirmar'
export const RESET_PATH = '/redefinir-senha'
export const MAIL_VERIFY_SUBJECT = 'Confirme seu e-mail no trAIning'
export const MAIL_RESET_SUBJECT = 'Redefinir a senha do trAIning'
export const MAIL_VERIFY_TEXT = 'Para confirmar o e-mail da sua conta no trAIning, abra o link abaixo. Ele vale por 24 horas.'
export const MAIL_RESET_TEXT = 'Para criar uma nova senha no trAIning, abra o link abaixo. Ele vale por 30 minutos. Se não foi você, ignore este e-mail.'
export const DATA_KEY_BYTES = 32
export const CIPHER_ALGORITHM = 'aes-256-gcm'
export const CIPHER_IV_BYTES = 12
export const CIPHER_VERSION = 'v1'
export const GARMIN_ROUTE = 'garmin'
export const GARMIN_PENDING_MINUTES = 10
export const GARMIN_REFRESH_MARGIN_MS = 15 * 60 * 1000
export const GARMIN_CODE_PATTERN = /^\d{4,8}$/
export const GARMIN_LOGIN_URL = 'https://sso.garmin.com/mobile/api/login'
export const GARMIN_MFA_URL = 'https://sso.garmin.com/mobile/api/mfa/verifyCode'
export const GARMIN_TOKEN_URL = 'https://diauth.garmin.com/di-oauth2-service/oauth/token'
export const GARMIN_API_BASE = 'https://connectapi.garmin.com'
export const GARMIN_SSO_ORIGIN = 'https://sso.garmin.com'
export const GARMIN_SSO_CLIENT_ID = 'GCM_IOS_DARK'
export const GARMIN_SERVICE_URL = 'https://mobile.integration.garmin.com/gcm/ios'
export const GARMIN_LOCALE = 'en-US'
export const GARMIN_LOGIN_USER_AGENT =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148'
export const GARMIN_SERVICE_TICKET_GRANT = 'https://connectapi.garmin.com/di-oauth2-service/oauth/grant/service_ticket'
export const GARMIN_REFRESH_GRANT = 'refresh_token'
export const GARMIN_CLIENT_IDS = [
  'GARMIN_CONNECT_MOBILE_ANDROID_DI_2025Q2',
  'GARMIN_CONNECT_MOBILE_ANDROID_DI_2024Q4',
  'GARMIN_CONNECT_MOBILE_ANDROID_DI',
  'GARMIN_CONNECT_MOBILE_IOS_DI',
] as const
export const GARMIN_NATIVE_HEADERS: Record<string, string> = {
  'User-Agent': 'GCM-Android-5.23',
  'X-Garmin-User-Agent': 'com.garmin.android.apps.connectmobile/5.23; ; Google/sdk_gphone64_arm64/google; Android/33; Dalvik/2.1.0',
  'X-Garmin-Paired-App-Version': '10861',
  'X-Garmin-Client-Platform': 'Android',
  'X-App-Ver': '10861',
  'X-Lang': 'en',
  'X-GCExperience': 'GC5',
  'Accept-Language': 'en-US,en;q=0.9',
}
export const GARMIN_DEFAULT_MFA_METHOD = 'email'
export const GARMIN_SUCCESS_STATUS = 'SUCCESSFUL'
export const GARMIN_MFA_STATUS = 'MFA_REQUIRED'
export const GARMIN_INVALID_CREDENTIALS_STATUS = 'INVALID_USERNAME_PASSWORD'
export const API_PATH_PREFIX = '/api/v1/'
export const API_ROUTER_QUERY = 'route'
export const INVITE_DAYS = 7
export const INVITE_PATH = '/convite'
export const INVITE_QUERY = 'c'
export const INVITE_CHANNELS = ['email', 'whatsapp', 'link'] as const
export const CLIENT_HEADER = 'x-training-client'
export const APP_CLIENT = 'app'
export const ACTIVE_WINDOW_DAYS = 7
export const MAIL_INVITE_SUBJECT = 'Convite para o trAIning'
export const INVITE_MESSAGE = (name: string, inviter: string, link: string) =>
  `Oi, ${name}! ${inviter} te convidou para o trAIning, que lê os dados da sua Garmin e mostra a prontidão do dia, a análise dos treinos e a previsão das provas.\n\nCrie sua conta por este link (vale 7 dias):\n${link}`
export const SYNC_HISTORY_DAYS = 180
export const SYNC_RECENT_DAYS = 3
export const SYNC_BUDGET_MS = 40_000
export const SYNC_ACTIVITY_PAGE = 50
export const SYNC_TIME_ZONE = 'America/Sao_Paulo'
export const CRON_ROUTE = 'cron/garmin-sync'
export const SYNC_VERSION = 4

export const WEATHER = {
  forecastUrl: 'https://api.open-meteo.com/v1/forecast',
  geocodingUrl: 'https://geocoding-api.open-meteo.com/v1/search',
  fields: 'temperature_2m,dew_point_2m',
  forecastDaysAhead: 16,
  defaultStartHour: 7,
  coordinateScale: 10,
  timeoutMs: 5000,
} as const

export const GOALS = {
  kinds: ['time', 'continuousLong'],
  maxDistanceKm: 100,
  minTargetSeconds: 60,
  maxTargetSeconds: 86_400,
  minPaceSecondsPerKm: 150,
  maxPaceSecondsPerKm: 900,
  maxActive: 20,
} as const

export const RACES = {
  lapsPerRequest: 15,
  activityHistoryDays: 365,
  priorities: ['A', 'B', 'C'],
  startTimePattern: /^([01]\d|2[0-3]):[0-5]\d$/,
} as const

export const ACTIVITY = {
  nameMaxLength: 100,
  historyDays: 365,
  comparisonFetchLimit: 4,
} as const

export const INVITE_REQUEST = {
  watches: ['garmin', 'other', 'none'],
  messageMaxLength: 500,
  maxPerIpPerHour: 3,
  maxPending: 100,
  honeypotField: 'website',
  mailSubject: 'Novo pedido de convite no trAIning',
  watchNames: { garmin: 'Garmin', other: 'Outro relógio', none: 'Não usa relógio' } as Record<string, string>,
  adminPath: '/administracao',
} as const
export const STRAVA_ROUTE = 'strava'
export const STRAVA_AUTHORIZE_URL = 'https://www.strava.com/oauth/authorize'
export const STRAVA_TOKEN_URL = 'https://www.strava.com/oauth/token'
export const STRAVA_DEAUTHORIZE_URL = 'https://www.strava.com/oauth/deauthorize'
export const STRAVA_API_BASE = 'https://www.strava.com/api/v3'
export const STRAVA_REDIRECT_URI = 'https://training.aglv.dev/api/v1/strava/callback'
export const STRAVA_APP_REDIRECT = 'training://strava'
export const STRAVA_SCOPE = 'activity:read_all,activity:write'
export const STRAVA_REQUIRED_SCOPES = ['activity:read_all', 'activity:write'] as const
export const STRAVA_STATE_MINUTES = 10
export const STRAVA_STATE_CONTEXT = 'training-strava-state'
export const STRAVA_REFRESH_MARGIN_MS = 5 * 60 * 1000
export const STRAVA_MATCH_WINDOW_MS = 15 * 60 * 1000
export const STRAVA_DISTANCE_TOLERANCE = 0.1
export const STRAVA_SIGNATURE = 'via training.aglv.dev'
export const STRAVA_FORMAT = 'B'
export const STRAVA_MAX_TEXT_LENGTH = 1000
