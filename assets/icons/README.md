# 图标资源管理

项目图标统一存放：

assets/icons/

结构：

source/
设计源文件

png/
展示文件

ico/
Windows快捷方式图标


快捷方式图标：

| 用途 | SVG源文件 | PNG展示文件 | Windows图标 |
| --- | --- | --- | --- |
| Codex Design VS Code | source/01_codex_workspace.svg | png/01_codex_workspace.png | ico/codex_workspace.ico |
| Codex Design 状态检查 | source/02_git_status.svg | png/02_git_status.png | ico/git_status.ico |
| Codex Design 发布GitHub | source/03_git_publish.svg | png/03_git_publish.png | ico/git_publish.ico |
| Codex Design 同步GitHub | source/17_git_sync.svg | png/17_git_sync.png | ico/git_sync.ico |
| Codex Design 环境检查 | source/18_environment_check.svg | png/18_environment_check.png | ico/environment_check.ico |
| Codex Design 终端 | source/04_codex_terminal.svg | png/04_codex_terminal.png | ico/codex_terminal.ico |
| Photoshop JSX脚本 | source/05_photoshop_jsx.svg | png/05_photoshop_jsx.png | ico/photoshop_jsx.ico |
| Illustrator JSX脚本 | source/06_illustrator_jsx.svg | png/06_illustrator_jsx.png | ico/illustrator_jsx.ico |
| Photoshop Beta安装脚本目录 | source/07_photoshop_scripts.svg | png/07_photoshop_scripts.png | ico/photoshop_beta_scripts.ico |
| Illustrator Beta安装脚本目录 | source/08_illustrator_scripts.svg | png/08_illustrator_scripts.png | ico/illustrator_beta_scripts.ico |
| Codex Design 文档 | source/09_documents.svg | png/09_documents.png | ico/codex_docs.ico |
| Codex Design 规则 | source/10_rules.svg | png/10_rules.png | ico/codex_rules.ico |
| Codex Design 项目备份 | source/11_backup.svg | png/11_backup.png | ico/project_backup.ico |


桌面工作台文件夹图标：

| 用途 | SVG源文件 | PNG展示文件 | Windows图标 |
| --- | --- | --- | --- |
| Even Codex Design 根文件夹 | source/12_folder_workspace.svg | png/12_folder_workspace.png | ico/folder_workspace.ico |
| 01_开发工具 | source/13_folder_development_tools.svg | png/13_folder_development_tools.png | ico/folder_development_tools.ico |
| 02_Adobe脚本 | source/14_folder_adobe_scripts.svg | png/14_folder_adobe_scripts.png | ico/folder_adobe_scripts.ico |
| 03_项目管理 | source/15_folder_project_management.svg | png/15_folder_project_management.png | ico/folder_project_management.ico |
| Codex Design 本地项目快捷方式 | source/16_codex_local_project.svg | png/16_codex_local_project.png | ico/codex_local_project.ico |


`14_folder_adobe_scripts` 的中心白色几何图形根据用户提供的参考图进行矢量重绘；参考图片仅用于造型识别，不复制进仓库。


全部图标统一采用明亮、精致的 Codex 流动新拟态材质：原有 11 个快捷方式图标使用有机云团/花瓣轮廓，4 个工作台目录保留清晰的文件夹轮廓，本地项目快捷方式使用云团与文件夹定位符号组合。颜色由多个径向色场、局部柔光和半透明表面层叠加形成非线性流动渐变，并通过柔和投影、轻微厚度和局部高光保持软胶/玻璃般的光泽。主体不使用闭合白色描边，白色仅用于功能符号和局部反光。


Photoshop Beta 与 Illustrator Beta 安装脚本目录分别采用 Adobe Photoshop 蓝青/深蓝和 Adobe Illustrator 金橙/棕红主色；其余图标采用 Codex Logo 的浅薰衣草紫、明亮蓝青、蓝紫和深电光紫色调。

中央符号规范：

- 所有中央符号按整枚图标的视觉重心进行水平和垂直居中。
- `Codex Design 发布GitHub` 保留用户原稿的宽云朵轮廓与大比例白色 GitHub 猫形关系，仅升级为当前流动新拟态材质。
- Photoshop、Illustrator 和 Adobe 脚本相关图标统一使用粗壮 `{ }` 大括号语言。
- `Codex Design 终端` 使用经典矩形终端窗口造型。
- `Codex Design 项目备份` 使用两层硬盘叠加造型，不使用箭头；每层硬盘采用参考 Codex 图标的柔和云团胶囊轮廓。
- `Codex Design 状态检查` 以粗线放大镜为主体，镜片内保留检查标记。
- `Codex Design 同步GitHub` 使用两枚首尾衔接的圆头快进箭头，表达只允许安全快进同步。
- `Codex Design 环境检查` 使用齿轮、圆环和检查标记，表达本机工具链健康检查。
- Photoshop Beta 安装脚本图标沿用原设计的深海军蓝背景与高亮青色符号组合。
- 功能符号统一采用面状造型或圆头粗线条，确保 Windows 小尺寸显示清晰。
- `Even Codex Design` 文件夹中央使用重绘的 Codex 云团 `>_` 标记；工作区、开发工具、Adobe 脚本和项目管理四个文件夹符号均以文件夹下半部矩形面板为基准进行垂直居中，不以包含顶部标签的总高度计算。
- GitHub 白色猫形的左右耳以图标中线对称分布，双腿底边与宽云朵底边齐平。


ICO文件统一包含 16、24、32、48、64、128、256 像素尺寸，供 Windows 资源管理器按显示比例选择。


文件夹图标由 `tools/create_desktop_shortcuts.ps1` 写入各目录的 `desktop.ini`。图标资源路径在脚本运行时从当前仓库位置生成，不在仓库配置中硬编码盘符。


禁止将桌面快捷方式文件(.lnk)加入Git。
