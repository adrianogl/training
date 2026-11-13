import { configDefaults, defineConfig } from 'vitest/config'

const postgresImage = process.env.SYNC_TEST_POSTGRES_IMAGE

export default defineConfig({
  test: {
    include: postgresImage === undefined ? ['test/**/*.test.ts'] : ['test/**/*.pg.test.ts'],
    exclude: postgresImage === undefined ? [...configDefaults.exclude, 'test/**/*.pg.test.ts'] : configDefaults.exclude,
    testTimeout: 60_000,
    hookTimeout: 60_000,
  },
})
