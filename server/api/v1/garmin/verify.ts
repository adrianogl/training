import { sharedSql } from '../../../src/db.js'
import { garminVerifyRoute } from '../../../src/garminRoutes.js'

export function POST(request: Request): Promise<Response> {
  return garminVerifyRoute(request, sharedSql())
}
