# Windows 新速度版验收

日期：2026-11-01。代码基线：`fb1a002`，分支 `codex/core-gameplay-mvp`。环境：Windows / Godot 4.6.2 / NVIDIA GeForce RTX 3060 Ti / OpenGL 3.3 Compatibility。

结论：当前公路原型的六组自动检查通过；补齐正常开局两种策略21天通关的模型证据。不能据此宣称handoff所有功能已完成、真人可玩性通过或已可发布。

## 本次运行

| 检查 | 结果 | 证据 |
|---|---|---|
| 成员、床位、睡眠、座椅约束 | failures=0，退出0 | [crew_rules.log](crew_rules.log) |
| 速度、帧步长、油耗、停靠、满载、事件唯一结算及制作维修耗时 | failures=0，退出0 | [journey_acceptance.log](journey_acceptance.log) |
| 前三天真实搜集与制作、预设高温预报和日结 | failures=0，退出0 | [cycle_rules.log](cycle_rules.log) |
| 真实图形后端的引擎拖放事件、非法格、Esc取消、滚动裁切 | failures=0，退出0 | [drag.log](drag.log) |
| 引擎视口鼠标键盘事件：行驶、暂停、倍速、停车、探索、战斗、升级、略过、日结、小窗口 | failures=0，退出0 | [input.log](input.log) |
| 正常开局两策略完整21天、每日合法布局/堆叠/时间、21次日结、终局防重复结算 | failures=0，退出0 | [full-cycle.log](full-cycle.log)、[逐日账本](full-cycle-ledger.json) |

所有测试使用Godot CLI。当前工具发现没有Godot MCP；没有通过Computer Use操作Godot。图形测试通过引擎输入事件驱动，有真实OpenGL视口；不等同真人操作或完整整局UI通关。

## 补齐 H02：正常开局21天

新增 `godot-engine/tests/full_cycle_acceptance.gd`，复用现有合法放置辅助函数。每条策略都从 `Model.new()` 开始，只通过行驶、地点搜索、自动战斗、制作、扩容、升级、物资搬移/合并/舍弃及日结推进。不直接赋值日期、尺寸、速度、健康或资源，不注入物品与图纸。

| 策略 | 终局设施差异 | 行驶里程 | 健康 | 车体 | 剩余水 / 粮 / 油 |
|---|---|---:|---:|---:|---|
| 被动隔热 | 隔热层，无制冷机 | 1620km | 8 | 36 | 0 / 9 / 12 |
| 发电制冷 | 隔热层＋发电机＋制冷机 | 4680km | 56 | 36 | 16 / 18 / 3 |

两条策略均完成第21晚胜利。第二条在高温期仍进行了行驶和搜集；第一条用健康承受余热。账本包含每日开始库存、日结结果、终了库存与设备状态。该结果仅证明至少两条合法可达路径，不证明所有选择可补救、平衡合理或玩家容易理解。

测试策略初版因仅保留一箱口粮、漏搜燃油补给导致一条路线断粮失败；调整测试玩家的装载/停靠策略后通过，没有因此修改游戏数值或规则。

## 画面检查

本次生成8张截图，人工查看了[初始画面](roadseer-speed-initial.png)、[战斗画面](roadseer-speed-combat.png)、[1280×820窗口](roadseer-speed-small.png)：中文可读，公路/车厢/上下文三栏及主要操作按钮在所查画面内可见。其他截图保留供复核，不代表所有分辨率、DPI或显卡已覆盖。

原输入测试写死 `/tmp` 截图目录，本次改为支持 `ROADSEER_TEST_OUTPUT_DIR`，默认写入Godot用户目录，并断言目录创建与截图保存成功；未改动游戏逻辑。

## 仍未完成与决策

- H01：Godot MCP未接入。H03：趣味性仍待真人试玩；本次策略第7天便可备齐被动路线物资，第8～21天不再行驶即可胜利，说明后半程可能缺乏行动动机，应优先验证。
- H04/H05：对照片段和新A/B/C方向尚未选择或实施，本轮不替用户选方向。
- H06：没有存档。H07～H20：完整车辆成长、多层车顶、完整自给、邻接联动、伙伴、随机岔路、丰富事件、雕像、副本、跨世界、交易和复杂状态等仍按handoff所列范围未完成或仅局部存在。
- H21/H22：正式音画资产、全面跨设备适配、独立发行包及发布验收未完成。H23：参考游戏真人试玩与媒体离线完整性未验证。H24：独立旧引擎工程未纳入本次验收。
- H25：本机已取得交接提交及之前4个更新；原文所述“未推送”是旧机器当时状态。本次新增验收文件纳入2026-11-02收纳demo版本，远端同步以实际推送结果为准。

建议下一步先让用户试玩当前速度版，聚焦等待时间、停靠理由、早期囤积后的空档和布局取舍，再确定10～15分钟对照片段。不要将新增系统数量代替玩法验证。

## 复跑

在仓库根目录，使用本机Godot路径：

```powershell
$env:ROADSEER_TEST_OUTPUT_DIR = Join-Path (Get-Location) 'docs/testing/2026-11-01-windows'
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path godot-engine --script res://tests/full_cycle_acceptance.gd
```

模型测试同理运行 `crew_rules.gd`、`journey_acceptance.gd`、`cycle_rules.gd`；图形测试 `layout_a_drag.gd`、`layout_a_input.gd` 不加 `--headless`。
