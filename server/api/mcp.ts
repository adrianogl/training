import { mcpRoute } from '../src/mcp/mcpRoute.js'
import { sharedSql } from '../src/db.js'

export function POST(request: Request): Promise<Response> {
  return mcpRoute(request, sharedSql())
}

export function GET(request: Request): Promise<Response> {
  return mcpRoute(request, sharedSql())
}
