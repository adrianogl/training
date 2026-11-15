import { accountIdFromAuthorization } from './auth.js'
import {
  APP_CLIENT,
  AUTH_ROUTE,
  CLIENT_HEADER,
  MAX_BODY_BYTES,
  RESET_PATH,
  RESET_TOKEN_MINUTES,
  VERIFY_PATH,
  VERIFY_TOKEN_HOURS,
} from './constants.js'
import { parseEmailBody, parseLogin, parseNameBody, parsePasswordChange, parseSignup, parseTokenBody } from './authValidate.js'
import type { Sql } from './db.js'
import { limitsFromEnv } from './limits.js'
import { acceptInvite, pendingInvite } from './invites.js'
import { mailerFromEnv } from './mailer.js'
import { resetPasswordMail, verifyEmailMail } from './mailTemplates.js'
import { hashPassword, verifyPassword } from './password.js'
import { clientIpHash } from './rateLimit.js'
import type { AuthEnv, EmailPurpose, User } from './types.js'
import {
  consumeEmailToken,
  createEmailToken,
  createSession,
  createUser,
  deleteOtherSessions,
  deleteSession,
  findSession,
  listSessions,
  loginAllowed,
  markVerified,
  recordLoginAttempt,
  tokenHash,
  updateName,
  updatePassword,
  userById,
  userWithPassword,
  type SessionMatch,
} from './users.js'

function json(status: number, body: unknown): Response {
  return Response.json(body, { status, headers: { 'cache-control': 'no-store' } })
}

function failure(status: number, error: string): Response {
  return json(status, { error })
}

function noContent(): Response {
  return new Response(null, { status: 204, headers: { 'cache-control': 'no-store' } })
}

export function isAdmin(env: AuthEnv, email: string): boolean {
  return env.adminEmails.includes(email.toLowerCase())
}

function publicUser(user: User, env: AuthEnv): Omit<User, 'accountId' | 'id'> & { admin: boolean } {
  return { email: user.email, name: user.name, emailVerified: user.emailVerified, role: user.role, admin: isAdmin(env, user.email) }
}

function fromApp(request: Request): boolean {
  return request.headers.get(CLIENT_HEADER) === APP_CLIENT
}

export function adminEmailsFromEnv(env: Record<string, string | undefined>): string[] {
  return (env.ADMIN_EMAILS ?? '')
    .split(',')
    .map((email) => email.trim().toLowerCase())
    .filter((email) => email !== '')
}

export function authEnvFromProcess(): AuthEnv {
  return {
    mailer: mailerFromEnv(process.env),
    appUrl: process.env.APP_URL ?? '',
    now: () => new Date(),
    maxAccounts: limitsFromEnv(process.env).maxAccounts,
    adminEmails: adminEmailsFromEnv(process.env),
  }
}

async function readBody(request: Request): Promise<string | undefined> {
  const text = await request.text()
  return Buffer.byteLength(text) > MAX_BODY_BYTES ? undefined : text
}

async function guarded(route: string, handle: () => Promise<Response>): Promise<Response> {
  try {
    return await handle()
  } catch (error) {
    console.error(JSON.stringify({ route: `${AUTH_ROUTE}/${route}`, error: error instanceof Error ? error.message : 'unknown' }))
    return failure(500, 'internal_error')
  }
}

async function currentSession(request: Request, sql: Sql, env: AuthEnv): Promise<SessionMatch | undefined> {
  const hash = accountIdFromAuthorization(request.headers.get('authorization'))
  return hash === undefined ? undefined : findSession(sql, hash, env.now())
}

async function sendLink(sql: Sql, env: AuthEnv, user: User, purpose: EmailPurpose): Promise<boolean> {
  if (env.mailer === undefined || env.appUrl === '') {
    return false
  }
  const now = env.now()
  const expires =
    purpose === 'verify'
      ? new Date(now.getTime() + VERIFY_TOKEN_HOURS * 60 * 60 * 1000)
      : new Date(now.getTime() + RESET_TOKEN_MINUTES * 60 * 1000)
  const token = await createEmailToken(sql, user.id, purpose, expires)
  const link = `${env.appUrl}${purpose === 'verify' ? VERIFY_PATH : RESET_PATH}?token=${token}`
  const content = purpose === 'verify' ? verifyEmailMail(link) : resetPasswordMail(link)
  await env.mailer.send({ to: user.email, ...content })
  return true
}

export function signupRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return guarded('signup', async () => {
    const body = await readBody(request)
    if (body === undefined) {
      return failure(413, 'body_too_large')
    }
    const parsed = parseSignup(body)
    if (!parsed.ok) {
      return failure(400, parsed.error)
    }
    const input = parsed.value
    const legacyAccountId = input.legacyKey === undefined ? undefined : tokenHash(input.legacyKey)
    const invite = input.inviteToken === undefined ? undefined : await pendingInvite(sql, input.inviteToken, env.now())
    if (input.inviteToken !== undefined && invite === undefined) {
      return failure(400, 'invalid_invite')
    }
    const trusted = legacyAccountId !== undefined || isAdmin(env, input.email)
    if (!trusted && invite === undefined) {
      return failure(403, 'invite_required')
    }
    const role = trusted ? 'member' : 'guest'
    if (role === 'guest' && fromApp(request)) {
      return failure(403, 'web_only')
    }
    const outcome = await createUser(
      sql,
      { name: input.name, email: input.email, passwordHash: await hashPassword(input.password), legacyAccountId, role },
      env.maxAccounts,
    )
    if (outcome.status !== 'created') {
      return outcome.status === 'limit' ? failure(429, 'rate_limited') : failure(409, outcome.status)
    }
    if (!trusted && invite !== undefined && !(await acceptInvite(sql, invite.id, outcome.user.id, env.now()))) {
      await sql('delete from accounts where id = $1', [outcome.user.accountId])
      return failure(400, 'invalid_invite')
    }
    const token = await createSession(sql, outcome.user.id, input.device, env.now())
    try {
      await sendLink(sql, env, outcome.user, 'verify')
    } catch (error) {
      console.error(JSON.stringify({ route: `${AUTH_ROUTE}/signup`, mail: error instanceof Error ? error.message : 'unknown' }))
    }
    return json(201, { token, user: publicUser(outcome.user, env) })
  })
}

export function loginRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return guarded('login', async () => {
    const ipHash = clientIpHash(request.headers)
    const now = env.now()
    if (!(await loginAllowed(sql, ipHash, now))) {
      return failure(429, 'rate_limited')
    }
    const body = await readBody(request)
    if (body === undefined) {
      return failure(413, 'body_too_large')
    }
    const parsed = parseLogin(body)
    if (!parsed.ok) {
      await recordLoginAttempt(sql, ipHash, now)
      return failure(401, 'invalid_credentials')
    }
    const found = await userWithPassword(sql, parsed.value.email)
    if (found === undefined || !(await verifyPassword(parsed.value.password, found.passwordHash))) {
      await recordLoginAttempt(sql, ipHash, now)
      return failure(401, 'invalid_credentials')
    }
    if (found.user.role === 'guest' && fromApp(request)) {
      return failure(403, 'web_only')
    }
    const token = await createSession(sql, found.user.id, parsed.value.device, now)
    return json(200, { token, user: publicUser(found.user, env) })
  })
}

export function logoutRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return guarded('logout', async () => {
    const session = await currentSession(request, sql, env)
    if (session !== undefined) {
      await deleteSession(sql, session.userId, session.sessionId)
    }
    return noContent()
  })
}

export function meRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return guarded('me', async () => {
    const session = await currentSession(request, sql, env)
    if (session === undefined) {
      return failure(401, 'unauthorized')
    }
    if (request.method === 'PATCH') {
      const body = await readBody(request)
      const parsed = body === undefined ? undefined : parseNameBody(body)
      if (parsed === undefined || !parsed.ok) {
        return failure(400, 'invalid_name')
      }
      const user = await updateName(sql, session.userId, parsed.value)
      return user === undefined ? failure(401, 'unauthorized') : json(200, { user: publicUser(user, env) })
    }
    const found = await userById(sql, session.userId)
    return found === undefined ? failure(401, 'unauthorized') : json(200, { user: publicUser(found.user, env) })
  })
}

export function changePasswordRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return guarded('password', async () => {
    const session = await currentSession(request, sql, env)
    if (session === undefined) {
      return failure(401, 'unauthorized')
    }
    const body = await readBody(request)
    const parsed = body === undefined ? undefined : parsePasswordChange(body)
    if (parsed === undefined || !parsed.ok) {
      return failure(400, 'invalid_password')
    }
    const found = await userById(sql, session.userId)
    if (found === undefined || !(await verifyPassword(parsed.value.current, found.passwordHash))) {
      return failure(401, 'invalid_credentials')
    }
    await updatePassword(sql, session.userId, await hashPassword(parsed.value.next))
    if (parsed.value.endOtherSessions) {
      await deleteOtherSessions(sql, session.userId, session.sessionId)
    }
    return noContent()
  })
}

export function forgotPasswordRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return guarded('forgot', async () => {
    if (env.mailer === undefined || env.appUrl === '') {
      return failure(503, 'mail_unavailable')
    }
    const body = await readBody(request)
    const parsed = body === undefined ? undefined : parseEmailBody(body)
    if (parsed === undefined || !parsed.ok) {
      return failure(400, 'invalid_email')
    }
    const found = await userWithPassword(sql, parsed.value)
    if (found !== undefined && found.user.emailVerified) {
      await sendLink(sql, env, found.user, 'reset')
    }
    return noContent()
  })
}

export function resetPasswordRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return guarded('reset', async () => {
    const body = await readBody(request)
    const parsed = body === undefined ? undefined : parseTokenBody(body)
    if (parsed === undefined || !parsed.ok || parsed.value.password === undefined) {
      return failure(400, parsed !== undefined && !parsed.ok ? parsed.error : 'invalid_password')
    }
    const userId = await consumeEmailToken(sql, parsed.value.token, 'reset', env.now())
    if (userId === undefined) {
      return failure(400, 'invalid_token')
    }
    await updatePassword(sql, userId, await hashPassword(parsed.value.password))
    await deleteOtherSessions(sql, userId, undefined)
    return noContent()
  })
}

export function verifyEmailRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return guarded('verify', async () => {
    const body = await readBody(request)
    const parsed = body === undefined ? undefined : parseTokenBody(body)
    if (parsed === undefined || !parsed.ok) {
      return failure(400, 'invalid_token')
    }
    const now = env.now()
    const userId = await consumeEmailToken(sql, parsed.value.token, 'verify', now)
    if (userId === undefined) {
      return failure(400, 'invalid_token')
    }
    await markVerified(sql, userId, now)
    return noContent()
  })
}

export function resendVerificationRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return guarded('verify/resend', async () => {
    const session = await currentSession(request, sql, env)
    if (session === undefined) {
      return failure(401, 'unauthorized')
    }
    const found = await userById(sql, session.userId)
    if (found === undefined) {
      return failure(401, 'unauthorized')
    }
    if (found.user.emailVerified) {
      return noContent()
    }
    return (await sendLink(sql, env, found.user, 'verify')) ? noContent() : failure(503, 'mail_unavailable')
  })
}

export function sessionsRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return guarded('sessions', async () => {
    const session = await currentSession(request, sql, env)
    if (session === undefined) {
      return failure(401, 'unauthorized')
    }
    if (request.method === 'DELETE') {
      const id = new URL(request.url).searchParams.get('id')
      if (id === null || id === '') {
        return failure(400, 'invalid_session')
      }
      await deleteSession(sql, session.userId, id)
      return noContent()
    }
    return json(200, { sessions: await listSessions(sql, session.userId, session.sessionId) })
  })
}
