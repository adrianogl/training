import { sharedSql } from '../../../src/db.js'
import { loginRoute } from '../../../src/authRoutes.js'

export function POST(request: Request): Promise<Response> {
  return loginRoute(request, sharedSql())
}
