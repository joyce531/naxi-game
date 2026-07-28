# Project Handoff

> 日期：2026-07-28  
> 分支：`feature_art`（已与 `origin/feature_art` 同步，工作区干净）  
> 本窗口主任务：诊断并修复 VN 图片不显示（占位/孤儿资源）→ 规范化命名 → 接线立绘/背景 → 整理 UI 协作方式并交接  
> 相关 commit 示例：`29c24cc` 规范化命名；`2999c36` 解决展位符的问题；后续美术已追加 quiz UI 切图与挂画素材

---

## 1. 项目简介

- **项目目的**  
  纳西文化 Demo（Godot）：通过视觉小说（Dialogic）+ 小游戏，让玩家接触东巴文字与纳西古乐。内容与代码分离，便于非程序同学改 JSON / 换素材。

- **当前实现功能**
  - 主菜单：开始 / 继续（存档只记流程 step）
  - VN 剧情段：`opening` → `dongba_intro` →（东巴答题）→ `clear_story` → `music_intro` →（古乐答题）→ 结束
  - 东巴 quiz / 古乐 quiz：错题重问；累计错满次数后跳过并给提示；结束后 `advance()` 进下一步（无独立通关失败卡死）
  - ContentDB 读 `Data/content.json`，缺失音视频有 placeholder 兜底
  - VN 背景 + 角色立绘已接到 Dialogic（本窗口完成的核心）

---

## 2. 当前技术栈

- **Framework:** Godot 4.6（项目按 Godot 4 场景/资源格式）
- **Language:** GDScript
- **Libraries / Plugins:**
  - Dialogic `2.0-Alpha-19 (Godot 4.4+)`（以 `addons/dialogic/plugin.cfg` 为准）
  - 自定义样式：`Assets/vn/style/naxi_style.tres`
- **APIs:** 无外部网络 API；本地 `user://savegame.json` 存档

---

## 3. 当前项目状态

### 已完成

- [x] Demo 主流程可跑通（VN ↔ quiz ↔ end）
- [x] `GameManager` 统一调度；VN/quiz 完成走 `advance()`
- [x] `content.json` 题库结构（东巴多题型 + 古乐辨识）
- [x] VN 立绘命名规范化（去空格、修拼写：`casual` / `pedestrian` / `neutral`）
- [x] Dialogic 角色接线：`tourist`=女主/游客，`host`=男主/朋友
- [x] 四段 `.dtl` 增加 `background` + `join`；说话人改用角色 ID（`tourist`/`host`），界面仍显示中文名
- [x] `opening` 背景定为直接 `bg_at_home_yard`（无古城过渡、无淡入）
- [x] `clear_story` / `dongba_intro` / `music_intro` 暂用 `bg_in_the_room`
- [x] 美术侧已入库：答题 UI 切图（`Assets/vn/UI/quiz/...`）、挂画 `deco_dongba_painting.png`
- [x] 明确「墙上字放大特写」暂不做，留给美术后续设计

### 未完成

- [ ] 将 `Assets/vn/UI/quiz/**` 切图真正接到 `QuizCard` / `DongbaQuiz` / `MusicQuiz` / 主菜单等场景（目前仓库有图，代码/场景**尚未引用**）
- [ ] 挂画 `deco_dongba_painting` 接入剧情或特写流程（用户曾选方案 A：Dialogic 背景切换；后叫停，等美术）
- [ ] 路人立绘 `char_pedestrian_01/02` 接线（表有，剧本未用）
- [ ] `clear_story` 背景仍为「暂定」`bg_in_the_room`，待最终确认
- [ ] 东巴 glyph/audio、古乐 ogv、sfx 等大量内容素材仍可能缺失（靠 placeholder / 空图逻辑）
- [ ] UI 大换血（主菜单 + 答题页）：设计稿驱动 + 改 `.tscn`/Theme；逻辑脚本尽量不动
- [ ] 给美术 Agent 的约束文档尚未落盘为独立 rules 文件（本 handoff 第 9 节有摘要）

---

## 4. 项目结构说明

```
naxi-game/
  Core/
    GameManager.gd      # 唯一流程调度 + quiz session / 存档
    ContentDB.gd        # 读 content.json；load_texture/audio/video + 缺失兜底
    SceneLoader.gd      # 切场景
  Data/
    content.json        # 题库、素材路径、中文文案（禁止把这些硬编码进 .gd）
  Dialogues/
    tourist.dch / host.dch   # 角色 + 立绘
    opening.dtl / dongba_intro.dtl / clear_story.dtl / music_intro.dtl
  Scenes/
    MainMenu / VNStage / DongbaQuiz / MusicQuiz / QuizCard / EndScreen / ResultScreen
  Assets/
    vn/backgrounds/     # bg_{slug}.png
    vn/portraits/       # char_{name}_{emotion}.png
    vn/decorations/     # 如 deco_dongba_painting.png（未接线）
    vn/UI/quiz/         # 答题 UI 切图（未接线）
    vn/style/           # Dialogic naxi_style
    dongba/ music/ sfx/ _placeholder/
  docs/handoff/         # 本交接目录
  addons/dialogic/      # 插件本体，勿随意改
  .cursorrules          # 项目铁律（Agent 必读）
```

---

## 5. 核心设计决策

- **内容与代码分离**  
  中文、题目、素材路径只进 `content.json`（及 Dialogic 对话资源），方便文案/美术换内容不改架构。

- **GameManager 单一调度**  
  禁止为单个小游戏发明 `start_quiz` 之类专属信号；完成一律 `advance()` 或统一 `advance` 信号。扩展成本保持「加 step + 加场景」。

- **Dialogic 管 VN，不重复造对话系统**  
  背景用 `[background arg="res://..."]`，立绘用 `join tourist (default) left` 等；样式在 `naxi_style.tres`（底部对话框约 1906×200，按约 1920×1080 设计）。

- **说话必须用角色目录 ID**  
  `project.godot` 里是 `tourist` / `host`。若 `.dtl` 写「游客:」「朋友:」，Dialogic 会创建**无立绘临时角色**，图再对也显示不出来。`display_name` 负责屏幕上的中文名。

- **素材缺失容错**  
  ContentDB：缺图返回 null（调用方画占位框）；缺音频回落到 `Assets/_placeholder/silent.wav`。正式资源按约定命名覆盖即可。

- **Retry 范围（1.0）**  
  只做「重做错题」，不做整模块推倒重来；须有退出路径（回主菜单）。

- **墙上字特写（未做）**  
  曾定方案 A：纯 Dialogic 换背景到书法特写图，不改核心调度。用户要求先不做。

- **UI 大换血协作**  
  美术出设计稿 + 切图；改外观优先动 `.tscn`/Theme，不改 `.gd` 逻辑与节点名。美术可用自己的 Agent，但必须带约束（见第 9 节）。

---

## 6. 当前代码状态

重要组件：

- **`Core/GameManager.gd`**
  - 功能：有序 `_flow`；`start_game` / `advance` / 存读档；quiz 错题队列与 `MAX_WRONG`
  - 状态：稳定；本窗口未改其核心跳转逻辑

- **`Core/ContentDB.gd`**
  - 功能：解析 `content.json`；`load_texture` / `load_audio` / `load_video`
  - 状态：稳定；VN 图不走 ContentDB，走 Dialogic 资源路径

- **`Scenes/VNStage.gd` + `VNStage.tscn`**
  - 功能：按 `pending_timeline` 启动 Dialogic；结束或 `advance` 信号后 `GameManager.advance()`
  - 状态：BG 仍是 ColorRect 底色；真正背景由 Dialogic FullBackground 层绘制

- **`Dialogues/tourist.dch` / `host.dch`**
  - 功能：立绘字典 + `default_portrait`
  - 状态：已接线；路人未建角色文件

- **`Dialogues/*.dtl`**
  - 功能：剧情 + background/join
  - 状态：`opening` 仅 `bg_at_home_yard`；其余屋内背景已加

- **`Scenes/QuizCard.gd` / `DongbaQuiz` / `MusicQuiz` / `MainMenu`**
  - 功能：答题与菜单交互
  - 状态：逻辑可用；视觉偏默认控件。`Assets/vn/UI/quiz/**` **尚未挂上**

- **`Assets/vn/decorations/deco_dongba_painting.png`**
  - 功能：墙上东巴挂画特写素材（美术已传）
  - 状态：文件在库，**无场景/时间线引用**

---

## 7. 已知问题 / Bug

列表：

1. **答题/主菜单 UI 仍丑** — 切图已部分入库（`Assets/vn/UI/quiz/`），但未接入场景；需要程序或美术 Agent 改 `.tscn`/Theme。
2. **挂画未进流程** — `deco_dongba_painting` 与 opening 文案中的「墙上作品」未做视觉特写。
3. **剧本说话人曾用中文名** — 已改为 ID；若有人再改回「游客:」「朋友:」会再次丢立绘。
4. **重命名立绘后依赖 Godot 重导** — 若本机 `.import` 异常，先在编辑器里重新导入再跑。
5. **`__pycache__/_tmp_read_xlsx.cpython-39.pyc`** 曾出现在「解决展位符」相关改动里 — 临时读表残留，不宜再进仓库；若仍存在可删并不要再提交。
6. **内容素材缺口** — `content.json` 指向的 dongba/music 文件可能仍缺，运行时走空图/静音，属预期容错而非崩溃。
7. **`clear_story` 背景未最终定稿** — 暂用 `bg_in_the_room`。
8. **设计分辨率** — `project.godot` 未显式写死 viewport；Dialogic 文本框按约 1920 宽配置，UI 设计建议统一 1920×1080 并与程序确认。

---

## 8. 下一步开发计划

按照优先级：

**P0:**
- 在 Godot 实机验收 VN：背景、左右立绘、中文显示名、整段流程
- 把 `Assets/vn/UI/quiz/**` 接到答题相关场景（先东巴答题一屏跑通，再铺古乐/菜单）
- 确认切图九宫格（`*_9p.png`）在 Godot StyleBoxTexture 中的边距设置

**P1:**
- UI 大换血协作落地：主菜单 + QuizCard；遵守「只改场景/Theme，不改节点名与 `.gd` 逻辑」
- 与美术确认 `clear_story` 最终背景；是否启用挂画特写（方案 A：`.dtl` 换 background）
- 清理仓库里不应提交的临时文件；补齐缺失的 dongba/music 正式素材（同名覆盖）

**P2:**
- 路人角色与剧本（若需要）
- 情绪立绘在对话中的切换（`host (formal):` / `tourist (happy_01):` 等）
- 将「美术 UI 规范 / Agent 约束」写成 `docs/` 或 Cursor rule，供美术同学的 Agent 直接引用
- ResultScreen 等遗留界面是否废弃或美化

---

## 9. 给下一位 Agent 的注意事项

避免重复踩坑。

1. **先读 `.cursorrules`**：内容进 JSON、禁止绝对路径、placeholder 兜底、流程只走 GameManager、设计取舍先问用户、不要主动 commit。
2. **VN 图不显示时先查三件事**：`.dch` 是否有 portraits；`.dtl` 是否有 background/join；说话人是否为 `tourist`/`host`（不是「游客」「朋友」）。
3. **不要为显示挂画/UI 去改 GameManager 核心跳转**；特写用 Dialogic background 事件即可（等用户确认再做）。
4. **UI 换皮**：优先改 `.tscn` / Theme / 贴图；**禁止**擅自改节点名（如 `StartButton`）、信号连接、`content.json` 答案、`addons/dialogic`。
5. **已接线资源换视觉用同名覆盖**；改名必须同步所有引用。
6. **当前分支是 `feature_art`**，不是默认去改 `develop`；合并走 PR。
7. **美术 Agent 可用，但须约束**：可改场景与 `Assets/vn/UI/`；不可改玩法脚本与流程；先做主菜单+东巴答题，实机对设计稿验收后再铺开。
8. **用户沟通语言**：直接、简洁；架构取舍先提案再写码。
9. **本窗口未要求的 md 不要乱建**；本文件为用户明确要求的交接文档。
10. **开场建议**：`git status` → 问用户「验收 VN / 接 quiz UI / 挂画特写 / 其他」→ 再动手。

---

## 附录：已确认的角色与背景映射

| 表中角色 | Dialogic | 默认立绘 |
|---|---|---|
| 女主 | `tourist`（游客） | `char_female_neutral` |
| 男主 | `host`（朋友） | `char_male_casual` |
| 路人 | 暂不接 | `char_pedestrian_01/02` |

| Timeline | 背景 |
|---|---|
| opening | `bg_at_home_yard`（直接，无淡入） |
| dongba_intro | `bg_in_the_room` |
| clear_story | `bg_in_the_room`（暂定） |
| music_intro | `bg_in_the_room` |

Excel 原始表（本机路径，仅作历史记录）：
- 立绘：`c:\Users\15005\xwechat_files\...\角色立绘对应表.xlsx`
- 背景：`f:\临时文件夹\剧情背景对应表.xlsx`
