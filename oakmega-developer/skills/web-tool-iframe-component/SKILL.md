---
name: web-tool-iframe-component
description: 用內部工具 cs_tool 上傳整份 html、取得同源 iframe 網址，再填進網頁型工具的「iframe 元件」。需要存取父層 localStorage、讀取或操作父層 DOM、共用父層登入狀態時走這條路。僅限 OakMega 員工。
---

# 同源 iframe 元件（cs_tool）

一般的客製化元件是**跨網域 sandbox iframe**，存取不到父層任何東西（見 `web-tool-custom-component` skill）。cs_tool 是 OakMega 內部工具，上傳**整份 html** 後會給你一個網址，該網址與客戶的網頁型工具**同源**，因此能存取父層。

## 第一步：確認身分

cs_tool 只有 OakMega 員工能用。**開始前先問**：

> 這個做法需要用到 OakMega 內部的 cs_tool，請問你是 OakMega 的員工嗎？

- **是** → 繼續。
- **不是** → 告訴他這需要 OakMega 員工協助上傳，請他聯繫窗口。同時判斷一下：如果需求其實不需要碰父層，改用 `web-tool-custom-component` skill，他自己就能完成，不必等人。

## 第二步：確認真的需要同源

只有以下情況用 cs_tool：

- 要讀寫父層的 `localStorage`／`sessionStorage`
- 要讀取或操作父層的 DOM
- 要呼叫父層既有的 JS
- 要共用父層的登入狀態或 cookie

**只是呈現、動畫、互動、打第三方 API → 用 `web-tool-custom-component` skill。** 同源元件綁死父層實作，父層一改版就會壞，不要因為「比較自由」就預設走這條。

## 範圍界線

只負責 iframe 內的前端。後端、API、資料庫、資料持久化都不在範圍內——遇到時明講這部分要另外處理，不要硬做。

## 產出與嵌入方式

**產出**：完整的一份 html，含 `<!DOCTYPE html>`／`<html>`／`<head>`／`<body>`，CSS 和 JS 直接內嵌。整份上傳 cs_tool，換得一個網址。

**嵌入**：填在網頁型工具設定的 **iframe 元件**（不是客製化元件）。設定項目：

| 設定 | 選項                                                              |
| ---- | ----------------------------------------------------------------- |
| 寬度 | 沒有選項，一律滿版寬度，不用問使用者                              |
| 高度 | 符合內容高度（`fit`）／滿版高度（`fill`）／自訂高度（填 px 數字） |

實際渲染出來的 DOM（外層 `.edit-preview-content` 是編輯器每個內容區塊共用的容器；`480px` 只是自訂高度模式下的例子，實際數值依下面選的模式而定）：

```html
<div class="edit-preview-content">
  <div class="mt-16 pb-4">
    <iframe
      style="display: block; border: none; width: 100%; height: 480px"
      src="https://你的cs_tool網址"
    ></iframe>
  </div>
</div>
```

## 高度：三種模式，自己依內容判斷選哪個，不用問使用者

跟客製化元件（跨網域 sandbox iframe，只能靠 `postMessage` 回報高度）不同，cs_tool 是同源，父層可以直接讀你的 `document`／`body` 的 `scrollHeight`。三種怎麼選，判斷邏輯跟客製化元件一樣，自己依使用者要做的內容判斷即可：

- **多數情境選 `fit`**：文字、卡片、表單、輪播圖、一般互動元件——只要「內容多高，這塊就多高」是合理預期，就用這個，預設值。
- **元件就是這個區塊的全部畫面時選 `fill`**：全螢幕地圖、簽名板、畫布／小遊戲，或使用者明確說要「撐滿」「佔滿畫面」。
- **自訂高度（數字 px）幾乎用不到**：只有 `fit`／`fill` 都無法表達需求時才考慮。

### `fit`（符合內容高度，多數情境選這個）

父層用 `ResizeObserver` 監看你的 `<body>`，自動把 iframe 高度調整成內容的實際高度——**完全不用自己寫任何回報高度的 code**。規則跟客製化元件的 `fit` 模式相同（因為量測方式一樣是抓 `scrollHeight`，會踩到一樣的坑）：

- 不要用 `height: 100vh`，也不要對 `html`／`body` 設 `height: 100%`——這樣量到的永遠是 viewport 高度，不是內容高度
- 不要用 `position: absolute`／`fixed` 做超出內容高度的浮層（下拉選單、tooltip、modal），要走文件流，否則量不到
- 不要用會改變版面尺寸的無限循環動畫（`transform`／`opacity` 不受此限）
- 不要讓容器變空
- 圖片給 `aspect-ratio` 或明確尺寸，減少圖片載入完成前後的高度跳動（`ResizeObserver` 會持續監看並重新量測，跳動會自動修正，但還是盡量避免閃爍）
- 首次量測完成前，父層會先套用預設高度 `calc(100vh - 52px)`，短暫的截斷或空白是正常現象，不要寫補償邏輯

### `fill`（滿版高度）

撐滿外層剩餘可用空間，跟客製化元件的 `fill` 概念相同。元件就是這個區塊的全部畫面時用（全螢幕地圖、簽名板、畫布／小遊戲）。自己輸出的 html 最外層元素寫 `height: 100%`（或 flex `flex: 1` + `min-height: 0`）撐滿即可；內容超出時預設出現內部捲軸。

### 自訂高度（數字 px，舊機制）

**沒有任何自動量測。** 設定裡填多少 px 就是多少，內容超過會出現 iframe 自己的捲軸——不會被裁掉，但體驗差。真的要用這個模式時，自己依內容抓一個合理數字即可，不用特地去問使用者；需要動態改高度時，同源可以直接改父層的 iframe 元素，見下。

## `window.frameElement`：同源最重要的入口

同源的價值不只是「能查父層 DOM」，而是你可以直接拿到**自己那個 `<iframe>` 元素**：

```js
var host = window.frameElement; // 父層文件裡的 <iframe> 元素
var pdoc = window.parent.document; // 父層 document
```

這比從 `parent.document` 用 selector 找可靠得多，因為完全不依賴父層的 class 名稱。常見用法：

```js
// 自訂高度模式才需要：動態覆蓋設定裡的固定 px
// （fit/fill 模式父層已經自動幫你調整高度，不用重複處理）
if (host) host.height = document.documentElement.scrollHeight;

// 找到自己所在的內容區塊，再從那裡找相鄰內容
var block = host && host.closest(".edit-preview-content");
```

用 `frameElement` 定位自己、再從那裡往外找，永遠優先於全域 selector 查找。

## 父層環境（依實際 DOM 確認）

- **Vue 3**：`#app[data-v-app]`，scoped style 產生的 `data-v-<hash>` 屬性
- **PrimeVue**：`p-toast`、`p-component`、`data-pc-name`、`data-pc-section`
- **Tailwind 風格 utility class**，含自訂 token：`bg-oakmega-surface`、`max-w-oakmegaContainer`
- **結構**：

  ```
  #app > main > .content-layout-container > .edit-preview-container > .edit-preview-content × N
  ```

  每個 `.edit-preview-content` 是一個內容區塊，你的 iframe 包在其中一個裡面。

> `edit-preview-*` 這組命名容易誤導——**這就是前台實際頁面的結構**，不是後台編輯器專用的。

選 `fill` 高度時，`.edit-preview-content` 會多一個 `.edit-preview-content-fill` class，iframe 外面也會多包一層 `.iframe-content-fill`（都是 flex 撐滿用的版面 class）。這兩個 class 只在 `fill` 模式才出現，不要拿來當定位用的 selector。

## 撰寫注意

- **不要拿 `data-v-<hash>` 當 selector。** 那是 Vue scoped style 產生的，元件原始碼一改就換一組。
- **不要修改 Vue 管理的 DOM。** Vue 下次 re-render 會覆蓋掉你的修改，甚至造成 patch 錯亂。要改就改 Vue 不管的節點，或透過它的既有互動（觸發事件）達成。
- **父層是非同步渲染的**，你的 iframe 載入時目標元素不一定存在。用 `MutationObserver` 或加逾時的輪詢，不要查一次找不到就放棄。
- `<!---->` 是 Vue `v-if` 的佔位註解，代表旁邊有條件渲染的兄弟節點，數量會變動——不要用 `nth-child` 之類的位置選擇器。
- **元素找不到一定要有處理**（`if (!el) return;`），不要讓一個失效的 selector 讓整段 JS 停擺。
- 寫父層 storage 用自己的 key 前綴，不要污染既有資料。

## 開發流程

使用者通常不是工程師。每一步都要給可照做的指示，並描述「你會看到什麼」讓他確認做對了。

### 1. 問清楚要達成什麼

用他答得出來的方式問：要從頁面上拿到什麼資訊、要改變頁面上的什麼、什麼時候發生。iframe 元件的高度模式（`fit`／`fill`／自訂）依內容判斷即可，不用問。**不要問 selector、storage key** ——那是你等一下要自己從存檔裡找出來的。

### 2. 請使用者蒐集現場資料

只有需要碰父層時才做。依需要挑，一次要一樣，拿到再要下一樣。

**頁面網址** — 每次都要。

**整頁存檔**（需要分析結構時）

> 請用電腦版 Chrome 打開那個頁面，按 `Cmd+S`（Windows 是 `Ctrl+S`），存檔類型選「**網頁，完整**」，存到我們的專案資料夾，再把路徑告訴我。
> 存好後你會看到多出一個 `.html` 檔和一個同名的資料夾，兩個都要留著。

**localStorage 內容**（需要讀寫父層 storage 時）

> 在那個頁面按 `F12`（Mac 是 `Option+Cmd+I`）打開開發者工具，上方選 `Application`（應用程式），左邊找到 `Local Storage` 點開，點裡面的網址，右邊會出現一個表格。把那個表格截圖給我。

**特定元素的結構**（需要操作某個元件時）

> 在頁面上對著那個東西按右鍵，選「檢查」，右邊會跳出一段被藍色標起來的程式碼。對那段按右鍵 → `Copy` → `Copy outerHTML`，然後貼給我。

### 3. 分析

整頁存檔通常有數 MB，直接讀會吃掉整個對話。**用 `web-tool-page-analyst` agent 分析**，它會回傳精簡報告：origin、storage key、目標元素的穩定 selector、框架、元素是靜態還是動態產生。

### 4. 提出做法讓使用者確認

用白話說明你要怎麼做、會動到父層的什麼、失敗時會發生什麼。等他確認再動手。

### 5. 產出

寫成一個完整的 `.html` 檔交給他上傳。

### 6. 上傳與設定

告訴使用者接下來要做的事：

> 1. 把這個檔案上傳到 cs_tool，會拿到一個網址。
> 2. 到網頁型工具的設定裡新增一個 **iframe 元件**，把網址貼進去。
> 3. 寬度不用設定（一律滿版），高度選 `___`（依你判斷的模式：`符合內容高度`／`滿版高度`；只有無法判斷時才用自訂並填 `___px`）。

### 7. 驗證

請他打開實際頁面確認。有問題就請他重新存檔或截圖，回到步驟 3——不要在沒有新資料的情況下反覆猜測修改。
