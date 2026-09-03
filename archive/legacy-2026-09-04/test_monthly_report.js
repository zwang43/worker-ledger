// 月度报告功能测试脚本
// 用于验证自动月度报告生成功能是否正常工作

class MonthlyReportTest {
  constructor() {
    this.testResults = [];
    this.generator = null;
  }

  // 添加测试结果
  addTestResult(testName, passed, message = '') {
    this.testResults.push({
      name: testName,
      passed: passed,
      message: message
    });
    
    const status = passed ? '✓' : '✗';
    console.log(`${status} ${testName}: ${message}`);
  }

  // 运行所有测试
  async runAllTests() {
    console.log('开始测试月度报告功能...');
    
    try {
      await this.testInitialization();
      await this.testConfiguration();
      await this.testReportGeneration();
      await this.testDataManagement();
      await this.testUIComponents();
      
      this.printTestSummary();
    } catch (error) {
      console.error('测试过程中发生错误:', error);
    }
  }

  // 测试初始化
  async testInitialization() {
    console.log('\n--- 测试初始化 ---');
    
    try {
      // 测试StorageManager
      const storageManager = new StorageManager();
      await storageManager.init();
      this.addTestResult('StorageManager初始化', true);
      
      // 测试DocumentManager
      const documentManager = new DocumentManager();
      const reports = await documentManager.getMonthlyReports();
      this.addTestResult('DocumentManager初始化', true);
      
      // 测试AutoMonthlyReportGenerator
      this.generator = new AutoMonthlyReportGenerator();
      await this.generator.init();
      this.addTestResult('AutoMonthlyReportGenerator初始化', true);
      
    } catch (error) {
      this.addTestResult('初始化测试', false, error.message);
    }
  }

  // 测试配置管理
  async testConfiguration() {
    console.log('\n--- 测试配置管理 ---');
    
    try {
      // 测试默认配置
      const defaultConfig = {
        generateTime: '09:00',
        generateDay: 1,
        autoSave: true,
        notification: true,
        retainMonths: 12
      };
      
      this.addTestResult('默认配置检查', 
        JSON.stringify(this.generator.config) === JSON.stringify(defaultConfig),
        '默认配置正确');
      
      // 测试配置保存和加载
      this.generator.config.generateTime = '10:00';
      this.generator.saveConfig();
      
      const newGenerator = new AutoMonthlyReportGenerator();
      await newGenerator.init();
      
      this.addTestResult('配置持久化', 
        newGenerator.config.generateTime === '10:00',
        '配置保存和加载正常');
      
    } catch (error) {
      this.addTestResult('配置管理测试', false, error.message);
    }
  }

  // 测试报告生成
  async testReportGeneration() {
    console.log('\n--- 测试报告生成 ---');
    
    try {
      // 创建测试数据
      const testTransactions = [
        { 日期: '2024-08-01', 分类: '吃饭', 金额: 25.00, 备注: '午餐' },
        { 日期: '2024-08-01', 分类: '交通', 金额: 10.00, 备注: '地铁' },
        { 日期: '2024-08-02', 分类: '房租', 金额: 3000.00, 备注: '8月房租' },
        { 日期: '2024-08-05', 分类: '购物', 金额: 150.00, 备注: '生活用品' },
        { 日期: '2024-08-10', 分类: '娱乐', 金额: 200.00, 备注: '电影' }
      ];
      
      // 保存测试数据
      await this.generator.storageManager.saveTransactions(testTransactions);
      this.addTestResult('测试数据保存', true);
      
      // 测试月度报告生成
      const report = await this.generator.createMonthlyReport(2024, 7); // 2024年8月
      this.addTestResult('月度报告生成', 
        report && report.title && report.statistics,
        '报告生成成功');
      
      // 测试报告格式
      const formattedReport = this.generator.formatReport(report);
      this.addTestResult('报告格式化', 
        formattedReport.includes('月度账单报告') && formattedReport.includes('收支统计'),
        '报告格式正确');
      
      // 测试手动生成
      const manualReport = await this.generator.generateManualReport(2024, 7);
      this.addTestResult('手动报告生成', 
        manualReport && manualReport.id === report.id,
        '手动生成成功');
      
    } catch (error) {
      this.addTestResult('报告生成测试', false, error.message);
    }
  }

  // 测试数据管理
  async testDataManagement() {
    console.log('\n--- 测试数据管理 ---');
    
    try {
      // 测试报告保存
      const testReport = {
        id: 'test_report',
        title: '测试报告',
        content: '# 测试报告内容',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
      
      await this.generator.documentManager.saveMonthlyReports([testReport]);
      this.addTestResult('报告保存', true);
      
      // 测试报告读取
      const reports = await this.generator.documentManager.getMonthlyReports();
      this.addTestResult('报告读取', 
        reports.length > 0 && reports[0].id === 'test_report',
        '报告读取成功');
      
      // 测试旧报告清理
      this.generator.config.retainMonths = 1; // 只保留1个月
      await this.generator.cleanupOldReports();
      this.addTestResult('旧报告清理', true);
      
    } catch (error) {
      this.addTestResult('数据管理测试', false, error.message);
    }
  }

  // 测试UI组件
  async testUIComponents() {
    console.log('\n--- 测试UI组件 ---');
    
    try {
      // 测试配置UI
      const configUI = new MonthlyReportConfigUI();
      this.addTestResult('配置UI创建', true);
      
      // 测试状态更新
      configUI.generator = this.generator;
      configUI.updateStatus();
      this.addTestResult('状态更新', true);
      
      // 测试提示功能
      configUI.showToast('测试消息', 'success');
      this.addTestResult('提示功能', true);
      
    } catch (error) {
      this.addTestResult('UI组件测试', false, error.message);
    }
  }

  // 打印测试总结
  printTestSummary() {
    console.log('\n=== 测试总结 ===');
    
    const passed = this.testResults.filter(r => r.passed).length;
    const total = this.testResults.length;
    
    console.log(`总测试数: ${total}`);
    console.log(`通过: ${passed}`);
    console.log(`失败: ${total - passed}`);
    
    if (passed < total) {
      console.log('\n失败的测试:');
      this.testResults.filter(r => !r.passed).forEach(result => {
        console.log(`- ${result.name}: ${result.message}`);
      });
    } else {
      console.log('\n所有测试都通过了！🎉');
    }
  }
}

// 运行测试
if (typeof window !== 'undefined') {
  // 在浏览器环境中运行
  document.addEventListener('DOMContentLoaded', async () => {
    const test = new MonthlyReportTest();
    await test.runAllTests();
  });
} else {
  // 在Node.js环境中运行
  const test = new MonthlyReportTest();
  test.runAllTests();
}

// 配置管理测试
async function testConfigManagement() {
    console.log('--- 测试配置管理 ---');
    
    try {
        // 测试配置读取
        const config = await generator.getConfig();
        console.log('✓ 配置读取成功');
        console.log(`  - 生成时间: ${config.generateTime}`);
        console.log(`  - 生成日期: ${config.generateDay}`);
        console.log(`  - 保留月数: ${config.retainMonths}`);
        
        // 测试配置更新
        const newConfig = {
            ...config,
            generateTime: '10:00',
            generateDay: 5
        };
        
        await generator.updateConfig(newConfig);
        console.log('✓ 配置更新成功');
        
        // 验证配置更新
        const updatedConfig = await generator.getConfig();
        if (updatedConfig.generateTime === '10:00' && updatedConfig.generateDay === 5) {
            console.log('✓ 配置验证成功');
        } else {
            console.log('✗ 配置验证失败');
        }
        
        return true;
    } catch (error) {
        console.error('✗ 配置管理测试失败:', error.message);
        return false;
    }
}
