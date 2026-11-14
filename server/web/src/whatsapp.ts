import { BRAZIL_PREFIX, WHATSAPP_URL } from './constants'

export function whatsappUrl(message: string, phone: string): string {
  const digits = phone.replace(/\D/g, '')
  const international = phone.trim().startsWith('+')
  const number = !international && (digits.length === 10 || digits.length === 11) ? `${BRAZIL_PREFIX}${digits}` : digits
  return `${WHATSAPP_URL}${number}?text=${encodeURIComponent(message)}`
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) {
    return `${bytes} B`
  }
  if (bytes < 1024 * 1024) {
    return `${Math.round(bytes / 1024)} KB`
  }
  return `${(bytes / 1024 / 1024).toFixed(1).replace('.', ',')} MB`
}
