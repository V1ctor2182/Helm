# Loop Report · B 轨 · drain/生产 #5

> 档位:🌙 放手模式。A 轨已全部合 main。Round 31。B 轨「生产」侧:补齐延后的 intent 缺口。

## 目标

可消化的现存 backlog 已清空。B 轨「loop 既消费也生产」——反思发现 **email-calendar m5 显式延后的真实 intent 缺口**:
intent#3 列「邮件→任务/记忆/**日历事件**」,m5 只做了 →记忆/→任务,**→日历事件未做**。本轮补齐(非镀金,是补既定 intent)。

## 做了什么

- **`helm/mail/routes.py`**（改）:`POST /api/mail/emails/{id}/to-event {start, end?}` —— 复用 `helm.calendar` `EventService`,
  subject→summary、body→description、用户选时间→start,source=local;404 on 缺邮件。
- **前端 `mailStore.svelte.ts`**（改）:`toEvent(id, start)`;`Mail.svelte` 详情加 **→日程** 按钮(`window.prompt` 取
  datetime,默认当前时间)。
- **测试**:后端 `test_mail.py` +1(email→event 建事件+入日历+404);前端 `calendar.test.ts` +1(toEvent POST start)。

至此 **intent#3 转换矩阵齐全**(邮件→记忆 / 任务 / 日历事件)。

## 决策(record_decision)

- **decision `3d326960`**（ai_proposed）:补齐 email→event,intent#3 完成。可逆(删事件)。

## 验证

- `pytest`（全量后端）→ **186 passed, 1 skipped**(drain#4 后 185 → +1)。
- 前端 `vitest` mail → **10 passed**;`svelte-check` → 0;`build` → ok。

## 熔断状态

未命中熔断。

## 下一步

intent#3 补齐后,可安全自动推进的工作进一步收窄。剩余 backlog 全为 `[needs-human]` / 需真实环境(打包评估)/
需外部集成(Skills)/高风险迁移(httpx2)。继续逼近「只剩 needs-human / 无可安全推进工作」的停止点。
