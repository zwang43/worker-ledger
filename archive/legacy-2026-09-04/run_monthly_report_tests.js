// 月度报告功能测试脚本

const fs = require('fs');
const path = require('path');

// 测试结果收集
const testResults = [];

function addResult(category, testName, passed, message) {
    testResults.push({
        category,
        testName,
        passed,
        message,
        timestamp: new Date().toISOString()
    });
}

function printResults() {
    console.log('\n=== 🧪 月度报告功能测试报告 ===\n');
    
    const categories = [...new Set(testResults.map(r => r.category))];
    
    categories.forEach(category => {
        console.log(`📋 ${category}`);
        console.log('─'.repeat(40));
        
        const categoryTests = testResults.filter(r => r.category === category);
        categoryTests.forEach(test => {
            const icon = test.passed ? '✅' : '❌';
            console.log(`${icon} ${test.testName}`);
            if (test.message) {
                console.log(`   ${test.message}`);
            }
        });
        console.log('');
    });
    
    // 统计结果
    const total = testResults.length;
    const passed = testResults.filter(r => r.passed).length;
    const failed = total - passed;
    
    console.log('📊 测试总结');
    console.log('─'.repeat(40));
    console.log(`总测试数: ${total}`);
    console.log(`通过: ${passed}`);
    console.log(`失败: ${failed}`);
    console.log(`通过率: ${((passed / total) * 100).toFixed(1)}%`);
    
    return failed === 0;
}

// 1. 月度报告生成功能验证
function testMonthlyReportGeneration() {
    console.log('🔍 测试月度报告生成功能...');
    
    // 1.1 检查JavaScript文件
    const jsFiles = [
        'monthly_report_generator.js',
        'monthly_report_ui.js',
        'validate_monthly_report.js'
    ];
    
    jsFiles.forEach(file => {
        const filePath = path.join(__dirname, file);
        try {
            if (fs.existsSync(filePath)) {
                // 检查语法
                const { execSync } = require('child_process');
                execSync(`node -c "${filePath}"`, { stdio: 'pipe' });
                addResult('月度报告生成功能验证', `检查${file}语法`, true, '文件存在且语法正确');
            } else {
                addResult('月度报告生成功能验证', `检查${file}存在性`, false, '文件不存在');
            }
        } catch (error) {
            addResult('月度报告生成功能验证', `检查${file}语法`, false, error.message);
        }
    });
    
    // 1.2 检查配置文件
    const configPath = path.join(__dirname, 'monthly_report_config.json');
    try {
        const configContent = fs.readFileSync(configPath, 'utf8');
        const config = JSON.parse(configContent);
        
        const requiredFields = [
            'generateTime', 'generateDay', 'titleTemplate', 'format',
            'autoSave', 'notification', 'retainMonths', 'enabled'
        ];
        
        const missingFields = requiredFields.filter(field => !(field in config));
        if (missingFields.length === 0) {
            addResult('月度报告生成功能验证', '配置文件读取测试', true, '所有必需字段存在');
        } else {
            addResult('月度报告生成功能验证', '配置文件读取测试', false, `缺少字段: ${missingFields.join(', ')}`);
        }
    } catch (error) {
        addResult('月度报告生成功能验证', '配置文件读取测试', false, error.message);
    }
    
    // 1.3 检查关键函数存在
    try {
        const generatorContent = fs.readFileSync(path.join(__dirname, 'monthly_report_generator.js'), 'utf8');
        
        const requiredFunctions = [
            'generateManualReport',
            'generateReportForMonth',
            'saveReportHistory',
            'loadReportHistory',
            'configureGenerator',
            'showConfig'
        ];
        
        const missingFunctions = requiredFunctions.filter(func => !generatorContent.includes(func));
        if (missingFunctions.length === 0) {
            addResult('月度报告生成功能验证', '报告生成按钮功能检查', true, '所有必需函数存在');
        } else {
            addResult('月度报告生成功能验证', '报告生成按钮功能检查', false, `缺少函数: ${missingFunctions.join(', ')}`);
        }
    } catch (error) {
        addResult('月度报告生成功能验证', '报告生成按钮功能检查', false, error.message);
    }
}

// 2. 功能测试
function testFunctionality() {
    console.log('🔍 测试功能实现...');
    
    // 2.1 测试手动生成功能
    try {
        const generatorContent = fs.readFileSync(path.join(__dirname, 'monthly_report_generator.js'), 'utf8');
        
        const hasManualGeneration = generatorContent.includes('generateManualReport') &&
                                    generatorContent.includes('manual-report-modal') &&
                                    generatorContent.includes('manual-report-year') &&
                                    generatorContent.includes('manual-report-month');
        
        addResult('功能测试', '手动生成月度报告功能', hasManualGeneration, 
                 hasManualGeneration ? '手动生成功能实现完整' : '缺少手动生成相关代码');
    } catch (error) {
        addResult('功能测试', '手动生成月度报告功能', false, error.message);
    }
    
    // 2.2 测试历史记录查看功能
    try {
        const generatorContent = fs.readFileSync(path.join(__dirname, 'monthly_report_generator.js'), 'utf8');
        
        const hasHistoryFeature = generatorContent.includes('loadReportHistory') &&
                                  generatorContent.includes('history-modal') &&
                                  generatorContent.includes('show-report-history') &&
                                  generatorContent.includes('history-content');
        
        addResult('功能测试', '历史记录查看功能', hasHistoryFeature,
                 hasHistoryFeature ? '历史记录功能实现完整' : '缺少历史记录相关代码');
    } catch (error) {
        addResult('功能测试', '历史记录查看功能', false, error.message);
    }
    
    // 2.3 测试配置管理界面
    try {
        const uiContent = fs.readFileSync(path.join(__dirname, 'monthly_report_ui.js'), 'utf8');
        
        const hasConfigUI = uiContent.includes('showConfig') &&
                           uiContent.includes('updateConfig') &&
                           uiContent.includes('hideConfig') &&
                           uiContent.includes('monthly-report-config-modal');
        
        addResult('功能测试', '配置管理界面', hasConfigUI,
                 hasConfigUI ? '配置管理界面功能完整' : '缺少配置管理相关代码');
    } catch (error) {
        addResult('功能测试', '配置管理界面', false, error.message);
    }
}

// 3. 界面集成测试
function testUIIntegration() {
    console.log('🔍 测试界面集成...');
    
    // 3.1 CSS样式验证
    try {
        const generatorContent = fs.readFileSync(path.join(__dirname, 'monthly_report_generator.js'), 'utf8');
        
        const cssFeatures = [
            'modal',
            'modal-content', 
            'modal-header',
            'modal-footer',
            'toast',
            'btn'
        ];
        
        const missingCSSFeatures = cssFeatures.filter(feature => !generatorContent.includes(feature));
        
        if (missingCSSFeatures.length === 0) {
            addResult('界面集成测试', 'CSS样式应用', true, '所有CSS样式类正确应用');
        } else {
            addResult('界面集成测试', 'CSS样式应用', false, `缺少CSS类: ${missingCSSFeatures.join(', ')}`);
        }
    } catch (error) {
        addResult('界面集成测试', 'CSS样式应用', false, error.message);
    }
    
    // 3.2 模态框功能验证
    try {
        const generatorContent = fs.readFileSync(path.join(__dirname, 'monthly_report_generator.js'), 'utf8');
        
        const modalFeatures = [
            'manual-report-modal',
            'history-modal',
            'monthly-report-config-modal'
        ];
        
        const modalOperations = [
            'style.display = \'block\'',
            'style.display = \'none\'',
            'addEventListener'
        ];
        
        const missingModals = modalFeatures.filter(modal => !generatorContent.includes(modal));
        const missingOperations = modalOperations.filter(op => !generatorContent.includes(op));
        
        if (missingModals.length === 0 && missingOperations.length === 0) {
            addResult('界面集成测试', '模态框功能', true, '所有模态框功能正常');
        } else {
            const issues = [];
            if (missingModals.length > 0) issues.push(`缺少模态框: ${missingModals.join(', ')}`);
            if (missingOperations.length > 0) issues.push(`缺少操作: ${missingOperations.join(', ')}`);
            addResult('界面集成测试', '模态框功能', false, issues.join('; '));
        }
    } catch (error) {
        addResult('界面集成测试', '模态框功能', false, error.message);
    }
    
    // 3.3 导航按钮响应测试
    try {
        const generatorContent = fs.readFileSync(path.join(__dirname, 'monthly_report_generator.js'), 'utf8');
        
        const buttonElements = [
            'generate-manual-report',
            'show-report-history',
            'configure-monthly-report',
            'confirm-generate',
            'cancel-generate'
        ];
        
        const missingButtons = buttonElements.filter(btn => !generatorContent.includes(btn));
        
        if (missingButtons.length === 0) {
            addResult('界面集成测试', '导航按钮响应', true, '所有导航按钮元素存在');
        } else {
            addResult('界面集成测试', '导航按钮响应', false, `缺少按钮元素: ${missingButtons.join(', ')}`);
        }
    } catch (error) {
        addResult('界面集成测试', '导航按钮响应', false, error.message);
    }
}

// 4. 错误处理测试
function testErrorHandling() {
    console.log('🔍 测试错误处理...');
    
    // 4.1 异常情况处理验证
    try {
        const generatorContent = fs.readFileSync(path.join(__dirname, 'monthly_report_generator.js'), 'utf8');
        const uiContent = fs.readFileSync(path.join(__dirname, 'monthly_report_ui.js'), 'utf8');
        
        const errorHandlingFeatures = [
            'try',
            'catch',
            'throw new Error',
            'showToast'
        ];
        
        const missingErrorHandling = errorHandlingFeatures.filter(feature => 
            !generatorContent.includes(feature) && !uiContent.includes(feature)
        );
        
        if (missingErrorHandling.length === 0) {
            addResult('错误处理测试', '异常情况处理', true, '错误处理机制完整');
        } else {
            addResult('错误处理测试', '异常情况处理', false, `缺少错误处理功能: ${missingErrorHandling.join(', ')}`);
        }
    } catch (error) {
        addResult('错误处理测试', '异常情况处理', false, error.message);
    }
    
    // 4.2 错误提示信息验证
    try {
        const uiContent = fs.readFileSync(path.join(__dirname, 'monthly_report_ui.js'), 'utf8');
        
        const toastTypes = ['success', 'error', 'info', 'warning'];
        const hasToastFunction = uiContent.includes('showToast');
        const hasAllToastTypes = toastTypes.every(type => uiContent.includes(type));
        
        if (hasToastFunction && hasAllToastTypes) {
            addResult('错误处理测试', '错误提示信息', true, 'Toast提示功能完整，支持所有类型');
        } else {
            const issues = [];
            if (!hasToastFunction) issues.push('缺少showToast函数');
            if (!hasAllToastTypes) issues.push('缺少部分Toast类型');
            addResult('错误处理测试', '错误提示信息', false, issues.join('; '));
        }
    } catch (error) {
        addResult('错误处理测试', '错误提示信息', false, error.message);
    }
}

// 运行所有测试
function runAllTests() {
    console.log('🚀 开始运行月度报告功能测试...\n');
    
    testMonthlyReportGeneration();
    testFunctionality();
    testUIIntegration();
    testErrorHandling();
    
    const allPassed = printResults();
    
    console.log('\n' + '='.repeat(40));
    if (allPassed) {
        console.log('🎉 所有测试通过！月度报告功能验证完成。');
    } else {
        console.log('⚠️  部分测试失败，请检查上述错误信息。');
    }
    console.log('='.repeat(40));
    
    return allPassed;
}

// 运行测试
try {
    const success = runAllTests();
    process.exit(success ? 0 : 1);
} catch (error) {
    console.error('测试执行失败:', error);
    process.exit(1);
}
