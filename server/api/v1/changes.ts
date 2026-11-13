import { sharedSql } from '../../src/db.js'
import { pullChangesRoute, pushChangesRoute } from '../../src/routes.js'

export function GET(request: Request): Promise<Response> {
  return pullChangesRoute(request, sharedSql())
}

export function POST(request: Request): Promise<Response> {
  return pushChangesRoute(request, sharedSql())
}
