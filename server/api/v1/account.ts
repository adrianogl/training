import { sharedSql } from '../../src/db.js'
import { createAccountRoute, deleteAccountRoute } from '../../src/routes.js'

export function POST(request: Request): Promise<Response> {
  return createAccountRoute(request, sharedSql())
}

export function DELETE(request: Request): Promise<Response> {
  return deleteAccountRoute(request, sharedSql())
}
