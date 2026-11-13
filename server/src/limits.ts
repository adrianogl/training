import { DEFAULT_MAX_ACCOUNT_BYTES, DEFAULT_MAX_ACCOUNTS, POSITIVE_INT_PATTERN } from './constants.js'
import type { Limits } from './types.js'

function positiveInt(value: string | undefined, fallback: number): number {
  return value !== undefined && POSITIVE_INT_PATTERN.test(value) ? Number(value) : fallback
}

export function limitsFromEnv(env: Record<string, string | undefined>): Limits {
  return {
    maxAccounts: positiveInt(env.MAX_ACCOUNTS, DEFAULT_MAX_ACCOUNTS),
    maxAccountBytes: positiveInt(env.MAX_ACCOUNT_BYTES, DEFAULT_MAX_ACCOUNT_BYTES),
  }
}
