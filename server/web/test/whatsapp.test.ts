import { describe, expect, it } from 'vitest'
import { formatBytes, whatsappUrl } from '../src/whatsapp'

describe('WhatsApp', () => {
  it('põe o 55 em celular brasileiro e codifica a mensagem', () => {
    expect(whatsappUrl('Oi, Marina!\nlink', '(31) 9 9999-0000')).toBe('https://wa.me/5531999990000?text=Oi%2C%20Marina!%0Alink')
    expect(whatsappUrl('Oi', '')).toBe('https://wa.me/?text=Oi')
    expect(whatsappUrl('Oi', '+1 415 555 0100')).toBe('https://wa.me/14155550100?text=Oi')
  })

  it('formata tamanhos', () => {
    expect(formatBytes(512)).toBe('512 B')
    expect(formatBytes(12_300)).toBe('12 KB')
    expect(formatBytes(2_516_582)).toBe('2,4 MB')
  })
})
