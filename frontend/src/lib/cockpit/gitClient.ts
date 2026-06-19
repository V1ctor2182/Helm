// Git diff fetch + ext→Monaco-language mapping (pure, testable). The Monaco
// DiffEditor wiring lives in DiffView.svelte (GUI, manual-verify).

export interface GitDiff {
  repo_root: string
  rel_path: string
  head: string
  working: string
  status: string
}

export async function fetchDiff(path: string): Promise<GitDiff | null> {
  const res = await fetch(`/api/cockpit/git/diff?path=${encodeURIComponent(path)}`)
  if (!res.ok) return null
  return (await res.json()) as GitDiff
}

const LANG: Record<string, string> = {
  ts: 'typescript', tsx: 'typescript', js: 'javascript', mjs: 'javascript',
  jsx: 'javascript', json: 'json', md: 'markdown', html: 'html', svelte: 'html',
  css: 'css', scss: 'scss', py: 'python', rs: 'rust', go: 'go', java: 'java',
  c: 'c', cpp: 'cpp', h: 'cpp', sh: 'shell', yml: 'yaml', yaml: 'yaml',
  xml: 'xml', sql: 'sql', toml: 'ini',
}

export function langForExt(ext: string): string {
  return LANG[ext.toLowerCase()] ?? 'plaintext'
}
