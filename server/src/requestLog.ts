import { REQUEST_LOG_RETENTION_DAYS } from './constants.js'
import type { Sql } from './db.js'
import type { RequestLogEntry } from './types.js'

export async function recordRequest(sql: Sql, entry: RequestLogEntry): Promise<void> {
  try {
    await sql(
      `with expired as (delete from request_log where created_at < now() - make_interval(days => $6::int))
       insert into request_log (method, route, status, record_count, account_prefix) values ($1, $2, $3, $4, $5)`,
      [entry.method, entry.route, entry.status, entry.recordCount, entry.accountPrefix, REQUEST_LOG_RETENTION_DAYS],
    )
  } catch (error) {
    console.error(JSON.stringify({ event: 'request_log_failed', error: error instanceof Error ? error.name : 'unknown' }))
  }
}
