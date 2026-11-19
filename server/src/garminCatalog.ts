import { adminEmailsFromEnv } from './authRoutes.js'
import { GARMIN_CATALOG } from './constants.js'
import { GARMIN_CATALOG_REFERENCED, GARMIN_CATALOG_SNAPSHOT } from './garminCatalogSnapshot.js'
import type { GarminCatalogEnv } from './garminCatalog.types.js'
import { mailerFromEnv } from './mailer.js'
import { garminCatalogMail } from './mailTemplates.js'
import type { GarminCatalogDiff } from './mailTemplates.types.js'

function json(status: number, body: unknown): Response {
  return Response.json(body, { status, headers: { 'cache-control': 'no-store' } })
}

export function parseNames(text: string): Record<string, string> {
  const names: Record<string, string> = {}
  for (const line of text.split(/\r?\n/)) {
    const index = line.indexOf('=')
    if (index <= 0 || line.startsWith('#')) continue
    names[line.slice(0, index).trim()] = line.slice(index + 1).trim()
  }
  return names
}

export function currentCatalog(exercises: unknown, names: Record<string, string>): Record<string, string | null> {
  const categories = (exercises as { categories?: Record<string, { exercises?: Record<string, unknown> }> }).categories
  if (categories === undefined || typeof categories !== 'object') throw new Error('garmin_catalog_format')
  const catalog: Record<string, string | null> = {}
  for (const [category, body] of Object.entries(categories)) {
    for (const name of Object.keys(body.exercises ?? {})) {
      catalog[`${category}/${name}`] = names[`${GARMIN_CATALOG.namePrefix}${name}`] ?? null
    }
  }
  if (Object.keys(catalog).length === 0) throw new Error('garmin_catalog_empty')
  return catalog
}

export function diffCatalog(
  snapshot: Record<string, string | null>,
  current: Record<string, string | null>,
  referenced: readonly string[],
): GarminCatalogDiff {
  const ids = (record: Record<string, string | null>) => Object.keys(record).sort()
  return {
    added: ids(current).filter((id) => !(id in snapshot)).map((id) => ({ id, name: current[id] ?? null })),
    removed: ids(snapshot)
      .filter((id) => !(id in current))
      .map((id) => ({ id, name: snapshot[id] ?? null, referenced: referenced.includes(id) })),
    renamed: ids(current)
      .filter((id) => id in snapshot && snapshot[id] !== current[id])
      .map((id) => ({ id, from: snapshot[id] ?? null, to: current[id] ?? null })),
  }
}

export const hasChanges = (diff: GarminCatalogDiff): boolean => diff.added.length + diff.removed.length + diff.renamed.length > 0

async function download(env: GarminCatalogEnv, url: string): Promise<Response> {
  const response = await env.fetcher(url, { signal: AbortSignal.timeout(GARMIN_CATALOG.timeoutMs) })
  if (!response.ok) throw new Error(`garmin_catalog_http_${response.status}`)
  return response
}

export async function garminCatalogCron(request: Request, env: GarminCatalogEnv): Promise<Response> {
  if (env.cronSecret === '') return json(503, { error: 'cron_not_configured' })
  if (request.headers.get('authorization') !== `Bearer ${env.cronSecret}`) return json(401, { error: 'unauthorized' })
  let diff: GarminCatalogDiff
  try {
    const [exercises, names] = await Promise.all([
      download(env, GARMIN_CATALOG.exercisesUrl).then((response) => response.json()),
      download(env, GARMIN_CATALOG.namesUrl).then((response) => response.text()),
    ])
    diff = diffCatalog(env.snapshot, currentCatalog(exercises, parseNames(names)), env.referenced)
  } catch (error) {
    return json(502, { error: error instanceof Error ? error.message : 'garmin_catalog_failed' })
  }
  if (!hasChanges(diff)) return json(200, { changed: false })
  let notified = 0
  if (env.mailer !== undefined) {
    const content = garminCatalogMail({ diff, checkedOn: env.now().toISOString().slice(0, 10).split('-').reverse().join('/') })
    for (const to of env.adminEmails) {
      await env.mailer.send({ to, ...content }).then(() => { notified += 1 }).catch(() => undefined)
    }
  }
  return json(200, { changed: true, added: diff.added.length, removed: diff.removed.length, renamed: diff.renamed.length, notified })
}

export function garminCatalogEnvFromProcess(): GarminCatalogEnv {
  return {
    cronSecret: process.env.CRON_SECRET ?? '',
    adminEmails: adminEmailsFromEnv(process.env),
    mailer: mailerFromEnv(process.env),
    fetcher: fetch,
    now: () => new Date(),
    snapshot: GARMIN_CATALOG_SNAPSHOT,
    referenced: GARMIN_CATALOG_REFERENCED,
  }
}
