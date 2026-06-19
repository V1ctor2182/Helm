/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import { svelteTesting } from '@testing-library/svelte/vite'

// In prod the built app is served by the FastAPI backend; in dev we run Vite's
// HMR server and proxy backend calls to it so the Vite origin can hit the API.
const BACKEND = 'http://127.0.0.1:8769'

export default defineConfig({
  plugins: [svelte(), svelteTesting()],
  server: {
    proxy: {
      '/api': BACKEND,
      '/healthz': BACKEND,
    },
  },
  build: { outDir: 'dist', emptyOutDir: true },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/setupTests.ts'],
  },
})
