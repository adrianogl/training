export type StravaErrorCode = 'rate_limited' | 'unauthorized' | 'unavailable'

export class StravaError extends Error {
  readonly code: StravaErrorCode

  constructor(code: StravaErrorCode) {
    super(code)
    this.code = code
  }
}
