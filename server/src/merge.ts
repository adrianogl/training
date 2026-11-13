import { MAX_PULL_PAGE_BYTES, PULL_PAGE_SIZE } from './constants.js'
import type { Sql, SqlStatement } from './db.js'
import type { IncomingRecord, PullResult, PushOutcome, RecordKey, StoredRecord } from './types.js'

function recordKey(record: RecordKey): string {
  return `${record.kind}\u0000${record.id}`
}

export function newestPerKey(records: IncomingRecord[]): { winners: IncomingRecord[]; ignored: RecordKey[] } {
  const winners = new Map<string, IncomingRecord>()
  const ignored: RecordKey[] = []
  for (const record of records) {
    const key = recordKey(record)
    const current = winners.get(key)
    if (current === undefined || record.updatedAt > current.updatedAt) {
      if (current !== undefined) {
        ignored.push({ kind: current.kind, id: current.id })
      }
      winners.set(key, record)
    } else {
      ignored.push({ kind: record.kind, id: record.id })
    }
  }
  return { winners: [...winners.values()], ignored }
}

const INCOMING_AND_USAGE = `
  incoming as (
    select * from jsonb_to_recordset($2::jsonb)
      as r(kind text, id text, "updatedAt" timestamptz, deleted boolean, payload text)
  ),
  current_usage as (
    select coalesce(sum(octet_length(payload)), 0)::bigint as bytes from records where account_id = $1
  ),
  projected as (
    select (select bytes from current_usage)
           + coalesce(sum(coalesce(octet_length(i.payload), 0) - coalesce(octet_length(r.payload), 0)), 0) as bytes
    from incoming i
    left join records r on r.account_id = $1 and r.kind = i.kind and r.id = i.id
    where r.id is null or r.updated_at < i."updatedAt"
  ),
  allowed as (
    select p.bytes <= $3::bigint or p.bytes <= c.bytes as ok from projected p, current_usage c
  )`

export function pushStatements(accountId: string, winners: IncomingRecord[], maxAccountBytes: number): SqlStatement[] {
  const params = [accountId, JSON.stringify(winners), maxAccountBytes]
  return [
    {
      text: 'select 1 as locked from pg_advisory_xact_lock(hashtext($1))',
      params: [accountId],
    },
    {
      text: `with ${INCOMING_AND_USAGE} select ok from allowed`,
      params,
    },
    {
      text: `with ${INCOMING_AND_USAGE}
             insert into records (account_id, kind, id, updated_at, deleted, payload)
             select $1, i.kind, i.id, i."updatedAt", i.deleted, i.payload
             from incoming i
             where (select ok from allowed)
             on conflict (account_id, kind, id) do update
             set updated_at = excluded.updated_at,
                 deleted = excluded.deleted,
                 payload = excluded.payload,
                 written_at = now(),
                 seq = nextval(pg_get_serial_sequence('records', 'seq'))
             where records.updated_at < excluded.updated_at
             returning kind, id`,
      params,
    },
    {
      text: 'select coalesce(max(seq), 0)::text as cursor from records where account_id = $1',
      params: [accountId],
    },
  ]
}

export async function pushRecords(
  sql: Sql,
  accountId: string,
  records: IncomingRecord[],
  maxAccountBytes: number,
): Promise<PushOutcome> {
  const { winners, ignored } = newestPerKey(records)
  const [, allowed, written, cursorRows] = await sql.transaction(pushStatements(accountId, winners, maxAccountBytes))
  if ((allowed?.[0] as { ok: boolean } | undefined)?.ok !== true) {
    return { status: 'quota_exceeded' }
  }
  const writtenKeys = new Set(((written ?? []) as RecordKey[]).map(recordKey))
  const cursor = (cursorRows?.[0] as { cursor: string } | undefined)?.cursor ?? '0'
  const rejected = winners
    .filter((record) => !writtenKeys.has(recordKey(record)))
    .map((record) => ({ kind: record.kind, id: record.id }))
  return { status: 'ok', result: { cursor: Number(cursor), ignored: [...ignored, ...rejected] } }
}

export function pullStatement(accountId: string, since: number): SqlStatement {
  return {
    text: `with page as (
             select candidates.*,
                    row_number() over (order by seq) as rn,
                    sum(coalesce(octet_length(payload), 0)) over (order by seq) as running
             from (
               select kind, id, updated_at, deleted, payload, seq
               from records
               where account_id = $1 and seq > $2::bigint
               order by seq
               limit $3
             ) candidates
           )
           select kind, id,
                  to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') as "updatedAt",
                  deleted, payload, seq::text as seq,
                  (select count(*) from page)::int as candidates
           from page
           where rn <= $4 and (rn = 1 or running <= $5)
           order by page.seq`,
    params: [accountId, since, PULL_PAGE_SIZE + 1, PULL_PAGE_SIZE, MAX_PULL_PAGE_BYTES],
  }
}

export async function pullChanges(sql: Sql, accountId: string, since: number): Promise<PullResult> {
  const statement = pullStatement(accountId, since)
  const rows = await sql<Omit<StoredRecord, 'seq'> & { seq: string | number; candidates: number }>(
    statement.text,
    statement.params,
  )
  const records = rows.map(({ candidates: _candidates, ...row }) => ({ ...row, seq: Number(row.seq) }))
  return {
    records,
    cursor: records.at(-1)?.seq ?? since,
    hasMore: (rows[0]?.candidates ?? 0) > records.length,
  }
}
