import type { Mailer } from './types.js'

export interface GarminCatalogEnv {
  cronSecret: string
  adminEmails: string[]
  mailer: Mailer | undefined
  fetcher: typeof fetch
  now: () => Date
  snapshot: Record<string, string | null>
  referenced: readonly string[]
}
