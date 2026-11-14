import { describe, expect, it } from 'vitest'
import { resolve } from '../src/App'
import { hrefFor, routeFromPath } from '../src/router'

describe('rotas', () => {
  it('lê o caminho com e sem barra no fim', () => {
    expect(routeFromPath('/app/hoje')).toBe('today')
    expect(routeFromPath('/app/ajustes/senha/')).toBe('password')
    expect(routeFromPath('/app')).toBeUndefined()
    expect(hrefFor('reset')).toBe('/app/redefinir-senha')
  })

  it('manda para o login quem não entrou e para o Hoje quem já entrou', () => {
    expect(resolve('today', false)).toBe('login')
    expect(resolve(undefined, false)).toBe('login')
    expect(resolve(undefined, true)).toBe('today')
    expect(resolve('login', true)).toBe('today')
    expect(resolve('settings', true)).toBe('settings')
  })

  it('links dos e-mails abrem com ou sem sessão', () => {
    expect(resolve('reset', false)).toBe('reset')
    expect(resolve('confirm', true)).toBe('confirm')
    expect(resolve('forgot', true)).toBe('forgot')
  })
})

describe('convites e administração', () => {
  it('o link do convite abre sem sessão e leva ao Hoje com sessão', () => {
    expect(routeFromPath('/app/convite')).toBe('invite')
    expect(resolve('invite', false)).toBe('invite')
    expect(resolve('invite', true)).toBe('today')
    expect(resolve('admin', false)).toBe('login')
  })
})
