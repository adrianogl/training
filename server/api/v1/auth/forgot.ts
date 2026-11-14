import { sharedSql } from '../../../src/db.js'
import { forgotPasswordRoute } from '../../../src/authRoutes.js'

export function POST(request: Request): Promise<Response> {
  return forgotPasswordRoute(request, sharedSql())
}
