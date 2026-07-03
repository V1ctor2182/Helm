// Map a file extension to how it previews. Drives PreviewPane.

export type PreviewKind = 'markdown' | 'code' | 'image' | 'pdf' | 'zip' | 'html' | 'none'

const CODE = new Set([
  'js', 'mjs', 'cjs', 'ts', 'tsx', 'jsx', 'json', 'html', 'css', 'scss',
  'svelte', 'vue', 'py', 'rs', 'go', 'rb', 'java', 'c', 'cpp', 'h', 'sh',
  'yml', 'yaml', 'toml', 'xml', 'sql', 'txt', 'ini', 'env', 'log',
])
const IMAGE = new Set(['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'heic', 'bmp'])

export function previewKind(ext: string): PreviewKind {
  if (ext === 'html' || ext === 'htm') return 'html'
  if (ext === 'md' || ext === 'markdown') return 'markdown'
  if (ext === 'pdf') return 'pdf'
  if (ext === 'zip') return 'zip'
  if (IMAGE.has(ext)) return 'image'
  if (CODE.has(ext)) return 'code'
  return 'none'
}

/** 隔离预览源(独立 origin,承 FanBox):/fs/<绝对路径>,相对资源自然解析。 */
export function previewOriginUrl(path: string, v: number | string = 0): string {
  return `http://127.0.0.1:8770/fs${path}?v=${v}`
}

export function rawUrl(path: string): string {
  return `/api/cockpit/raw?path=${encodeURIComponent(path)}`
}
