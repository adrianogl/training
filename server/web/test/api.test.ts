import { afterEach, describe, expect, it, vi } from 'vitest'
import { api } from '../src/api'
import { clearToken, readToken, saveToken } from '../src/session'

afterEach(() => {
  clearToken()
  vi.unstubAllGlobals()
})

describe('api', () => {
  it('manda o token salvo e devolve o código de erro do servidor', async () => {
    saveToken('sessao', true)
    const fetchMock = vi.fn(async () => new Response(JSON.stringify({ error: 'invalid_credentials' }), { status: 401 }))
    vi.stubGlobal('fetch', fetchMock)

    const result = await api.changePassword('a', 'b', true)

    const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit]
    expect(url).toBe('/api/v1/auth/password')
    expect((init.headers as Record<string, string>).authorization).toBe('Bearer sessao')
    expect(result).toEqual({ ok: false, error: 'invalid_credentials', status: 401 })
  })

  it('204 vira sucesso sem corpo e falha de rede vira network', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(null, { status: 204 })))
    expect(await api.logout()).toEqual({ ok: true, value: undefined })

    vi.stubGlobal('fetch', vi.fn(async () => Promise.reject(new TypeError('offline'))))
    expect(await api.logout()).toEqual({ ok: false, error: 'network', status: 0 })
  })

  it('sessão sem manter conectado fica só na aba', () => {
    saveToken('aba', false)

    expect(window.localStorage.getItem('training.session')).toBeNull()
    expect(readToken()).toBe('aba')
  })
})
