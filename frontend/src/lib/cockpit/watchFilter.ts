// 变更噪声过滤(承 FanBox app:3183-3192,原样移植):
// 高亮/收件箱/跟随共用一套判断——隐藏文件/构建依赖目录/sqlite sidecar/
// 中段 .tmp 原子写临时名都算噪声。纯函数可测。

const CHANGE_IGNORE = new Set([
  '.git', 'node_modules', '.next', 'dist', 'build', '.cache', '.venv', 'venv',
  '__pycache__', '.DS_Store', 'target', '.turbo', '.expo', 'Library', 'Caches',
  '.Trash', 'CloudStorage', '.cocoapods', 'DerivedData',
])

export function isNoisyChange(relPath: string): boolean {
  const segs = String(relPath).split('/')
  // 隐藏文件/目录一律算噪声:agent 写 .git、各种 .config 时用户什么都没得看
  if (segs.some((s) => CHANGE_IGNORE.has(s) || s.startsWith('.'))) return true
  const name = segs[segs.length - 1]
  return (
    !name ||
    name.endsWith('~') ||
    name.endsWith('.swp') ||
    // .tmp 可能在中段:原子写 foo.swift.tmp.<pid>.<hex>;sqlite 的 -journal/-shm/-wal sidecar
    /\.(tmp|part|crdownload|lock)(\.|$)|-(journal|shm|wal)$/i.test(name)
  )
}
