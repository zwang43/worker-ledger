// 月度报告功能UI集成脚本
// 专门用于在现有界面中集成月度报告功能

class MonthlyReportUI {
  constructor() {
    this.generator = null;
    this.configUI = null;
    this.init();
  }

  async init() {
    try {
      // 等待主应用加载完成
      if (document.readyState === 'loading') {
        await new Promise(resolve => {
          document.addEventListener('DOMContentLoaded', resolve);
        });
      }
      
      // 初始化月度报告系统
      this.generator = await window.initMonthlyReportSystem();
      this.configUI = new window.MonthlyReportConfigUI();
      this.configUI.generator = this.generator;
      
      // 绑定UI事件
      this.bindEvents();
      
      console.log('月度报告UI集成完成');
    } catch (error) {
      console.error('月度报告UI初始化失败:', error);
    }
  }

  bindEvents() {
    // 绑定导航栏中的生成按钮
    const generateBtn = document.getElementById('generate-manual-report');
    if (generateBtn) {
      generateBtn.addEventListener('click', () => {
        this.showManualReportModal();
      });
    }

    // 绑定导航栏中的配置按钮
    const configBtn = document.getElementById('configure-monthly-report');
    if (configBtn) {
      configBtn.addEventListener('click', () => {
        this.showConfigModal();
      });
    }

    // 绑定月度总结页面中的生成按钮
    const monthlyReportBtn = document.getElementById('generate-monthly-report-btn');
    if (monthlyReportBtn) {
      monthlyReportBtn.addEventListener('click', () => {
        this.generateCurrentMonthReport();
      });
    }

    // 绑定手动生成报告模态框的确认按钮
    const confirmGenerateBtn = document.getElementById('confirm-generate');
    if (confirmGenerateBtn) {
      confirmGenerateBtn.addEventListener('click', async () => {
        await this.handleManualGenerate();
      });
    }

    // 绑定配置保存按钮
    const saveConfigBtn = document.getElementById('save-config');
    if (saveConfigBtn) {
      saveConfigBtn.addEventListener('click', () => {
        this.handleSaveConfig();
      });
    }

    // 绑定历史报告按钮
    const historyBtn = document.getElementById('view-report-history');
    if (historyBtn) {
      historyBtn.addEventListener('click', () => {
        this.showHistoryModal();
      });
    }

    // 绑定关闭按钮
    document.querySelectorAll('.close, .cancel').forEach(button => {
      button.addEventListener('click', (e) => {
        const modal = e.target.closest('.modal');
        if (modal) {
          modal.style.display = 'none';
        }
      });
    });

    // 绑定下载报告按钮
    const downloadBtn = document.getElementById('download-report');
    if (downloadBtn) {
      downloadBtn.addEventListener('click', () => {
        this.downloadCurrentReport();
      });
    }

    // 绑定分享报告按钮
    const shareBtn = document.getElementById('share-report');
    if (shareBtn) {
      shareBtn.addEventListener('click', () => {
        this.shareCurrentReport();
      });
    }

    // 定期更新状态
    setInterval(() => {
      this.updateStatus();
    }, 60000);
  }

  // 显示手动生成报告模态框
  showManualReportModal() {
    const modal = document.getElementById('manual-report-modal');
    if (modal) {
      // 设置默认值为当前年月
      const now = new Date();
      document.getElementById('manual-report-year').value = now.getFullYear();
      document.getElementById('manual-report-month').value = now.getMonth() + 1;
      modal.style.display = 'block';
    }
  }

  // 显示配置模态框
  showConfigModal() {
    const modal = document.getElementById('monthly-report-config-modal');
    if (modal) {
      // 加载当前配置
      const config = this.generator.config;
      document.getElementById('generate-time').value = config.generateTime;
      document.getElementById('generate-day').value = config.generateDay;
      document.getElementById('auto-save').checked = config.autoSave;
      document.getElementById('notification').checked = config.notification;
      document.getElementById('retain-months').value = config.retainMonths;
      modal.style.display = 'block';
    }
  }

  // 生成当前月度报告
  async generateCurrentMonthReport() {
    try {
      const now = new Date();
      const year = now.getFullYear();
      const month = now.getMonth();
      
      // 显示加载状态
      const btn = document.getElementById('generate-monthly-report-btn');
      const originalText = btn.innerHTML;
      btn.innerHTML = '<svg data-page-node-id="JIq0oo3UbijjmgrafqntF3" aria-hidden="true" class="app-icon" viewBox="0 0 24 24"><use data-page-node-id="HX5jkd6q4NSEtt8FoLVbrO" href="#icon-clock"></use></svg><span>生成中...</span>';
      btn.disabled = true;
      
      // 生成报告
      const report = await this.generator.generateManualReport(year, month);
      
      // 显示报告
      this.configUI.showGeneratedReport(report);
      
      // 显示成功提示
      this.configUI.showToast('月度账单报告生成成功！', 'success');
      
      // 恢复按钮状态
      btn.innerHTML = originalText;
      btn.disabled = false;
      
    } catch (error) {
      console.error('生成报告失败:', error);
      this.configUI.showToast('生成报告失败：' + error.message, 'error');
      
      // 恢复按钮状态
      const btn = document.getElementById('generate-monthly-report-btn');
      btn.innerHTML = '<svg data-page-node-id="JIq0oo3UbijjmgrafqntF3" aria-hidden="true" class="app-icon" viewBox="0 0 24 24"><use data-page-node-id="HX5jkd6q4NSEtt8FoLVbrO" href="#icon-receipt"></use></svg><span>生成月度账单报告</span>';
      btn.disabled = false;
    }
  }

  // 处理手动生成
  async handleManualGenerate() {
    const year = parseInt(document.getElementById('manual-report-year')?.value);
    const month = parseInt(document.getElementById('manual-report-month')?.value) - 1;
    
    if (year && month !== undefined) {
     try {
       const report = await this.generator.generateManualReport(year, month);
       const modalElement = document.getElementById('manual-report-modal');
       if (modalElement) modalElement.style.display = 'none';
       this.configUI.showGeneratedReport(report);
       this.configUI.showToast('报告生成成功！', 'success');
      } catch (error) {
        this.configUI.showToast('生成失败：' + error.message, 'error');
      }
    }
  }

  // 处理配置保存
  handleSaveConfig() {
    const config = {
      generateTime: document.getElementById('generate-time')?.value || '09:00',
      generateDay: parseInt(document.getElementById('generate-day')?.value) || 1,
      autoSave: document.getElementById('auto-save')?.checked !== false,
      notification: document.getElementById('notification')?.checked !== false,
      retainMonths: parseInt(document.getElementById('retain-months')?.value) || 12
    };
    
   this.configUI.updateConfig(config);
   const configModal = document.getElementById('monthly-report-config-modal');
   if (configModal) configModal.style.display = 'none';
 }

  // 显示历史报告模态框
  async showHistoryModal() {
    try {
      const history = await this.generator.getGenerationHistory();
      const historyList = document.getElementById('history-list');
      
      if (historyList) {
        if (history.length === 0) {
          historyList.innerHTML = '<p>暂无历史报告</p>';
        } else {
          historyList.innerHTML = history.map(doc => `
            <div class="history-item">
              <div class="history-header">
                <h4>${doc.title}</h4>
                <span class="history-date">${new Date(doc.createdAt).toLocaleDateString()}</span>
              </div>
              <div class="history-actions">
                <button class="btn btn-secondary" onclick="window.viewHistoryReport('${doc.id}')">查看</button>
                <button class="btn btn-secondary" onclick="window.downloadHistoryReport('${doc.id}')">下载</button>
              </div>
            </div>
          `).join('');
       }
       
       const historyModal = document.getElementById('history-modal');
       if (historyModal) historyModal.style.display = 'block';
     }
   } catch (error) {
     console.error('获取历史报告失败:', error);
     this.configUI.showToast('获取历史报告失败：' + error.message, 'error');
    }
  }

  // 下载当前报告
  downloadCurrentReport() {
    const modal = document.getElementById('generated-report-modal');
    const content = document.getElementById('generated-report-content');
    
    if (modal && content) {
      const reportText = content.querySelector('pre')?.textContent || content.textContent;
      const blob = new Blob([reportText], { type: 'text/markdown' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `月度账单报告_${new Date().toLocaleDateString('zh-CN')}.md`;
      a.click();
      URL.revokeObjectURL(url);
    }
  }

  // 分享当前报告
  async shareCurrentReport() {
    const modal = document.getElementById('generated-report-modal');
    const content = document.getElementById('generated-report-content');
    
    if (modal && content) {
      const reportText = content.querySelector('pre')?.textContent || content.textContent;
      
      if (navigator.share) {
        try {
          await navigator.share({
            title: '月度账单报告',
            text: reportText,
            url: window.location.href
          });
        } catch (error) {
          console.error('分享失败:', error);
        }
      } else {
        // 复制到剪贴板
        try {
          await navigator.clipboard.writeText(reportText);
          this.configUI.showToast('报告已复制到剪贴板！', 'success');
        } catch (error) {
          this.configUI.showToast('分享失败，请手动复制', 'error');
        }
      }
    }
  }

  // 更新状态显示
  updateStatus() {
    const statusElement = document.getElementById('monthly-report-status');
    if (statusElement && this.generator) {
      const now = new Date();
      const nextGeneration = this.generator.getNextGenerationTime(now);
      const timeUntilNext = nextGeneration.getTime() - now.getTime();
      
      if (timeUntilNext > 0) {
        const days = Math.floor(timeUntilNext / 1000 / 60 / 60 / 24);
        const hours = Math.floor((timeUntilNext % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        statusElement.textContent = `下次自动生成: ${days}天${hours}小时后`;
        statusElement.style.display = 'block';
      } else {
        statusElement.textContent = '等待生成...';
        statusElement.style.display = 'block';
      }
    }
  }
}

// 初始化UI
document.addEventListener('DOMContentLoaded', () => {
  new MonthlyReportUI();
});

// 导出
window.MonthlyReportUI = MonthlyReportUI;
