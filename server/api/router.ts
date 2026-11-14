import { dispatch } from '../src/apiRouter.js'
import { sharedSql } from '../src/db.js'

export function GET(request: Request): Promise<Response> {
  return dispatch(request, sharedSql())
}

export function POST(request: Request): Promise<Response> {
  return dispatch(request, sharedSql())
}

export function PUT(request: Request): Promise<Response> {
  return dispatch(request, sharedSql())
}

export function PATCH(request: Request): Promise<Response> {
  return dispatch(request, sharedSql())
}

export function DELETE(request: Request): Promise<Response> {
  return dispatch(request, sharedSql())
}
