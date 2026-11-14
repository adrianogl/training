import { ERRORS } from './constants'

export function errorText(code: string): string {
  return ERRORS[code] ?? ERRORS.unknown ?? ''
}
