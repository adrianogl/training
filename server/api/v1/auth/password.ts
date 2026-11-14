import { sharedSql } from '../../../src/db.js'
import { changePasswordRoute } from '../../../src/authRoutes.js'

export function POST(request: Request): Promise<Response> {
  return changePasswordRoute(request, sharedSql())
}
