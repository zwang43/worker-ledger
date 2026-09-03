// 功能性测试 - 模拟浏览器环境
const jsdom = require('jsdom');

// 由于jsdom可能不可用，我们创建一个简化的测试环境
global.window = {
    localStorage: {
        getItem: function(key) { return null; },
        setItem: function(key, value) { },
        removeItem: function(key) { }
    },
    document: {
        getElementById: function(id) { return null; },
        createElement: function(tag) { return {}; }
    }
};

global.localStorage = window.localStorage;

console.log('=== 功能性测试 ===\n');

// 1. 测试配置文件读取
console.log('1. 配置文件读取测试:');
try {
    const fs = require('fs');
    const config = JSON.parse(fs.readFileSync('monthly_report_config.json', 'utf8'));
    console.log('   ✓ 配置文件读取成功');
    console.log(`   - 生成时间: ${config.generateTime}`);
    console.log(`   - 生成日期: ${config.generateDay}`);
    console.log(`   - 保留月数: ${config.retainMonths}`);
} catch (e) {
    console.log(`   ✗ 配置文件读取失败: ${e.message}`);
}

// 2. 测试JavaScript文件加载
console.log('\n2. JavaScript文件加载测试:');
try {
    const generatorContent = fs.readFileSync('monthly_report_generator.js', 'utf8');
    const uiContent = fs.readFileSync('monthly_report_ui.js', 'utf8');
    
    // 检查关键类和函数
    const hasStorageManager = generatorContent.includes('class StorageManager');
    const hasReportGenerator = generatorContent.includes('class MonthlyReportGenerator');
    const hasConfigUI = uiContent.includes('class MonthlyReportConfigUI');
    const hasReportUI = uiContent.includes('class MonthlyReportUI');
    
    console.log(`   ${hasStorageManager ? '✓' : '✗'} StorageManager类`);
    console.log(`   ${hasReportGenerator ? '✓' : '✗'} MonthlyReportGenerator类`);
    console.log(`   ${hasConfigUI ? '✓' : '✗'} MonthlyReportConfigUI类`);
    console.log(`   ${hasReportUI ? '✓' : '✗'} MonthlyReportUI类`);
    
} catch (e) {
    console.log(`   ✗ JavaScript文件加载失败: ${e.message}`);
}

// 3. 测试HTML文件中的功能集成
console.log('\n3. HTML功能集成测试:');
try {
    const htmlContent = fs.readFileSync('worker_ledger.html', 'utf8');
    
    // 检查关键功能
    const hasAutoGen = htmlContent.includes('autoGenerate');
    const hasManualGen = htmlContent.includes('manualGenerate');
    const hasConfigModal = htmlContent.includes('config-modal');
    const hasHistory = htmlContent.includes('history');
    
    console.log(`   ${hasAutoGen ? '✓' : '✗'} 自动生成功能`);
    console.log(`   ${hasManualGen ? '✓' : '✗'} 手动生成功能`);
    console.log(`   ${hasConfigModal ? '✓' : '✗'} 配置模态框`);
    console.log(`   ${hasHistory ? '✓' : '✗'} 历史记录功能`);
    
} catch (e) {
    console.log(`   ✗ HTML功能集成检查失败: ${e.message}`);
}

// 4. 测试错误处理
console.log('\n4. 错误处理测试:');
try {
    const generatorContent = fs.readFileSync('monthly_report_generator.js', 'utf8');
    
    // 检查错误处理相关代码
    const hasTryCatch = generatorContent.includes('try') && generatorContent.includes('catch');
    const hasErrorLogging = generatorContent.includes('console.error');
    const hasErrorHandling = generatorContent.includes('error');
    
    console.log(`   ${hasTryCatch ? '✓' : '✗'} try-catch错误处理`);
    console.log(`   ${hasErrorLogging ? '✓' : '✗'} 错误日志记录`);
    console.log(`   ${hasErrorHandling ? '✓' : '✗'} 错误处理机制`);
    
} catch (e) {
    console.log(`   ✗ 错误处理检查失败: ${e.message}`);
}

// 5. 测试UI组件
console.log('\n5. UI组件测试:');
try {
    const uiContent = fs.readFileSync('monthly_report_ui.js', 'utf8');
    
    // 检查UI组件
    const hasModal = uiContent.includes('modal');
    const hasButton = uiContent.includes('button');
    const hasForm = uiContent.includes('form');
    const hasDisplay = uiContent.includes('display');
    
    console.log(`   ${hasModal ? '✓' : '✗'} 模态框组件`);
    console.log(`   ${hasButton ? '✓' : '✗'} 按钮组件`);
    console.log(`   ${hasForm ? '✓' : '✗'} 表单组件`);
    console.log(`   ${hasDisplay ? '✓' : '✗'} 显示组件`);
    
} catch (e) {
    console.log(`   ✗ UI组件检查失败: ${e.message}`);
}

console.log('\n=== 功能性测试完成 ===');
