import { describe, expect, it } from 'vitest'
import { currentCatalog, diffCatalog, garminCatalogCron, parseNames } from '../src/garminCatalog.js'
import { GARMIN_CATALOG_REFERENCED, GARMIN_CATALOG_SNAPSHOT } from '../src/garminCatalogSnapshot.js'
import type { GarminCatalogEnv } from '../src/garminCatalog.types.js'
import type { Mail } from '../src/types.js'

const exercises = {
  categories: {
    SQUAT: { exercises: { GOBLET_SQUAT: {}, STEP_UP: {} } },
    PLANK: { exercises: { PLANK: {} } },
  },
}
const names = 'exercise_type_GOBLET_SQUAT=Agachamento Goblet\nexercise_type_STEP_UP=Step\nexercise_type_PLANK=Prancha\n'

function fakeFetch(body: unknown = exercises, text = names, status = 200): typeof fetch {
  return (async (input: string | URL | Request) => {
    const url = String(input)
    if (status !== 200) return new Response('erro', { status })
    return url.endsWith('.json') ? Response.json(body) : new Response(text)
  }) as typeof fetch
}

function env(overrides: Partial<GarminCatalogEnv> = {}, sent: Mail[] = []): GarminCatalogEnv {
  return {
    cronSecret: 'segredo',
    adminEmails: ['a@x.dev', 'b@x.dev'],
    mailer: { send: async (mail) => { sent.push(mail) } },
    fetcher: fakeFetch(),
    now: () => new Date('2026-12-01T12:00:00Z'),
    snapshot: { 'SQUAT/GOBLET_SQUAT': 'Agachamento Goblet', 'SQUAT/STEP_UP': 'Step', 'PLANK/PLANK': 'Prancha' },
    referenced: ['SQUAT/GOBLET_SQUAT'],
    ...overrides,
  }
}

const request = (token = 'segredo') => new Request('https://x.dev/api/cron/garmin-catalog', { headers: { authorization: `Bearer ${token}` } })

describe('aviso do catálogo da Garmin', () => {
  it('só roda com o segredo do cron', async () => {
    expect((await garminCatalogCron(request(), env({ cronSecret: '' }))).status).toBe(503)
    expect((await garminCatalogCron(request('outro'), env())).status).toBe(401)
  })

  it('não manda e-mail quando a lista é igual ao retrato', async () => {
    const sent: Mail[] = []
    const response = await garminCatalogCron(request(), env({}, sent))
    expect(await response.json()).toEqual({ changed: false })
    expect(sent).toHaveLength(0)
  })

  it('manda e-mail aos admins com novos, removidos e renomeados', async () => {
    const sent: Mail[] = []
    const current = { categories: { SQUAT: { exercises: { STEP_UP: {}, NORDIC: {} } }, PLANK: { exercises: { PLANK: {} } } } }
    const response = await garminCatalogCron(request(), env({ fetcher: fakeFetch(current, `${names}exercise_type_STEP_UP=Subida no step\n`) }, sent))
    expect(await response.json()).toEqual({ changed: true, added: 1, removed: 1, renamed: 1, notified: 2 })
    expect(sent.map((mail) => mail.to)).toEqual(['a@x.dev', 'b@x.dev'])
    const [mail] = sent
    expect(mail?.subject).toBe('Catálogo da Garmin mudou: 1 novos, 1 removidos, 1 renomeados')
    expect(mail?.html).toContain('SQUAT/NORDIC')
    expect(mail?.html).toContain('Está no mapa de ids antigos: precisa de um novo destino.')
    expect(mail?.html).toContain('Step → Subida no step')
    expect(mail?.html).toContain('01/12/2026')
    expect(mail?.text).toContain('Rode: python3 scripts/garmin-catalog.py')
  })

  it('responde 502 sem mandar e-mail quando a Garmin falha ou muda o formato', async () => {
    const sent: Mail[] = []
    expect((await garminCatalogCron(request(), env({ fetcher: fakeFetch(exercises, names, 404) }, sent))).status).toBe(502)
    expect((await garminCatalogCron(request(), env({ fetcher: fakeFetch({ outra: 1 }) }, sent))).status).toBe(502)
    expect(sent).toHaveLength(0)
  })

  it('lê os nomes e monta o catálogo atual', () => {
    expect(parseNames('# comentário\nexercise_type_A=Um = dois\n\n')).toEqual({ exercise_type_A: 'Um = dois' })
    expect(currentCatalog(exercises, parseNames(names))['SQUAT/STEP_UP']).toBe('Step')
    expect(diffCatalog({ 'A/B': null }, { 'A/B': null }, [])).toEqual({ added: [], removed: [], renamed: [] })
  })

  it('o retrato gerado pelo script cobre os ids referenciados pelo app', () => {
    expect(Object.keys(GARMIN_CATALOG_SNAPSHOT).length).toBeGreaterThan(1000)
    for (const id of GARMIN_CATALOG_REFERENCED) expect(GARMIN_CATALOG_SNAPSHOT).toHaveProperty([id])
  })
})
