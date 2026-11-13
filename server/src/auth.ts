import { createHash } from 'node:crypto'
import { TOKEN_BYTES, TOKEN_PATTERN } from './constants.js'
import type { Sql } from './db.js'

export function accountIdFromAuthorization(header: string | null): string | undefined {
  const token = header === null ? undefined : TOKEN_PATTERN.exec(header)?.[1]
  if (token === undefined) {
    return undefined
  }
  const bytes = Buffer.from(token, 'base64url')
  if (bytes.length !== TOKEN_BYTES || bytes.toString('base64url') !== token) {
    return undefined
  }
  return createHash('sha256').update(bytes).digest('hex')
}

export async function accountExists(sql: Sql, accountId: string): Promise<boolean> {
  const rows = await sql('select 1 from accounts where id = $1', [accountId])
  return rows.length > 0
}
