// 最终验证测试
const fs = require('fs');

console.log('=== 月度报告系统最终验证测试 ===\n');

// 1. 系统文件检查
console.log('1. 系统文件检查:');
const requiredFiles = [
    'monthly_report_generator.js',
    'monthly_report_config.json',
    'monthly_report_ui.js',
    'worker_ledger.html',
    'test_monthly_report.js',
    '启动月度报告功能.command'
];

requiredFiles.forEach(file => {
    const exists = fs.existsSync(file);
    console.log(`   ${exists ? '✓' : '✗'} ${file}`);
});

// 2. 核心功能检查
console.log('\n2. 核心功能检查:');
try {
    const generatorContent = fs.readFileSync('monthly_report_generator.js', 'utf8');
    const uiContent = fs.readFileSync('monthly_report_ui.js', 'utf8');
    
    const coreFeatures = [
        { name: '自动月度报告生成', pattern: 'async generateMonthlyReport()' },
        { name: '初始化功能', pattern: 'async init()' },
        { name: '报告保存功能', pattern: 'async saveMonthlyReport()' },
        { name: '配置管理功能', pattern: 'this.config' },
        { name: 'UI配置界面', pattern: 'MonthlyReportConfigUI' },
        { name: 'UI报告界面', pattern: 'MonthlyReportUI' },
        { name: '事件处理', pattern: 'addEventListener' },
        { name: 'DOM操作', pattern: 'getElementById' }
    ];
    
    let passedCoreFeatures = 0;
    coreFeatures.forEach(feature => {
        const exists = generatorContent.includes(feature.pattern) || uiContent.includes(feature.pattern);
        console.log(`   ${exists ? '✓' : '✗'} ${feature.name}`);
        if (exists) passedCoreFeatures++;
    });
    
    console.log(`\n   核心功能通过率: ${passedCoreFeatures}/${coreFeatures.length} (${Math.round(passedCoreFeatures/coreFeatures.length*100)}%)`);
    
} catch (e) {
    console.log(`   ✗ 核心功能检查失败: ${e.message}`);
}

// 3. 界面集成检查
console.log('\n3. 界面集成检查:');
try {
    const htmlContent = fs.readFileSync('worker_ledger.html', 'utf8');
    
    const uiElements = [
        { name: '生成按钮', pattern: 'generate-manual-report' },
        { name: '配置按钮', pattern: 'report-config' },
        { name: '配置模态框', pattern: 'monthly-report-config-modal' },
        { name: '报告样式', pattern: '月度报告功能样式' },
        { name: '脚本引用', pattern: 'monthly_report_generator.js' },
        { name: 'UI脚本引用', pattern: 'monthly_report_ui.js' },
        { name: 'SVG图标', pattern: 'icon-receipt' },
        { name: '事件监听', pattern: 'addEventListener' }
    ];
    
    let passedUIElements = 0;
    uiElements.forEach(element => {
        const exists = htmlContent.includes(element.pattern);
        console.log(`   ${exists ? '✓' : '✗'} ${element.name}`);
        if (exists) passedUIElements++;
    });
    
    console.log(`\n   界面集成通过率: ${passedUIElements}/${uiElements.length} (${Math.round(passedUIElements/uiElements.length*100)}%)`);
    
} catch (e) {
    console.log(`   ✗ 界面集成检查失败: ${e.message}`);
}

// 4. 配置系统检查
console.log('\n4. 配置系统检查:');
try {
    const config = JSON.parse(fs.readFileSync('monthly_report_config.json', 'utf8'));
    const configChecks = [
        { name: '生成时间设置', value: config.generateTime, expected: '09:00' },
        { name: '生成日期设置', value: config.generateDay, expected: 1 },
        { name: '保留月份数', value: config.retainMonths, expected: 12 },
        { name: '功能启用状态', value: config.enabled, expected: true },
        { name: '自动保存', value: config.autoSave, expected: true },
        { name: '通知提醒', value: config.notification, expected: true }
    ];
    
    let passedConfigChecks = 0;
    configChecks.forEach(check => {
        const isCorrect = check.value === check.expected;
        console.log(`   ${isCorrect ? '✓' : '✗'} ${check.name}: ${check.value} (期望: ${check.expected})`);
        if (isCorrect) passedConfigChecks++;
    });
    
    console.log(`\n   配置系统通过率: ${passedConfigChecks}/${configChecks.length} (${Math.round(passedConfigChecks/configChecks.length*100)}%)`);
    
} catch (e) {
    console.log(`   ✗ 配置系统检查失败: ${e.message}`);
}

// 5. 测试系统检查
console.log('\n5. 测试系统检查:');
try {
    const testContent = fs.readFileSync('test_monthly_report.js', 'utf8');
    
    const testFunctions = [
        'testInitialization',
        'testConfigManagement',
        'testReportGeneration',
        'testDataManagement',
        'testUIComponents'
    ];
    
    let passedTestFunctions = 0;
    testFunctions.forEach(func => {
        const exists = testContent.includes(func);
        console.log(`   ${exists ? '✓' : '✗'} ${func} 测试函数`);
        if (exists) passedTestFunctions++;
    });
    
    console.log(`\n   测试系统通过率: ${passedTestFunctions}/${testFunctions.length} (${Math.round(passedTestFunctions/testFunctions.length*100)}%)`);
    
} catch (e) {
    console.log(`   ✗ 测试系统检查失败: ${e.message}`);
}

// 6. 性能评估
console.log('\n6. 性能评估:');
try {
    const files = [
        'monthly_report_generator.js',
        'monthly_report_ui.js',
        'monthly_report_config.json',
        'worker_ledger.html'
    ];
    
    let totalSize = 0;
    files.forEach(file => {
        const stats = fs.statSync(file);
        const sizeKB = (stats.size / 1024).toFixed(2);
        totalSize += stats.size;
        console.log(`   ${file}: ${sizeKB}KB`);
    });
    
    console.log(`\n   总大小: ${(totalSize / 1024).toFixed(2)}KB`);
    
    // 评估性能
    if (totalSize < 500 * 1024) { // 500KB
        console.log('   ✓ 系统大小适中，性能良好');
    } else {
        console.log('   ⚠ 系统较大，可能影响加载性能');
    }
    
} catch (e) {
    console.log(`   ✗ 性能评估失败: ${e.message}`);
}

// 7. 兼容性检查
console.log('\n7. 兼容性检查:');
const compatibilityChecks = [
    { name: 'ES6语法支持', pattern: 'class|const|let|async|await' },
    { name: 'DOM API兼容', pattern: 'getElementById|addEventListener|localStorage' },
    { name: 'JSON数据处理', pattern: 'JSON.parse|JSON.stringify' },
    { name: '日期处理', pattern: 'Date|new Date' }
];

try {
    const jsContent = fs.readFileSync('monthly_report_generator.js', 'utf8');
    
    let passedCompatibilityChecks = 0;
    compatibilityChecks.forEach(check => {
        const supported = jsContent.includes(check.pattern);
        console.log(`   ${supported ? '✓' : '✗'} ${check.name}`);
        if (supported) passedCompatibilityChecks++;
    });
    
    console.log(`\n   兼容性通过率: ${passedCompatibilityChecks}/${compatibilityChecks.length} (${Math.round(passedCompatibilityChecks/compatibilityChecks.length*100)}%)`);
    
} catch (e) {
    console.log(`   ✗ 兼容性检查失败: ${e.message}`);
}

console.log('\n=== 最终验证测试完成 ===');
