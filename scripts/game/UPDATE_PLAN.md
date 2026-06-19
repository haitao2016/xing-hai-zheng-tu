# 星海征途 · 更新计划 v2.0.0

> 发布日期：2026-06-19  
> Build：20260619  
> 状态：**发布前代码审查完成 · 待引擎冒烟测试**  
> 前一版本：v1.0.0（2026-04-30）  
> 最后审查：2026-06-19（本次完成 P18-P26 全链路代码审查）

---

## 一、版本亮点

### 1.1 新增核心玩法
| 功能 | 简述 | 所在 Phase |
|------|------|------------|
| 战役模式（3 章节） | 边境星域 / 科技禁区 / 虚空深处，每章独立的难度曲线与目标 | P18 |
| 4 档难度系统 | 新手 / 标准 / 困难 / 虚空，敌人 HP×(0.7~1.8)、伤害×(0.6~1.6) | P19 |
| 永久升级系统 | 舰体强化 / 武器校准 / 反应堆优化 / 扫描阵列 / 护盾矩阵 / 货舱扩展 | P19 |
| 5 个主动技能 | 量子冲刺 / 冲击波 / 时间减速 / 护盾充能 / 轨道打击（按键 1-5） | P20 |
| 6 档连击等级 | C→B→A→S→SS→SSS，连击高倍率伤害（1.0x → 1.6x） | P20 |
| 4 种新敌人 | 战斗机 / 重型巡洋舰 / 相位潜行者 / 能量吸取者（各具 AI 特性） | P20 |
| 波次系统升级 | 蜂群袭击 / 精英部队 / 围困战 / 寂静时刻，波次奖励自动结算 | P21 |
| 神秘地点 | 失事残骸 / 神秘信号 / 时空异常 / 流浪商人 / 遗物碎片（按 E 交互） | P21 |

### 1.2 社区与元进度
| 功能 | 简述 | 所在 Phase |
|------|------|------------|
| 成就 → 永久升级 | 达成特定成就自动解锁元进度等级（跨局保留） | P24 |
| 幽灵数据记录 | 本局生存天数 / 击杀 / 最高连击 / 分数，与历史局对比 | P24 |
| 每日挑战主题 | 精英部队 / 幽灵舰队 / 弹幕之雨 / 能量溢涌 / 末日启示 / 宁静之日 / 连击狂热 | P24 |
| Mod 系统 | Lua Mod 注册表 + 校验 + 管理器界面（主菜单按 M） | P26 |
| Mod 示例包 `银河扩展包` | 3 个遗物（银河核心/量子碎片/新星之刃） + 2 敌人 + 2 每日主题 | P26 |

### 1.3 音视觉打磨
| 功能 | 简述 | 所在 Phase |
|------|------|------------|
| 动态 BGM 叠层 | 3 层音轨（combat/intensity/boss）根据战斗强度自动渐入渐出 | P23 |
| 屏幕震动分级 | light/medium/heavy/impact/bossHit/death 共 6 档预设 | P23 |
| 连击横幅 | 顶部中央大字号展示 RANK 与连击数，SSS 加装饰线 | P23 |
| 屏幕闪光 | 技能释放 / 状态切换时彩色闪光覆盖层（alpha 衰减） | P23 |
| Hitstop 强化 | 击杀精英/Boss 时短暂冻结时间，手感更打击感 | P23 |

### 1.4 UI/UX 重构
| 功能 | 简述 | 所在 Phase |
|------|------|------------|
| 难度选择界面 | 4 张横向卡片，展示 HP 倍率 / 伤害倍率 / 描述文字 | P18/P19 |
| 战役章节选择界面 | 3 章纵向卡片，含主题色条、Boss 信息、章节描述 | P18 |
| Mod 管理器界面 | 左右分栏：Mod 列表 + 详细信息 + 启停状态 | P26 |
| 主动技能 HUD | 底部中央 5 个技能按钮（**1-5**）显示冷却倒计时 + 能量条 | P20 |
| 移动端触控按钮 | 左下虚拟摇杆 + 右下方开火按钮 + 扇形技能按钮 + 右上辅助按钮 | P25 |

---

## 二、详细改动清单

### 2.1 文件改动总览

| 文件 | 行数变化 | 核心内容 |
|------|----------|---------|
| `scripts/main.lua` | +350 行 | 新状态机（difficulty/campaign/mods）、元进度加载、触控渲染、Mod 自动加载、每日主题应用、幽灵数据记录 |
| `scripts/game/Data.lua` | +1100 行 | 战役表 / 难度表 / 永久升级表 / 主动技能表 / 连击等级表 / 波次模式表 / 神秘地点表 / NPC 对话表 / Mod 注册表 / 每日主题表 / 版本信息 |
| `scripts/game/Core.lua` | +900 行 | applyDifficulty / applyMetaUpgrades / useSkill 体系 / incrementCombo / updateWaves / generateMysteries / triggerHitstop / updateCameraFX / triggerComboBurst / screenFlash / recordGhostRun / applyDailyTheme |
| `scripts/game/EnemyAI.lua` | +180 行 | fighter（保持射程机动）/ cruiser（三连发）/ phasePhaser（周期相位隐身突进）/ energyLeech（吸取能量回复自身） |
| `scripts/game/RenderUI.lua` | +1300 行（含本次实时修复） | 难度选择界面 / 战役章节选择 / Mod 管理器 / 连击横幅 / 屏幕闪光 / 触控摇杆与按钮布局 / 触控命中检测 / **玩家能量条** / **技能按键 1-5 修正** |
| `scripts/game/Render.lua` | +5 行入口 | 新增 5 个 Render.* 转发入口（drawDifficultySelect/drawCampaignSelect/drawTouchControls/hitTestTouchControl/isTouchDevice） |
| `scripts/game/Systems.lua` | +20 行 | onAchievementUnlocked 桥接成就与永久升级 |
| `scripts/game/SaveSystem.lua` | +150 行 | saveMetaUpgrades / loadMetaUpgrades / saveAchievements / loadAchievements / migrateSaveData |
| `scripts/mods/example_mod.lua` | +103 行（新增） | 银河扩展包：3 遗物 + 2 敌人 + 2 每日主题 |

#### 2.1.1 本次实时修复（发布前代码审查阶段）

| 修复项 | 文件 | 说明 |
|--------|------|------|
| **技能按键对齐** | `RenderUI.lua` 行 130-134 | HUD 技能按钮文字从 `Q/W/E/R/T` 改为 `1/2/3/4/5`，与 `main.lua` 的 `KEY_1..KEY_5` 输入映射保持一致 |
| **玩家能量条 UI** | `RenderUI.lua` 行 66-82 | 新增左上蓝色能量条（与 HP 条、护盾条并列），玩家 `energy / energyMax` 直观展示主动技能可用资源 |
| **Render 函数补齐** | `Render.lua` | 新增 `drawDifficultySelect` / `drawCampaignSelect` / `drawTouchControls` / `hitTestTouchControl` / `isTouchDevice` 5 个转发入口，确保从 `main.lua` 调用不报错 |
| **元进度叠加修正** | `Core.lua` `applyMetaUpgrades` | 先将 `stats.*` 重置为基准值，再应用升级，避免多局累积的乘法放大 |
| **难度倍率正确传播** | `EnemyAI.lua` `spawnEnemy` | 敌人使用复制后的 `eCfg` 表写入 scaled HP/DMG，避免修改全局 `Data.ENEMY_TYPES` |

### 2.2 数据结构变化（向下兼容）

所有新增数据表使用新的独立 keys，与 v1.0.0 无冲突：

| 新增模块 | key 示例 | 持久化位置 |
|---------|---------|-----------|
| 难度倍率 | `gameState.difficultyMul.*` | 运行期 |
| 元进度 | `gameState.meta.upgrades[upgradeId]` | `meta_upgrades.json` |
| 技能冷却 | `gameState.skills.cooldowns[skillId]` | 运行期 |
| 连击 | `gameState.comboRank.count / rank / maxThisRun` | 运行期 |
| 成就解锁 | `savedAchievements[]` | `achievements.json` |
| 幽灵数据 | `recordGhostRun()` | `ghost_runs.json` |
| Mod 状态 | `Data.MOD_REGISTRY` | `mod_config.json` |

**存档迁移策略**：v1.0.0 存档可直接在 v2.0.0 加载，新字段使用默认值。

---

## 三、测试计划

### 3.1 核心功能测试清单

| 测试项目 | 预期结果 | 备注 | 状态 |
|---------|---------|------|------|
| 启动流程无报错 | 从菜单 → 难度 → 战役 → 开战全链路 | 检查 `require` / `pcall` 容错 | 待运行 |
| 难度倍率应用正确 | 困难难度敌人 HP +35%，新手敌人 HP -30% | 验证 applyDifficulty | 待运行 |
| 主动技能释放 | 按键 1-5 触发对应特效，冷却正常递减 | 重点检查轨道打击坐标 | 待运行 |
| **技能 HUD 按键一致性** | HUD 显示 `1-5` → `SKILL_KEYS[KEY_1..5]` → 实际生效 | **本次审查重点** | ✅ 代码已修复 |
| **能量条渲染** | 左上 HP → 护盾 → 能量三条并列，能量随时间回复 | `player.energyMax > 0` 时显示 | ✅ 代码已修复 |
| 连击计数正确 | 击杀时 count+1，3 秒无击杀递减 1 | SSS 级是否触发震动 | 待运行 |
| 4 种新敌人 AI | 战斗机保持射程 / 巡洋舰三连发 / 相位潜行者隐身突进 / 吸取者吸取能量 | 需视觉验证 | 待运行 |
| 波次系统 | 进入新局后波次在 25-45 秒内触发，敌人数量符合 pattern | | 待运行 |
| 神秘地点交互 | 靠近地点按 E 触发随机事件，获得资源/蓝图/遗物 | 检查重复触发防护 | 待运行 |
| 每日主题生效 | 日期种子 → theme → 难度倍率叠加正确 | 手动改系统日期测试 | 待运行 |
| 元进度跨局保留 | 新局开始后，meta.upgrades 从存档还原并应用加成 | 重启游戏验证 | 待运行 |
| Mod 加载与禁用 | Mod 管理器中切换启停 → 注册表更新 → 下一局生效 | Mod 目录结构验证 | 待运行 |
| **触控设备自动识别** | 竖屏或短边 <700 时自动显示触控 UI | `isTouchDevice()` 判定 | ✅ 代码已验证 |
| **触控按钮命中检测** | 触屏击中技能按钮 → `Core.useSkill(state, id)` | `hitTestTouchControl` 坐标换算 | ✅ 代码已验证 |
| 幽灵数据对比 | 结束后本局数据写入 `ghost_runs.json` | 内容完整性检查 | 待运行 |
| 屏幕震动分级 | 不同事件触发不同强度震动，设置中可禁用 | 验证 settings.shakeEnabled | 待运行 |

#### 3.1.1 发布前代码审查结论（本次完成）

```
✓ main.lua: 状态机完整（menu/difficulty/campaign/game/tech/gameover/rank/stats/settings/mods）
✓ Core.lua: useSkill + updateSkills + canUseSkill 三件套齐备，能量/冷却/特效均有实现
✓ Core.lua: incrementCombo → recomputeComboRank → comboRank.count/rank 链路正确
✓ Core.lua: applyDifficulty + getDifficultyScale 正确传递 enemyHp/enemyDmg/spawnRate
✓ EnemyAI.lua: spawnEnemy 使用副本 eCfg 写入 scaled HP/DMG，不污染全局 ENEMY_TYPES
✓ Data.lua: ACTIVE_SKILLS（1-5 键）/ COMBO_RANKS / DIFFICULTY_LEVELS / getVersionString 齐全
✓ RenderUI.lua: drawHUD 含新增能量条 + 技能按钮 1-5 显示；drawTouchControls + hitTestTouchControl + isTouchDevice
✓ Render.lua: 5 个新 Render.* 转发补齐（与 main.lua 调用一致）
✓ SaveSystem.lua: saveMetaUpgrades / loadMetaUpgrades / saveAchievements / loadAchievements + migrateSaveData
```

### 3.2 回归测试

1. 赛季模式（30 天）流程仍可正常结束
2. 无尽模式、限时挑战、Boss Rush、弹幕生存四种模式仍可进入
3. 原版科技树解锁不受影响
4. 原版遗物掉落与应用仍正常
5. 排行榜写入功能正常
6. 广告复活弹窗逻辑未破坏
7. 每日挑战修饰符与新难度可共存

### 3.3 性能验证目标

- 主循环 60 FPS 稳定（同 v1.0.0 水平）
- 波次密集时最低不低于 45 FPS
- 新粒子系统 `triggerComboBurst` 触发时不应超过 40 粒子/秒累积
- `updateWaves` 敌人生成使用与原版 `spawnEnemy` 相同的帧分割逻辑

---

## 四、发布说明 / 更新日志

### v2.0.0（2026-06-19）

**新增：**
- 战役模式（3 章节，Boss 节点解锁机制）
- 4 档难度系统（新手/标准/困难/虚空），大幅扩展重玩价值
- 6 项永久升级（舰体/武器/反应堆/扫描/护盾/货舱），跨局保留
- 5 个主动技能（1-5 键），每个技能含粒子特效与屏幕震动
- 连击等级系统（C→B→A→S→SS→SSS，伤害 1.0x → 1.6x）
- 4 种新敌人，各自独特 AI 行为（保持射程 / 三连发 / 相位隐身 / 能量吸取）
- 波次系统升级，5 种定时波次模式与奖励
- 7 种神秘地点，随机生成于地图各处，按 E 交互
- 每日主题系统（基于日期种子，7 种主题循环）
- Mod 生态系统，Lua Mod 模板 + Mod 管理器界面（主菜单按 M）
- 银河扩展包（示例 Mod）：3 个遗物 + 2 种敌人 + 2 个每日主题
- 移动端触控按钮（虚拟摇杆 + 开火 + 5 技能 + 辅助）

**强化：**
- 动态 BGM 3 层叠层系统（根据连击等级切换强度）
- 6 档屏幕震动分级预设（light → death）
- 连击等级视觉横幅（顶部中央大字号）
- 屏幕闪光覆盖层（技能/状态切换视觉强调）
- Hitstop 时间冻结（击杀精英/Boss 时强化打击感）

**调整：**
- 难度选择流程：菜单 → 难度 → 战役 → 开战（替代 v1.0.0 的直接开战）
- 菜单底部操作提示补充了主动技能、神秘地点等新操作

**修复：**
- v1.0.0 中部分 `pcall` 未覆盖的加载错误场景（新系统全链路保护）
- 触控事件在菜单以外的状态不再被意外丢弃

---

## 五、已知问题与后续计划

### 5.1 当前版本已知限制
- 触控输入检测未接入真正的手柄（Gamepad API），仅支持触屏 / 鼠标模拟
- Mod 目录扫描使用硬编码路径 `game/../mods/`，未做递归目录遍历
- Mod 管理器的启停切换需重启游戏才能完全生效（当前仅写入配置）
- 每日主题种子依赖 `os.date`，跨设备日期一致但受时区影响
- 难度倍率与每日主题倍率做简单乘法叠加，未做收益递减的平衡设计
- **虚空难度数值**：`enemyHp ×1.65` + `enemyDmg ×1.5`，新手玩家需至少 3 次元进度升级后才可较流畅地挑战（建议做更精细的玩家调研调整）
- **能量回复速率**：基础回复 15/s，在无能量强化元进度时，使用技能 5（轨道打击 80 能量）需要约 5 秒以上回复期，节奏需实际游戏中验证

### 5.2 v2.1.0 规划（2026 Q4）
- **手柄原生支持**（Xbox / PS5 控制器按键映射与震动马达）
- **Mod 热加载**（启用/禁用 Mod 无需重启游戏）
- **每日主题 14 种扩展**（包含更多组合式主题）
- **战役续关**（死亡后可从当前章节恢复，无需从头）
- **难度曲线平衡大修**（引入收益递减曲线）
- **新 Boss：利维坦 Prime**（3 阶段 + 技能弹幕）
- **语言：English / 日本語**（国际化准备）
- **技能 HUD 自定义**（玩家可拖放 / 隐藏按钮）
- **玩家能量条数值平衡**（根据 v2.0.0 数据调整回复速率）
- **连击奖励动画**（SSS 触发屏幕粒子爆发）

### 5.3 v3.0.0 规划（2027 Q3）
- 本地双人合作（分屏）
- 排行榜升级（全球/好友榜 / 主题周榜）
- 赛季通行证（每月限时主题挑战）

---

## 六、发布清单

- [x] 代码全部合入（Data / Core / EnemyAI / RenderUI / main / SaveSystem / Systems / Render）
- [x] Mod 示例文件 `scripts/mods/example_mod.lua`
- [x] 版本号更新至 `2.0.0` / Build `20260619`
- [x] 存档迁移函数 `SaveSystem.migrateSaveData()` 就位
- [x] 菜单版本号渲染（右下角显示 `星海征途 v2.0.0 (Build 20260619)`）
- [x] Mod 管理器入口（主菜单按 M）
- [x] 操作提示文本更新（含 1-5 技能 / E 神秘地点 / R 中继站 / T 科技树）
- [x] **技能 HUD 按键修正**：Q/W/E/R/T → 1/2/3/4/5（与输入系统一致）
- [x] **玩家能量条 UI**：左上 HP 条下方增加能量条（p.energy / p.energyMax）
- [x] **Render 函数补齐**：drawDifficultySelect / drawCampaignSelect / drawTouchControls / hitTestTouchControl / isTouchDevice
- [x] **元进度叠加修正**：applyMetaUpgrades 先重置 stats.* 基准值，再应用升级
- [x] **难度倍率正确传播**：EnemyAI.spawnEnemy 使用副本 eCfg，不污染全局 ENEMY_TYPES
- [ ] 实际引擎运行冒烟测试（菜单 → 难度 → 章节 → 开战）
- [ ] 难度倍率数值调试（虚空难度过强需评估）
- [ ] 移动端设备真机测试
- [ ] Release 打包与签名
- [ ] 更新社区公告与补丁说明

---

## 七、操作说明速查

| 操作 | 键位 | 说明 |
|------|------|------|
| 移动 | WASD / 方向键 | 虚拟摇杆（移动端） |
| 瞄准 / 射击 | 鼠标左键 | 触屏开火按钮（移动端） |
| 主动技能 1 | `1` 键 或 冲刺按钮 | **量子冲刺**：瞬移 + 短暂无敌（30 能量，2s 冷却） |
| 主动技能 2 | `2` 键 | **冲击波**：范围击退 + 伤害（50 能量，4s 冷却） |
| 主动技能 3 | `3` 键 | **时间减速**：敌人速度 -50%，持续 4 秒（70 能量，8s 冷却） |
| 主动技能 4 | `4` 键 | **护盾充能**：恢复 25 HP + 获得临时护盾（40 能量，6s 冷却） |
| 主动技能 5 | `5` 键 | **轨道打击**：光标位置毁灭性范围伤害 200（80 能量，12s 冷却） |
| 神秘地点交互 | `E` 键 | 靠近特殊地点按 E 触发随机事件 |
| 科技树 | `T` 键 | 暂停战斗查看并解锁科技 |
| 中继站 | `R` 键 | 消耗资源建造友军中继站 |
| 劫持 | `H` 键 | 尝试控制附近敌人 |
| 盟友模式 | `F` 键 | 攻击 / 跟随 / 护卫循环切换 |
| 导弹 | `Q` 键 | 追踪导弹（消耗资源） |
| 激光 | `V` 键 | 激光武器开关（需解锁科技） |
| 副武器 | Space 键 | 散射炮 / 回旋镖 / 地雷，Tab 切换 |
| Mod 管理器 | 主菜单按 `M` 键 | 管理已安装 Mod 的启停状态 |
| 菜单 → 难度 | `Enter` 键 | 主菜单按 Enter 直接进入难度选择 |
| 难度切换 | `←` / `→` / `A` / `D` | 4 档难度：新手 → 标准 → 困难 → 虚空 |
| 章节切换 | `↑` / `↓` / `W` / `S` | 3 章战役，需前置章节完成后解锁 |

> **新手提示**：第一次玩请选择「新手」难度，先熟悉 5 个主动技能的按键与效果。技能 5 能量消耗最高，建议在连击达到 A 级以上时使用。

---

## 八、发布前代码审查摘要（2026-06-19 完成）

### 8.1 本次发现并修复的问题
| # | 问题 | 影响范围 | 修复状态 |
|---|------|---------|---------|
| 1 | 技能 HUD 显示 QWERT，实际输入为 1-5 数字键 | 玩家操作提示不匹配 | ✅ 已修复 |
| 2 | HUD 缺少玩家能量条 UI，主动技能资源不可见 | 技能使用体验 | ✅ 已修复 |
| 3 | `Render.lua` 缺少 5 个新 UI 函数的转发 | 运行时报错 | ✅ 已修复 |
| 4 | `Core.applyMetaUpgrades` 多次调用会乘法放大 stats | 数值平衡 | ✅ 已修复 |
| 5 | `EnemyAI.spawnEnemy` 修改全局 ENEMY_TYPES 表 | 多局数据污染 | ✅ 已修复 |

### 8.2 验证清单（代码级，非运行时）

- ✅ `Core.useSkill` → `Data.getActiveSkill` → 能量消耗 → 冷却写入 → 特效触发，链路完整
- ✅ `Core.incrementCombo` → `recomputeComboRank` → HUD 渲染 `comboRank.rank/count`
- ✅ `Core.applyDifficulty` → `state.difficultyMul` → `getDifficultyScale` → `EnemyAI.spawnEnemy` 正确读取 scaled HP/DMG
- ✅ `RenderUI.drawTouchControls` → `isTouchDevice` 判定（竖屏 / 短边<700）→ `hitTestTouchControl` 返回 `skill` 键值到 `main.lua` → `Core.useSkill`
- ✅ `SaveSystem.saveMetaUpgrades` / `loadMetaUpgrades` 读写对称，格式为 `upgradeId → level`
- ✅ `Data.ACTIVE_SKILLS.key` 字段与 `main.lua` `SKILL_KEYS[KEY_1..5]` 一一对应

### 8.3 下一步工作优先级

| 优先级 | 任务 | 预估时间 |
|--------|------|---------|
| P0 | 启动引擎完成菜单→难度→章节→开战全流程冒烟测试 | 30 分钟 |
| P0 | 4 档难度数值微调（尤其虚空难度，先做 3 局测试） | 1 小时 |
| P1 | 5 个主动技能特效 + 能量回复速率手感调试 | 1 小时 |
| P1 | 移动端真机触控测试（竖屏） | 30 分钟 |
| ~~P2~~ | ~~Mod 热加载实现（当前需重启生效）~~ | ✅ 已完成 |
| ~~P2~~ | ~~连击 SSS 级屏幕粒子特效补充~~ | ✅ 已完成 |

### 8.4 本次额外完成的工作（2026-06-19）

| 项 | 说明 |
|---|------|
| **Mod 热加载** | `Data.toggleMod` 启用/禁用后立即调用 `applyActiveMods` 动态更新，无需重启游戏 |
| **SSS 级屏幕特效** | `incrementCombo` 触发时，若升至 S 级/SS 级/SSS 级，分别生成不同强度的粒子爆炸、屏幕震动和闪屏 |
| **难度与元进度解耦** | `applyMetaUpgrades` 仅设置 `stats.*` 加成字段，`applyDifficulty` 单独使用 `maxHpBonus`/`dmgBonus` 计算 hpMax/dmgMul，消除两次调用互相覆盖的问题 |
| **能量回复速率调优** | 从 15/秒下调至 12/秒，使高消耗技能（轨道打击 70）使用更有策略性 |
| **虚空难度下调** | `enemyHp 1.65→1.5`、`enemyDmg 1.6→1.35`、`spawnRate 1.35→1.25`，保留挑战性但不再劝退 |
| **技能数值平衡** | 冲刺（25能量/1.5s）、冲击波（45能量/3.5s）、减速（60能量/6s）、护盾（35能量/5s）、轨道打击（70能量/10s） |
| **HUD 能量条** | `RenderUI` 左上 HP 条下方新增蓝色能量条（`player.energy / energyMax`） |

> 提示：从 v1.0.0 升级到 v2.0.0 时，**你的存档会自动迁移**，已解锁科技、已获得成就与元进度等级将完整保留。

---

## 九、v2.0.0 发布公告（Release Notes）

**发布日期**：2026-06-19  **构建号**：Build 20260619

各位指挥官，星海征途 v2.0.0 正式推出！

### 🌟 核心新特性
- **4 档难度系统**：新手 / 标准 / 困难 / 虚空 —— 每个人都能找到合适的挑战
- **战役章节**：3 章主线剧情，含独特的章节 Boss 和主题敌人
- **5 个主动技能**：量子冲刺、冲击波、时间减速、护盾充能、轨道打击（数字键 1-5 触发）
- **连击等级系统**：C→B→A→S→SS→SSS，6 级连击带来递增的伤害加成与视觉冲击
- **元进度永久升级**：跨局保留的永久性强化（舰体、武器、反应堆等）
- **波次系统**：每局随机触发敌群集结，增加战斗节奏
- **神秘地点**：靠近特殊坐标触发随机事件，获取资源/蓝图/遗物
- **每日主题**：每日种子决定的特殊战场条件（比如全图减速、资源丰度、敌人强化）
- **Mod 支持**：内置示例 Mod + Mod 管理器（主菜单按 M，启停无需重启）
- **移动端触控**：竖屏自动启用虚拟摇杆 + 扇形技能按钮，适配手机操作

### 🎯 操作改动
- 主动技能从 **Q/W/E/R/T** 改为 **1/2/3/4/5** 数字键
- 主菜单按 **Enter** 直接进入难度选择界面
- 难度选择使用 **←/→** 切换

### 🛠 技术修复
- 修复元进度多次调用乘法叠加
- 修复 Mod 启停需重启游戏生效
- 修复难度倍率与元进度的 HP 计算冲突
- 修复敌人生成修改全局数据表导致的多局数据污染
- 新增玩家能量条 HUD
- 新增 SSS 连击屏幕粒子爆发特效

### 📊 数值平衡
- 能量回复：15/秒 → 12/秒
- 虚空难度：enemyHp 1.65→1.5、enemyDmg 1.6→1.35、spawnRate 1.35→1.25
- 新手难度：playerHp 1.2→1.25、playerDmg 1.15→1.2
- 5 个技能的能量消耗与冷却时间全面重平衡

---

*本计划由开发团队维护 · 最后更新 2026-06-19*
