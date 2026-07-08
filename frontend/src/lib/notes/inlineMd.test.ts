import { describe, expect, it } from 'vitest'
import { htmlToMd, mdToHtml, renderInline } from './inlineMd'

// 轻格式(2026-07-08 用户拍板):粗体/斜体/高亮,md 兼容标记存储
describe('inlineMd', () => {
  it('mdToHtml 渲染三种标记 + 换行', () => {
    expect(mdToHtml('**粗**体 *斜* <mark>亮</mark>\n行2'))
      .toBe('<b>粗</b>体 <i>斜</i> <mark>亮</mark><br>行2')
  })

  it('mdToHtml 转义 HTML(防注入)', () => {
    expect(mdToHtml('<script>x</script>')).toBe('&lt;script&gt;x&lt;/script&gt;')
    expect(renderInline('a<b')).toBe('a&lt;b')
  })

  it('htmlToMd 序列化 b/i/mark 与换行', () => {
    const el = document.createElement('div')
    el.innerHTML = '<b>粗</b>体 <i>斜</i> <mark>亮</mark><br>行2'
    expect(htmlToMd(el)).toBe('**粗**体 *斜* <mark>亮</mark>\n行2')
  })

  it('htmlToMd:execCommand 的背景 span 也算高亮,div 归一成行', () => {
    const el = document.createElement('div')
    el.innerHTML = '<div>行1 <span style="background-color: rgb(255,243,191)">亮</span></div><div><strong>粗</strong></div>'
    expect(htmlToMd(el)).toBe('行1 <mark>亮</mark>\n**粗**')
  })

  it('roundtrip:md → html → md 不漂移', () => {
    const md = '**粗**体和*斜体*,<mark>重点</mark>\n第二行'
    const el = document.createElement('div')
    el.innerHTML = mdToHtml(md)
    expect(htmlToMd(el)).toBe(md)
  })
})
