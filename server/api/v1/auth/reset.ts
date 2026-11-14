import { sharedSql } from '../../../src/db.js'
import { resetPasswordRoute } from '../../../src/authRoutes.js'

export function POST(request: Request): Promise<Response> {
  return resetPasswordRoute(request, sharedSql())
}
