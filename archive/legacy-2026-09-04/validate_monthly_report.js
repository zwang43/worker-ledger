// 月度报告功能验证测试
const fs = require('fs');
const path = require('path');

console.log('=== 月度报告系统验证测试 ===\n');

// 1. 检查文件存在性
const requiredFiles = [
    'monthly_report_generator.js',
    'monthly_report_config.json', 
    'monthly_report_ui.js',
    'worker_ledger.html',
    'test_monthly_report.js'
];

console.log('1. 文件存在性检查:');
requiredFiles.forEach(file => {
    const exists = fs.existsSync(file);
    console.log(`   ${exists ? '✓' : '✗'} ${file}`);
});

// 2. 检查配置文件格式
console.log('\n2. 配置文件检查:');
try {
    const configContent = fs.readFileSync('monthly_report_config.json', 'utf8');
    const config = JSON.parse(configContent);
    console.log('   ✓ 配置文件格式正确');
    console.log(`   - 自动生成时间: ${config.generateTime}`);
    console.log(`   - 自动生成日期: ${config.generateDay}`);
    console.log(`   - 保留月份数: ${config.retainMonths}`);
    console.log(`   - 功能启用状态: ${config.enabled}`);
} catch (e) {
    console.log(`   ✗ 配置文件错误: ${e.message}`);
}

// 3. 检查HTML文件集成
console.log('\n3. HTML文件集成检查:');
try {
    const htmlContent = fs.readFileSync('worker_ledger.html', 'utf8');
    
    // 检查JavaScript文件引用
    const hasGenerator = htmlContent.includes('monthly_report_generator.js');
    const hasUI = htmlContent.includes('monthly_report_ui.js');
    const hasButton = htmlContent.includes('generate-manual-report');
    const hasModal = htmlContent.includes('manual-report-modal');
    
    console.log(`   ${hasGenerator ? '✓' : '✗'} 生成器脚本引用`);
    console.log(`   ${hasUI ? '✓' : '✗'} UI脚本引用`);
    console.log(`   ${hasButton ? '✓' : '✗'} 生成按钮存在`);
    console.log(`   ${hasModal ? '✓' : '✗'} 模态框存在`);
    
} catch (e) {
    console.log(`   ✗ HTML文件读取错误: ${e.message}`);
}

// 4. 检查JavaScript语法
console.log('\n4. JavaScript语法检查:');
const jsFiles = ['monthly_report_generator.js', 'monthly_report_ui.js'];
jsFiles.forEach(file => {
    try {
        const content = fs.readFileSync(file, 'utf8');
        // 基本的语法检查
        const brackets = content.match(/[{}]/g) || [];
        const openBrackets = brackets.filter(b => b === '{').length;
        const closeBrackets = brackets.filter(b => b === '}').length;
        
        if (openBrackets === closeBrackets) {
            console.log(`   ✓ ${file} - 括号匹配`);
        } else {
            console.log(`   ✗ ${file} - 括号不匹配`);
        }
    } catch (e) {
        console.log(`   ✗ ${file} - 读取错误: ${e.message}`);
    }
});

// 5. 检查测试文件
console.log('\n5. 测试文件检查:');
try {
    const testContent = fs.readFileSync('test_monthly_report.js', 'utf8');
    const testFunctions = [
        'testInitialization',
        'testConfigManagement', 
        'testReportGeneration',
        'testDataManagement',
        'testUIComponents'
    ];
    
    testFunctions.forEach(func => {
        const hasTest = testContent.includes(func);
        console.log(`   ${hasTest ? '✓' : '✗'} ${func} 测试函数`);
    });
} catch (e) {
    console.log(`   ✗ 测试文件读取错误: ${e.message}`);
}

console.log('\n=== 验证测试完成 ===');
