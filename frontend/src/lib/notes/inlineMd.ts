// 轻格式(2026-07-08 用户拍板):用户不会手写 markdown——编辑器是所见即所得
// (contenteditable + 粗体/斜体/高亮三钮),存储仍是 md 兼容标记(**粗体**/
// *斜体*/<mark>高亮</mark>),这样日记的 marked 渲染、notch、AI 管线吃到的
// content 都保持纯文本可读。本模块是两个方向的转换 + 卡片轻渲染。

/** 存储 md → 编辑器/卡片 HTML(先转义,再只放行我们自己的三种标记)。 */
export function mdToHtml(src: string): string {
  const esc = (src ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
  return esc
    .replace(/&lt;mark&gt;([\s\S]*?)&lt;\/mark&gt;/g, '<mark>$1</mark>')
    .replace(/\*\*([^*\n][^*\n]*?)\*\*/g, '<b>$1</b>')
    .replace(/(^|[^*])\*([^*\n]+)\*(?!\*)/g, '$1<i>$2</i>')
    .replace(/\n/g, '<br>')
}

/** 卡片/详情原文轻渲染 = 同一转换(输出只含 b/i/mark/br,来源已转义,安全)。 */
export const renderInline = mdToHtml

/** 编辑器 DOM → 存储 md。只认 b/i/mark(execCommand 的 span 背景也算高亮),
 *  div/p/br 归一成换行,其它标签剥壳留文本。 */
export function htmlToMd(root: Node): string {
  let out = ''
  const walk = (nodes: NodeListOf<ChildNode>): void => {
    for (const node of nodes) {
      if (node.nodeType === Node.TEXT_NODE) {
        out += node.textContent ?? ''
        continue
      }
      if (!(node instanceof HTMLElement)) continue
      const tag = node.tagName
      if (tag === 'BR') {
        out += '\n'
        continue
      }
      if (tag === 'DIV' || tag === 'P') {
        if (out && !out.endsWith('\n')) out += '\n'
        walk(node.childNodes)
        continue
      }
      const inner = htmlToMd(node)
      const bg = node.style?.backgroundColor
      if (tag === 'B' || tag === 'STRONG') out += inner ? `**${inner}**` : ''
      else if (tag === 'I' || tag === 'EM') out += inner ? `*${inner}*` : ''
      else if (tag === 'MARK' || (tag === 'SPAN' && bg)) out += inner ? `<mark>${inner}</mark>` : ''
      else out += inner
    }
  }
  walk(root.childNodes as NodeListOf<ChildNode>)
  return out
}
