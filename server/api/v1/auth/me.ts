import { sharedSql } from '../../../src/db.js'
import { meRoute } from '../../../src/authRoutes.js'

export function GET(request: Request): Promise<Response> {
  return meRoute(request, sharedSql())
}

export function PATCH(request: Request): Promise<Response> {
  return meRoute(request, sharedSql())
}
