import { adminRoute } from '../src/admin.js'
import { sharedSql } from '../src/db.js'

export function GET(request: Request): Promise<Response> {
  return adminRoute(request, sharedSql(), process.env.ADMIN_TOKEN)
}

export function POST(request: Request): Promise<Response> {
  return adminRoute(request, sharedSql(), process.env.ADMIN_TOKEN)
}
