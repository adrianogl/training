import { createHash, randomBytes, randomUUID } from 'node:crypto'
import { LOGIN_ATTEMPT_LIMIT, LOGIN_ATTEMPT_WINDOW_MS, SESSION_IDLE_DAYS, TOKEN_BYTES } from './constants.js'
import type { Sql } from './db.js'
import type { EmailPurpose, SessionInfo, User } from './types.js'

interface UserRow {
  id: string
  account_id: string
  email: string
  name: string
  email_verified_at: string | null
  password_hash: string
}

export interface SessionMatch {
  sessionId: string
  userId: string
  accountId: string
}

export type CreateUserOutcome = { status: 'created'; user: User } | { status: 'email_taken' | 'limit' | 'legacy_unavailable' }

export function newToken(): string {
  return randomBytes(TOKEN_BYTES).toString('base64url')
}

export function tokenHash(token: string): string {
  return createHash('sha256').update(Buffer.from(token, 'base64url')).digest('hex')
}

function toUser(row: UserRow): User {
  return {
    id: row.id,
    accountId: row.account_id,
    email: row.email,
    name: row.name,
    emailVerified: row.email_verified_at !== null,
  }
}

function sessionExpiry(now: Date): string {
  return new Date(now.getTime() + SESSION_IDLE_DAYS * 24 * 60 * 60 * 1000).toISOString()
}

export async function createUser(
  sql: Sql,
  input: { name: string; email: string; passwordHash: string; legacyAccountId: string | undefined },
  maxAccounts: number,
): Promise<CreateUserOutcome> {
  const taken = await sql('select 1 from users where lower(email) = lower($1)', [input.email])
  if (taken.length > 0) {
    return { status: 'email_taken' }
  }
  let accountId = input.legacyAccountId
  if (accountId !== undefined) {
    const free = await sql(
      'select 1 from accounts a where a.id = $1 and not exists (select 1 from users u where u.account_id = a.id)',
      [accountId],
    )
    if (free.length === 0) {
      return { status: 'legacy_unavailable' }
    }
  } else {
    accountId = randomBytes(TOKEN_BYTES).toString('hex')
    const created = await sql(
      `insert into accounts (id) select $1::text where (select count(*) from accounts) < $2::int returning id`,
      [accountId, maxAccounts],
    )
    if (created.length === 0) {
      return { status: 'limit' }
    }
  }
  try {
    const rows = await sql<UserRow>(
      `insert into users (id, account_id, email, name, password_hash) values ($1, $2, $3, $4, $5)
       returning id, account_id, email, name, email_verified_at, password_hash`,
      [randomUUID(), accountId, input.email, input.name, input.passwordHash],
    )
    return { status: 'created', user: toUser(rows[0] as UserRow) }
  } catch (error) {
    if (input.legacyAccountId === undefined) {
      await sql('delete from accounts where id = $1', [accountId])
    }
    if (typeof error === 'object' && error !== null && 'code' in error && error.code === '23505') {
      return { status: 'email_taken' }
    }
    throw error
  }
}

export async function userWithPassword(sql: Sql, email: string): Promise<{ user: User; passwordHash: string } | undefined> {
  const rows = await sql<UserRow>(
    'select id, account_id, email, name, email_verified_at, password_hash from users where lower(email) = lower($1)',
    [email],
  )
  const row = rows[0]
  return row === undefined ? undefined : { user: toUser(row), passwordHash: row.password_hash }
}

export async function userById(sql: Sql, id: string): Promise<{ user: User; passwordHash: string } | undefined> {
  const rows = await sql<UserRow>(
    'select id, account_id, email, name, email_verified_at, password_hash from users where id = $1',
    [id],
  )
  const row = rows[0]
  return row === undefined ? undefined : { user: toUser(row), passwordHash: row.password_hash }
}

export async function createSession(sql: Sql, userId: string, device: string, now: Date): Promise<string> {
  const token = newToken()
  await sql(
    `insert into sessions (token_hash, id, user_id, device, created_at, last_seen_at, expires_at)
     values ($1, $2, $3, $4, $5, $5, $6)`,
    [tokenHash(token), randomUUID(), userId, device, now.toISOString(), sessionExpiry(now)],
  )
  return token
}

export async function findSession(sql: Sql, hash: string, now: Date): Promise<SessionMatch | undefined> {
  const rows = await sql<{ id: string; user_id: string; account_id: string }>(
    `update sessions s set last_seen_at = $2, expires_at = $3
     from users u
     where s.token_hash = $1 and s.user_id = u.id and s.expires_at > $2
     returning s.id, s.user_id, u.account_id`,
    [hash, now.toISOString(), sessionExpiry(now)],
  )
  const row = rows[0]
  return row === undefined ? undefined : { sessionId: row.id, userId: row.user_id, accountId: row.account_id }
}

export async function listSessions(sql: Sql, userId: string, currentId: string): Promise<SessionInfo[]> {
  const rows = await sql<{ id: string; device: string; last_seen_at: string | Date }>(
    'select id, device, last_seen_at from sessions where user_id = $1 order by last_seen_at desc',
    [userId],
  )
  return rows.map((row) => ({
    id: row.id,
    device: row.device,
    lastSeenAt: new Date(row.last_seen_at).toISOString(),
    current: row.id === currentId,
  }))
}

export async function deleteSession(sql: Sql, userId: string, sessionId: string): Promise<void> {
  await sql('delete from sessions where user_id = $1 and id = $2', [userId, sessionId])
}

export async function deleteOtherSessions(sql: Sql, userId: string, keepId: string | undefined): Promise<void> {
  await sql('delete from sessions where user_id = $1 and ($2::text is null or id <> $2::text)', [userId, keepId ?? null])
}

export async function createEmailToken(sql: Sql, userId: string, purpose: EmailPurpose, expiresAt: Date): Promise<string> {
  const token = newToken()
  await sql('delete from email_tokens where user_id = $1 and purpose = $2 and used_at is null', [userId, purpose])
  await sql('insert into email_tokens (token_hash, user_id, purpose, expires_at) values ($1, $2, $3, $4)', [
    tokenHash(token),
    userId,
    purpose,
    expiresAt.toISOString(),
  ])
  return token
}

export async function consumeEmailToken(sql: Sql, token: string, purpose: EmailPurpose, now: Date): Promise<string | undefined> {
  const rows = await sql<{ user_id: string }>(
    `update email_tokens set used_at = $3
     where token_hash = $1 and purpose = $2 and used_at is null and expires_at > $3
     returning user_id`,
    [tokenHash(token), purpose, now.toISOString()],
  )
  return rows[0]?.user_id
}

export async function markVerified(sql: Sql, userId: string, now: Date): Promise<void> {
  await sql('update users set email_verified_at = coalesce(email_verified_at, $2) where id = $1', [userId, now.toISOString()])
}

export async function updatePassword(sql: Sql, userId: string, passwordHash: string): Promise<void> {
  await sql('update users set password_hash = $2 where id = $1', [userId, passwordHash])
}

export async function updateName(sql: Sql, userId: string, name: string): Promise<User | undefined> {
  const rows = await sql<UserRow>(
    `update users set name = $2 where id = $1
     returning id, account_id, email, name, email_verified_at, password_hash`,
    [userId, name],
  )
  const row = rows[0]
  return row === undefined ? undefined : toUser(row)
}

export async function loginAllowed(sql: Sql, ipHash: string, now: Date): Promise<boolean> {
  const windowStart = new Date(now.getTime() - LOGIN_ATTEMPT_WINDOW_MS).toISOString()
  await sql('delete from login_attempts where created_at <= $1', [windowStart])
  const rows = await sql<{ count: number }>(
    'select count(*)::int as count from login_attempts where ip_hash = $1 and created_at > $2',
    [ipHash, windowStart],
  )
  return (rows[0]?.count ?? 0) < LOGIN_ATTEMPT_LIMIT
}

export async function recordLoginAttempt(sql: Sql, ipHash: string, now: Date): Promise<void> {
  await sql('insert into login_attempts (ip_hash, created_at) values ($1, $2)', [ipHash, now.toISOString()])
}
