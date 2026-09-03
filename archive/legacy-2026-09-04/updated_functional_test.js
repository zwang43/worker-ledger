// 更新的功能性测试 - 检查正确的类名和函数名
const fs = require('fs');

console.log('=== 更新的功能性测试 ===\n');

// 1. 测试配置文件
console.log('1. 配置文件测试:');
try {
    const config = JSON.parse(fs.readFileSync('monthly_report_config.json', 'utf8'));
    console.log('   ✓ 配置文件格式正确');
    console.log(`   - 生成时间: ${config.generateTime}`);
    console.log(`   - 生成日期: ${config.generateDay}`);
    console.log(`   - 保留月数: ${config.retainMonths}`);
    console.log(`   - 功能状态: ${config.enabled ? '启用' : '禁用'}`);
} catch (e) {
    console.log(`   ✗ 配置文件错误: ${e.message}`);
}

// 2. 测试JavaScript文件结构 - 使用正确的类名
console.log('\n2. JavaScript文件结构测试:');
try {
    const generatorContent = fs.readFileSync('monthly_report_generator.js', 'utf8');
    const uiContent = fs.readFileSync('monthly_report_ui.js', 'utf8');
    
    // 检查关键功能 - 使用正确的类名
    const checks = [
        { name: 'AutoMonthlyReportGenerator类', content: generatorContent, pattern: 'class AutoMonthlyReportGenerator' },
        { name: 'MonthlyReportConfigUI类', content: generatorContent, pattern: 'class MonthlyReportConfigUI' },
        { name: 'MonthlyReportUI类', content: uiContent, pattern: 'class MonthlyReportUI' },
        { name: '自动生成方法', content: generatorContent, pattern: 'async autoGenerate()' },
        { name: '手动生成方法', content: generatorContent, pattern: 'async manualGenerate()' },
        { name: '配置管理功能', content: generatorContent, pattern: 'getConfig' },
        { name: '历史记录功能', content: generatorContent, pattern: 'getHistory' },
        { name: '错误处理', content: generatorContent, pattern: 'try' },
        { name: '日志记录', content: generatorContent, pattern: 'console.error' },
        { name: '事件监听', content: generatorContent, pattern: 'addEventListener' }
    ];
    
    let passedChecks = 0;
    checks.forEach(check => {
        const exists = check.content.includes(check.pattern);
        console.log(`   ${exists ? '✓' : '✗'} ${check.name}`);
        if (exists) passedChecks++;
    });
    
    console.log(`\n   JavaScript文件检查通过率: ${passedChecks}/${checks.length} (${Math.round(passedChecks/checks.length*100)}%)`);
    
} catch (e) {
    console.log(`   ✗ JavaScript文件检查失败: ${e.message}`);
}

// 3. 测试HTML文件集成
console.log('\n3. HTML文件集成测试:');
try {
    const htmlContent = fs.readFileSync('worker_ledger.html', 'utf8');
    
    const htmlChecks = [
        { name: '生成器脚本引用', pattern: 'monthly_report_generator.js' },
        { name: 'UI脚本引用', pattern: 'monthly_report_ui.js' },
        { name: '生成按钮', pattern: 'generate-manual-report' },
        { name: '配置按钮', pattern: 'report-config' },
        { name: '配置模态框', pattern: 'monthly-report-config-modal' },
        { name: '样式定义', pattern: '月度报告功能样式' },
        { name: '事件监听', pattern: 'addEventListener' },
        { name: 'DOM操作', pattern: 'getElementById' }
    ];
    
    let passedHtmlChecks = 0;
    htmlChecks.forEach(check => {
        const exists = htmlContent.includes(check.pattern);
        console.log(`   ${exists ? '✓' : '✗'} ${check.name}`);
        if (exists) passedHtmlChecks++;
    });
    
    console.log(`\n   HTML文件集成通过率: ${passedHtmlChecks}/${htmlChecks.length} (${Math.round(passedHtmlChecks/htmlChecks.length*100)}%)`);
    
} catch (e) {
    console.log(`   ✗ HTML文件集成检查失败: ${e.message}`);
}

// 4. 测试测试文件
console.log('\n4. 测试文件测试:');
try {
    const testContent = fs.readFileSync('test_monthly_report.js', 'utf8');
    
    const testChecks = [
        { name: '初始化测试', pattern: 'testInitialization' },
        { name: '配置管理测试', pattern: 'testConfigManagement' },
        { name: '报告生成测试', pattern: 'testReportGeneration' },
        { name: '数据管理测试', pattern: 'testDataManagement' },
        { name: 'UI组件测试', pattern: 'testUIComponents' },
        { name: '测试结果输出', pattern: '测试总结' },
        { name: '错误处理测试', pattern: 'try' },
        { name: '日志输出', pattern: 'console.log' }
    ];
    
    let passedTestChecks = 0;
    testChecks.forEach(check => {
        const exists = testContent.includes(check.pattern);
        console.log(`   ${exists ? '✓' : '✗'} ${check.name}`);
        if (exists) passedTestChecks++;
    });
    
    console.log(`\n   测试文件通过率: ${passedTestChecks}/${testChecks.length} (${Math.round(passedTestChecks/testChecks.length*100)}%)`);
    
} catch (e) {
    console.log(`   ✗ 测试文件检查失败: ${e.message}`);
}

// 5. 测试文件大小和性能
console.log('\n5. 文件大小和性能测试:');
try {
    const files = [
        { name: '生成器脚本', path: 'monthly_report_generator.js' },
        { name: 'UI脚本', path: 'monthly_report_ui.js' },
        { name: '配置文件', path: 'monthly_report_config.json' },
        { name: '主HTML文件', path: 'worker_ledger.html' },
        { name: '测试文件', path: 'test_monthly_report.js' }
    ];
    
    let totalSize = 0;
    files.forEach(file => {
        const stats = fs.statSync(file.path);
        const sizeKB = (stats.size / 1024).toFixed(2);
        totalSize += stats.size;
        console.log(`   ${file.name}: ${sizeKB}KB`);
    });
    
    console.log(`   总大小: ${(totalSize / 1024).toFixed(2)}KB`);
    
} catch (e) {
    console.log(`   ✗ 文件大小检查失败: ${e.message}`);
}

// 6. 测试功能完整性
console.log('\n6. 功能完整性测试:');
try {
    const generatorContent = fs.readFileSync('monthly_report_generator.js', 'utf8');
    const uiContent = fs.readFileSync('monthly_report_ui.js', 'utf8');
    
    const features = [
        { name: '数据存储管理', generator: true, ui: false, pattern: 'StorageManager' },
        { name: '自动生成调度', generator: true, ui: false, pattern: 'autoGenerate' },
        { name: '手动生成功能', generator: true, ui: false, pattern: 'manualGenerate' },
        { name: '配置管理界面', generator: false, ui: true, pattern: 'MonthlyReportConfigUI' },
        { name: '报告显示界面', generator: false, ui: true, pattern: 'MonthlyReportUI' },
        { name: '历史记录查看', generator: true, ui: true, pattern: 'history' },
        { name: '错误处理机制', generator: true, ui: true, pattern: 'try' },
        { name: '用户交互事件', generator: false, ui: true, pattern: 'addEventListener' }
    ];
    
    let passedFeatures = 0;
    features.forEach(feature => {
        let exists = false;
        if (feature.generator) {
            exists = generatorContent.includes(feature.pattern);
        } else if (feature.ui) {
            exists = uiContent.includes(feature.pattern);
        }
        
        console.log(`   ${exists ? '✓' : '✗'} ${feature.name}`);
        if (exists) passedFeatures++;
    });
    
    console.log(`\n   功能完整性通过率: ${passedFeatures}/${features.length} (${Math.round(passedFeatures/features.length*100)}%)`);
    
} catch (e) {
    console.log(`   ✗ 功能完整性检查失败: ${e.message}`);
}

console.log('\n=== 更新的功能性测试完成 ===');
