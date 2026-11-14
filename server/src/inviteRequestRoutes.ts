import { deliver, withAdmin } from './adminRoutes.js'
import { authEnvFromProcess } from './authRoutes.js'
import { dataKeyFromEnv } from './cipher.js'
import { EMAIL_MAX_LENGTH, EMAIL_PATTERN, INVITE_REQUEST, MAX_BODY_BYTES, NAME_MAX_LENGTH } from './constants.js'
import type { Sql } from './db.js'
import { createInvite } from './invites.js'
import { handleRequest, pendingCount, pendingRequests, recentRequestsFrom, saveRequest } from './inviteRequests.js'
import { clientIpHash } from './rateLimit.js'
import type { AuthEnv, InviteRequestInput } from './types.js'
import { parseObject } from './validate.js'

function json(status: number, body: unknown): Response {
  return Response.json(body, { status, headers: { 'cache-control': 'no-store' } })
}

async function bodyOf(request: Request): Promise<Record<string, unknown> | undefined> {
  const text = await request.text()
  if (Buffer.byteLength(text) > MAX_BODY_BYTES) return undefined
  const parsed = parseObject(text)
  return parsed.ok ? parsed.value : undefined
}

export function parseInviteRequest(value: Record<string, unknown> | undefined): InviteRequestInput | string {
  if (value === undefined) return 'invalid_body'
  const name = typeof value.name === 'string' ? value.name.trim() : ''
  const email = typeof value.email === 'string' ? value.email.trim() : ''
  const message = typeof value.message === 'string' ? value.message.trim() : ''
  if (name === '' || [...name].length > NAME_MAX_LENGTH) return 'invalid_name'
  if (email.length > EMAIL_MAX_LENGTH || !EMAIL_PATTERN.test(email)) return 'invalid_email'
  if (typeof value.watch !== 'string' || !INVITE_REQUEST.watches.some((item) => item === value.watch)) return 'invalid_watch'
  if ([...message].length > INVITE_REQUEST.messageMaxLength) return 'invalid_message'
  return { name, email, watch: value.watch, message }
}

export async function inviteRequestRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess(), dataKey: Buffer | undefined = dataKeyFromEnv(process.env)): Promise<Response> {
  try {
    const value = await bodyOf(request)
    const honeypot = value?.[INVITE_REQUEST.honeypotField]
    if (typeof honeypot === 'string' && honeypot !== '') return json(202, { received: true })
    const input = parseInviteRequest(value)
    if (typeof input === 'string') return json(400, { error: input })
    if (dataKey === undefined) return json(503, { error: 'storage_unavailable' })
    const now = env.now()
    const ipHash = clientIpHash(request.headers)
    if ((await recentRequestsFrom(sql, ipHash, new Date(now.getTime() - 3_600_000))) >= INVITE_REQUEST.maxPerIpPerHour || (await pendingCount(sql)) >= INVITE_REQUEST.maxPending) {
      return json(429, { error: 'rate_limited' })
    }
    await saveRequest(sql, dataKey, input, ipHash, now)
    if (env.mailer !== undefined) {
      const text = INVITE_REQUEST.mailText(input.name, input.email, INVITE_REQUEST.watchNames[input.watch] ?? input.watch, input.message, `${env.appUrl}${INVITE_REQUEST.adminPath}`)
      for (const to of env.adminEmails) {
        await env.mailer.send({ to, subject: INVITE_REQUEST.mailSubject, text }).catch(() => undefined)
      }
    }
    return json(202, { received: true })
  } catch (error) {
    console.error(JSON.stringify({ route: 'invite-requests', error: error instanceof Error ? error.name : 'unknown' }))
    return json(500, { error: 'internal_error' })
  }
}

export function inviteRequestActionRoute(request: Request, sql: Sql, env: AuthEnv = authEnvFromProcess(), dataKey: Buffer | undefined = dataKeyFromEnv(process.env)): Promise<Response> {
  return withAdmin(request, sql, env, async (admin) => {
    const value = await bodyOf(request)
    const id = typeof value?.id === 'string' ? value.id : ''
    if (dataKey === undefined) return json(503, { error: 'storage_unavailable' })
    const found = (await pendingRequests(sql, dataKey)).find((item) => item.id === id)
    if (found === undefined) return json(404, { error: 'not_found' })
    const now = env.now()
    if (value?.action === 'decline') {
      await handleRequest(sql, id, 'declined', now)
      return json(200, { id, status: 'declined' })
    }
    if (value?.action !== 'invite') return json(400, { error: 'invalid_action' })
    const channel = env.mailer === undefined ? 'link' : 'email'
    const created = await createInvite(sql, { name: found.name, email: found.email, channel }, admin.id, now)
    await handleRequest(sql, id, 'invited', now)
    return deliver(env, admin, created.invite, created.token)
  })
}
