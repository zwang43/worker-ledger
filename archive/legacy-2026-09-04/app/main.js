/* 打工人小账本 · Electron 主进程
   职责: 拉起 AI 桥接 sidecar(动态端口) → 健康检查 → 加载 UI;
   管理模型注册表、每次启动的数据备份、UI 版本解析(升级通道)。 */
const { app, BrowserWindow, ipcMain, shell, dialog } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const http = require('http');
const net = require('net');

const APP_DIR = __dirname;
const DEFAULT_REGISTRY = path.join(APP_DIR, 'default_model_registry.json');
const STORAGE_KEY = 'wb_workspace_worker_ledger_state_v1';
const BACKUP_KEEP = 3;

/* ---------- 数据目录: 重定向到项目文件夹(自包含), 并从旧位置迁移 ----------
   项目根的标志是根目录下的 worker_ledger.html; 从可执行文件位置逐级向上找。
   注意: 打包出的 .app 必须保留在项目的 app/dist 目录树内, 否则找不到项目根,
   会退回系统默认的 ~/Library/Application Support/。 */
function findProjectDir(startDir) {
  let dir = startDir;
  for (let i = 0; i < 10; i++) {
    if (fs.existsSync(path.join(dir, 'worker_ledger.html'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
  return null;
}

function migrateLegacyUserData(newDir) {
  const legacy = path.join(app.getPath('appData'), '打工人小账本');
  if (!fs.existsSync(legacy)) return;
  if (fs.existsSync(path.join(newDir, 'Local Storage'))) return; // 已迁移过
  fs.mkdirSync(newDir, { recursive: true });
  const skip = /Cache|Crashpad|blob_storage|Shared[ _]Dictionary|GPUCache|ShaderCache|^GrShaderCache/i;
  for (const entry of fs.readdirSync(legacy)) {
    if (skip.test(entry)) continue;
    try {
      fs.cpSync(path.join(legacy, entry), path.join(newDir, entry), { recursive: true, force: true });
    } catch (e) {
      console.warn('[migrate] failed:', entry, e.message);
    }
  }
  console.log('[migrate] userData migrated:', legacy, '->', newDir);
}

const projectDir = findProjectDir(APP_DIR);
if (projectDir) {
  const dataDir = path.join(projectDir, '账本数据');
  migrateLegacyUserData(dataDir);
  fs.mkdirSync(dataDir, { recursive: true });
  app.setPath('userData', dataDir);
} else {
  console.warn('[main] 未找到项目根(worker_ledger.html), 数据仍存系统默认目录');
}

const userData = app.getPath('userData');
const registryPath = path.join(userData, 'model_registry.json');
const backupsDir = path.join(userData, 'backups');
const uiInstalledDir = path.join(userData, 'ui');

let bridgeProc = null;
let bridgePort = 0;
let mainWindow = null;

/* ---------- 基础准备 ---------- */
function ensureDirs() {
  for (const dir of [userData, backupsDir]) fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(registryPath)) {
    fs.copyFileSync(DEFAULT_REGISTRY, registryPath);
  }
}

function findFreePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.unref();
    srv.on('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const port = srv.address().port;
      srv.close(() => resolve(port));
    });
  });
}

/* ---------- UI 版本解析（升级通道: 包内 vs userData 已安装, 取新者） ---------- */
function readUiVersion(dir) {
  try {
    return fs.readFileSync(path.join(dir, 'ui_version.txt'), 'utf8').trim();
  } catch (e) {
    return '0.0.0';
  }
}

function versionGt(a, b) {
  const pa = String(a).split('.').map(Number);
  const pb = String(b).split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const x = pa[i] || 0, y = pb[i] || 0;
    if (x !== y) return x > y;
  }
  return false;
}

function resolveUiDir() {
  const bundledDir = path.join(APP_DIR, 'resources', 'ui');
  const bundledVersion = readUiVersion(bundledDir);
  const installedVersion = readUiVersion(uiInstalledDir);
  if (versionGt(installedVersion, bundledVersion) && fs.existsSync(path.join(uiInstalledDir, 'worker_ledger.html'))) {
    return { dir: uiInstalledDir, version: installedVersion, source: 'installed' };
  }
  return { dir: bundledDir, version: bundledVersion, source: 'bundled' };
}

/* ---------- 数据备份: 启动与手动各一次, 保留最近 BACKUP_KEEP 份 ---------- */
function pruneBackups() {
  const files = fs.readdirSync(backupsDir)
    .filter((f) => f.startsWith('ledger-state-') && f.endsWith('.json'))
    .sort();
  while (files.length > BACKUP_KEEP) {
    fs.unlinkSync(path.join(backupsDir, files.shift()));
  }
}

async function backupState() {
  if (!mainWindow || mainWindow.isDestroyed()) return { ok: false, reason: 'window not ready' };
  try {
    const raw = await mainWindow.webContents.executeJavaScript(
      `localStorage.getItem(${JSON.stringify(STORAGE_KEY)})`, true);
    if (!raw) return { ok: false, reason: '暂无数据' };
    const stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const file = path.join(backupsDir, `ledger-state-${stamp}.json`);
    fs.writeFileSync(file, raw, 'utf8');
    pruneBackups();
    return { ok: true, file };
  } catch (e) {
    return { ok: false, reason: e.message };
  }
}

/* ---------- AI 桥接 sidecar ---------- */
function bridgeCommand() {
  if (app.isPackaged) {
    const bin = path.join(process.resourcesPath, 'bridge-bin', 'ai_bridge');
    if (fs.existsSync(bin)) return { cmd: bin, args: [], cwd: path.dirname(bin) };
    const script = path.join(process.resourcesPath, 'bridge', 'ai_bridge.py');
    return { cmd: 'python3', args: [script], cwd: path.dirname(script) };
  }
  const script = path.join(APP_DIR, 'bridge', 'ai_bridge.py');
  return { cmd: 'python3', args: [script], cwd: path.dirname(script) };
}

function startBridge(port) {
  const { cmd, args, cwd } = bridgeCommand();
  bridgeProc = spawn(cmd, args, {
    cwd,
    env: {
      ...process.env,
      AI_BRIDGE_PORT: String(port),
      LEDGER_MODEL_REGISTRY: registryPath,
      PYTHONUNBUFFERED: '1'
    },
    stdio: ['ignore', 'pipe', 'pipe']
  });
  bridgeProc.stdout.on('data', (d) => console.log('[bridge]', String(d).trim()));
  bridgeProc.stderr.on('data', (d) => console.log('[bridge]', String(d).trim()));
  bridgeProc.on('exit', (code) => console.log('[bridge] exited', code));
}

function stopBridge() {
  if (bridgeProc && bridgeProc.exitCode === null) {
    try { bridgeProc.kill(); } catch (e) { /* ignore */ }
  }
  bridgeProc = null;
}

function healthOnce(port) {
  return new Promise((resolve) => {
    const req = http.get({ host: '127.0.0.1', port, path: '/health', timeout: 1500 }, (res) => {
      let body = '';
      res.on('data', (c) => { body += c; });
      res.on('end', () => {
        try { resolve(JSON.parse(body)); } catch (e) { resolve(null); }
      });
    });
    req.on('error', () => resolve(null));
    req.on('timeout', () => { req.destroy(); resolve(null); });
  });
}

async function waitBridgeHealthy(port, timeoutMs = 30000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const health = await healthOnce(port);
    if (health && health.ok && health.bridge) return health;
    await new Promise((r) => setTimeout(r, 500));
  }
  return null;
}

/* ---------- 窗口 ---------- */
async function createWindow() {
  bridgePort = await findFreePort();
  startBridge(bridgePort);
  const health = await waitBridgeHealthy(bridgePort);
  if (!health) {
    dialog.showErrorBox('AI 桥接启动失败',
      '桥接服务未能在 30 秒内就绪。请重试，或检查终端日志。\n（记账功能仍可离线使用）');
  }

  const ui = resolveUiDir();
  mainWindow = new BrowserWindow({
    width: 1440,
    height: 920,
    title: '打工人小账本',
    webPreferences: {
      preload: path.join(APP_DIR, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });
  mainWindow.loadFile(path.join(ui.dir, 'worker_ledger.html'));
  mainWindow.webContents.on('did-finish-load', async () => {
    mainWindow.webContents.executeJavaScript(
      `window.__LEDGER_BRIDGE_PORT__ = ${bridgePort}; true;`, true);
    // 页面初始化写 localStorage 需要一点时间, 备份重试直至有数据
    for (let i = 0; i < 5; i++) {
      await new Promise((r) => setTimeout(r, 2000));
      const result = await backupState();
      if (result.ok) break;
    }
  });
  mainWindow.on('closed', () => { mainWindow = null; });
}

/* ---------- IPC ---------- */
ipcMain.handle('bridge:info', () => ({ port: bridgePort, healthy: bridgePort > 0 }));

ipcMain.handle('registry:read', () => {
  try { return { ok: true, data: JSON.parse(fs.readFileSync(registryPath, 'utf8')) }; }
  catch (e) { return { ok: false, error: e.message }; }
});

ipcMain.handle('registry:write', (event, data) => {
  try {
    if (!data || !Array.isArray(data.models) || !data.models.length) {
      return { ok: false, error: '注册表格式不合法' };
    }
    fs.writeFileSync(registryPath, JSON.stringify(data, null, 2), 'utf8');
    return { ok: true };
  } catch (e) { return { ok: false, error: e.message }; }
});

ipcMain.handle('app:openUserData', () => shell.openPath(userData));

ipcMain.handle('app:backupNow', async () => {
  const result = await backupState();
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('backup:status', result);
  }
  return result;
});

/* ---------- 生命周期 ---------- */
app.whenReady().then(async () => {
  ensureDirs();
  await createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  stopBridge();
  app.quit();
});

app.on('before-quit', stopBridge);
