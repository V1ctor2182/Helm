// 后端时间戳是 UTC:SQLite isoformat 出裸 ISO(无时区标记),tz-aware 字段带
// +00:00/Z。显示一律转本地钟;裸 ISO 补 Z 再解析,避免被 Date 当成本地时间。

export function toLocal(iso: string): Date {
  return new Date(/(Z|[+-]\d{2}:?\d{2})$/.test(iso) ? iso : iso + 'Z')
}

const pad2 = (n: number) => String(n).padStart(2, '0')

/** 本地 HH:MM;空值返回 ''。 */
export function localHHMM(iso: string | null): string {
  if (!iso) return ''
  const d = toLocal(iso)
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`
}

/** 本地 YYYY-MM-DD;空值返回 ''。 */
export function localDate(iso: string | null): string {
  if (!iso) return ''
  const d = toLocal(iso)
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
}

/** 本地 YYYY-MM-DD HH:MM;空值返回 '—'。 */
export function localDateTime(iso: string | null): string {
  if (!iso) return '—'
  return `${localDate(iso)} ${localHHMM(iso)}`
}
