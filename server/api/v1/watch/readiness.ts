import { sharedSql } from '../../../src/db.js'
import { getWatchReadinessRoute, putWatchReadinessRoute } from '../../../src/routes.js'

export function GET(request: Request): Promise<Response> {
  return getWatchReadinessRoute(request, sharedSql())
}

export function PUT(request: Request): Promise<Response> {
  return putWatchReadinessRoute(request, sharedSql())
}
