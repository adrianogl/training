import type { GarminErrorCode } from './types.js'

export class GarminError extends Error {
  readonly code: GarminErrorCode

  constructor(code: GarminErrorCode) {
    super(code)
    this.code = code
  }
}
