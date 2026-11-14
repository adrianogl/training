import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  base: '/app/',
  plugins: [react()],
  build: { outDir: '../public/app', emptyOutDir: true },
  server: { proxy: { '/api': process.env.API_ORIGIN ?? 'http://localhost:3000' } },
})
