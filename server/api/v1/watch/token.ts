import { sharedSql } from '../../../src/db.js'
import { deleteWatchTokenRoute, putWatchTokenRoute } from '../../../src/routes.js'

export function PUT(request: Request): Promise<Response> {
  return putWatchTokenRoute(request, sharedSql())
}

export function DELETE(request: Request): Promise<Response> {
  return deleteWatchTokenRoute(request, sharedSql())
}
