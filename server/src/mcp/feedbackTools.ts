import { adminEmailsFromEnv } from '../authRoutes.js'
import type { Sql } from '../db.js'
import { FEEDBACK } from './mcpConstants.js'
import { readBlob, writeBlob } from './mcpStore.js'
import { MCP_TEXT } from './mcpText.js'
import type { FeedbackEntry, PendingFeedback } from './feedbackTypes.js'

interface FeedbackResult {
  text: string
  isError: boolean
}

const ok = (text: string): FeedbackResult => ({ text, isError: false })
const fail = (text: string): FeedbackResult => ({ text, isError: true })

export async function isAdminAccount(sql: Sql, accountId: string): Promise<boolean> {
  const rows = await sql<{ email: string }>('select email from users where account_id = $1', [accountId])
  const email = rows[0]?.email
  return email !== undefined && adminEmailsFromEnv(process.env).includes(email.toLowerCase())
}

const shortAccount = (accountId: string) => accountId.slice(0, FEEDBACK.accountPrefixLength)

const dateFromReference = (seconds: number) => new Date((seconds + FEEDBACK.referenceEpochSeconds) * 1000)

function isPending(entry: FeedbackEntry, undone: Set<string>): boolean {
  return entry.status === FEEDBACK.pending && (entry.undoes === undefined || entry.undoes === null) && !undone.has(entry.id)
}

function parseEntries(text: string): FeedbackEntry[] | null {
  try {
    const parsed: unknown = JSON.parse(text)
    return Array.isArray(parsed) ? (parsed as FeedbackEntry[]) : null
  } catch {
    return null
  }
}

function pendingOf(entries: FeedbackEntry[]): FeedbackEntry[] {
  const undone = new Set(entries.flatMap((entry) => (typeof entry.undoes === 'string' ? [entry.undoes] : [])))
  return entries.filter((entry) => entry.verdict === FEEDBACK.doesNotMatch && isPending(entry, undone))
}

async function accountsWithFeedback(sql: Sql, prefix?: string): Promise<string[]> {
  const rows = await sql<{ account_id: string }>(
    `select account_id from records
     where kind = 'preference' and id = $1 and not deleted and format = 'plain'
       and ($2::text is null or account_id like $2 || '%')
     order by account_id`,
    [FEEDBACK.blobId, prefix ?? null],
  )
  return rows.map((row) => row.account_id)
}

export async function listFeedback(sql: Sql, key: Buffer): Promise<FeedbackResult> {
  const items: PendingFeedback[] = []
  for (const account of await accountsWithFeedback(sql)) {
    const blob = await readBlob(sql, key, account, FEEDBACK.blobId)
    const entries = blob === null ? null : parseEntries(blob.text)
    if (entries === null) continue
    for (const entry of pendingOf(entries)) items.push({ account, entry })
  }
  if (items.length === 0) return ok(MCP_TEXT.feedbackNone)
  return ok(
    items
      .map(({ account, entry }) =>
        MCP_TEXT.feedbackItem({
          account: shortAccount(account),
          id: entry.id,
          exercise: entry.exerciseName,
          media: entry.mediaId,
          alternative: entry.chosenMediaId ?? MCP_TEXT.feedbackNoAlternative,
          note: entry.note ?? MCP_TEXT.feedbackNoNote,
          date: dateFromReference(entry.createdAt).toISOString().slice(0, 10),
        }),
      )
      .join('\n\n'),
  )
}

export async function resolveFeedback(sql: Sql, key: Buffer, args: Record<string, unknown>, now: Date): Promise<FeedbackResult> {
  const { conta, id, resolucao, versao } = args
  if (![conta, id, resolucao, versao].every((value) => typeof value === 'string' && value !== '')) return fail(MCP_TEXT.feedbackMissingArguments)
  const prefix = (conta as string).toLowerCase()
  if (!FEEDBACK.accountPrefixPattern.test(prefix)) return fail(MCP_TEXT.feedbackAccountNotFound(conta as string))
  const accounts = await accountsWithFeedback(sql, prefix)
  const account = accounts[0]
  if (accounts.length !== 1 || account === undefined) return fail(MCP_TEXT.feedbackAccountNotFound(conta as string))
  const blob = await readBlob(sql, key, account, FEEDBACK.blobId)
  const entries = blob === null ? null : parseEntries(blob.text)
  if (blob === null || entries === null) return fail(MCP_TEXT.feedbackEntryNotFound)
  const target = pendingOf(entries).find((entry) => entry.id === id)
  if (target === undefined) return fail(MCP_TEXT.feedbackEntryNotFound)
  const newest = Math.max(...entries.map((entry) => entry.updatedAt))
  const stamp = Math.max(now.getTime() / 1000 - FEEDBACK.referenceEpochSeconds, newest + FEEDBACK.minimumBumpSeconds)
  const updated = entries.map((entry) =>
    entry === target ? { ...entry, status: FEEDBACK.resolved, resolution: resolucao, resolvedIn: versao, updatedAt: stamp } : entry,
  )
  const serverTime = new Date(Math.max(now.getTime(), Date.parse(blob.updatedAt) + FEEDBACK.minimumBumpSeconds * 1000, dateFromReference(stamp).getTime()))
  const saved = await writeBlob(sql, key, account, FEEDBACK.blobId, JSON.stringify(updated), serverTime)
  return saved ? ok(MCP_TEXT.feedbackResolved(target.id, shortAccount(account))) : fail(MCP_TEXT.feedbackSaveFailed)
}
