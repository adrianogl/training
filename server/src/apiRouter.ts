import {
  changePasswordRoute,
  forgotPasswordRoute,
  loginRoute,
  logoutRoute,
  meRoute,
  resendVerificationRoute,
  resetPasswordRoute,
  sessionsRoute,
  signupRoute,
  verifyEmailRoute,
} from './authRoutes.js'
import { API_PATH_PREFIX, API_ROUTER_QUERY } from './constants.js'
import type { Sql } from './db.js'
import { garminConnectRoute, garminSessionRoute, garminStatusRoute, garminVerifyRoute } from './garminRoutes.js'
import {
  createAccountRoute,
  deleteAccountRoute,
  deleteWatchTokenRoute,
  getWatchReadinessRoute,
  pullChangesRoute,
  pushChangesRoute,
  putWatchReadinessRoute,
  putWatchTokenRoute,
} from './routes.js'

type Handler = (request: Request, sql: Sql) => Promise<Response>

const ROUTES: Record<string, Partial<Record<string, Handler>>> = {
  account: { POST: (request, sql) => createAccountRoute(request, sql), DELETE: deleteAccountRoute },
  changes: { GET: pullChangesRoute, POST: (request, sql) => pushChangesRoute(request, sql) },
  'watch/token': { PUT: putWatchTokenRoute, DELETE: deleteWatchTokenRoute },
  'watch/readiness': { GET: getWatchReadinessRoute, PUT: putWatchReadinessRoute },
  'auth/signup': { POST: (request, sql) => signupRoute(request, sql) },
  'auth/login': { POST: (request, sql) => loginRoute(request, sql) },
  'auth/logout': { POST: (request, sql) => logoutRoute(request, sql) },
  'auth/me': { GET: (request, sql) => meRoute(request, sql), PATCH: (request, sql) => meRoute(request, sql) },
  'auth/password': { POST: (request, sql) => changePasswordRoute(request, sql) },
  'auth/forgot': { POST: (request, sql) => forgotPasswordRoute(request, sql) },
  'auth/reset': { POST: (request, sql) => resetPasswordRoute(request, sql) },
  'auth/verify': { POST: (request, sql) => verifyEmailRoute(request, sql) },
  'auth/resend-verification': { POST: (request, sql) => resendVerificationRoute(request, sql) },
  'auth/sessions': { GET: (request, sql) => sessionsRoute(request, sql), DELETE: (request, sql) => sessionsRoute(request, sql) },
  'garmin/connect': { POST: (request, sql) => garminConnectRoute(request, sql) },
  'garmin/verify': { POST: (request, sql) => garminVerifyRoute(request, sql) },
  'garmin/status': { GET: (request, sql) => garminStatusRoute(request, sql), DELETE: (request, sql) => garminStatusRoute(request, sql) },
  'garmin/session': { GET: (request, sql) => garminSessionRoute(request, sql) },
}

export function routeKey(request: Request): string {
  const url = new URL(request.url)
  const fromQuery = url.searchParams.get(API_ROUTER_QUERY)
  const path = fromQuery ?? (url.pathname.startsWith(API_PATH_PREFIX) ? url.pathname.slice(API_PATH_PREFIX.length) : '')
  return path.replace(/^\/+|\/+$/g, '')
}

export function dispatch(request: Request, sql: Sql): Promise<Response> {
  const routes = ROUTES[routeKey(request)]
  if (routes === undefined) {
    return Promise.resolve(Response.json({ error: 'not_found' }, { status: 404 }))
  }
  const handler = routes[request.method]
  if (handler === undefined) {
    return Promise.resolve(
      Response.json({ error: 'method_not_allowed' }, { status: 405, headers: { allow: Object.keys(routes).join(', ') } }),
    )
  }
  return handler(request, sql)
}
