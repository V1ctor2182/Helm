<script lang="ts">
  // 记录详情(K2 重排,稿:helm-journal-kinds.html):原文主角,AI 注脚化。
  // 层级:原文大字(链接内联高亮) → 提到的内容附件卡 → 标签+线索胶囊 →
  // AI 注脚(hover 展开) → 操作(AI 读出时间线索时主钮=「→任务 · 线索」)。
  import type { Note } from './notesStore.svelte'
  import { renderInline } from './inlineMd'
  import { localDateTime } from '../time'

  let {
    note,
    onclose,
    onedit,
    totask,
    ondelete,
  }: {
    note: Note
    onclose: () => void
    onedit?: (n: Note) => void
    totask?: (n: Note) => void
    ondelete?: (n: Note) => void
  } = $props()

  // 删除两击确认(用户反馈:速记要有删除入口——详情页统一给)
  let delArmed = $state(false)

  const KIND_ZH: Record<string, string> = {
    note: '速记', journal: '日记', task: '待办', focus: '专注', idea: '想法',
  }
  const TYPE_ZH: Record<string, string> = {
    youtube: '视频', paper: '论文', article: '网页', inspiration: '灵感', text: '速记',
  }
  const TYPE_BADGE: Record<string, [string, string]> = {
    youtube: ['YT', '#ff2d2d'], paper: ['AX', '#8b5a2b'],
    inspiration: ['AW', '#0a84ff'], article: ['WEB', '#0a84ff'],
  }

  // 原文按 URL 切分,链接内联高亮(短显示)
  const URL_RE = /(https?:\/\/[^\s<>"')\]]+)/g
  const parts = $derived(note.content.split(URL_RE))
  const isUrl = (p: string) => /^https?:\/\//.test(p)
  const shortUrl = (u: string) => u.replace(/^https?:\/\//, '').replace(/\/$/, '').slice(0, 42)

  // 附件卡:当前后端为单链接 meta(K3 扩多链接后此处自动接 meta.links)
  const attachments = $derived(
    note.meta?.links?.length
      ? note.meta.links.map((l) => ({
          url: l.url,
          title: l.title ?? l.url,
          summary: l.summary,
          site: l.site,
          type: l.type ?? 'article',
          image: l.image,
        }))
      : note.meta?.url
        ? [{
            url: note.meta.url,
            title: note.meta.title ?? note.meta.url,
            summary: note.meta.summary,
            site: note.meta.site,
            type: note.meta.type ?? 'article',
            image: note.meta.image,
          }]
        : [],
  )
  // 链接即全部内容(纯收藏)→ hero 大图态;否则原文主场
  const heroMode = $derived(
    attachments.length === 1 && !!note.meta?.image && note.content.replace(URL_RE, '').trim().length <= 24,
  )

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onclose()
  }
</script>

<svelte:window {onkeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
<div class="scrim" role="presentation" onclick={onclose}>
  <div class="sheet" role="dialog" aria-label="记录详情" tabindex="-1" onclick={(e) => e.stopPropagation()}>
    <header class="dh">
      <!-- F1:优先 label(精确规范类别),否则老 type 中文,再否则 kind -->
      <span class="kind">{note.meta?.label ?? TYPE_ZH[note.meta?.type ?? ''] ?? KIND_ZH[note.kind] ?? note.kind}</span>
      <span class="when">{note.created_at ? localDateTime(note.created_at) : ''}</span>
      <button class="x" aria-label="关闭" onclick={onclose}>×</button>
    </header>

    {#if heroMode && note.meta?.image}
      <img class="hero" src={note.meta.image} alt=""
        onerror={(e) => ((e.currentTarget as HTMLImageElement).style.display = 'none')} />
    {/if}

    <div class="body">
      {#if heroMode}
        <h2 class="ti">{note.meta?.title}</h2>
        {#if note.meta?.summary}<p class="herosum">{note.meta.summary}</p>{/if}
      {:else}
        <!-- 原文主角:大字排版,链接内联高亮 -->
        <p class="prose">
          {#each parts as p, i (i)}
            <!-- 轻格式渲染(粗体/斜体/高亮,renderInline 先转义,安全) -->
            {#if isUrl(p)}<a class="inlink" href={p} target="_blank" rel="noreferrer">{shortUrl(p)}</a>{:else}{@html renderInline(p)}{/if}
          {/each}
        </p>
        {#if attachments.length > 0}
          <div class="attachh">提到的内容 · {attachments.length}</div>
          {#each attachments as a (a.url)}
            <a class="attach" href={a.url} target="_blank" rel="noreferrer">
              <span class="ab" style="background:{TYPE_BADGE[a.type]?.[1] ?? '#0a84ff'}">{TYPE_BADGE[a.type]?.[0] ?? 'WEB'}</span>
              <span class="amid">
                <span class="at">{a.title}</span>
                {#if a.summary}<span class="as">{a.summary}</span>{/if}
                <span class="asrc">{a.site ?? shortUrl(a.url)} · 已解析</span>
              </span>
              <span class="go">打开</span>
            </a>
          {/each}
        {/if}
      {/if}

      {#if (note.meta?.tags?.length ?? 0) > 0 || note.meta?.when || note.meta?.where}
        <div class="tagrow">
          {#each note.meta?.tags ?? [] as t (t)}<span class="tg">#{t}</span>{/each}
          {#if note.meta?.when}<span class="clue">时间线索 · {note.meta.when}</span>{/if}
          {#if note.meta?.where}<span class="clue">地点线索 · {note.meta.where}</span>{/if}
        </div>
      {/if}

      <div class="ainote">
        <span class="spark" aria-hidden="true"></span>
        AI · 自动归类为{TYPE_ZH[note.meta?.type ?? ''] ?? KIND_ZH[note.kind] ?? note.kind}
        <span class="full">
          · {attachments.length ? `解析出 ${attachments.length} 个链接` : '未发现链接'}
          {note.meta?.when ? ` · 读出时间线索「${note.meta.when}」` : ''}
        </span>
      </div>
    </div>

    <footer class="acts">
      {#if totask && note.kind !== 'journal' && note.meta?.when}
        <button class="pri" onclick={() => { totask?.(note); onclose() }}>→任务 · {note.meta.when}</button>
      {:else if heroMode && note.meta?.url}
        <a class="pri" href={note.meta.url} target="_blank" rel="noreferrer">打开原链接</a>
      {/if}
      {#if onedit}<button onclick={() => { onedit?.(note); onclose() }}>编辑</button>{/if}
      {#if totask && note.kind !== 'journal' && !note.meta?.when}<button onclick={() => { totask?.(note); onclose() }}>→任务</button>{/if}
      {#if ondelete}
        <button class="danger" class:armed={delArmed}
          onclick={() => { if (delArmed) { ondelete?.(note); onclose() } else delArmed = true }}>
          {delArmed ? '确认删除' : '删除'}
        </button>
      {/if}
      <button onclick={onclose}>关闭</button>
    </footer>
  </div>
</div>

<style>
  .prose :global(mark) {
    background: #fff3bf;
    border-radius: 3px;
    padding: 0 2px;
  }
  .scrim {
    position: fixed;
    inset: 0;
    background: color-mix(in srgb, var(--t1) 26%, transparent);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 90;
    padding: 32px;
  }
  .sheet {
    width: min(580px, 92vw);
    max-height: 84vh;
    overflow-y: auto;
    background: var(--card);
    border-radius: 20px;
    box-shadow: var(--shadow-lg);
    display: flex;
    flex-direction: column;
  }
  .dh {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 14px 18px 10px;
  }
  .kind {
    font: 600 11px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border-radius: var(--radius-pill);
    padding: 5px 11px;
  }
  .when {
    font: 400 11px/1 var(--sans);
    color: var(--t4);
  }
  .x {
    margin-left: auto;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    border: 0;
    background: var(--pill);
    color: var(--t3);
    font-size: 15px;
    cursor: pointer;
  }
  .x:hover { color: var(--t1); }
  .hero {
    width: 100%;
    max-height: 240px;
    object-fit: cover;
  }
  .body {
    padding: 14px 20px 6px;
  }
  .ti {
    font: 700 18px/1.35 var(--sans);
    color: var(--t1);
    margin: 0 0 8px;
  }
  .herosum {
    font: 400 13.5px/1.65 var(--sans);
    color: var(--t3);
    margin: 0;
  }
  /* 原文主角 */
  .prose {
    font: 400 17px/1.85 var(--sans);
    color: var(--t1);
    white-space: pre-wrap;
    word-break: break-word;
    margin: 0;
  }
  .inlink {
    color: var(--g2);
    text-decoration: none;
    border-bottom: 1px solid color-mix(in srgb, var(--g2) 40%, transparent);
  }
  .inlink:hover {
    border-bottom-color: var(--g2);
  }
  /* 附件卡 */
  .attachh {
    font: 600 11px/1 var(--sans);
    color: var(--t4);
    letter-spacing: 0.4px;
    margin: 18px 0 8px;
  }
  .attach {
    display: flex;
    gap: 11px;
    align-items: flex-start;
    background: var(--bg);
    border-radius: 14px;
    padding: 11px 13px;
    margin-bottom: 8px;
    text-decoration: none;
    transition: background var(--dur-micro) var(--ease);
  }
  .attach:hover {
    background: var(--pill);
  }
  .ab {
    flex: none;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 24px;
    height: 24px;
    padding: 0 5px;
    border-radius: 7px;
    color: #fff;
    font: 800 9.5px/1 var(--sans);
    margin-top: 2px;
  }
  .amid {
    min-width: 0;
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .at {
    font: 600 13px/1.4 var(--sans);
    color: var(--t1);
  }
  .as {
    font: 400 11.5px/1.5 var(--sans);
    color: var(--t4);
    display: -webkit-box;
    -webkit-line-clamp: 1;
    line-clamp: 1;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .asrc {
    font: 400 10px/1 var(--sans);
    color: var(--t4);
    margin-top: 2px;
  }
  .go {
    margin-left: auto;
    flex: none;
    font: 500 10.5px/1 var(--sans);
    color: var(--t3);
    background: var(--card);
    border-radius: var(--radius-pill);
    padding: 6px 11px;
  }
  /* 标签+线索 */
  .tagrow {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 14px;
    font: 400 11.5px/1 var(--sans);
    align-items: center;
  }
  .tg { color: var(--cyan); }
  .clue {
    color: var(--t3);
    background: var(--pill);
    border-radius: var(--radius-pill);
    padding: 5px 11px;
  }
  /* AI 注脚 */
  .ainote {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-top: 16px;
    font: 400 10.5px/1.5 var(--sans);
    color: var(--t4);
  }
  .spark {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    flex: none;
    background: conic-gradient(from 210deg, var(--g1), var(--g2), var(--g1));
  }
  .ainote .full { display: none; }
  .ainote:hover .full { display: inline; }
  /* 操作 */
  .acts {
    display: flex;
    gap: 8px;
    padding: 14px 20px 18px;
    align-items: center;
    flex-wrap: wrap;
  }
  .acts button.danger:hover,
  .acts button.danger.armed {
    color: #d3382f;
  }
  .acts button,
  .acts a {
    font: 500 12px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 9px 16px;
    cursor: pointer;
    text-decoration: none;
  }
  .acts button:hover,
  .acts a:hover { color: var(--t1); }
  .acts .pri {
    color: #fff;
    background: var(--grad);
    font-weight: 600;
  }
</style>
