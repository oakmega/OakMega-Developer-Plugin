# oakmega-developer

開發 OakMega 網頁型工具（授權頁、表單、預約中心、優惠券）客製化元件的 Claude Code plugin。

## 入口

```
/web-tool-component [要做的元件]
```

指令是薄入口，實際規則以兩份 skill 為準。

## 架構

```
oakmega-developer/
├── commands/web-tool-component.md          進入情境，判斷走哪一種 iframe
├── skills/
│   ├── web-tool-custom-component/          跨網域 sandbox iframe（三段字串）
│   └── web-tool-iframe-component/         cs_tool 同源 iframe（整份 html）
└── agents/web-tool-page-analyst.md         分析頁面存檔的 subagent
```

**為什麼互動流程放在 command 而不是 agent**：subagent 跑完才回報，中途無法向使用者要資料。同源開發需要來回請使用者存檔、截圖，必須在主線進行。agent 只承接「讀完數 MB 的存檔、回傳精簡報告」這種會吃 context 又不需要互動的工作。

## 兩份 skill 的分界

判斷準則只有一個：**跨網域 sandbox iframe 拿不到父層任何東西。**

| 需求 | 走哪份 |
| --- | --- |
| 呈現、動畫、互動、打第三方 API | `web-tool-custom-component` |
| 讀寫父層 localStorage、操作父層 DOM、共用登入狀態 | `web-tool-iframe-component` |

前者的每一條規則都可以對回 `iframe-shell` 的實作或瀏覽器規範；後者的父層環境（Vue 3 + PrimeVue + Tailwind 風格 utility class）與 DOM 結構依實際頁面確認。

`web-tool-iframe-component` 額外有一道**身分閘門**：cs_tool 是內部工具，走這條前必須先確認對方是 OakMega 員工，不是的話請他聯繫窗口，並回頭確認需求是否走另一份 skill 就能自己完成。

## 範圍

只負責 iframe 內的前端。後端、API、資料持久化不在範圍內。
