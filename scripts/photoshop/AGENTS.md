# Photoshop 自动化局部规则

## 1. 适用范围

本文档适用于 `scripts/photoshop/` 及其子目录。未在本文档中另行规定的内容，继承仓库根目录 `AGENTS.md` 和 `CODING_RULES.md`。

`scripts/photoshop/docs/README.md` 是 Photoshop 能力和工作流指南，不重复本文档的强制规则。

## 2. 交付位置

- 正式 Photoshop ExtendScript / JSX 保存到 `scripts/photoshop/jsx/`。
- 测试样例放在 `scripts/photoshop/examples/` 或用户明确指定的测试目录。
- 不得将正式脚本仅保存在 `docs/`、临时目录、聊天附件或仓库外。

## 3. 稳定版本与命名

- 优化已有生产脚本时，默认保留原始稳定版本。
- 新版本使用递增的 `_vNN` 后缀；未经用户明确同意，不得覆盖、删除或重命名原版本。
- 文件名使用小写英文和下划线，建议结构为 `功能_对象_动作_vNN.jsx`。

示例：

- `large_format_batch_output_v27.jsx`
- `large_format_single_file_process_v19.jsx`

## 4. Photoshop 生产参数

涉及图像尺寸、输出或色彩时，必须明确：

- 物理尺寸、像素尺寸和分辨率属性。
- 是否重采样及使用的重采样方法。
- 色彩模式、位深、配置文件和转换意图。
- 输出格式、质量参数和保存目录。

未经确认不得改变像素数量、物理尺寸、色彩环境或已有输出规则。

## 5. 验证与交付说明

优先使用代表性文件验证图层结构、尺寸、像素、分辨率、色彩、命名和输出格式。

完成后说明：

- 最终文件名称和相对路径。
- 原始稳定版本是否保持不变。
- 修改摘要和测试结果。
- 尚未完成的 Photoshop 真机验证或剩余风险。
