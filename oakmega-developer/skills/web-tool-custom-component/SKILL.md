---
name: web-tool-custom-component
description: 產生 OakMega 客製化元件的 html/css/js 三段字串，在跨網域 sandbox iframe 中渲染。當使用者要在授權頁、表單、預約中心、優惠券的內容區塊裡放一段自訂呈現時使用。若需要存取父層 localStorage 或 DOM，改用 web-tool-iframe-component。
---

# OakMega 客製化元件

產出 `html`、`css`、`js` 三個字串，會被送進獨立 iframe（`scrm.oakmega.site/0/iframe-shell`）渲染，位置是使用者在授權頁／表單／預約中心／優惠券裡編排的內容區塊。

**視覺份量由使用者決定。** 客戶自己寫 html，常常就是為了蓋掉平台預設的視覺。他要多大就做多大，不要自我設限。以下限制全部來自 shell 的實作機制，不是美感建議。

## 輸出

| 欄位 | 內容 | 不含 |
| --- | --- | --- |
| `html` | 只有 body 內的元素 | `<!DOCTYPE>`／`<html>`／`<head>`／`<body>`／任何 `<script>` |
| `css` | 只有 CSS 規則 | `<style>` |
| `js` | 只有邏輯 | `<script>` |

不需要的欄位給 `""`，不要給 `null`。

## 規則

### 格式

1. `html` 不得有 `<script>`，**含 `<script src>`**。（`innerHTML` 插入的 script 一律不執行。要載 CDN 就在 `js` 裡 `createElement('script')`，並處理 `onerror`）
2. `js` 不得出現字面的 `</script>`，`css` 不得出現 `</style>`。（兩者是用 `.innerHTML` 寫入節點的，會提前終止解析）需要時寫成 `'<\/script>'`。

### JS

3. 整段包進 IIFE。（每次渲染都建新的 script 節點，最外層的 `let`/`const` 會殘留，下次渲染直接 `Identifier has already been declared`，整段停擺）
4. 用 `addEventListener`，不要 inline `onclick`。（IIFE 內的函式不在全域作用域）
5. **不要等 `DOMContentLoaded`/`load`。** 你的 script 是在 html 注入 DOM 之後才被建立的，執行時 DOM 已就緒，而這兩個事件早已觸發過——掛了永遠不會被呼叫，元件會完全沒反應。
6. 非 module，不能用 `import`／`export`／top-level `await`。
7. 必須冪等，不要依賴上次渲染殘留的 DOM 或全域變數。
8. 查到的元素先判斷存在。可以 `fetch` 第三方 API，但該 API 必須允許 CORS，且一定要 `catch` 並有失敗畫面。

### 版面

9. 寬度固定為容器 100%，不可調。用響應式寫法，不要寫死大 px。主要情境是手機的 LINE 內建瀏覽器。
10. 高度由 `documentElement.scrollHeight` 量測、`ResizeObserver` 監看 `body` 持續自動回報，你不需要做任何事。但因此：
    - 不要用 `height: 100vh`／`100%`（會量錯）
    - 不要用 `position: absolute`/`fixed` 做超出內容高度的浮層——下拉選單、tooltip、modal 都不行。（`overflow: hidden` 會裁切，且不改變 `body` 尺寸所以連重算都不觸發）展開／收合要走文件流
    - 不要用會改變版面尺寸的無限循環動畫（每幀觸發回報，高度抖動）。`transform`/`opacity` 不影響 layout，不受此限
    - 不要讓容器變空（`body` 高度趨近 0，iframe 會塌成一條線）
    - 圖片給 `aspect-ratio` 或明確尺寸，減少載入後的高度跳動
    - 首次量測完成前外部頁面會先套用一個過渡高度，短暫的截斷或空白是正常現象，不要寫任何補償邏輯

### 環境

11. iframe 有獨立 document，CSS 天然隔離：可放心用 `body`／`*` 等全域選擇器，不需要做 scope 或 class 前綴。已套用 `* { margin: 0; padding: 0; box-sizing: border-box }`，不需重做；你的 `<style>` 是後插入的，同 specificity 下以你的規則為準，要覆寫直接寫。
12. shell 沒有設定任何背景色。需要背景就畫在自己最外層的容器上，不要設在 `body`/`html`；要融入頁面就完全不設。
13. 不要用 `prefers-color-scheme`。沒有主題傳遞管道，它跟隨的是使用者作業系統，會在淺色頁面上冒出深色元件。
14. 沒有 CSP，外部圖片／字體／CDN 都可用，但載入失敗要有降級畫面。
15. 不可用：`window.parent`／`window.top`、對外 `postMessage`、cookie／localStorage／sessionStorage、OakMega 平台的任何 API。品牌色等平台設定也不會傳入。

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

使用者通常不是工程師。技術細節（字體、間距、佈局、DOM 結構）一律自己決定，不要問——問了他也答不出來。內容與意圖不明確時可以問，但只問他答得出來的事：要顯示什麼、文案怎麼寫、資料是固定的還是要即時撈、點下去要發生什麼。給選項而不是開放式提問，一次最多一到兩件。能靠預設補完的就先產一版，讓他指著成品說要改哪裡。
