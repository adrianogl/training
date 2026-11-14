import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto'
import { CIPHER_ALGORITHM, CIPHER_IV_BYTES, CIPHER_VERSION, DATA_KEY_BYTES } from './constants.js'

export function dataKeyFromEnv(env: Record<string, string | undefined>): Buffer | undefined {
  const value = env.DATA_KEY
  if (value === undefined || value === '') {
    return undefined
  }
  const key = Buffer.from(value, 'base64url')
  return key.length === DATA_KEY_BYTES ? key : undefined
}

export function seal(key: Buffer, plaintext: string, context: string): string {
  const iv = randomBytes(CIPHER_IV_BYTES)
  const cipher = createCipheriv(CIPHER_ALGORITHM, key, iv)
  cipher.setAAD(Buffer.from(context))
  const body = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()])
  return [CIPHER_VERSION, iv.toString('base64url'), body.toString('base64url'), cipher.getAuthTag().toString('base64url')].join('.')
}

export function open(key: Buffer, sealed: string, context: string): string | undefined {
  const [version, iv, body, tag] = sealed.split('.')
  if (version !== CIPHER_VERSION || iv === undefined || body === undefined || tag === undefined) {
    return undefined
  }
  try {
    const decipher = createDecipheriv(CIPHER_ALGORITHM, key, Buffer.from(iv, 'base64url'))
    decipher.setAAD(Buffer.from(context))
    decipher.setAuthTag(Buffer.from(tag, 'base64url'))
    return Buffer.concat([decipher.update(Buffer.from(body, 'base64url')), decipher.final()]).toString('utf8')
  } catch {
    return undefined
  }
}
