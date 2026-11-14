import { sharedSql } from '../../../src/db.js'
import { garminConnectRoute } from '../../../src/garminRoutes.js'

export function POST(request: Request): Promise<Response> {
  return garminConnectRoute(request, sharedSql())
}
