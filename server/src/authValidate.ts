import {
  DEVICE_MAX_LENGTH,
  EMAIL_MAX_LENGTH,
  EMAIL_PATTERN,
  NAME_MAX_LENGTH,
  PASSWORD_MAX_LENGTH,
  PASSWORD_MIN_LENGTH,
  TOKEN_BYTES,
} from './constants.js'
import type { BodyParseResult, LoginInput, PasswordChangeInput, SignupInput } from './types.js'
import { parseObject } from './validate.js'

function text(value: unknown, max: number): string | undefined {
  if (typeof value !== 'string') {
    return undefined
  }
  const trimmed = value.trim()
  return trimmed.length > 0 && [...trimmed].length <= max ? trimmed : undefined
}

function email(value: unknown): string | undefined {
  const parsed = text(value, EMAIL_MAX_LENGTH)
  return parsed !== undefined && EMAIL_PATTERN.test(parsed) ? parsed : undefined
}

function password(value: unknown): string | undefined {
  if (typeof value !== 'string') {
    return undefined
  }
  const length = [...value].length
  return length >= PASSWORD_MIN_LENGTH && length <= PASSWORD_MAX_LENGTH ? value : undefined
}

export function isToken(value: unknown): value is string {
  if (typeof value !== 'string') {
    return false
  }
  const bytes = Buffer.from(value, 'base64url')
  return bytes.length === TOKEN_BYTES && bytes.toString('base64url') === value
}

export function parseSignup(body: string): BodyParseResult<SignupInput> {
  const parsed = parseObject(body)
  if (!parsed.ok) {
    return parsed
  }
  const value = parsed.value
  const name = text(value.name, NAME_MAX_LENGTH)
  if (name === undefined) {
    return { ok: false, error: 'invalid_name' }
  }
  const address = email(value.email)
  if (address === undefined) {
    return { ok: false, error: 'invalid_email' }
  }
  const secret = password(value.password)
  if (secret === undefined) {
    return { ok: false, error: 'invalid_password' }
  }
  const device = text(value.device, DEVICE_MAX_LENGTH)
  if (device === undefined) {
    return { ok: false, error: 'invalid_device' }
  }
  if (value.legacyKey !== undefined && !isToken(value.legacyKey)) {
    return { ok: false, error: 'invalid_legacy_key' }
  }
  return { ok: true, value: { name, email: address, password: secret, device, legacyKey: value.legacyKey as string | undefined } }
}

export function parseLogin(body: string): BodyParseResult<LoginInput> {
  const parsed = parseObject(body)
  if (!parsed.ok) {
    return parsed
  }
  const address = email(parsed.value.email)
  const device = text(parsed.value.device, DEVICE_MAX_LENGTH)
  if (address === undefined || typeof parsed.value.password !== 'string' || device === undefined) {
    return { ok: false, error: 'invalid_credentials' }
  }
  return { ok: true, value: { email: address, password: parsed.value.password, device } }
}

export function parsePasswordChange(body: string): BodyParseResult<PasswordChangeInput> {
  const parsed = parseObject(body)
  if (!parsed.ok) {
    return parsed
  }
  const next = password(parsed.value.next)
  if (typeof parsed.value.current !== 'string' || next === undefined) {
    return { ok: false, error: 'invalid_password' }
  }
  return { ok: true, value: { current: parsed.value.current, next, endOtherSessions: parsed.value.endOtherSessions !== false } }
}

export function parseEmailBody(body: string): BodyParseResult<string> {
  const parsed = parseObject(body)
  if (!parsed.ok) {
    return parsed
  }
  const address = email(parsed.value.email)
  return address === undefined ? { ok: false, error: 'invalid_email' } : { ok: true, value: address }
}

export function parseTokenBody(body: string): BodyParseResult<{ token: string; password: string | undefined }> {
  const parsed = parseObject(body)
  if (!parsed.ok) {
    return parsed
  }
  if (!isToken(parsed.value.token)) {
    return { ok: false, error: 'invalid_token' }
  }
  if (parsed.value.password === undefined) {
    return { ok: true, value: { token: parsed.value.token, password: undefined } }
  }
  const secret = password(parsed.value.password)
  return secret === undefined ? { ok: false, error: 'invalid_password' } : { ok: true, value: { token: parsed.value.token, password: secret } }
}

export function parseNameBody(body: string): BodyParseResult<string> {
  const parsed = parseObject(body)
  if (!parsed.ok) {
    return parsed
  }
  const name = text(parsed.value.name, NAME_MAX_LENGTH)
  return name === undefined ? { ok: false, error: 'invalid_name' } : { ok: true, value: name }
}
