import { createHash } from 'node:crypto'

export function clientIpHash(headers: Headers): string {
  const forwarded = headers.get('x-forwarded-for')?.split(',')[0]?.trim()
  const ip = forwarded || headers.get('x-real-ip')?.trim() || 'unknown'
  return createHash('sha256').update(ip).digest('hex')
}
