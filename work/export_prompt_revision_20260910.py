from pathlib import Path
import zipfile, hashlib, json, subprocess
root=Path(__file__).resolve().parents[1]
out=root/'work/prompt-revision-2026-09-10-integrated'
out.mkdir(exist_ok=True)
paths=['AI_Skills/Graphic_Design/references/Prompt_Framework.md','AI_Skills/Graphic_Design/references/routes/production/image-generation.md','docs/VISUAL_WORKBENCH.md','docs/AIGC_CREATIVE_RULES.md']
cache=Path('C:/Users/SUMAI/.codex/plugins/cache/codex-design/codex-design-visuals/0.6.2')
for p in paths[:2]:
    rel=Path(p).relative_to('AI_Skills/Graphic_Design')
    assert (root/p).read_bytes()==(root/'plugins/codex-design-visuals'/rel).read_bytes()==(cache/rel).read_bytes()
manifest=[]
for p in paths:
    data=(root/p).read_bytes()
    (out/Path(p).name).write_bytes(data)
    manifest.append({'source':p,'sha256':hashlib.sha256(data).hexdigest()})
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(out/'changes.diff').write_bytes(subprocess.check_output(['git','diff','--no-ext-diff','--'],cwd=root))
(out/'README.md').write_text('''# 本地合并交付记录

2026-09-10：基于本地提交 19b2c49 的 2.0 版增量合并，未用旧上传副本覆盖。保留四类提示模板；Prompt_Framework.md 2.1 增补 RCE 上层边界和六段顺序；image-generation.md 增补确定性合成验收；其余两份文档同步职责与实验记录要求。

验证：Skill 结构 52 PASS / 0 WARN / 0 FAIL；仓库 27 项、0 错误、0 警告；git diff --check 通过。插件 0.6.2 已安装，两份改动引用的源、分发和安装缓存逐字节一致。当前会话不会自动重新加载新插件；新会话中可使用。未进行生图或生产质量验证。

云端替换：仅用包内四份同名 Markdown 替换旧来源；同时将 VISUAL_WORKBENCH.md 的 Project 总指令同步到项目设置并复核。本文仅为交接记录，不是平行规范。原相对引用按仓库布局保留，其他依赖未重复打包。八模块旧导航未改。

当前状态：本地源与分发已合并并验证；未提交、推送；云端来源和设置尚未替换。此包取代上一轮基于上传版本的修订包，用于接下来的云端同步。
''',encoding='utf-8')
dest=out.with_suffix('.zip')
with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(out.iterdir()): z.write(p,p.name)
with zipfile.ZipFile(dest) as z: assert z.testzip() is None
print('Source/distribution/cache identical; verified archive:',dest)
