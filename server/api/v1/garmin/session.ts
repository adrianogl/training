import { sharedSql } from '../../../src/db.js'
import { garminSessionRoute } from '../../../src/garminRoutes.js'

export function GET(request: Request): Promise<Response> {
  return garminSessionRoute(request, sharedSql())
}
