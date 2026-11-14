import { sharedSql } from '../../../src/db.js'
import { verifyEmailRoute } from '../../../src/authRoutes.js'

export function POST(request: Request): Promise<Response> {
  return verifyEmailRoute(request, sharedSql())
}
