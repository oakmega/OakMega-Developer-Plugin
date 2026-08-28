---
name: web-tool-custom-component
description: 產生 OakMega 客製化元件的 html/css/js/height_setting 四個欄位，在跨網域 sandbox iframe 中渲染。當使用者要在授權頁、表單、預約中心、優惠券的內容區塊裡放一段自訂呈現時使用。若需要存取父層 localStorage 或 DOM，改用 web-tool-iframe-component。
---

## 動手前先查版本

**每次進到這個流程，第一件事就是執行這段**（本次對話已經查過就跳過）：

```bash
S=$(ls -d ~/.claude/plugins/cache/*/oakmega-developer/*/scripts/version-check.sh 2>/dev/null | tail -1); [ -n "$S" ] && bash "$S"
```

- **沒有任何輸出** → 已是最新。什麼都別說，直接往下做。
- **有輸出** → 照輸出裡的指示做：先在回覆開頭把版本狀況講給使用者聽，再繼續原本的工作。不要因為版本落後就拒絕做事。

這一步大約 0.5 秒，離線或連不上 GitHub 時會安靜跳過，不會擋住你。

# OakMega 客製化元件

產出 `html`、`css`、`js`、`height_setting` 四個欄位，`html`／`css`／`js` 會被送進獨立 iframe 渲染。視覺份量由使用者決定，他要多大就做多大，不要自我設限。

## 輸出

對應使用者介面的高度單選 + 三個貼上欄位，依序輸出成這個格式：

```
高度選擇:
符合內容高度 或 滿版高度
------------
html:
（貼上內容）
------------
css:
（貼上內容）
------------
js:
（貼上內容）
```

- `高度選擇` 二選一，只留最終選的那個：「符合內容高度」（下文稱 `fit`，多數情境用這個，預設）／「滿版高度」（下文稱 `fill`，見下方怎麼選）
- `html` 只放 body 內的元素，不含 `<!DOCTYPE>`／`<html>`／`<head>`／`<body>`／任何 `<script>`
- `css` 只放 CSS 規則，不含 `<style>`
- `js` 只放邏輯，不含 `<script>`
- `html`／`css`／`js` 不需要就留空，不要寫 `null` 或省略整段

### 高度怎麼選

- **符合內容高度／`fit`（預設，多數情境用這個）**：文字、卡片、表單、輪播圖、一般互動元件。
- **滿版高度／`fill`**：元件就是這個區塊的全部畫面時用，例如全螢幕地圖、簽名板、畫布／小遊戲。不確定時選 `fit`，使用者明確要「撐滿」「佔滿畫面」才選 `fill`。

## 規則

### 格式

1. `html` 不得有 `<script>`，**含 `<script src>`**。要載 CDN 就在 `js` 裡用 `createElement('script')`，並處理 `onerror`。
2. `js` 不得出現字面的 `</script>`，`css` 不得出現 `</style>`，需要時寫成 `'<\/script>'`。

### JS

3. 整段包進 IIFE。
4. 用 `addEventListener`，不要 inline `onclick`。
5. 不要等 `DOMContentLoaded`/`load`，直接執行。
6. 非 module，不能用 `import`／`export`／top-level `await`。
7. 必須冪等，不要依賴上次渲染殘留的 DOM 或全域變數。
8. 查到的元素先判斷存在。可以 `fetch` 第三方 API，但該 API 必須允許 CORS，且一定要 `catch` 並有失敗畫面。

### 版面

9. 寬度固定為容器 100%，用響應式寫法，不要寫死大 px（主要情境是手機的 LINE 內建瀏覽器）。
10. 以下規則依 `height_setting` 而不同：

    **`fit` 模式**：

    - 不要用 `height: 100vh`，也不要在 `css` 裡對 `html`/`body` 設 `height: 100%`
    - 不要用 `position: absolute`/`fixed` 做超出內容高度的浮層——下拉選單、tooltip、modal 都不行，展開／收合要走文件流
    - 不要用會改變版面尺寸的無限循環動畫。`transform`/`opacity` 不受此限
    - 不要讓容器變空
    - 圖片給 `aspect-ratio` 或明確尺寸
    - 首次量測完成前外部頁面會先套用一個過渡高度，短暫的截斷或空白是正常現象，不要寫補償邏輯

    **`fill` 模式**：

    - 在自己輸出的 html 最外層元素上寫 `height: 100%`（或用 flex `flex: 1` + `min-height: 0`）即可撐滿；不要自己在 `css` 裡覆寫 `html`/`body` 的高度
    - 內容超出容器高度時預設會出現內部捲軸，不會被裁切；想要裁切效果才自己在最外層元素加 `overflow: hidden`
    - 可以放心用 `position: absolute`/`fixed` 的滿版浮層

### 環境

11. 可放心用 `body`／`*` 等全域選擇器，不需要 scope 或 class 前綴。已套用 `* { margin: 0; padding: 0; box-sizing: border-box }`，不需重做；要覆寫直接寫在你的 `css` 裡。
12. 需要背景色就畫在自己最外層的容器上，不要設在 `body`/`html`；要融入頁面就不設。
13. 不要用 `prefers-color-scheme`。
14. 外部圖片／字體／CDN 都可用，但載入失敗要有降級畫面。
15. 不可用：`window.parent`／`window.top`、對外 `postMessage`、cookie／localStorage／sessionStorage、OakMega 平台的任何 API（含品牌色等平台設定）。

## 使用者身分

`window.__OAKMEGA_LINE_PROFILE__` 是唯一的資料管道，在你的 `js` 執行前已同步設定好。

```ts
type LineProfile = {
  user_type: "line";
  user_unique_id: string | null;
  display_name: string | null;
  profile_url: string | null;
} | null;
```

整個值可能是 `null`，各欄位也可能是 `null`（例如沒設大頭貼）。兩層都要檢查，並準備好沒有身分時的文案。

```js
(function () {
  var p = window.__OAKMEGA_LINE_PROFILE__;
  var name = (p && p.display_name) || "貴賓";
  var el = document.getElementById("hi");
  if (!el) return;
  el.textContent = name + " 您好";
})();
```

## 提問

使用者通常不是工程師。技術細節（字體、間距、佈局、DOM 結構）一律自己決定，不要問。內容與意圖不明確時可以問，但只問他答得出來的事：要顯示什麼、文案怎麼寫、資料是固定的還是要即時撈、點下去要發生什麼。給選項而不是開放式提問，一次最多一到兩件。能靠預設補完的就先產一版，讓他指著成品說要改哪裡。
