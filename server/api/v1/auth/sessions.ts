import { sharedSql } from '../../../src/db.js'
import { sessionsRoute } from '../../../src/authRoutes.js'

export function GET(request: Request): Promise<Response> {
  return sessionsRoute(request, sharedSql())
}

export function DELETE(request: Request): Promise<Response> {
  return sessionsRoute(request, sharedSql())
}
