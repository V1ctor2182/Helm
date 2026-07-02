<script lang="ts">
  import { layout } from './layout.svelte'

  // Today = 无卡片仪表读数（承 helm-pro.html `.rd`）。数据用设计稿同款 mock；
  // 真实数据（任务→F6 / agent→F5 / 项目→F1 / 邮件→F7）阶段2 接 /api，保持此版式。
  const tasks = [
    { label: '对齐 notch scroll 手感（实机复验）', due: '今天', hot: true, done: false },
    { label: '写 F8 Shell 设计稿 → loop 进 Svelte', due: '今天', hot: false, done: false },
    { label: '回 Odysseus RAG 迁移的问题', due: '完成', hot: false, done: true },
  ]
  const agents = [
    { name: 'notch', activity: '正在思考…', status: 'run', tag: 'CLAUDE CODE', thinking: true },
    { name: 'helm', activity: 'Bash: swift build ✓ · 3 文件改动待看', status: 'ok', tag: '2 MIN', thinking: false },
  ]
  const recent = [
    { name: 'helm', branch: '⎇ feat/notch · ↑2' },
    { name: 'odysseus-dev', branch: '⎇ main' },
  ]

  function newChat() {
    layout.setMode('chat')
    layout.openTab('New Chat', 'chat')
  }
  function newResearch() {
    layout.setMode('research')
    layout.openTab('Research', 'research')
  }
</script>

<div class="rd">
  <header class="rdhead">
    <h1>Today</h1>
    <span class="date">周三 · 25.03 · 08:41</span>
    <span class="pg">LOADING · 001/009</span>
  </header>

  <div class="rdrow">
    <div class="gut"><span class="tm">今日</span><br />3 未完</div>
    <div>
      <div class="h">任务 / TASKS</div>
      {#each tasks as t (t.label)}
        <div class="task">
          <span class="cbx" class:done={t.done} aria-hidden="true"></span>
          <span class:strk={t.done}>{t.label}</span>
          <span class="due" class:hot={t.hot}>{t.due}</span>
        </div>
      {/each}
    </div>
  </div>

  <div class="rdrow">
    <div class="gut"><span class="tm">08:41</span></div>
    <div>
      <div class="h">日记 / JOURNAL</div>
      <div class="jr">
        <span class="car" aria-hidden="true"></span>写两行今天…
        <button class="aibtn" onclick={() => layout.setMode('journal')}>AI 今日小结</button>
      </div>
    </div>
  </div>

  <div class="rdrow">
    <div class="gut"><span class="tm">刚刚</span><br />2 活跃</div>
    <div>
      <div class="h">Agent 收件箱 / VIEWPORT</div>
      <div class="framed">
        {#each agents as a (a.name)}
          <div class="agl">
            <span class="sdot" class:run={a.status === 'run'} class:ok={a.status === 'ok'} aria-hidden="true"></span>
            <span class="nm">{a.name}</span>
            <span class="ac">
              {#if a.thinking}<span class="cstar" aria-hidden="true">✻</span> {/if}{a.activity}
            </span>
            <span class="st">{a.tag}</span>
          </div>
        {/each}
      </div>
    </div>
  </div>

  <div class="rdrow">
    <div class="gut"><span class="tm">本周</span></div>
    <div>
      <div class="h">最近项目 / PROJECTS</div>
      {#each recent as p (p.name)}
        <button class="projline" onclick={() => layout.setMode('cockpit')}>
          <span class="pd" aria-hidden="true"></span>
          <span class="pp">{p.name}</span>
          <span class="br">{p.branch}</span>
        </button>
      {/each}
    </div>
  </div>

  <div class="rdrow">
    <div class="gut"><span class="tm">收件</span><br />AI 分诊</div>
    <div>
      <div class="h">邮件 / MAIL</div>
      <div class="mailn">
        <span class="fl" aria-hidden="true"></span>
        <span class="from">Anthropic</span>
        <span class="sj">— API 用量本月…</span>
        <span class="urg">紧急</span>
      </div>
    </div>
  </div>

  <div class="qacts">
    <button class="qa pri" onclick={newChat}>＋ 新 Chat</button>
    <button class="qa" onclick={newResearch}>发起研究</button>
    <button class="qa" onclick={() => layout.openCapture()}>记一条 · ⌘N</button>
  </div>
</div>

<style>
  .rd {
    height: 100%;
    overflow: auto;
    padding: 18px 24px 24px 0;
    font-family: var(--sans);
  }
  .rdhead {
    display: flex;
    align-items: baseline;
    gap: 12px;
    padding-left: var(--gutter-w);
    margin-bottom: 6px;
  }
  .rdhead h1 {
    font-family: var(--mono);
    font-size: 24px;
    font-weight: 800;
    letter-spacing: 1px;
    color: var(--t1);
    margin: 0;
  }
  .rdhead .date {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--acc-ink);
    font-weight: 700;
  }
  .rdhead .pg {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    letter-spacing: .5px;
    font-variant-numeric: tabular-nums; /* DESIGN:数据/计数一律 tabular */
  }
  .rdrow {
    display: grid;
    grid-template-columns: var(--gutter-w) 1fr;
    border-top: 1px solid var(--hair);
    padding: 10px 0;
  }
  .rdrow:first-of-type {
    border-top: none;
  }
  .gut {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    line-height: 1.5;
    padding-top: 3px;
    letter-spacing: .3px;
  }
  .gut .tm {
    color: var(--t3);
  }
  .h {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    letter-spacing: 1px;
    text-transform: uppercase;
    margin-bottom: 7px;
  }
  .task {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 3px 0;
    font-size: 13px;
    color: var(--t2);
  }
  .cbx {
    width: 13px;
    height: 13px;
    border: 1.4px solid var(--t4);
    flex: none;
  }
  .cbx.done {
    border-color: var(--acc-ink);
    background: var(--acc);
  }
  .strk {
    color: var(--t4);
    text-decoration: line-through;
  }
  .due {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
  }
  .due.hot {
    color: var(--orange);
  }
  .jr {
    display: flex;
    align-items: center;
    gap: 9px;
    color: var(--t4);
    font-size: 13px;
  }
  .car {
    width: 2px;
    height: 14px;
    background: var(--acc);
    display: inline-block;
    animation: blink 1s steps(1) infinite;
  }
  @keyframes blink {
    50% { opacity: 0; }
  }
  .aibtn {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--acc-ink);
    border: 1px solid var(--acc-ink);
    background: transparent;
    padding: 3px 8px;
    cursor: pointer;
  }
  /* Agent 框选视口（frame + 琥珀 L 角） */
  .framed {
    position: relative;
    border: 1px solid var(--line);
    padding: 10px 12px;
    margin-top: 2px;
  }
  .framed::before,
  .framed::after {
    content: '';
    position: absolute;
    width: 9px;
    height: 9px;
    border: 1.4px solid var(--acc-ink);
  }
  .framed::before {
    top: -1px;
    left: -1px;
    border-right: none;
    border-bottom: none;
  }
  .framed::after {
    bottom: -1px;
    right: -1px;
    border-left: none;
    border-top: none;
  }
  .agl {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 4px 0;
  }
  .sdot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex: none;
    background: var(--t4);
  }
  .sdot.ok { background: var(--green); }
  .sdot.run { background: var(--acc); }
  .agl .nm {
    color: var(--t1);
    font-weight: 600;
    font-size: 12px;
  }
  .agl .ac {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t3);
  }
  .agl .st {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
  }
  .cstar {
    color: var(--acc-ink);
    display: inline-block;
    animation: cspin 1.1s ease-in-out infinite;
  }
  @keyframes cspin {
    0% { transform: rotate(0) scale(.85); opacity: .6; }
    50% { transform: rotate(180deg) scale(1.12); opacity: 1; }
    100% { transform: rotate(360deg) scale(.85); opacity: .6; }
  }
  .projline {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 4px 0;
    font-size: 12.5px;
    width: 100%;
    background: transparent;
    border: 0;
    cursor: pointer;
    text-align: left;
  }
  .projline .pd {
    width: 13px;
    height: 13px;
    border-radius: 3px;
    background: linear-gradient(135deg, #e8a07a, #6a4f8f);
    flex: none;
  }
  .projline .pp {
    color: var(--t2);
  }
  .projline .br {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    margin-left: auto;
  }
  .mailn {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 4px 0;
    font-size: 12.5px;
  }
  .mailn .fl {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--red);
    flex: none;
  }
  .mailn .from {
    color: var(--t2);
  }
  .mailn .sj {
    color: var(--t4);
  }
  .mailn .urg {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--orange);
  }
  .qacts {
    padding-left: var(--gutter-w);
    margin-top: 15px;
    display: flex;
    gap: 8px;
  }
  .qa {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t3);
    border: 1px solid var(--line);
    background: transparent;
    padding: 6px 11px;
    cursor: pointer;
  }
  .qa:hover {
    color: var(--t1);
  }
  .qa.pri {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
</style>
