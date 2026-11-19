import { garminCatalogCron, garminCatalogEnvFromProcess } from '../../src/garminCatalog.js'

export function GET(request: Request): Promise<Response> {
  return garminCatalogCron(request, garminCatalogEnvFromProcess())
}
