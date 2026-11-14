import { sharedSql } from '../../../src/db.js'
import { signupRoute } from '../../../src/authRoutes.js'

export function POST(request: Request): Promise<Response> {
  return signupRoute(request, sharedSql())
}
