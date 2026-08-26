@echo off
chcp 65001 >nul
setlocal

if "%~1"=="" (
  echo 请把 MP4、MOV、MKV 或 WebM 人物动作视频拖到这个文件上。
  pause
  exit /b 1
)

set "SKILL_DIR=%~dp0"
set "INPUT_VIDEO=%~f1"
set "OUTPUT_DIR=%~dpn1_深度骨骼输出"

python "%SKILL_DIR%scripts\check_environment.py"
if errorlevel 1 (
  echo 正在安装缺少的 Python 依赖……
  python -m pip install -r "%SKILL_DIR%scripts\requirements.txt"
  if errorlevel 1 (
    echo 依赖安装失败，请检查网络和 Python 环境。
    pause
    exit /b 1
  )
)

echo 开始转换：%INPUT_VIDEO%
python "%SKILL_DIR%scripts\convert_video.py" "%INPUT_VIDEO%" --output-dir "%OUTPUT_DIR%"
if errorlevel 1 (
  echo 转换未通过质量验证，请查看输出目录中的 validation_report.json。
  pause
  exit /b 1
)

echo.
echo 转换成功：%OUTPUT_DIR%
start "" "%OUTPUT_DIR%"
pause
