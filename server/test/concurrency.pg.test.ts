import { execFileSync, spawn, spawnSync, type ChildProcessWithoutNullStreams } from 'node:child_process'
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import type { SqlStatement } from '../src/db.js'
import { createAccountStatements } from '../src/account.js'
import { pullStatement, pushStatements } from '../src/merge.js'
import { incomingRecord, migrationsDir } from './helpers.js'

const image = process.env.SYNC_TEST_POSTGRES_IMAGE ?? 'postgres:17-alpine'
const account = 'conta-concorrente'

function quote(value: unknown): string {
  return `'${String(value).replaceAll('\\', '\\\\').replaceAll("'", "''")}'`
}

function bound(statement: SqlStatement): string {
  return `${statement.text}\n\\bind ${statement.params.map(quote).join(' ')} \\g\n`
}

class PsqlSession {
  private readonly process: ChildProcessWithoutNullStreams
  private output = ''
  private counter = 0
  private exited = false

  constructor(container: string) {
    this.process = spawn('docker', [
      'exec', '-i', container, 'psql', '-U', 'postgres', '-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1',
    ])
    this.process.stdout.on('data', (chunk: Buffer) => {
      this.output += chunk.toString()
    })
    this.process.stderr.on('data', (chunk: Buffer) => {
      this.output += chunk.toString()
    })
    this.process.on('exit', () => {
      this.exited = true
    })
  }

  run(script: string): Promise<string[]> {
    const marker = `__fim_${++this.counter}__`
    this.process.stdin.write(`${script}\n\\echo ${marker}\n`)
    return new Promise((resolve, reject) => {
      const check = () => {
        const index = this.output.indexOf(marker)
        if (index === -1 && this.exited) {
          reject(new Error(`psql encerrou: ${this.output}`))
          return
        }
        if (index === -1) {
          setTimeout(check, 10)
          return
        }
        const lines = this.output.slice(0, index).split('\n').filter((line) => line !== '')
        this.output = this.output.slice(index + marker.length + 1)
        resolve(lines)
      }
      check()
    })
  }

  close(): void {
    this.process.stdin.end()
  }
}

async function pulledIds(session: PsqlSession, since: number): Promise<{ ids: string[]; cursor: number }> {
  const rows = (await session.run(bound(pullStatement(account, since)))).map((line) => line.split('|'))
  return { ids: rows.map((row) => row[1] ?? ''), cursor: rows.length === 0 ? since : Number(rows.at(-1)?.[5]) }
}

async function waitForLockWait(observer: PsqlSession, finished: Promise<unknown>): Promise<void> {
  let done = false
  void finished.then(() => {
    done = true
  })
  while (!done) {
    const [waiting] = await observer.run("select count(*) from pg_stat_activity where wait_event_type = 'Lock';")
    if (waiting !== '0') {
      return
    }
    await new Promise((resolve) => setTimeout(resolve, 20))
  }
}

describe('push concorrente contra Postgres real', () => {
  let container = ''
  const sessions: PsqlSession[] = []

  beforeAll(async () => {
    container = execFileSync('docker', [
      'run', '-d', '--rm', '--pull=never', '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', image,
    ]).toString().trim()
    for (let attempt = 0; attempt < 150; attempt++) {
      const logs = spawnSync('docker', ['logs', container], { encoding: 'utf8' })
      if (`${logs.stdout}${logs.stderr}`.includes('init process complete')) {
        break
      }
      await new Promise((resolve) => setTimeout(resolve, 200))
    }
    const setup = new PsqlSession(container)
    sessions.push(setup)
    for (const name of readdirSync(migrationsDir).filter((file) => file.endsWith('.sql')).sort()) {
      await setup.run(readFileSync(join(migrationsDir, name), 'utf8'))
    }
    await setup.run(`insert into accounts (id) values (${quote(account)});`)
  })

  afterAll(() => {
    sessions.forEach((session) => session.close())
    if (container !== '') {
      execFileSync('docker', ['rm', '-f', container], { stdio: 'ignore' })
    }
  })

  it('pull não perde o registro de seq menor que commita depois', async () => {
    const first = new PsqlSession(container)
    const second = new PsqlSession(container)
    const reader = new PsqlSession(container)
    sessions.push(first, second, reader)

    await first.run(`begin;\n${pushStatements(account, [incomingRecord('primeiro')], 1024 * 1024).map(bound).join('')}`)
    const secondDone = second.run(
      `begin;\n${pushStatements(account, [incomingRecord('segundo')], 1024 * 1024).map(bound).join('')}commit;`,
    )
    await waitForLockWait(reader, secondDone)

    const before = await pulledIds(reader, 0)
    await first.run('commit;')
    await secondDone
    const after = await pulledIds(reader, before.cursor)

    expect([...before.ids, ...after.ids].sort()).toEqual(['primeiro', 'segundo'])
  })

  it('criação concorrente respeita o limite total de contas', async () => {
    const first = new PsqlSession(container)
    const second = new PsqlSession(container)
    const reader = new PsqlSession(container)
    sessions.push(first, second, reader)
    const [{ count: before } = { count: '0' }] = (await reader.run('select count(*) from accounts;')).map((count) => ({ count }))
    const limit = Number(before) + 1
    const now = new Date()

    await first.run(`begin;\n${createAccountStatements('nova-a', 'ip-a', now, limit).map(bound).join('')}`)
    const secondDone = second.run(`begin;\n${createAccountStatements('nova-b', 'ip-b', now, limit).map(bound).join('')}commit;`)
    await waitForLockWait(reader, secondDone)
    await first.run('commit;')
    await secondDone

    const created = await reader.run("select id from accounts where id in ('nova-a', 'nova-b') order by id;")
    expect(created).toEqual(['nova-a'])
  })
})
