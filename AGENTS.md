# 项目 Agent 规范

以下规则适用于当前项目及其所有子目录。

## 飞书操作限制

- 禁止使用 `lark-cli`。
- 禁止通过任何方式操作飞书，包括 CLI、API、连接器、浏览器和 Computer Use。

## Git 操作限制

- 禁止直接操作 Git，包括通过命令行、脚本、Git 库或其他工具执行 Git 操作。
- 提交代码时，必须使用 Computer Use 操作 GitHub Desktop 完成。
- 其他需要执行的 Git 操作也必须通过 Computer Use 操作 GitHub Desktop 完成，不得绕过该限制。
- 如果 Computer Use 或 GitHub Desktop 不可用，应说明阻碍，不得改用命令行或其他方式操作 Git。

## Godot 操作方式

- Godot 开发、运行、调试与验证使用 CLI 和 Godot MCP。
- 禁止使用 Computer Use 操作 Godot 编辑器或运行中的游戏窗口。
- 先检查当前会话可用的 MCP 能力；未接入或不可用时明确说明，继续使用 CLI 完成可验证部分，不得声称已完成 MCP 或交互验收。
- 此规则不改变上述 Git 规范；Git 操作仍只能通过 Computer Use 操作 GitHub Desktop 完成。
