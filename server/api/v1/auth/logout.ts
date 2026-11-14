import { sharedSql } from '../../../src/db.js'
import { logoutRoute } from '../../../src/authRoutes.js'

export function POST(request: Request): Promise<Response> {
  return logoutRoute(request, sharedSql())
}
