# OakMega Developer — Claude Code Plugin

讓你在 Claude Code 裡開發 OakMega 網頁型工具（授權頁、表單、預約中心、優惠券）的客製化元件。

- 安裝步驟請見 **[INSTALL.md](INSTALL.md)**（桌面 app 與終端機 CLI 兩種）。
- License：專有，保留所有權利，見 [LICENSE](LICENSE)。

## 這個 plugin 做什麼

裝好後，在 Claude Code 輸入框打 **`/web-tool-component`** 就進入元件開發情境，例如：

- `/web-tool-component` → 先問你要做什麼元件。
- `/web-tool-component 優惠券頁加一個到期倒數計時` → 直接把需求帶進流程。

它會先判斷這個需求屬於哪一種 iframe，再套用對應的規則產出程式碼。

## 兩種 iframe

| | 跨網域 sandbox iframe | 同源 iframe（cs_tool） |
| --- | --- | --- |
| 誰能用 | 所有人，客戶自己也能在後台貼 | **僅限 OakMega 員工**（cs_tool 是內部工具） |
| 產出 | `html`／`css`／`js` 三段字串 | 完整一份 html，上傳後取得網址 |
| 填在哪 | **客製化元件** | **iframe 元件**（可選滿版／符合內容寬度，高度填 px） |
| 能不能碰父層 | **完全不行**（不同網域） | 可以（localStorage、DOM、登入狀態） |
| 高度 | 自動量測回報，不可固定 | **使用者填的固定 px**，無自動量測 |
| 適用 | 呈現、動畫、互動、打第三方 API | 需要讀寫父層狀態時 |
| skill | `web-tool-custom-component` | `web-tool-iframe-component` |

**絕大多數需求走前者。** 同源 iframe 會綁死父層實作，父層改版就會壞，只有真的需要碰父層才用。

兩邊的高度規則是**相反的**：sandbox 那邊禁用 `height: 100%`／`100vh`（會讓自動量測出錯），cs_tool 這邊可以用（iframe 高度本來就固定）。skill 各自寫清楚了，不要混用。

## 範圍界線

**只負責 iframe 內的前端。** 後端、API、資料庫、資料持久化不在這個 plugin 的範圍——那部分請直接用 Claude 自由處理。

## 內容

| 類型 | 名稱 | 用途 |
| --- | --- | --- |
| 指令 | `/web-tool-component` | 進入元件開發情境，判斷走哪一種 iframe |
| Skill | `web-tool-custom-component` | 跨網域 sandbox iframe 的完整規則 |
| Skill | `web-tool-iframe-component` | cs_tool 同源 iframe 的開發流程 |
| Agent | `web-tool-page-analyst` | 分析使用者下載的整頁存檔，回傳父層結構的精簡報告 |
| 腳本 | `scripts/version-check.sh` | 三個進入點在開頭都會呼叫它，比對 GitHub 版本，落後就自動更新 |

`web-tool-page-analyst` 是 subagent，用來讀那些動輒數 MB 的網頁存檔，只把開發需要的少量事實帶回主對話，不佔用主線 context。

## 版本守門（自動更新）

`/web-tool-component` 指令和兩份 skill 的 markdown **開頭都寫了一段「動手前先查版本」**，AI 進到流程就會先跑 [`scripts/version-check.sh`](oakmega-developer/scripts/version-check.sh)。

- 已是最新 → 腳本沒有任何輸出，AI 直接往下做，不會多嘴。
- 有新版 → 直接把新檔案換進 plugin 快取目錄，並要 AI 告訴你「重啟 Claude Code 才會載入」。
- 沒辦法自動更新（本機開發用 checkout、沒有寫入權限）→ 只提示，不動你的檔案。

### 為什麼不用 hook

本來是做成 `SessionStart` / `UserPromptSubmit` hook 的，但**在 Claude 桌面版實測，plugin hook 一次都沒有被觸發**（在腳本第一行寫 log 驗證過，log 全空）。`/reload-plugins` 也只有終端機 CLI 才有。

寫在 markdown 裡不依賴任何註冊機制 —— 只要指令或 skill 被叫起來，這段就一定會被讀到。代價是它靠 AI 照著做，不像 hook 那樣是硬性的。

### 腳本行為

- 只用 **curl + tar**（macOS／Linux／Git for Windows 都內建）。沒有 curl 就試 wget，都沒有才退回 git；連 git 都沒有就靜默跳過。
- 平常只抓一個 `plugin.json`（幾百 bytes，約 0.5 秒）比對版本；真的要更新時才下載 tarball（約 13 KB）。
- **沒有快取、沒有狀態檔。** 每次都問一次，答案永遠是當下的事實。
- timeout 壓在連線 3 秒／總計 6 秒。離線約 0.09 秒就結束。
- 換檔案用 rename swap，舊版整個換掉。`.in_use` 等 Claude Code 自己的標記檔會保留。
- 只動 `plugins/cache/*/*/*` 底下的目錄；本機開發用的 checkout（有 `.git`）一律不碰。
- 任何一步失敗都靜默結束，不會擋住你的對話。
