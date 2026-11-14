import { sharedSql } from '../../../src/db.js'
import { resendVerificationRoute } from '../../../src/authRoutes.js'

export function POST(request: Request): Promise<Response> {
  return resendVerificationRoute(request, sharedSql())
}
