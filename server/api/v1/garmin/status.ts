import { sharedSql } from '../../../src/db.js'
import { garminStatusRoute } from '../../../src/garminRoutes.js'

export function GET(request: Request): Promise<Response> {
  return garminStatusRoute(request, sharedSql())
}

export function DELETE(request: Request): Promise<Response> {
  return garminStatusRoute(request, sharedSql())
}
