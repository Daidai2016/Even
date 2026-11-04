# 单画面 V21 / 多画面 V30：输出格式与保存规格

## 使用入口

在目标 Photoshop 中选择“文件 > 脚本 > 浏览”：

- 单画面：`scripts/photoshop/jsx/large_format_single_file_process_v21.jsx`，处理当前打开的 JPG/JPEG 或 TIF/TIFF 文件。
- 多画面：`scripts/photoshop/jsx/large_format_batch_output_v30.jsx`，按原流程选择输入文件夹与输出位置。

按仓库稳定版本规则保留 V20、V29 原版，不覆盖旧版。先前的输出位置检查和异常清理修复继续保留。

## 输出规格

| 输入文件 | 输出文件 | 保存规格 |
| --- | --- | --- |
| `.jpg` / `.jpeg`（不区分大小写） | `.jpg` | Photoshop 品质 12，基线标准，嵌入 ICC |
| `.tif` / `.tiff`（不区分大小写） | `.tif` | 单图层可见合成图，LZW 无损压缩，保留透明，嵌入 ICC |

TIFF 不携带可编辑的多图层数据，输出重新打开后是一个图层；透明与半透明区域保留，不填充白色背景。保存选项为 `layers = false`、`transparency = true`，不对源文档执行展平或合并。Adobe 对 TIFF 压缩及透明保存的说明见 [TIFF 保存说明](https://helpx.adobe.com/photoshop/desktop/save-and-export/save-files/save-in-tiff-format.html)。

单画面预览会显示实际格式，输出文件与报告中的扩展名同步变化。源文件格式以当前文档名称后缀判断；未保存文件仍需先保存，不支持的文件类型在处理前提示退出。多画面原已支持格式跟随和 JPG 品质 12 / 基线标准，本次补齐 TIFF 保存选项。

输出目录、命名、报告字段及邮箱保持原规则；像素不变、不重采样，不执行色彩模式、位深或 ICC 转换。两版各自原有的尺寸与分辨率计算逻辑不变。

## 验证结果

2026-11-04，Windows / Photoshop 27.11.0：

- 自动回归覆盖单画面完整脚本、批量实际保存函数、JPG/JPEG/TIF/TIFF 大小写后缀、报告文件名、参数及原有写入异常分支。
- Photoshop 实测透明 RGB 8 位、透明 CMYK 8 位、透明 RGB 16 位、不透明 TIFF、RGB JPG、CMYK JPG。单画面执行完整处理代码（自动确认预览），多画面执行实际保存函数；本次没有重新运行批量文件夹选择和完整两轮扫描界面。
- 12 个输出均重新打开检查：一个图层、40 × 60 像素、30 ppi，色彩模式、位深与 ICC 保持一致。源文件重新打开仍为 300 ppi，原图层数不变。
- 三类透明 TIFF 的单画面与多画面结果均通过透明通道直方图检查：1475 个全透明像素、525 个不透明像素、400 个半透明像素，确认保留半透明区域。
- TIFF 文件内部检查确认 LZW 压缩、无 Photoshop 多图层数据、原有位深/透明样本标记/ICC 字节保持一致。
- JPG 文件内部 Photoshop 品质记录为 12、格式记录为基线标准，JPEG 帧标记为 SOF0。

未重新验证用户原始生产目录、网络盘、macOS 或其他 Photoshop 版本；大尺寸生产稿本次未实测。先前记录的特殊路径限制继续适用。

## 回归入口

- Node：`node scripts/photoshop/examples/test_output_formats_v21_v30.js`
- Photoshop：“文件 > 脚本 > 浏览”运行 `scripts/photoshop/examples/test_output_formats_v21_v30.jsx`，仅创建测试文档，结果保存在本次唯一的 `work/format_v21_v30_<时间戳>/`。
- 文件规格检查：`python scripts/photoshop/examples/verify_output_format_files.py work/format_v21_v30_<时间戳>`，需要已有的 Pillow 和 tifffile。

`work/` 中的测试输入、输出和日志均为临时验证材料，不属于生产交付或 Git 提交内容。
