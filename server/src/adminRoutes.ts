import { adminOverview, adminUsers } from './adminStats.js'
import { accountIdFromAuthorization } from './auth.js'
import { authEnvFromProcess, isAdmin } from './authRoutes.js'
import { inviteMail } from './mailTemplates.js'
import { EMAIL_MAX_LENGTH, EMAIL_PATTERN, INVITE_CHANNELS, INVITE_MESSAGE, INVITE_PATH, INVITE_QUERY, NAME_MAX_LENGTH } from './constants.js'
import { dataKeyFromEnv } from './cipher.js'
import type { Sql } from './db.js'
import { pendingRequests } from './inviteRequests.js'
import { cancelInvite, createInvite, inviteById, listInvites, pendingInvite, renewInvite } from './invites.js'
import type { AuthEnv, InviteChannel, InviteRow, User } from './types.js'
import { findSession, userById } from './users.js'
import { parseObject } from './validate.js'

function json(status: number, body: unknown): Response {
  return Response.json(body, { status, headers: { 'cache-control': 'no-store' } })
}

function failure(status: number, error: string): Response {
  return json(status, { error })
}

async function bodyOf(request: Request): Promise<Record<string, unknown> | undefined> {
  const parsed = parseObject(await request.text())
  return parsed.ok ? parsed.value : undefined
}

export async function withAdmin(request: Request, sql: Sql, env: AuthEnv, handle: (admin: User) => Promise<Response>): Promise<Response> {
  try {
    const hash = accountIdFromAuthorization(request.headers.get('authorization'))
    const session = hash === undefined ? undefined : await findSession(sql, hash, env.now())
    const found = session === undefined ? undefined : await userById(sql, session.userId)
    if (found === undefined) {
      return failure(401, 'unauthorized')
    }
    if (!isAdmin(env, found.user.email)) {
      return failure(403, 'forbidden')
    }
    return await handle(found.user)
  } catch (error) {
    console.error(JSON.stringify({ route: 'admin', error: error instanceof Error ? error.name : 'unknown' }))
    return failure(500, 'internal_error')
  }
}

function inviteLink(env: AuthEnv, token: string): string {
  return `${env.appUrl}${INVITE_PATH}?${INVITE_QUERY}=${token}`
}

export async function deliver(env: AuthEnv, admin: User, invite: InviteRow, token: string): Promise<Response> {
  const link = inviteLink(env, token)
  const message = INVITE_MESSAGE(invite.name, admin.name, link)
  if (invite.channel === 'email' && invite.email !== null) {
    if (env.mailer === undefined) {
      return json(200, { invite, link, message, mailed: false })
    }
    await env.mailer.send({ to: invite.email, ...inviteMail({ name: invite.name, inviter: admin.name, link, message }) })
    return json(200, { invite, link, message, mailed: true })
  }
  return json(200, { invite, link, message, mailed: false })
}

export function adminOverviewRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess(), dataKey: Buffer | undefined = dataKeyFromEnv(process.env)): Promise<Response> {
  return withAdmin(request, sql, env, async () => {
    const now = env.now()
    return json(200, {
      overview: await adminOverview(sql, now, env.maxAccounts),
      users: await adminUsers(sql, env.adminEmails),
      invites: await listInvites(sql, now),
      requests: dataKey === undefined ? [] : await pendingRequests(sql, dataKey),
    })
  })
}

export function adminCreateInviteRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return withAdmin(request, sql, env, async (admin) => {
    const value = await bodyOf(request)
    const name = typeof value?.name === 'string' ? value.name.trim() : ''
    const channel = value?.channel
    const email = typeof value?.email === 'string' && value.email.trim() !== '' ? value.email.trim() : undefined
    if (name === '' || [...name].length > NAME_MAX_LENGTH) {
      return failure(400, 'invalid_name')
    }
    if (typeof channel !== 'string' || !INVITE_CHANNELS.includes(channel as InviteChannel)) {
      return failure(400, 'invalid_channel')
    }
    if (email !== undefined && (email.length > EMAIL_MAX_LENGTH || !EMAIL_PATTERN.test(email))) {
      return failure(400, 'invalid_email')
    }
    if (channel === 'email' && email === undefined) {
      return failure(400, 'invalid_email')
    }
    if (channel === 'email' && env.mailer === undefined) {
      return failure(503, 'mail_unavailable')
    }
    const created = await createInvite(sql, { name, email, channel: channel as InviteChannel }, admin.id, env.now())
    return deliver(env, admin, created.invite, created.token)
  })
}

export function adminInviteActionRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return withAdmin(request, sql, env, async (admin) => {
    const value = await bodyOf(request)
    const id = typeof value?.id === 'string' ? value.id : ''
    const action = value?.action
    const now = env.now()
    if ((await inviteById(sql, id, now)) === undefined) {
      return failure(404, 'not_found')
    }
    if (action === 'cancel') {
      await cancelInvite(sql, id, now)
      return json(200, { invite: await inviteById(sql, id, now) })
    }
    if (action === 'renew') {
      const renewed = await renewInvite(sql, id, now)
      return renewed === undefined ? failure(409, 'already_accepted') : deliver(env, admin, renewed.invite, renewed.token)
    }
    return failure(400, 'invalid_action')
  })
}

export function adminDeleteUserRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  return withAdmin(request, sql, env, async (admin) => {
    const id = new URL(request.url).searchParams.get('id') ?? ''
    const found = await userById(sql, id)
    if (found === undefined) {
      return failure(404, 'not_found')
    }
    if (found.user.id === admin.id || isAdmin(env, found.user.email)) {
      return failure(409, 'cannot_remove_admin')
    }
    await sql('delete from accounts where id = $1', [found.user.accountId])
    return new Response(null, { status: 204, headers: { 'cache-control': 'no-store' } })
  })
}

export async function invitePreviewRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess()): Promise<Response> {
  const token = new URL(request.url).searchParams.get(INVITE_QUERY) ?? ''
  try {
    const invite = token === '' ? undefined : await pendingInvite(sql, token, env.now())
    if (invite === undefined) {
      return failure(404, 'invalid_invite')
    }
    return json(200, { name: invite.name, email: invite.email, inviterName: invite.inviterName, expiresAt: invite.expiresAt })
  } catch {
    return failure(404, 'invalid_invite')
  }
}
