# Photoshop Agent Rules

本文档适用于：

scripts/photoshop/

以及该目录下的全部子目录。


---

# 一、Photoshop脚本交付位置

正式 Photoshop ExtendScript / JSX 文件统一保存到：

scripts/photoshop/jsx/


不得将正式交付脚本保存到：

- docs/
- examples/
- 临时目录
- 仓库根目录
- 仓库外部目录


---

# 二、生产脚本版本规则

优化已有生产脚本时：

默认保留原始稳定版本。

例如：

原始版本：

scripts/photoshop/jsx/Even_大画面批量输出助手_v26.jsx


优化版本：

scripts/photoshop/jsx/Even_大画面批量输出助手_v27.jsx


未经用户明确确认：

不得覆盖、删除或重命名原始稳定版本。


---

# 三、修改原则

修改 Photoshop 生产脚本前：

必须先完成：

1. 当前功能分析
2. 修改目标说明
3. 涉及区域定位
4. 风险说明
5. 验证方案


默认采用：

小范围修改。


禁止未经确认：

- 重写完整脚本
- 大规模重构
- 改变生产流程
- 改变输出参数
- 改变报告规则
- 改变文件命名规则


---

# 四、交付要求

完成修改后：

必须将最终脚本直接保存到：

scripts/photoshop/jsx/


同时说明：

- 最终文件名称
- 最终相对路径
- 原始文件是否保持不变
- 修改摘要
- 测试步骤
- 尚未验证的风险


---

# 五、临时文件处理

分析过程产生的临时文件：

不得混入正式交付目录。

测试文件应放入：

scripts/photoshop/examples/

或用户明确指定的测试目录。


任务完成前：

必须检查并清理无意义的临时文件。


---

# 六、Git安全规则

任务完成后可以运行：

git status

git diff --stat

git diff


未经用户明确确认：

不得自动提交或推送 Git。