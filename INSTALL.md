# 安裝 OakMega Developer plugin

> 你**不需要懂程式**。依你使用的 Claude Code 版本，選下面其中一種。

---

## A. 桌面 / 網頁版 Claude Code（多數人用這個）

1. 開啟 Claude Code，右上角進入 **Customize**（自訂）。
2. 左側 **Personal plugins** 旁邊按 **＋** → **Create plugin** → **Add marketplace**。
3. 在 **URL** 欄位貼上：

   ```
   <你的GitHub帳號>/OakMega-Developer-Plugin
   ```

   按 **Sync**。
4. 清單會出現 **oakmega-developer**，按 **Install**。
5. 依提示重新啟動 Claude Code。

> 注意：這個欄位只接受 GitHub `帳號/repo` 或 git 網址，**不能填本機資料夾路徑**。

---

## B. 終端機版 Claude Code（CLI）

在 Claude Code 輸入框貼上這兩行（一次一行）：

```
/plugin marketplace add <你的GitHub帳號>/OakMega-Developer-Plugin
```

```
/plugin install oakmega-developer@oakmega-developer
```

> 或只輸入 `/plugin`，從選單裡找到 **oakmega-developer** 點 Install。安裝後依提示重新啟動。

---

## 裝好之後怎麼用

在 Claude Code 輸入框打 **`/web-tool-component`**：

- `/web-tool-component`
  → 先問你要做什麼元件。
- `/web-tool-component 表單題目下面加一個計算機`
  → 直接把需求帶進流程。

> 也可以直接用講的，例如「幫我在**優惠券**頁面加一個倒數計時的**客製化元件**」，Claude 一樣會接手。

## 你會被要求做的事

如果你的元件需要讀取頁面上既有的資料（例如使用者已經填的內容），Claude 會請你：

- 用電腦版 Chrome 打開那個頁面，按 `Cmd+S` 存成「網頁，完整」
- 或打開開發者工具截一張圖給它

它會一步一步告訴你怎麼做、你會看到什麼。照著做就好，看不懂就直接說「我看不到你講的那個」。

> 這些存檔可能含有你自己的個人資料，**不要上傳到公開的地方**。專案的 `.gitignore` 已經幫你擋掉常見的存檔路徑。

## 更新 plugin

- 桌面版：在 Personal plugins 裡對 marketplace 按 re-sync / update。
- CLI 版：

  ```
  /plugin marketplace update oakmega-developer
  ```

  再重新啟動 Claude Code。
