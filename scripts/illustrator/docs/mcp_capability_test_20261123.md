# Illustrator 2027 MCP 本机实测

日期：2026-11-23。宿主：Adobe Illustrator 2027，进程产品版本 31.0.0。连接：本机 18412 端口，项目配置名称 `adobe_illustrator`。

## 结论与验证范围

本机 `tools/list` 返回 **47 个工具**，全部完成实际调用，且每个工具至少一次返回成功。此结论是接口及代表性场景验证，不代表每个参数、对象类型和复杂生产文件均已通过验收。

测试开始时没有打开的文档。所有写入仅作用于本次新建的测试文档及合成素材，没有修改用户作品。矩形、圆形、文字、曲线和嵌入图像由合成 SVG 提供，再通过 `OpenDocument` 打开；不能据此声称 MCP 有直接绘制这些对象的接口。

## 实测能力

| 能力 | 验证结果 |
|---|---|
| 文档创建、打开、列出、切换 | 新建 210 × 148 mm、CMYK、四边 3 mm 出血文档；回读出血为约 8.504 pt；打开 SVG、AI、PDF 并切换成功 |
| 文档与对象检查 | 可读图层树、编组、对象类型、边界、路径节点数、填充、描边、透明度、字体与文字内容；支持色板读取及条件查找 |
| 对象变换 | 移动、旋转 15°、缩放 1.2 倍、顶部对齐及 20 pt 等距分布成功；回读几何边界核对 |
| 外观编辑 | 填充改为指定 RGB 色，设置描边及 75% 透明度成功；缩放后描边宽度从 2 pt 变为 2.4 pt |
| 文字与字体 | `MCP Test 2027` 替换为 `MCP Verified 2027`；Arial Regular 改为 Arial Bold；回读确认文字仍是文本对象 |
| 图层、组与对象管理 | 新建图层和空组、复制、重命名、删除测试对象、修改叠放顺序、移动对象入组、创建剪切蒙版成功 |
| 画板管理 | 新建、改名、背景色、A4 横向预设、精确缩放为 300 × 200 pt、移动、连内容复制、删除、切换及适合指定对象成功 |
| 图像描摹 | 复制合成黑白位图，在副本调用 `Vectorize`，使用 `blackAndWhiteLogo` 和 `trace_live`；返回实时描摹对象，预览可见描摹结果 |
| 路径简化 | 密集正弦曲线从 61 个节点简化为 3 个，几何回读确认；边界略有变化，不能当成无损清理 |
| 路径平滑 | `smooth` 调用成功，但原 5 节点样例的节点数与边界未变化；未充分验证有明显变化的平滑效果 |
| 生产预检 | 返回 document、images、links、text、colors、objects 六域报告；在合成样例中检出缺少色彩配置、空组、画板外对象等 9 类问题。仅验证报告能力，不是实际客户文件的印前结论 |
| 预览与选区 | 可生成并查看 PNG 预览、读取选中对象；选区写入后需等待宿主刷新再回读 |

## 导出验证

12 种格式均实际生成非空文件：PNG、JPEG、SVG、PDF、AI、EPS、TIFF、PSD、WebP、BMP、DWG、DXF。

- PNG、JPEG、TIFF、PSD、WebP、BMP：使用图像库成功解码；PSD 仅核对合成图可读取，未在 Photoshop 验证图层结构。
- SVG：通过 XML 解析。
- AI：额外导出全画布文件并在 Illustrator 重新打开，确认图层、组、画板和可编辑文字保留。
- PDF：在 Illustrator 重新打开，读取画板并生成预览，图像检查通过。
- EPS、DWG、DXF：仅确认接口成功、文件非空及格式头，未在对应下游应用验证。
- 首轮导出沿用应用偏好，各格式分辨率和尺寸不同，不能当作已统一的交付规格。

## 实测注意事项

1. **快速连续调用会读到未更新的状态。** 选区切换后立即读取，出现旧选区或多出位图；等待 1 秒再读，两次测试均得到准确选区。1 秒仅为本次有效等待值，不是所有文档的稳定保证。
2. **复制画板后立即适合图稿出现遗漏。** 自动范围只识别了 1 个对象，而复制返回 8 个；显式指定这 8 个 UUID 可正确适配，重新打开文件后的自动适配也识别了 8 个。原因未定位，建议等待刷新、回读结构后再执行依赖操作。
3. **BMP 的画板范围未按预期生效。** 同一文档、同一画板、72 ppi，PNG 得到 640 × 481 px，BMP 得到 1457 × 436 px，后者与全画布对象范围更接近。不能仅凭导出返回成功认定裁切正确。PNG 的 481 px 高度也表明需核对像素舍入。
4. **AI 导出不是普通保存。** 导出的 AI 可重新打开且保留文字，但本次实时描摹对象在重新打开后变为普通矢量组。不能承诺所有实时效果与原始编辑状态完整保留。
5. **编组会保护叠放关系。** `preserveStacking=true` 在潜在重叠冲突时拒绝移动；将本次测试对象移至不重叠区域后，同样的保护参数下成功入组。没有关闭保护来绕过拒绝。
6. **路径清理成功不一定改变几何。** 原本仅 5 节点的曲线简化和平滑均返回成功但无明显变化；增加密集曲线样例后才验证了实际减点。
7. **UUID 不跨文档稳定。** AI 重新打开后对象标识发生变化，应重新读取结构，不能复用原文档 UUID。

## 本机未公开的独立工具

本次完整清单中没有直接创建矩形/椭圆/任意路径/文字框、任意 JSX 执行、Save/SaveAs、关闭文档、路径查找器、3D、Firefly 生成、渐变设置或智能重配色工具。工具描述虽然提及 `SetGradient`、`RecolorArtwork`、`PlaceImage` 等名称，但这些工具没有出现在本机清单中，不能据描述交叉引用视为可调用。

现阶段可使用“外部生成 SVG → OpenDocument → MCP 检查与编辑 → Export”的组合；这与 MCP 原生提供绘图接口是不同的能力。

## 47 个工具清单

| 类别 | 工具 |
|---|---|
| 文档（4） | `CreateDocument`, `OpenDocument`, `ListDocuments`, `SwitchDocument` |
| 画板（11） | `ListArtboards`, `CreateArtboard`, `SetArtboardProperties`, `DuplicateArtboard`, `GetActiveArtboard`, `ScaleArtboards`, `FitArtboard`, `DeleteArtboard`, `SetActiveArtboard`, `MoveArtboards`, `GetArtboardProperties` |
| 检查、查找、预览（12） | `GetCanvasStructure`, `GetArtboardStructure`, `VisualizeSelection`, `CapturePreview`, `FindObjects`, `GetVisualAppearance`, `GetGeometry`, `GetTypographyMetrics`, `GetObjectStructure`, `GetBounds`, `RunPreflightChecks`, `GetSwatches` |
| 对象组织（9） | `CreateLayer`, `RenameObject`, `SelectObjects`, `DeleteObjects`, `DuplicateObjects`, `CreateGroup`, `MoveObjectsToContainer`, `CreateClippingMask`, `ArrangeArt` |
| 变换与外观（6） | `AlignObjects`, `DistributeObjects`, `SetAppearance`, `MoveObjects`, `RotateObjects`, `ScaleObjects` |
| 文字（2） | `ReplaceText`, `ReplaceFont` |
| 路径与描摹（2） | `CleanupPath`, `Vectorize` |
| 导出（1） | `Export` |

## 本机证据与保留状态

临时材料位于仓库相对目录 `work/illustrator_mcp_probe_20261123/`，不作为正式生产素材，不加入 Git：

- `tools.json`：完整工具声明。
- `calls.jsonl`：请求参数与原始返回；不记录鉴权令牌。
- `file_validation.json`：首轮输出文件解码与格式头记录；其中 AI/PDF 的后续重新打开验证见调用日志。
- `verified_canvas.ai`：可打开检查的测试结果。
- `verified_preview.png`：测试主画板预览。
- `scope_72.png`、`scope_72.BMP`：同画板与分辨率的范围差异对照。
- `dense_curve.svg`、`dense_curve_cleaned.svg`：61 → 3 节点简化前后文件。

第一阶段记录的中文名称曾因测试客户端字符解码显示异常，随后修正为 UTF-8；后续回读中文正常，不据此前记录判定 Illustrator 中文异常。

结束时保留 5 个本次测试文档，当前为 `verified_canvas`。MCP 没有关闭文档接口，本次未通过其他自动化通道关闭它们。未修改或运行仓库既有生产 JSX，未执行 Git 提交或推送。
