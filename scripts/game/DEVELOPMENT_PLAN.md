# 星海征途 - v2.0.0 开发计划 · 执行手册

> 发布日期：2026-06-19  
> 构建号：Build 20260619  
> 当前版本：v2.0.0-beta  
> 基础：ROADMAP.md Phase 18~27  
> 文档目的：将 ROADMAP.md 的高层规划细化为可执行的代码实现计划

---

## 0. 当前系统状态诊断

### 0.1 已实现系统（有运行时逻辑）

| 系统 | 状态 | 关键文件 | 备注 |
|------|------|---------|------|
| 战役章节选择 | ✅ 基础可用 | Data.lua / main.lua | 3 章节，可在菜单中选择 |
| 4 档难度系统 | ✅ 基础可用 | Data.lua / Core.lua / EnemyAI.lua | enemyHp/enemyDmg/spawnRate/playerHp 均有倍率 |
| 主动技能（5个） | ✅ 完整 | Data.lua / Core.lua / main.lua | 能量/冷却/特效完整，按键 1-5 |
| 连击等级系统 | ✅ 完整 | Data.lua / Core.lua / RenderUI.lua | C→B→A→S→SS→SSS |
| 元进度永久升级 | ✅ 基础可用 | Data.lua / Core.lua / SaveSystem.lua | META_UPGRADES + save/load |
| 每日主题 | ✅ 基础可用 | Data.lua / Core.lua | 日期种子 → 主题倍率叠加 |
| NPC 对话数据 | ✅ 数据定义 | Data.lua | NPC_DIALOGUE 有定义，**缺渲染组件** |
| 波次系统 | ✅ 基础可用 | Core.lua / World.lua | state.wave + 定时器，**缺视觉警报** |
| 神秘地点 | ✅ 数据定义 | Data.lua / Core.lua | state.mysteries + 触发逻辑，**缺 UI 提示** |
| Mod 系统 | ✅ 完整 | Data.lua / main.lua | registerMod/toggleMod/applyActiveMods + 管理器 UI |
| 触控支持 | ✅ 基础可用 | RenderUI.lua / main.lua | drawTouchControls + hitTestTouchControl |
| 存档系统 | ✅ 完整 | SaveSystem.lua | saveMetaUpgrades/migrateSaveData/saveGhost |
| 区域化地图 | ✅ 数据定义 | Data.lua | ZONES 表 + getZone，**缺区域切换视觉** |
| 第二武器 | ✅ 数据定义 | Data.lua | SECONDARY_WEAPONS 表，**缺 Q 键切换 + 升级链** |

### 0.2 优先级总览

| 优先级 | 系统 | 预估工作量 |
|--------|------|-----------|
| 🔴 最高（P0） | 支线任务系统 + 对话框组件 + 成就-元进度联动 + 难度数值微调 + QA/冒烟测试 | 6-8 人周 |
| 🟡 高（P1） | 第二武器完整化 + 区域化地图视觉 + 幽灵数据 UI + 波次视觉警报 + 神秘地点 UI | 4-6 人周 |
| 🟢 中（P2） | 可视化科技树 + Mod 管理器增强 + 屏幕空间特效 + 连击视觉强度分级 | 4-5 人周 |

---

## Phase A: 核心缺失系统（P0）
**目标**：补齐最关键的缺失系统，让 v2.0.0 达到"功能完整"  
**预估工作量**：约 6-8 人周  
**验收标准**：所有 Phase A 系统可玩、UI 可操作、无崩溃

---

### A.1 支线任务系统

#### 目标
- 每局随机 3 个支线任务
- 多种类型：击杀/收集/生存/Boss 速杀/建造/连击
- 完成奖励：蓝图 + 元经验
- 任务面板在 HUD 右侧浮动显示

#### 需要修改的文件
| 文件 | 改动 |
|------|------|
| `Data.lua` | 新增 QUESTS_SIDE 表 + getRandomQuests() 函数 |
| `Core.lua` | 新增 state.quests + initializeQuests + updateQuestProgress + completeQuest + 各类任务触发函数 |
| `RenderUI.lua` | 新增 drawQuestPanel() 右侧浮窗 |
| `main.lua` | 在游戏状态下调用 drawQuestPanel |

#### Data.lua - 数据表设计（位置：NPC_DIALOGUE 之后、DAILY_THEMES 之前）

```lua
Data.QUESTS_SIDE = {
    {
        id = "kill_drones", name = "无人机清扫",
        desc = "在本局内击杀 20 个无人机",
        type = "kill", target = 20, targetKind = "drone",
        reward = { blueprint = 3, metaXp = 10 }, difficulty = "easy",
    },
    {
        id = "kill_any_30", name = "歼灭作战",
        desc = "在本局内击杀 30 个任何敌人",
        type = "kill", target = 30, targetKind = "any",
        reward = { metal = 50, metaXp = 8 }, difficulty = "easy",
    },
    {
        id = "kill_elite_5", name = "精英猎杀",
        desc = "在本局内击杀 5 个精英敌人",
        type = "kill", target = 5, targetKind = "elite",
        reward = { blueprint = 5, metaXp = 20 }, difficulty = "hard",
    },
    {
        id = "collect_metal_100", name = "金属收集者",
        desc = "收集 100 单位金属",
        type = "collect", target = 100, resource = "metal",
        reward = { blueprint = 2, metaXp = 10 }, difficulty = "easy",
    },
    {
        id = "collect_energy_60", name = "能量回收",
        desc = "收集 60 单位能量",
        type = "collect", target = 60, resource = "energy",
        reward = { blueprint = 2, metaXp = 10 }, difficulty = "easy",
    },
    {
        id = "survive_day_3", name = "坚守三天",
        desc = "成功进入第 3 天",
        type = "survive", target = 3, targetField = "day",
        reward = { blueprint = 4, metaXp = 15 }, difficulty = "medium",
    },
    {
        id = "no_shield_loss_60s", name = "完美防御",
        desc = "连续 60 秒不掉护盾",
        type = "survive_time", target = 60, failOnHit = true,
        reward = { blueprint = 5, metaXp = 25 }, difficulty = "hard",
    },
    {
        id = "boss_rush", name = "Boss 速杀",
        desc = "在 Boss 出现后 45 秒内击败",
        type = "boss_kill_time", target = 45,
        reward = { blueprint = 8, metaXp = 40 }, difficulty = "hard",
    },
    {
        id = "build_relay_3", name = "防御网络",
        desc = "在本局内建造 3 座中继站",
        type = "build", target = 3, buildKind = "relay",
        reward = { blueprint = 4, metaXp = 15 }, difficulty = "medium",
    },
    {
        id = "combo_S", name = "连击大师",
        desc = "达成 S 级连击",
        type = "combo_rank", targetRank = "S",
        reward = { blueprint = 4, metaXp = 15 }, difficulty = "medium",
    },
}

-- 工具函数：获取随机 N 个不重复任务
function Data.getRandomQuests(count)
    count = count or 3
    local pool = {}
    for _, q in ipairs(Data.QUESTS_SIDE) do table.insert(pool, q) end
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local result = {}
    for i = 1, math.min(count, #pool) do
        table.insert(result, {
            id = pool[i].id, name = pool[i].name, desc = pool[i].desc,
            progress = 0, target = pool[i].target, completed = false,
            reward = pool[i].reward, type = pool[i].type,
            targetKind = pool[i].targetKind, resource = pool[i].resource,
            targetRank = pool[i].targetRank, buildKind = pool[i].buildKind,
        })
    end
    return result
end
```

#### Core.lua - 任务系统实现（位置：newGame 中 comboRank 之后）

```lua
-- 状态字段初始化
state.quests = {
    active = {},
    completed = {},
    noShieldLossTimer = 0,
    bossAppearTime = nil,
}

function Core.initializeQuests(state)
    state.quests.active = Data.getRandomQuests(3)
    state.quests.completed = {}
    state.quests.noShieldLossTimer = 0
    state.quests.bossAppearTime = nil
end

function Core.updateQuestProgress(state, dt)
    if not state.quests or not state.quests.active then return end
    for _, q in ipairs(state.quests.active) do
        if q.completed then goto continue end
        if q.type == "survive" and state.day > q.progress then
            q.progress = state.day
        elseif q.type == "survive_time" and q.id == "no_shield_loss_60s" then
            state.quests.noShieldLossTimer = state.quests.noShieldLossTimer + dt
            local secs = math.floor(state.quests.noShieldLossTimer)
            if secs > q.progress then q.progress = secs end
        end
        if not q.completed and q.progress >= q.target then
            Core.completeQuest(state, q)
        end
        ::continue::
    end
end

function Core.onQuestKill(state, enemyKind)
    if not state.quests then return end
    for _, q in ipairs(state.quests.active) do
        if q.type == "kill" and not q.completed then
            local match = (q.targetKind == "any" or q.targetKind == enemyKind)
            if q.targetKind == "elite" then
                match = (enemyKind == "guard" or enemyKind == "summoner" or
                         enemyKind == "cruiser" or enemyKind == "phasePhaser" or
                         enemyKind == "energyLeech")
            end
            if match then
                q.progress = q.progress + 1
                if q.progress >= q.target then Core.completeQuest(state, q) end
            end
        end
    end
end

function Core.onQuestResource(state, resourceKind, amount)
    if not state.quests then return end
    for _, q in ipairs(state.quests.active) do
        if q.type == "collect" and not q.completed and q.resource == resourceKind then
            q.progress = q.progress + amount
            if q.progress >= q.target then Core.completeQuest(state, q) end
        end
    end
end

function Core.onQuestBuild(state, buildKind)
    if not state.quests then return end
    for _, q in ipairs(state.quests.active) do
        if q.type == "build" and not q.completed and q.buildKind == buildKind then
            q.progress = q.progress + 1
            if q.progress >= q.target then Core.completeQuest(state, q) end
        end
    end
end

function Core.onQuestCombo(state, rank)
    if not state.quests then return end
    local rankOrder = { C = 1, B = 2, A = 3, S = 4, SS = 5, SSS = 6 }
    for _, q in ipairs(state.quests.active) do
        if q.type == "combo_rank" and not q.completed then
            local need = rankOrder[q.targetRank] or 1
            local cur = rankOrder[rank] or 1
            if cur >= need and q.progress < need then
                q.progress = need
                Core.completeQuest(state, q)
            end
        end
    end
end

function Core.onQuestShieldLost(state)
    if not state.quests then return end
    state.quests.noShieldLossTimer = 0
    for _, q in ipairs(state.quests.active) do
        if q.id == "no_shield_loss_60s" and not q.completed then q.progress = 0 end
    end
end

function Core.onQuestBossAppear(state)
    if not state.quests then return end
    state.quests.bossAppearTime = state.elapsedTime or 0
end

function Core.onQuestBossKilled(state)
    if not state.quests or not state.quests.bossAppearTime then return end
    local elapsed = (state.elapsedTime or 0) - state.quests.bossAppearTime
    for _, q in ipairs(state.quests.active) do
        if q.type == "boss_kill_time" and not q.completed and elapsed <= q.target then
            q.progress = q.target
            Core.completeQuest(state, q)
        end
    end
end

function Core.completeQuest(state, quest)
    if quest.completed then return end
    quest.completed = true
    table.insert(state.quests.completed, quest.id)
    local r = quest.reward or {}
    if r.blueprint and state.resources then
        state.resources.blueprint = (state.resources.blueprint or 0) + r.blueprint
    end
    if r.metal and state.resources then
        state.resources.metal = (state.resources.metal or 0) + r.metal
    end
    if r.metaXp then
        state.earnedMetaXp = (state.earnedMetaXp or 0) + r.metaXp
    end
    Core.addToast(state, "任务完成: " .. quest.name .. " +" .. (r.blueprint or 0) .. " 蓝图", { 100, 255, 150 })
    Core.shake(state, 2, 0.2)
    Core.spawnParticles(state, state.player.x, state.player.y, { 100, 255, 150 }, 25)
end
```

**关键插入点**：
- `Core.onQuestKill(state, enemy.kind)` → 在 `Core.onEnemyKilled()` 内调用
- `Core.onQuestShieldLost(state)` → 在玩家护盾减少的逻辑中调用
- `Core.updateQuestProgress(state, dt)` → 在 `Core.update()` 中每帧调用
- `Core.onQuestCombo(state, state.comboRank.rank)` → 在 `Core.incrementCombo()` 末尾调用

#### RenderUI.lua - 任务面板

```lua
function M.drawQuestPanel(vg, sw, sh, state)
    if not state.quests or not state.quests.active or #state.quests.active == 0 then return end
    local panelW = 240
    local panelH = 40 + #state.quests.active * 50
    local panelX = sw - panelW - 20
    local panelY = 120
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 6)
    nvgFillColor(vg, nvgRGBA(10, 15, 25, 180))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(180, 220, 255))
    nvgText(vg, panelX + 12, panelY + 22, "支线任务")
    local itemY = panelY + 40
    for _, q in ipairs(state.quests.active) do
        local isDone = q.completed or false
        nvgFontSize(vg, 11)
        nvgFillColor(vg, isDone and nvgRGBA(100, 255, 150) or nvgRGBA(220, 220, 255))
        nvgText(vg, panelX + 12, itemY + 8, q.name)
        local barW = panelW - 24
        nvgBeginPath(vg)
        nvgRoundedRect(vg, panelX + 12, itemY + 14, barW, 6, 2)
        nvgFillColor(vg, nvgRGBA(50, 60, 80, 200))
        nvgFill(vg)
        local ratio = math.min(1, q.progress / q.target)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, panelX + 12, itemY + 14, barW * ratio, 6, 2)
        local c = isDone and { 100, 255, 150 } or { 100, 180, 255 }
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 220))
        nvgFill(vg)
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(160, 200, 240, 180))
        nvgText(vg, panelX + 12, itemY + 32, tostring(math.floor(q.progress)) .. " / " .. tostring(q.target))
        if isDone then
            nvgFillColor(vg, nvgRGBA(100, 255, 150, 200))
            nvgText(vg, panelX + barW - 30, itemY + 32, "完成")
        end
        itemY = itemY + 50
    end
end
```

**测试清单**：
- [ ] 新开局后 state.quests.active 有 3 个任务
- [ ] 击杀敌人后 kill 类任务进度递增
- [ ] 任务完成 → 奖励发放 + toast 提示
- [ ] 护盾损失时 no_shield_loss_60s 计时器重置
- [ ] 任务面板在 UI 中正确显示并实时更新
- [ ] 达到 S 级连击时 combo_S 任务完成

---

### A.2 对话框渲染组件

#### 目标
- 章节开始显示剧情对话
- 支持多台词轮播、NPC 头像
- Enter/空格 推进对话

#### 需要修改的文件
| 文件 | 改动 |
|------|------|
| `Data.lua` | 检查 NPC_DIALOGUE 表结构，确保有 id/lines/character 字段 |
| `Core.lua` | 新增 triggerDialogue(npcId) + advanceDialogue() + 状态字段 |
| `RenderUI.lua` | 新增 drawDialogBox() 底部对话框 |
| `main.lua` | 对话期间拦截输入，Enter/空格推进 |

#### Core.lua - 对话状态

```lua
state.dialogue = {
    active = false,
    npcId = nil,
    currentLine = 0,
    lines = {},
    characterName = "",
}

function Core.triggerDialogue(state, npcId)
    local npc = Data.getNPCDialogue(npcId)
    if not npc then return end
    state.dialogue.active = true
    state.dialogue.npcId = npcId
    state.dialogue.currentLine = 1
    state.dialogue.lines = type(npc.lines) == "table" and npc.lines or { npc.text }
    state.dialogue.characterName = npc.name or npc.character or "?"
end

function Core.advanceDialogue(state)
    if not state.dialogue.active then return end
    state.dialogue.currentLine = state.dialogue.currentLine + 1
    if state.dialogue.currentLine > #state.dialogue.lines then
        state.dialogue.active = false
    end
end

function Core.getDialogueLine(state)
    if not state.dialogue.active then return nil end
    return state.dialogue.lines[state.dialogue.currentLine], state.dialogue.characterName
end
```

#### RenderUI.lua - 对话框

```lua
function M.drawDialogBox(vg, sw, sh, state)
    if not state.dialogue or not state.dialogue.active then return end
    local text, name = Core.getDialogueLine(state)
    if not text then return end
    local boxW = sw - 200
    local boxH = 140
    local boxX = 100
    local boxY = sh - boxH - 30
    nvgBeginPath(vg)
    nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 8)
    nvgFillColor(vg, nvgRGBA(5, 10, 20, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 180))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)
    -- 角色名
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(255, 220, 100))
    nvgText(vg, boxX + 20, boxY + 28, name)
    -- 台词（自动换行）
    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(240, 240, 255))
    nvgTextBox(vg, boxX + 20, boxY + 60, boxW - 40, text)
    -- 提示
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(160, 200, 240, 180))
    nvgText(vg, boxX + boxW - 100, boxY + boxH - 15, "Enter 继续")
end
```

**测试清单**：
- [ ] 章节开始自动触发对话
- [ ] Enter 键可推进对话
- [ ] 对话期间不影响核心游戏循环
- [ ] 对话结束后自动关闭

---

### A.3 成就 → 元进度联动

#### 目标
- 解锁成就时触发元进度升级奖励
- 玩家可在 UI 中看到已解锁的元升级

#### 需要修改的文件
| 文件 | 改动 |
|------|------|
| `Core.lua` | 验证 applyAchievementUnlocks() 是否正确写入 state.meta.upgrades |
| `SaveSystem.lua` | 确认 saveMetaUpgrades/loadMetaUpgrades 对称 |
| `RenderUI.lua` | 新增简易元进度面板（可选） |

#### 验证清单
- [ ] 解锁成就时，元进度等级递增
- [ ] 重新开始游戏时，meta.upgrades 从存档还原
- [ ] applyMetaUpgrades 设置的 stats 字段（maxHpBonus/dmgBonus/energyRegenBonus）被 applyDifficulty 正确读取
- [ ] saveMetaUpgrades 与 loadMetaUpgrades 字段名一致

---

## Phase B: 系统完整性（P1）
**目标**：让已有数据定义的系统真正完整可用  
**预估工作量**：约 4-6 人周

---

### B.1 第二武器完整化

#### 目标
- Q 键切换散射炮/回旋镖/地雷
- 每种武器独立伤害/冷却升级链
- HUD 底部显示当前副武器

#### 需要修改的文件
| 文件 | 改动 |
|------|------|
| `Data.lua` | 检查 SECONDARY_WEAPONS，补充 upgradeLevel 字段 |
| `Core.lua` | 新增 switchSecondaryWeapon() + fireSecondaryWeapon() |
| `PlayerCtrl.lua` | Q 键绑定切换 |
| `RenderUI.lua` | 底部 HUD 显示当前副武器图标 + 冷却 |

#### 核心函数
```lua
-- Core.lua
state.secondary = {
    current = "spread",
    unlocked = { spread = true, boomerang = false, mine = false },
    upgrades = { spread = 1, boomerang = 1, mine = 1 },
}

function Core.switchSecondaryWeapon(state)
    local order = { "spread", "boomerang", "mine" }
    local nextIdx = 1
    for i, w in ipairs(order) do
        if w == state.secondary.current then
            for j = i + 1, #order do
                if state.secondary.unlocked[order[j]] then nextIdx = j; break end
            end
            if nextIdx == i then -- 没有下一个，回头找第一个
                for j = 1, i - 1 do
                    if state.secondary.unlocked[order[j]] then nextIdx = j; break end
                end
            end
            break
        end
    end
    state.secondary.current = order[nextIdx]
    Core.addToast(state, "副武器: " .. state.secondary.current, { 200, 200, 255 })
end
```

**测试清单**：
- [ ] Q 键切换副武器
- [ ] 每种武器发射正确
- [ ] 未解锁武器无法选中
- [ ] HUD 显示当前副武器 + 冷却

---

### B.2 区域化地图视觉

#### 目标
- 根据玩家位置/当前 Day 切换区域
- 区域背景色渐变
- 敌人/资源倾向根据 ZONES 表

#### 需要修改的文件
| 文件 | 改动 |
|------|------|
| `Data.lua` | ZONES 表已有，验证 bgColor/enemyWeights/resourceWeights 字段 |
| `Core.lua` | state.currentZone + updateZoneByDay() |
| `RenderWorld.lua` | 背景色根据 zone 渐变 |

**测试清单**：
- [ ] Day 1 → 边境星域（深蓝）
- [ ] Day 2 → 科技禁区（青绿）
- [ ] Day 3+ → 虚空裂隙（紫红）
- [ ] 区域切换时背景平滑渐变
- [ ] 不同区域的敌人/资源权重生效

---

### B.3 幽灵数据 UI

#### 目标
- 结算页面显示本局幽灵数据快照
- 对比历史最佳

#### 需要修改的文件
| 文件 | 改动 |
|------|------|
| `Core.lua` | 完善 getGhostSnapshot() 输出内容 |
| `RenderUI.lua` | 结算页面 drawGameOverScreen() 增加幽灵数据块 |
| `SaveSystem.lua` | saveGhost 确保有读取函数 loadGhostBest() |

**测试清单**：
- [ ] 死亡时 saveGhost 被调用
- [ ] 结算页面显示 kills/damage/days/最高连击
- [ ] 历史最佳从 loadGhostBest 读取并对比
- [ ] 新纪录时有特殊高亮显示

---

### B.4 波次视觉警报

#### 目标
- 波次触发时屏幕警告
- 敌人类型倒计时显示

#### 需要修改的文件
| 文件 | 改动 |
|------|------|
| `Core.lua` | updateWaves() 触发时设置警报标志 |
| `RenderUI.lua` | drawWaveAlert() 顶部横幅 |

**测试清单**：
- [ ] 波次开始时顶部显示警告
- [ ] 警告 3 秒后淡出
- [ ] Boss 波次有特殊红色警告

---

### B.5 神秘地点 UI 提示

#### 目标
- 小地图上显示神秘地点位置
- 接近时提示按 E 交互

#### 需要修改的文件
| 文件 | 改动 |
|------|------|
| `RenderUI.lua` | drawMinimap() 增加神秘地点图标 |
| `RenderUI.lua` | drawMysteryHint() 接近时底部提示 |

**测试清单**：
- [ ] 小地图上有神秘地点图标
- [ ] 接近时显示"按 E 探索"
- [ ] 按 E 后神秘地点消失并触发事件

---

## Phase C: UI/UX 增强（P2）
**目标**：让界面更美观、信息更清晰  
**预估工作量**：约 3-4 人周

---

### C.1 可视化科技树节点图（可选）
#### 目标：科技树从列表升级为节点连线图

### C.2 Mod 管理器增强
#### 目标：显示依赖、冲突、版本号，支持"打开 Mod 目录"

### C.3 HUD 布局优化
#### 目标：调整信息密度，确保移动端 60fps

---

## Phase D: 视觉与特效（P2）
**目标**：加强战斗反馈  
**预估工作量**：约 1-2 人周

---

### D.1 屏幕空间特效
- 低血量 <30%：屏幕边缘红色渐晕 + 去饱和
- 受击瞬间：径向模糊 1 帧
- 连击 ≥SSS：全屏轻微震动 + 颜色脉冲

### D.2 连击视觉强度分级
- comboRank 影响粒子颜色饱和/粒子数
- SSS 击杀有额外爆炸粒子

---

## Phase E: QA/平衡与发布准备（P0-P1）
**目标**：确保所有难度平衡、存档正常、系统稳定

---

### E.1 难度数值微调（已完成基础框架 + 需实际游戏验证）

**当前设置**：
- 新手：enemyHp ×0.65, enemyDmg ×0.55, spawnRate ×0.7, playerHp ×1.25, playerDmg ×1.2
- 标准：×1.0 全部
- 困难：enemyHp ×1.3, enemyDmg ×1.2, spawnRate ×1.15, playerHp ×0.9, playerDmg ×1.05
- 虚空：enemyHp ×1.5, enemyDmg ×1.35, enemySpeed ×1.15, spawnRate ×1.25, playerHp ×0.85, playerDmg ×1.1, metaXp ×2.5

**验证清单**：
- [ ] 新手难度：新玩家无元进度 1 局至少能过 Day 1 Boss
- [ ] 标准难度：平衡挑战
- [ ] 困难难度：需 2-3 局元进度才能流畅
- [ ] 虚空难度：需满元进度 + 经验才能稳定通关，极具挑战
- [ ] 各难度资源掉落倍率正确

### E.2 存档迁移测试
- [ ] v0.8.0 存档 → v2.0.0 migrateSaveData 成功
- [ ] meta.upgrades 字段保留
- [ ] achievements 字段保留
- [ ] 新开局后 meta 加成正确应用

### E.3 发布前冒烟测试清单
- [ ] 主菜单 → 难度选择 → 章节选择 → 开战全流程
- [ ] 5 个主动技能各施放 3 次（能量/冷却/特效）
- [ ] 击杀敌人 → 连击等级递增 → SSS 视觉触发
- [ ] 神秘地点事件触发 + 奖励发放
- [ ] 波次系统正常触发敌人
- [ ] Mod 管理器可启用/禁用 Mod（无需重启）
- [ ] 移动端竖屏模式触控按钮可操作
- [ ] 死亡 → 结算 → 元经验结算 → 回主菜单
- [ ] 游戏退出 → saveMetaUpgrades 写入

---

## 发布里程碑

| 里程碑 | 状态 | 说明 |
|--------|------|------|
| M1：Phase A 完成 | ⏳ 待开发 | 支线任务 + 对话框 + 元进度联动 |
| M2：Phase B 完成 | ⏳ 待开发 | 副武器/区域地图/幽灵 UI/波次警报/神秘地点 |
| M3：QA 第一轮 | ⏳ 待测试 | 难度数值平衡 + 存档迁移 |
| M4：v2.0.0-RC1 | ⏳ 待发布 | 所有 P0-P1 完成 |
| M5：v2.0.0 正式发布 | ⏳ | 发布公告 + 社区反馈 |

---

*最后更新：2026-06-19*  
*本计划由开发团队维护，每次 Phase 完成后更新状态列*
