/* 预加载脚本: 以最小面暴露主进程能力给 UI（模型面板等） */
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('ledgerApp', {
  bridgeInfo: () => ipcRenderer.invoke('bridge:info'),
  readRegistry: () => ipcRenderer.invoke('registry:read'),
  writeRegistry: (data) => ipcRenderer.invoke('registry:write', data),
  openDataDir: () => ipcRenderer.invoke('app:openUserData'),
  backupNow: () => ipcRenderer.invoke('app:backupNow'),
  onBackupStatus: (cb) => ipcRenderer.on('backup:status', (_event, msg) => cb(msg))
});
