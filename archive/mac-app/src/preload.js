const { contextBridge, ipcRenderer } = require('electron');

// 向渲染进程暴露API
contextBridge.exposeInMainWorld('electronAPI', {
  // 检查服务状态
  checkServicesStatus: () => ipcRenderer.invoke('check-services-status'),
  
  // 启动服务
  startServices: () => ipcRenderer.invoke('start-services'),
  
  // 停止服务
  stopServices: () => ipcRenderer.invoke('stop-services'),
  
  // 平台信息
  platform: process.platform,
  version: process.versions.electron
});

// 向渲染进程暴露Node.js模块（安全的方式）
contextBridge.exposeInMainWorld('nodeAPI', {
  fs: {
    readFile: (path) => window.electronAPI.readFile(path),
    writeFile: (path, data) => window.electronAPI.writeFile(path, data),
    existsSync: (path) => window.electronAPI.existsSync(path)
  }
});
