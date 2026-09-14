"use strict";
const $ = (id) => document.getElementById(id);
const form = $("release-form");
const dialog = $("confirm-dialog");
let current = null;
let pending = null;
let publishing = false;
let language = "zh";
const reserved = new Set(["version", "version_code", "force_update", "update_url", "announcement", "timestamp", "last_force_version_code", "__proto__", "constructor", "prototype"]);

function showStatus(message, error = false) {
  const node = $("status");
  node.textContent = message;
  node.classList.toggle("error", error);
  node.hidden = false;
}

async function request(path, options = {}) {
  const response = await fetch(path, { ...options, cache: "no-store", credentials: "omit", signal: AbortSignal.timeout(15000) });
  let data;
  try { data = await response.json(); } catch (_) { throw new Error("服务器未返回 JSON，请检查反向代理和服务地址。"); }
  if (!response.ok) {
    const messages = {
      unauthorized: "管理员令牌无效，请检查服务器上的令牌。",
      version_conflict: "构建号冲突：已发布版本不可修改，请刷新当前版本并使用更高的构建号。",
      invalid_release: "版本信息不合法，请检查字段、双语公告和 HTTPS 下载地址。",
      storage_unavailable: "服务器暂时无法访问版本数据库，请稍后重试。",
      invalid_body: "请求正文过大或不完整，请将公告和扩展字段控制在 64 KiB 内。",
    };
    const error = new Error(messages[data.error?.code] || `请求失败（HTTP ${response.status}）`);
    error.code = data.error?.code;
    throw error;
  }
  return data;
}

function renderCurrent(data) {
  current = data;
  $("current-version").textContent = data ? data.version : "尚未发布";
  $("current-code").textContent = data ? `构建号 ${data.version_code}` : "可以创建第一个 Android 版本";
  $("current-policy").textContent = data ? (data.force_update ? "强制更新" : "普通更新") : "—";
  $("current-floor").textContent = data ? String(data.last_force_version_code || 0) : "0";
  updatePreview();
}

async function refresh() {
  $("refresh").disabled = true;
  try {
    renderCurrent(await request("/client/android"));
  } catch (error) {
    if (error.code === "no_release") renderCurrent(null);
    else {
      $("current-code").textContent = "连接失败，可点击刷新重试";
      showStatus(error.message || "连接失败，请稍后重试。", true);
    }
  } finally { $("refresh").disabled = false; }
}

function buildPayload() {
  const version = $("version").value.trim();
  if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.+-]+)?$/.test(version)) throw new Error("版本号格式不正确，例如 0.3.24。");
  const code = Number($("version-code").value);
  if (!Number.isSafeInteger(code) || code < 1 || code > 2100000000) throw new Error("构建号必须是 1–2100000000 之间的整数。");
  const url = new URL($("update-url").value.trim());
  if (url.protocol !== "https:" || url.username || url.password) throw new Error("下载地址必须是无用户名和密码的 HTTPS 地址。");
  let extra = {};
  if ($("extra-fields").value.trim()) {
    try { extra = JSON.parse($("extra-fields").value); } catch (_) { throw new Error("扩展字段不是有效的 JSON。"); }
    if (!extra || typeof extra !== "object" || Array.isArray(extra)) throw new Error("扩展字段必须是 JSON 对象。");
    for (const key of Object.keys(extra)) if (reserved.has(key)) throw new Error(`扩展字段不能覆盖 ${key}。`);
  }
  const payload = { ...extra, version, version_code: code, force_update: $("force-update").checked, update_url: $("update-url").value.trim() };
  const zh = $("announcement-zh").value.trim();
  const en = $("announcement-en").value.trim();
  if (zh || en) payload.announcement = { zh, en };
  if (new TextEncoder().encode(JSON.stringify(payload)).length > 65536) throw new Error("发布内容超过 64 KiB，请缩短公告或扩展字段。");
  return payload;
}

function updatePreview() {
  const version = $("version").value.trim();
  const force = $("force-update").checked;
  $("preview-title").textContent = version ? `发现新版本：${version}` : "发现新版本";
  $("preview-policy").textContent = force ? "强制更新" : "普通更新";
  const zh = $("announcement-zh").value.trim();
  const en = $("announcement-en").value.trim();
  $("preview-announcement").textContent = (language === "zh" ? zh || en : en || zh) || "填写公告后在这里预览。";
  $("preview-skip").textContent = force ? "应急跳过 1 天" : "跳过此版本";
  const floor = current?.last_force_version_code || 0;
  $("policy-hint").textContent = force
    ? "发布后，本次构建号将成为新的强制升级要求。"
    : floor ? `普通更新仍保留强制构建号 ${floor}：低于此构建号的客户端仍需升级。` : "普通更新保留历史强制要求，符合条件的客户端可以跳过此版本。";
}

form.addEventListener("input", updatePreview);
for (const lang of ["zh", "en"]) $("preview-" + lang).addEventListener("click", () => {
  language = lang;
  for (const other of ["zh", "en"]) {
    $("preview-" + other).classList.toggle("active", other === lang);
    $("preview-" + other).setAttribute("aria-pressed", String(other === lang));
  }
  updatePreview();
});
form.addEventListener("submit", (event) => {
  event.preventDefault();
  if (publishing || !form.reportValidity()) return;
  try {
    pending = buildPayload();
    const token = $("admin-token").value.trim();
    if (!/^[\x21-\x7e]{32,}$/.test(token)) throw new Error("管理员令牌至少需要 32 个不含空白的 ASCII 字符。");
    $("payload-preview").textContent = JSON.stringify(pending, null, 2);
    $("confirm-summary").textContent = `${pending.version} · 构建号 ${pending.version_code} · ${pending.force_update ? "强制更新" : "普通更新"}。发布成功后不可修改。`;
    $("publish-error").hidden = true;
    dialog.showModal();
  } catch (error) { showStatus(error.message, true); }
});
$("cancel-publish").addEventListener("click", () => { if (!publishing) dialog.close(); });
dialog.addEventListener("cancel", (event) => { if (publishing) event.preventDefault(); });
$("confirm-publish").addEventListener("click", async () => {
  if (publishing || !pending) return;
  publishing = true;
  $("confirm-publish").disabled = true;
  $("cancel-publish").disabled = true;
  $("confirm-publish").textContent = "正在发布…";
  $("publish-error").hidden = true;
  try {
    const published = await request("/admin/client/android/releases", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${$("admin-token").value.trim()}` },
      body: JSON.stringify(pending),
    });
    renderCurrent(published);
    dialog.close();
    showStatus(`版本 ${published.version}（构建号 ${published.version_code}）已发布。客户端将在下一次冷启动检查时获取更新。`);
    $("admin-token").value = "";
    pending = null;
    window.scrollTo({ top: 0, behavior: "smooth" });
  } catch (error) {
    $("publish-error").textContent = error.name === "TimeoutError" ? "请求超时，服务器可能已完成发布。可先返回并刷新当前版本，再重试相同内容。" : error.message || "发布失败，请检查网络后重试。";
    $("publish-error").hidden = false;
  } finally {
    publishing = false;
    $("confirm-publish").disabled = false;
    $("cancel-publish").disabled = false;
    $("confirm-publish").textContent = "确认发布";
  }
});
$("refresh").addEventListener("click", refresh);
$("server-origin").textContent = location.origin;
refresh();
