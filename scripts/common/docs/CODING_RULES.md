# Adobe Automation Coding Rules


## 一、文档定位


本文档是：

Codex Design 项目 Adobe 自动化脚本开发总规范。


适用于：

- Photoshop
- Illustrator
- InDesign
- Bridge
- Acrobat


所有 Adobe 自动化脚本：

必须遵守本规范。


软件专项规则：

参考对应目录：
scripts/photoshop/docs/README.md
scripts/illustrator/docs/README.md


---

# 二、开发原则


## 1. 明确需求


创建脚本前：

必须明确：

- 应用软件
- 输入内容
- 输出结果
- 执行动作


例如：

需求：

> 自动导出PNG文件


需要明确：

- 来源文件
- 输出路径
- 文件命名
- 是否覆盖


---

## 2. 小步开发


脚本开发：

遵循：
简单功能
↓
测试
↓
增加功能
↓
优化


不要一次创建复杂自动化系统。


---

# 三、文件命名规范


## 基本规则


使用：
英文小写
+
下划线
+
功能描述


禁止：

- 中文文件名
- 空格
- 拼音
- 无意义名称


正确：
create_layer.jsx
export_png.jsx
batch_resize.jsx


错误：
新建图层.jsx
test.jsx
abc.jsx


---

# 四、目录规范


所有脚本：

存放：
scripts/


例如：

Photoshop：
scripts/photoshop/


Illustrator：
scripts/illustrator/


公共代码：
scripts/common/


---

# 五、脚本文件规范


每个脚本必须包含文件说明。


模板：

```javascript
// =================================
// Script:
// Application:
// Purpose:
// Author: Codex
// Version:
// Date:
// =================================

示例：
// =================================
// Script: export_png.jsx
// Application: Photoshop
// Purpose: 自动导出PNG文件
// Author: Codex
// Version: 1.0
// =================================

六、代码结构规范
推荐结构：
文件说明

↓

初始化

↓

参数设置

↓

核心功能

↓

保存输出

↓

错误处理

# 七、生产自动化脚本原则


Adobe 自动化脚本主要用于设计生产环境。


开发时：

优先考虑：

- 无人值守稳定运行
- 批处理不中断
- 自动错误记录
- 自动生成报告


---

## 1. 稳定性优先


生产脚本：

稳定运行优先于代码简洁。


不得为了：

- 减少代码数量
- 强制模块化
- 提高通用性

降低生产可靠性。


---

## 2. 支持无人值守运行


批处理脚本应尽量做到：
开始任务
↓
自动执行
↓
自动处理异常
↓
生成结果报告
↓
结束任务


运行过程中：

不应依赖人工操作。


---

## 3. 异常处理原则


单个文件失败：

不得导致整个批处理停止。


应该：
记录错误
↓
跳过问题文件
↓
继续处理其他文件
↓
最终生成错误报告


---

## 4. 单文件脚本允许存在


Adobe JSX 环境特殊：

为了保证：

- 路径稳定
- 部署简单
- 双击运行可靠


允许：

单个 JSX 文件包含完整流程。


模块化不是强制要求。


---

## 5. 生产逻辑优先


脚本结构优化：

必须服从实际生产流程。


例如：

印刷输出流程中的：

- DPI规则
- 尺寸规则
- 色彩规则
- 文件规则

属于业务标准。


不得为了代码通用性随意改变。



# 八、错误处理规范
所有脚本：
必须包含错误捕获。
标准：
try
{

}
catch(error)
{

}
错误信息：
使用中文。
例如：
alert("执行失败：" + error.message);

# 九、文件操作规范
涉及文件：
必须检查：
文件是否存在
路径是否正确
输出位置
禁止：
未确认覆盖源文件
删除用户文件

# 十、版本管理规范
重要修改：
保留版本。
例如：
export_png_v1.jsx

export_png_v2.jsx
不要直接覆盖重要脚本。

# 十一、测试规范
新脚本：
必须：
使用测试文件
验证输出
确认结果
测试完成后：
记录：
使用方法
注意事项
已知问题

# 十二、Git规范
提交信息：
使用明确描述。
推荐：
Add Photoshop export script

Add Illustrator shape generator

Update automation rules
Add Photoshop export script

Add Illustrator shape generator

Update automation rules
避免：
test

update

修改

# 十三、Codex执行规范
Codex生成脚本时：
遵循：
理解需求

↓

说明方案

↓

创建脚本

↓

解释使用方法

↓

等待反馈

# 十四、目标
建立：
自然语言需求

↓

Codex

↓

Adobe JSX脚本

↓

Adobe软件执行

↓

自动化设计生产
