# CODING_RULES.md

# Adobe 自动化脚本开发规范

版本：V1.0

适用范围：

- Photoshop JSX
- Illustrator JSX
- InDesign JSX
- Bridge JSX
- Acrobat JavaScript

项目目标：

使用 Codex 辅助开发稳定、可靠、可维护的 Adobe 自动化脚本。


---

# 一、开发原则


## 1. 生产可靠性优先

脚本主要用于设计生产环境。

开发优先级：

1. 无人值守稳定运行
2. 批处理不中断
3. 输出结果可靠
4. 自动记录日志
5. 代码结构优化


代码简洁性不能降低生产可靠性。


---

## 2. 遵循实际生产流程

脚本必须服务于实际设计和印刷流程。

以下内容属于业务规则：

- 尺寸规范
- DPI规则
- 色彩规则
- 文件格式规则
- 输出规则


不得为了代码通用性随意改变生产逻辑。


---

# 二、Adobe JSX 编码规范


## 1. JavaScript版本兼容

Adobe ExtendScript主要兼容：

JavaScript ES3


禁止主动使用：

- let
- const
- 箭头函数 =>
- class
- import
- export


推荐使用：

- var
- function
- try/catch


示例：


推荐：

```javascript
var doc = app.activeDocument;

function processFile(){

}
避免：
const doc = app.activeDocument;

const processFile = () => {

};
三、文件命名规范
JSX文件
使用：
小写英文 + 下划线
示例：
batch_resize_tiff.jsx

export_print_pdf.jsx

check_color_profile.jsx
避免：
测试1.jsx

最终版.jsx

new.jsx
四、脚本结构规范
推荐结构：
脚本名称.jsx

├── 文件说明
├── 配置区域
├── 工具函数
├── 核心处理函数
├── 输出处理
├── 日志记录
└── 主程序入口
五、无人值守运行规范
1. 禁止依赖人工操作
批处理脚本运行过程中：
不得要求：
点击确认
手动选择文件
手动处理异常
2. 异常处理
单个文件失败：
不得导致整个任务停止。
正确流程：
发现错误

↓

记录文件名

↓

记录错误原因

↓

继续处理下一文件

↓

最终生成报告
3. try/catch要求
以下操作必须包含异常处理：
打开文件
读取文件信息
修改文档
保存文件
关闭文件
六、Photoshop脚本规范
图像处理原则
修改分辨率时：
如果目标是改变物理尺寸：
必须保持像素不变。
使用：
ResampleMethod.NONE
禁止：
未明确要求时改变：
width
height
pixel dimensions
七、Illustrator脚本规范
重点：
画板处理
路径处理
文本处理
导出流程
注意：
Illustrator MCP功能有限。
优先考虑：
JSX脚本
文件交互
自动化流程
八、日志与报告规范
生产脚本必须记录：
开始时间
结束时间
处理数量
成功数量
失败数量
错误原因
输出报告应方便：
设计人员
制作人员
印刷人员
查看。
九、模块化原则
Adobe脚本环境特殊。
模块化不是强制要求。
允许：
单文件完整脚本。
优先保证：
部署简单
路径稳定
双击运行可靠
十、Codex修改原则
Codex修改脚本时：
必须：
修改前说明计划
不主动删除代码
保留已有生产逻辑
保持兼容Adobe环境
修改后说明变化
禁止：
未经确认：
大规模重构
改变输出流程
改变文件规则
十一、Git提交规范
一次提交：
只完成一个明确目标。
提交信息示例：
Add Photoshop TIFF batch process

Fix Illustrator export script

Update automation documentation
避免：
update

test

修改
十二、注释规范
重要生产逻辑必须添加中文注释。
例如：
// 修改PPI但保持像素数量不变
// 用于大画面印刷1:10制作流程恢复
注释重点说明：
为什么这样做。
而不是：
简单描述代码动作。

---