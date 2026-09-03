const { app, BrowserWindow, Menu, Tray, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const { spawn, exec } = require('child_process');
const Store = require('electron-store');
const toml = require('toml');

let mainWindow;
let tray;
let omlxProcess = null;
let bridgeProcess = null;

// 应用配置
const store = new Store();
const config = {
  app: {
    name: 'Worker Ledger AI',
    version: '1.0.0',
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600
  },
  services: {
    omlx: {
      host: '127.0.0.1',
      port: 8080,
      command: 'omlx',
      args: ['serve', '--host', '127.0.0.1', '--port', '8080']
    },
    bridge: {
      host: '127.0.0.1',
      port: 8899,
      script: path.join(__dirname, '../resources/omlx-bridge.py'),
      python: 'python3'
    }
  }
};

// 创建主窗口
function createWindow() {
  mainWindow = new BrowserWindow({
    width: config.app.width,
    height: config.app.height,
    minWidth: config.app.minWidth,
    minHeight: config.app.minHeight,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      enableRemoteModule: false,
      preload: path.join(__dirname, 'preload.js')
    },
    icon: path.join(__dirname, '../resources/icon.icns'),
    show: false
  });

  // 加载应用
  const appPath = path.join(__dirname, '../../worker_ledger_local_enhanced.html');
  if (fs.existsSync(appPath)) {
    mainWindow.loadFile(appPath);
  } else {
    // 如果找不到HTML文件，使用一个备用页面
    mainWindow.loadFile(path.join(__dirname, 'index.html'));
  }

  // 窗口准备好后显示
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  // 开发工具（仅在开发模式）
  if (process.env.NODE_ENV === 'development') {
    mainWindow.webContents.openDevTools();
  }

  // 窗口关闭时的处理
  mainWindow.on('closed', () => {
    mainWindow = null;
    stopServices();
  });
}

// 创建系统托盘
function createTray() {
  tray = new Tray(path.join(__dirname, '../resources/icon.icns'));
  
  const contextMenu = Menu.buildFromTemplate([
    {
      label: '显示应用',
      click: () => {
        if (mainWindow) {
          mainWindow.show();
          mainWindow.focus();
        }
      }
    },
    {
      label: '隐藏应用',
      click: () => {
        if (mainWindow) {
          mainWindow.hide();
        }
      }
    },
    {
      label: '启动AI服务',
      click: startServices
    },
    {
      label: '停止AI服务',
      click: stopServices
    },
    {
      label: '检查服务状态',
      click: checkServices
    },
    {
      type: 'separator'
    },
    {
      label: '设置',
      click: openSettings
    },
    {
      label: '关于',
      click: () => {
        dialog.showMessageBox(mainWindow, {
          type: 'info',
          title: '关于 Worker Ledger AI',
          message: 'Worker Ledger AI',
          detail: '版本: ' + config.app.version + '\n\n本地化AI记账工作台\n基于oMLX的智能记账应用',
          buttons: ['确定']
        });
      }
    },
    {
      type: 'separator'
    },
    {
      label: '退出',
      click: () => {
        app.quit();
      }
    }
  ]);

  tray.setContextMenu(contextMenu);
  tray.setToolTip('Worker Ledger AI - 本地化AI记账工作台');
}

// 启动oMLX服务
function startOMLXService() {
  return new Promise((resolve, reject) => {
    if (omlxProcess) {
      resolve(true);
      return;
    }

    try {
      // 检查omlx命令是否可用
      exec('which omlx', (error) => {
        if (error) {
          // 如果omlx命令不存在，尝试使用python -m omlx
          config.services.omlx.command = 'python3';
          config.services.omlx.args = ['-m', 'omlx', 'serve', '--host', '127.0.0.1', '--port', '8080'];
        }

        omlxProcess = spawn(config.services.omlx.command, config.services.omlx.args);
        
        omlxProcess.stdout.on('data', (data) => {
          console.log(`oMLX: ${data}`);
        });

        omlxProcess.stderr.on('data', (data) => {
          console.error(`oMLX Error: ${data}`);
        });

        omlxProcess.on('close', (code) => {
          console.log(`oMLX process exited with code ${code}`);
          omlxProcess = null;
        });

        // 等待服务启动
        setTimeout(() => {
          resolve(true);
        }, 3000);
      });
    } catch (error) {
      reject(error);
    }
  });
}

// 启动桥接服务
function startBridgeService() {
  return new Promise((resolve, reject) => {
    if (bridgeProcess) {
      resolve(true);
      return;
    }

    try {
      bridgeProcess = spawn(config.services.bridge.python, [config.services.bridge.script]);
      
      bridgeProcess.stdout.on('data', (data) => {
        console.log(`Bridge: ${data}`);
      });

      bridgeProcess.stderr.on('data', (data) => {
        console.error(`Bridge Error: ${data}`);
      });

      bridgeProcess.on('close', (code) => {
        console.log(`Bridge process exited with code ${code}`);
        bridgeProcess = null;
      });

      // 等待服务启动
      setTimeout(() => {
        resolve(true);
      }, 2000);
    } catch (error) {
      reject(error);
    }
  });
}

// 启动所有服务
async function startServices() {
  try {
    await startOMLXService();
    await startBridgeService();
    
    if (mainWindow) {
      dialog.showMessageBox(mainWindow, {
        type: 'info',
        title: '服务启动成功',
        message: 'oMLX和桥接服务已启动',
        buttons: ['确定']
      });
    }
  } catch (error) {
    console.error('启动服务失败:', error);
    if (mainWindow) {
      dialog.showMessageBox(mainWindow, {
        type: 'error',
        title: '服务启动失败',
        message: '无法启动AI服务，请检查安装',
        buttons: ['确定']
      });
    }
  }
}

// 停止所有服务
function stopServices() {
  if (omlxProcess) {
    omlxProcess.kill();
    omlxProcess = null;
  }
  
  if (bridgeProcess) {
    bridgeProcess.kill();
    bridgeProcess = null;
  }
}

// 检查服务状态
async function checkServices() {
  try {
    const fetch = require('node-fetch');
    
    // 检查oMLX服务
    const omlxResponse = await fetch(`http://${config.services.omlx.host}:${config.services.omlx.port}/health`);
    const omlxStatus = omlxResponse.ok ? '正常' : '异常';
    
    // 检查桥接服务
    const bridgeResponse = await fetch(`http://${config.services.bridge.host}:${config.services.bridge.port}/health`);
    const bridgeStatus = bridgeResponse.ok ? '正常' : '异常';
    
    if (mainWindow) {
      dialog.showMessageBox(mainWindow, {
        type: 'info',
        title: '服务状态',
        message: `oMLX服务: ${omlxStatus}\n桥接服务: ${bridgeStatus}`,
        buttons: ['确定']
      });
    }
  } catch (error) {
    console.error('检查服务状态失败:', error);
    if (mainWindow) {
      dialog.showMessageBox(mainWindow, {
        type: 'warning',
        title: '服务状态',
        message: 'oMLX服务: 异常\n桥接服务: 异常',
        buttons: ['确定']
      });
    }
  }
}

// 打开设置
function openSettings() {
  if (mainWindow) {
    // 这里可以打开设置窗口
    dialog.showMessageBox(mainWindow, {
      type: 'info',
      title: '设置',
      message: '设置功能开发中...',
      buttons: ['确定']
    });
  }
}

// 应用准备就绪
app.whenReady().then(() => {
  createWindow();
  createTray();
  
  // macOS特定行为
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

// 应用退出
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('before-quit', () => {
  stopServices();
});

// IPC处理程序
ipcMain.handle('check-services-status', async () => {
  try {
    const fetch = require('node-fetch');
    
    const omlxResponse = await fetch(`http://${config.services.omlx.host}:${config.services.omlx.port}/health`);
    const bridgeResponse = await fetch(`http://${config.services.bridge.host}:${config.services.bridge.port}/health`);
    
    return {
      omlx: omlxResponse.ok,
      bridge: bridgeResponse.ok
    };
  } catch (error) {
    return {
      omlx: false,
      bridge: false
    };
  }
});

ipcMain.handle('start-services', async () => {
  await startServices();
});

ipcMain.handle('stop-services', async () => {
  stopServices();
});
