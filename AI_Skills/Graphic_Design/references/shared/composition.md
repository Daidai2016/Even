# Composition｜构图与留白

记录主体位置、构图结构、空间密度、视觉方向、裁切、安全区和留白策略。可用值包括 `CENTER/OFFSET/EDGE/FULL_BLEED`、`CENTERED/ASYMMETRIC/GRID/DIAGONAL/EDITORIAL`、`SPARSE/BALANCED/DENSE`。

## 检查

- **PASS**：主体和文字安全区明确；留白具有容纳文字、强调主体或形成节奏的功能；疏密与方向支持 H1。
- **WARNING**：留白存在但用途不清；多画幅迁移后主体或标题接近危险裁切区。
- **FAIL**：平均分布导致无焦点；关键信息越界；用户锁定画幅被改变；所谓“张力”只表现为随机倾斜或堆叠。

超宽与竖版必须重新检查阅读路径和安全区，不得只把同一版式机械缩放。
