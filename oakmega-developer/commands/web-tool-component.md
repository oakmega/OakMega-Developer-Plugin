---
description: 開發 OakMega 網頁型工具的客製化元件（授權頁／表單／預約中心／優惠券）。
argument-hint: [要做的元件，例如：優惠券頁加一個倒數計時；留空＝先問需求]
---

## 動手前先查版本

**每次進到這個流程，第一件事就是執行這段**（本次對話已經查過就跳過）：

```bash
S=$(ls -d ~/.claude/plugins/cache/*/oakmega-developer/*/scripts/version-check.sh 2>/dev/null | tail -1); [ -n "$S" ] && bash "$S"
```

- **沒有任何輸出** → 已是最新。什麼都別說，直接往下做。
- **有輸出** → 照輸出裡的指示做：先在回覆開頭把版本狀況講給使用者聽，再繼續原本的工作。不要因為版本落後就拒絕做事。

這一步大約 0.5 秒，離線或連不上 GitHub 時會安靜跳過，不會擋住你。

使用者要開發 OakMega 網頁型工具的客製化元件。

## 先判斷走哪一條

問清楚需求後判斷。判斷準則只有一個：**跨網域 sandbox iframe 拿不到父層任何東西。**

- **只是呈現／互動／打第三方 API** → 依 `web-tool-custom-component` skill，產出 `html`／`css`／`js` 三段字串，填在**客製化元件**。**絕大多數情況都是這條。**
- **需要存取父層 localStorage、讀取或操作父層 DOM、呼叫父層 JS、共用父層登入狀態** → 依 `web-tool-iframe-component` skill，產出完整一份 html 上傳 cs_tool，取得網址後填在 **iframe 元件**。

走第二條之前**一定要先確認對方是不是 OakMega 員工**——cs_tool 是內部工具。不是員工就請他聯繫 OakMega 窗口協助，並回頭確認需求是否其實走第一條就能自己完成。同源元件會綁死父層實作，父層改版就會壞，不要因為「比較自由」就預設走這條。

不確定時問使用者，但要用他答得出來的方式問（他通常不是工程師）：問「這個元件需不需要知道使用者在這個頁面上已經填了什麼／選了什麼？」，不要問「你需要同源存取嗎？」。

## 範圍界線

**只負責 iframe 內的前端。** 後端、API、資料庫、資料持久化都不在這個流程裡。遇到時直接告訴使用者這部分要另外處理，不要硬做、也不要假裝做得到。

本次需求：$ARGUMENTS
（留空代表先問使用者要做什麼。）

> 若 skill 未自動載入，請直接讀取並遵循
> `${CLAUDE_PLUGIN_ROOT}/skills/web-tool-custom-component/SKILL.md`
> 或 `${CLAUDE_PLUGIN_ROOT}/skills/web-tool-iframe-component/SKILL.md`。
