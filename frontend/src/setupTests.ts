import '@testing-library/jest-dom/vitest'

// xterm 需要 matchMedia/ResizeObserver;jsdom 没有 → 挂 CockpitView(dock 含终端)的测试要用
if (typeof window !== 'undefined') {
  if (!window.matchMedia) {
    window.matchMedia = (q: string) =>
      ({ matches: false, media: q, addEventListener() {}, removeEventListener() {}, addListener() {}, removeListener() {}, onchange: null, dispatchEvent: () => false }) as MediaQueryList
  }
  if (!window.ResizeObserver) {
    window.ResizeObserver = class { observe() {} unobserve() {} disconnect() {} } as unknown as typeof ResizeObserver
  }
}
