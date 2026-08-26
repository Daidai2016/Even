# Audit｜共享视觉审计

按顺序执行：Requirement → Lock → Hierarchy → Composition → Typography → Color → Style → Production。动态任务再追加 Motion Audit。

## 结论

- **PASS**：硬约束全部满足，结构与生产检查无阻断项。
- **WARNING**：硬约束满足，但存在字体授权、素材版权、印刷、视频编码、软件可用性或人工审美待确认项。
- **FAIL**：任一 `LOCKED` 漂移；准确内容错误；路由串味；输出规格不符；关键视觉在目标尺寸不可用。

## 输出记录

每个问题写明：审计类别、证据、严重度、关联失败代码、修复动作、复核状态。`FAIL` 未修复前不得标记最终完成；软件未实际执行时必须明确写“未执行”，不能以操作清单冒充成品。
