#!/bin/zsh
# Start the local prototype through Godot CLI.
set -e
roadseer_project_dir="${0:A:h}"
roadseer_engine_bin="${ROADSEER_GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$roadseer_engine_bin" ]]; then
  echo "未找到 Godot。请安装 Godot 4.6，或设置 ROADSEER_GODOT_BIN 为引擎可执行文件路径。"
  exit 1
fi
exec "$roadseer_engine_bin" --path "$roadseer_project_dir"
