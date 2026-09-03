/* App 专属: 模型管理面板（仅存在于 App 的 UI 资源副本中）
   - 浮动按钮 → 弹窗: oMLX 连接状态 / 已加载模型 / 切换激活模型 / 新增模型条目
   - 模型注册表由主进程读写, 桥接每次解析时读取, 切换即时生效 */
(function () {
  'use strict';

  let port = (window.__LEDGER_BRIDGE_PORT__ || 0);
  let registry = null;
  let msg;
  let healthSelect;

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  async function bridgeInfo() {
    if (window.ledgerApp) {
      const info = await window.ledgerApp.bridgeInfo();
      if (info && info.port) return info.port;
    }
    return port;
  }

  async function fetchHealth() {
    const p = await bridgeInfo();
    if (!p) return null;
    try {
      const res = await fetch(`http://127.0.0.1:${p}/health`, { cache: 'no-store' });
      return await res.json();
    } catch (e) {
      return null;
    }
  }

  function ensureStyles() {
    if (document.getElementById('model-panel-style')) return;
    const style = document.createElement('style');
    style.id = 'model-panel-style';
    style.textContent = `
      #model-fab { position: fixed; right: 18px; bottom: 18px; z-index: 9999; min-height: 40px;
        padding: 8px 16px; border-radius: 999px; font-size: 13px; font-weight: 700; cursor: pointer;
        box-shadow: 0 4px 14px rgba(0,0,0,.18); }
      #model-dialog { position: fixed; inset: 0; z-index: 10000; display: none; align-items: center;
        justify-content: center; background: rgba(0,0,0,.45); }
      #model-dialog.open { display: flex; }
      .model-card { width: min(520px, 92vw); max-height: 84vh; overflow: auto; background: var(--surface, #fff);
        color: var(--ink, #222); border-radius: 16px; padding: 18px; display: grid; gap: 12px; }
      .model-card h3 { margin: 0; font-size: 16px; }
      .model-health { font-size: 13px; line-height: 1.6; color: var(--muted, #666); white-space: pre-line;
        border: 1px dashed var(--line, #ccc); border-radius: 10px; padding: 10px 12px; }
      .model-row { display: flex; align-items: center; gap: 10px; padding: 10px 12px;
        border: 1px solid var(--line, #ddd); border-radius: 12px; font-size: 13px; }
      .model-row.active { border-color: var(--positive, #2e7d32); background: var(--positive-pale, #e8f5e9); }
      .model-row .grow { flex: 1 1 auto; min-width: 0; }
      .model-row small { color: var(--muted, #888); display: block; }
      .model-actions { display: flex; gap: 8px; flex-wrap: wrap; }
      .model-actions button, .model-row button { cursor: pointer; font-size: 13px; min-height: 34px;
        padding: 4px 12px; border-radius: 10px; border: 1px solid var(--line, #ccc); background: var(--surface, #fff); }
      .model-actions button.primary { background: var(--positive-strong, #2e7d32); color: #fff; border-color: transparent; }
      .model-add { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; font-size: 13px; }
      .model-add select { flex: 1 1 200px; min-height: 34px; }
      .model-msg { font-size: 12px; color: var(--muted, #888); min-height: 16px; }
    `;
    document.head.appendChild(style);
  }

  function describeHealth(h) {
    if (!h) return '桥接不可达（App 正在启动或已退出）';
    if (!h.online) return 'oMLX 离线 — 请打开菜单栏 oMLX 并加载模型';
    const load = h.loaded ? '已加载 ✓' : '未加载 ✗（请在 oMLX 里加载该模型）';
    return [
      'oMLX 在线 ✓',
      `激活模型: ${h.active}（${h.model}）`,
      `加载状态: ${load} | Prompt 档案: ${h.promptProfile} | 思考: ${h.think ? '开' : '关'}`,
      `oMLX 已加载: ${(h.models || []).join(', ') || '（无）'}`
    ].join('\n');
  }

  function renderRows(card) {
    const list = el('div', 'model-rows');
    (registry.models || []).forEach((m) => {
      const isActive = m.id === registry.active;
      const row = el('div', 'model-row' + (isActive ? ' active' : ''));
      const grow = el('div', 'grow');
      grow.appendChild(el('div', '', `${isActive ? '● ' : ''}${m.name}`));
      grow.appendChild(el('small', '', `${m.modelId || '(modelId 待填)'} · ${m.promptProfile} · 思考${m.think ? '开' : '关'}`));
      row.appendChild(grow);
      if (!isActive) {
        const btn = el('button', '', '切换');
        btn.type = 'button';
        btn.addEventListener('click', async () => {
          registry.active = m.id;
          const result = await window.ledgerApp.writeRegistry(registry);
          msg.textContent = result.ok ? '已切换，立即生效 ✓' : ('保存失败: ' + result.error);
          refresh(card);
        });
        row.appendChild(btn);
      } else {
        row.appendChild(el('span', '', '使用中'));
      }
      list.appendChild(row);
    });
    card.insertBefore(list, card.querySelector('.model-add'));
  }

  function renderAddRow(card) {
    healthSelect = el('select');
    healthSelect.setAttribute('aria-label', '从 oMLX 已加载模型选择');
    const addBtn = el('button', 'primary', '新增条目');
    addBtn.type = 'button';
    const wrap = el('div', 'model-add');
    wrap.appendChild(el('span', '', '从 oMLX 已加载模型新增:'));
    wrap.appendChild(healthSelect);
    wrap.appendChild(addBtn);

    addBtn.addEventListener('click', async () => {
      const modelId = healthSelect.value;
      if (!modelId) { msg.textContent = '请先选择一个 oMLX 中的模型'; return; }
      const id = 'model-' + Date.now();
      registry.models.push({
        id,
        name: modelId,
        endpoint: 'http://127.0.0.1:8000/v1',
        modelId,
        think: false,
        promptProfile: 'generic-full'
      });
      const result = await window.ledgerApp.writeRegistry(registry);
      if (result.ok) {
        msg.textContent = `已新增「${modelId}」（generic-full 档案）。微调模型请把 promptProfile 改为 finetune-compressed`;
        refresh(card);
      } else {
        msg.textContent = '保存失败: ' + result.error;
      }
    });
    card.appendChild(wrap);
  }

  async function refresh(card) {
    card.querySelectorAll('.model-rows, .model-health').forEach((n) => n.remove());
    const health = await fetchHealth();
    const healthBox = el('div', 'model-health', describeHealth(health));
    card.insertBefore(healthBox, card.querySelector('.model-add'));

    const regResult = await window.ledgerApp.readRegistry();
    if (regResult.ok) registry = regResult.data;
    if (registry) renderRows(card);
    if (health && health.online) {
      const existing = new Set((registry ? registry.models : []).map((m) => m.modelId));
      healthSelect.innerHTML = '';
      (health.models || []).forEach((id) => {
        if (existing.has(id)) return;
        const opt = document.createElement('option');
        opt.value = id; opt.textContent = id;
        healthSelect.appendChild(opt);
      });
    }
  }

  function openDialog() {
    ensureStyles();
    let dialog = document.getElementById('model-dialog');
    if (!dialog) {
      dialog = el('div');
      dialog.id = 'model-dialog';
      const card = el('div', 'model-card');
      card.appendChild(el('h3', '', '模型管理'));
      const actions = el('div', 'model-actions');
      const refreshBtn = el('button', '', '刷新状态');
      refreshBtn.type = 'button';
      refreshBtn.addEventListener('click', () => refresh(card));
      const backupBtn = el('button', '', '立即备份账本');
      backupBtn.type = 'button';
      backupBtn.addEventListener('click', async () => {
        const r = await window.ledgerApp.backupNow();
        msg.textContent = r.ok ? '已备份到数据目录 ✓' : ('备份失败: ' + (r.reason || '未知'));
      });
      const dirBtn = el('button', '', '打开数据目录');
      dirBtn.type = 'button';
      dirBtn.addEventListener('click', () => window.ledgerApp.openDataDir());
      const closeBtn = el('button', '', '关闭');
      closeBtn.type = 'button';
      closeBtn.addEventListener('click', () => dialog.classList.remove('open'));
      actions.append(refreshBtn, backupBtn, dirBtn, closeBtn);
      card.appendChild(actions);
      msg = el('div', 'model-msg', '');
      card.appendChild(msg);
      renderAddRow(card);
      dialog.appendChild(card);
      dialog.addEventListener('click', (e) => {
        if (e.target === dialog) dialog.classList.remove('open');
      });
      document.body.appendChild(dialog);
    }
    dialog.classList.add('open');
    refresh(dialog.querySelector('.model-card'));
  }

  function mount() {
    if (!window.ledgerApp) return; // 非 App 环境(直接浏览器打开)不注入
    ensureStyles();
    const fab = el('button', '', '🤖 模型');
    fab.id = 'model-fab';
    fab.type = 'button';
    fab.addEventListener('click', openDialog);
    document.body.appendChild(fab);
    bridgeInfo().then((p) => { port = p; });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mount);
  } else {
    mount();
  }
})();
