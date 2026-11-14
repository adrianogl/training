import { randomBytes, scrypt, timingSafeEqual } from 'node:crypto'
import {
  PASSWORD_HASH_PREFIX,
  SCRYPT_BLOCK_SIZE,
  SCRYPT_COST,
  SCRYPT_KEY_LENGTH,
  SCRYPT_MAX_MEMORY,
  SCRYPT_PARALLELISM,
  SCRYPT_SALT_BYTES,
} from './constants.js'

function derive(password: string, salt: Buffer, cost: number, blockSize: number, parallelism: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    scrypt(
      password.normalize('NFC'),
      salt,
      SCRYPT_KEY_LENGTH,
      { N: cost, r: blockSize, p: parallelism, maxmem: SCRYPT_MAX_MEMORY },
      (error, key) => (error === null ? resolve(key) : reject(error)),
    )
  })
}

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(SCRYPT_SALT_BYTES)
  const key = await derive(password, salt, SCRYPT_COST, SCRYPT_BLOCK_SIZE, SCRYPT_PARALLELISM)
  return [PASSWORD_HASH_PREFIX, SCRYPT_COST, SCRYPT_BLOCK_SIZE, SCRYPT_PARALLELISM, salt.toString('base64url'), key.toString('base64url')].join('$')
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [prefix, cost, blockSize, parallelism, salt, key] = stored.split('$')
  if (prefix !== PASSWORD_HASH_PREFIX || salt === undefined || key === undefined) {
    return false
  }
  const expected = Buffer.from(key, 'base64url')
  const actual = await derive(password, Buffer.from(salt, 'base64url'), Number(cost), Number(blockSize), Number(parallelism))
  return actual.length === expected.length && timingSafeEqual(actual, expected)
}
