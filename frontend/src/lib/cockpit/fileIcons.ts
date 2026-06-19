// Strong-color entity icons (ported from FanBox): each file type "looks like
// itself". Framework-agnostic so it's reused by cards/list/preview alike.

export interface IconSpec {
  glyph: string
  color: string
}

const FOLDER: IconSpec = { glyph: '📁', color: '#8a8f98' }
const GENERIC: IconSpec = { glyph: '📄', color: '#8a8f98' }

const BY_EXT: Record<string, IconSpec> = {
  pdf: { glyph: 'PDF', color: '#e5484d' },
  js: { glyph: 'JS', color: '#f5d90a' },
  mjs: { glyph: 'JS', color: '#f5d90a' },
  ts: { glyph: 'TS', color: '#3178c6' },
  tsx: { glyph: 'TSX', color: '#3178c6' },
  jsx: { glyph: 'JSX', color: '#f5d90a' },
  json: { glyph: '{}', color: '#c97b1f' },
  md: { glyph: 'MD', color: '#4250ff' },
  html: { glyph: '<>', color: '#e8590c' },
  css: { glyph: 'CSS', color: '#1c7ed6' },
  svelte: { glyph: 'SV', color: '#ff3e00' },
  py: { glyph: 'PY', color: '#3572a5' },
  rs: { glyph: 'RS', color: '#dea584' },
  go: { glyph: 'GO', color: '#00add8' },
  png: { glyph: '🖼', color: '#37b24d' },
  jpg: { glyph: '🖼', color: '#37b24d' },
  jpeg: { glyph: '🖼', color: '#37b24d' },
  gif: { glyph: '🖼', color: '#37b24d' },
  webp: { glyph: '🖼', color: '#37b24d' },
  heic: { glyph: '🖼', color: '#37b24d' },
  svg: { glyph: '🖼', color: '#37b24d' },
  mp4: { glyph: '🎞', color: '#7048e8' },
  mov: { glyph: '🎞', color: '#7048e8' },
  zip: { glyph: '🗜', color: '#f08c00' },
  tar: { glyph: '🗜', color: '#f08c00' },
  gz: { glyph: '🗜', color: '#f08c00' },
}

export function iconFor(entry: { is_dir: boolean; ext: string }): IconSpec {
  if (entry.is_dir) return FOLDER
  return BY_EXT[entry.ext] ?? GENERIC
}
