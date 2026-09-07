# Parameter Lock｜参数硬锁

先建立参数表，再生成或修改视觉：

```yaml
parameter:
  value: "用户给出的值"
  source: user
  state: LOCKED
```

用户明确的主体、颜色、画幅、尺寸、背景、材质、文字、Logo、字体、构图方向、风格和输出均设为 `LOCKED`。动态任务还锁定时长、帧率、节奏、循环、转场、首尾帧、镜头许可与音频策略。

- **PASS**：每个关键参数有 value/source/state，最终输出逐项复核 `LOCKED`。
- **WARNING**：参数可合理默认，但来源未写明或尚未得到品牌方确认。
- **FAIL**：为了“更好看”修改 `LOCKED`；把未填写值伪装成用户要求；遗漏会改变身份或生产规格的参数。

默认值只在用户未指定时生效，并始终保持 `FLEXIBLE`。
