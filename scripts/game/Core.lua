-- ============================================================================
-- 星海征途 - 游戏核心编排器
-- 状态初始化、系统协调、共享工具函数
-- 具体逻辑委托给: PlayerCtrl / EnemyAI / Combat / World
-- ============================================================================

local Data = require("game.Data")
local Systems = require("game.Systems")
local Audio = require("game.Audio")
local U = require("game.CoreUtils")
local PlayerCtrl = require("game.PlayerCtrl")
local EnemyAI = require("game.EnemyAI")
local Combat = require("game.Combat")
local World = require("game.World")
local S = require("game.Strings")

local WORLD = Data.WORLD
local TAU = U.TAU
local rand, randInt, dist, lerp, clamp, angleToward =
    U.rand, U.randInt, U.dist, U.lerp, U.clamp, U.angleToward

local Core = {}

-- 导出工具函数供子模块通过 Core 引用访问
Core.rand = rand
Core.randInt = randInt
Core.dist = dist
Core.clamp = clamp
Core.lerp = lerp
Core.angleToward = angleToward

-- ============================================================================
-- 游戏状态初始化
-- ============================================================================
function Core.newGame(playerName, factionId, gameMode)
    local state = {
        -- 玩家
        player = {
            x = 0, y = 0,
            vx = 0, vy = 0,
            angle = -math.pi / 2,
            hp = 100, hpMax = 100,
            shield = 0, shieldMax = 0,
            fireCd = 0, hitFlash = 0,
            speed = 220, fireRate = 0.25,
            energy = 100, energyMax = 100,
        },
        -- 相机
        cam = { x = 0, y = 0 },
        -- 赛季
        day = 1, dayTimer = 0, dayLength = 22,
        score = 0, seasonOver = false,
        isEndless = false, -- P7.2 无尽模式标志
        gameMode = gameMode or "season", -- P11 游戏模式
        -- P11.1 限时挑战模式参数
        timeAttackDuration = 60,
        -- 资源
        resources = { metal = 0, energy = 0, blueprint = 0, ancient_key = 0 },
        -- 科技
        ownedTech = { "w1" },
        stats = nil,
        -- P18: 战役与难度
        campaignId = nil,
        chapterProgress = {},
        difficultyId = "standard",
        zoneId = "frontier",
        -- P19.2: 元进度（永久升级累积经验/已解锁等级）
        meta = {
            xp = 0,
            upgrades = {},  -- id -> level
        },
        -- P20.1: 主动技能状态
        skills = {
            unlocked = {
                skill_dash = true,
                skill_shock = true,
                skill_slow = true,
                skill_shield = true,
                skill_strike = true,
            },
            cooldowns = {},                     -- id -> remaining seconds
            slowRemaining = 0,                  -- 时间减速剩余
            invulnRemaining = 0,                -- 无敌剩余
            tempShield = 0,                     -- 临时护盾数
        },
        -- P20.2: 连击等级（独立于 Phase3 的 combo 计数器）
        comboRank = {
            count = 0,
            rank = "C",
            decayTimer = 0,
            maxThisRun = 0,
        },
        -- P21.2: 波次状态
        wave = {
            pattern = nil,
            timeInPattern = 0,
            spawnAccumulator = 0,
            nextWaveTimer = 30,
        },
        -- P21.3: 神秘地点（每局随机生成几个）
        mysteries = {},
        -- P12.4: NPC 对话进度
        npcProgress = {
            commander = 0, engineer = 0, scout = 0,
        },
        flags = {},
        playerDied = false,
        isDailyChallenge = false,
        -- 阵营
        factionId = factionId,
        faction = factionId and Data.getFaction(factionId) or nil,
        -- 实体
        enemies = {},
        bullets = {},
        enemyBullets = {},
        asteroids = {},
        particles = {},
        pickups = {},
        relicDrops = {},
        toasts = {},
        -- Boss/任务
        bossesKilled = {},
        bossesSpawned = {},
        completedQuests = {},
        relayStations = {},
        relayCount = 0,
        -- P14.2: 每周挑战
        weeklyChallenge = {
            id = nil, name = nil, progress = 0, target = 0, type = nil, completed = false,
        },
        -- 杂项
        name = playerName or "征途者",
        spawnTimer = 0,
        stars = {},
        floatingTexts = {},
        nearRelay = false,
        shakeTime = 0, shakeIntensity = 0, shakeMaxTime = 0,
        shakeOffX = 0, shakeOffY = 0, shakePhase = 0,
        shakeDirX = 0, shakeDirY = 0,  -- 方向性震动
        -- Phase 23: Hitstop / ScreenFlash FX
        hitstop = 0,
        _screenFlash = {},
        -- Phase 6.4: 相机前瞻
        camLookAheadX = 0, camLookAheadY = 0,
        -- P3.2 统计
        totalKills = 0, totalDmgDealt = 0, totalDmgTaken = 0,
        totalCollected = { metal = 0, energy = 0, blueprint = 0, ancient_key = 0 },
        -- P3.4 临时道具
        powerups = {},
        activePowerups = {},
        -- P4.1 波次
        wavesTriggered = {},
        waveActive = false, waveTimer = 0, waveName = "",
        -- P4.2 随机事件
        eventTimer = rand(15, 30),
        activeEvent = nil, eventRemaining = 0,
        -- P4.5 权限劫持
        allies = {},
        hijackCd = 0,
        -- P3.6 事件选择系统
        eventChoice = nil,
        eventChoiceAnim = 0,
        eventIsSpecial = false,
        -- P7.3 时空裂缝 - 时间缩放
        timeScale = 1.0,
        timeSlowRemaining = 0,
        -- P3.7 Power-up 收集动画
        collectAnims = {},
        -- P3.8 盟友模式
        allyMode = "attack",
        -- P4.4 激光武器
        laser = { active = false, charge = 0, angle = 0, heat = 0 },
        -- P4.5 追踪导弹
        missiles = {},
        missileCd = 0,
        -- P7.1 副武器系统
        secondaryIdx = 1,       -- 当前选中副武器索引 (1=散射炮,2=回旋镖,3=地雷)
        secondaryCd = 0,        -- 副武器冷却
        boomerangs = {},        -- 活跃回旋镖列表
        mines = {},             -- 活跃地雷列表
        -- P4.6 Boss技能可视化
        bossLasers = {},
        bossWarnings = {},
        -- P6.1 新手教程
        tutorialStep = 0,
        tutorialTimer = 0,
        -- P6.2 难度曲线
        diffScale = 1.0,
    }
    -- 计算科技属性
    state.stats = Data.techStats(state.ownedTech)
    Core.applyStats(state, true)
    -- 应用阵营加成
    if state.faction then
        local b = state.faction.bonuses
        if b.dmgMul then state.stats.dmgMul = state.stats.dmgMul * b.dmgMul end
        if b.fireRateMul then state.stats.fireRateMul = state.stats.fireRateMul * b.fireRateMul end
        if b.shieldRegenAdd then state.stats.shieldRegen = state.stats.shieldRegen + b.shieldRegenAdd end
        state.tradeDiscount = b.tradeDiscount or 0
        state.blueprintMul = b.blueprintMul or 1.0
    else
        state.tradeDiscount = 0
        state.blueprintMul = 1.0
    end
    -- P14.2: 初始化每周挑战
    local weekly = Data.getWeeklyChallenge()
    if weekly then
        state.weeklyChallenge = {
            id = weekly.id,
            name = weekly.name,
            desc = weekly.desc,
            target = weekly.target,
            type = weekly.type,
            progress = 0,
            completed = false,
        }
    end
    -- 初始化扩展系统
    Systems.initRelics(state)
    Systems.initHazards(state)
    Systems.initAchievements(state)
    Systems.resetCombo()
    state.bossNoHitFlag = true
    Core.spawnInitial(state)
    Core.generateStars(state)
    Core.generateMysteries(state)
    return state
end

function Core.applyStats(state, reset)
    local s = state.stats
    local newHpMax = math.floor((100 + s.hpBonus) * s.allBonus)
    if reset then
        state.player.hpMax = newHpMax
        state.player.hp = newHpMax
    else
        local ratio = state.player.hp / state.player.hpMax
        state.player.hpMax = newHpMax
        state.player.hp = math.min(newHpMax, math.floor(newHpMax * ratio))
    end
    state.player.shieldMax = math.floor(s.shieldMax * s.allBonus)
    if reset then
        state.player.shield = state.player.shieldMax
    else
        state.player.shield = math.min(state.player.shieldMax, state.player.shield)
    end
    state.player.speed = 220 * s.speedMul
    state.player.fireRate = 0.25 / s.fireRateMul
end

function Core.recomputeStats(state)
    state.stats = Data.techStats(state.ownedTech)
    if state.faction then
        local b = state.faction.bonuses
        if b.dmgMul then state.stats.dmgMul = state.stats.dmgMul * b.dmgMul end
        if b.fireRateMul then state.stats.fireRateMul = state.stats.fireRateMul * b.fireRateMul end
        if b.shieldRegenAdd then state.stats.shieldRegen = state.stats.shieldRegen + b.shieldRegenAdd end
    end
    Core.applyStats(state, false)
end

-- ============================================================================
-- 星空背景 & 初始生成
-- ============================================================================
function Core.generateStars(state)
    state.stars = {}
    for i = 1, 200 do
        state.stars[i] = {
            x = rand(-3000, 3000),
            y = rand(-3000, 3000),
            size = rand(0.5, 2.5),
            brightness = rand(0.3, 1.0),
            layer = randInt(1, 3),
        }
    end
end

function Core.spawnInitial(state)
    for i = 1, 30 do Core.spawnAsteroid(state, "outer") end
    for i = 1, 20 do Core.spawnAsteroid(state, "middle") end
    for i = 1, 8 do Core.spawnEnemy(state, "drone", "middle") end
    for i = 1, 4 do Core.spawnEnemy(state, "aberration", "inner") end
    for i = 1, 2 do Core.spawnEnemy(state, "guard", "inner") end
end

function Core.spawnAsteroid(state, zone)
    local ang = rand(0, TAU)
    local r = rand(200, 2200)
    table.insert(state.asteroids, {
        x = math.cos(ang) * r,
        y = math.sin(ang) * r,
        radius = rand(12, 28),
        rotation = rand(0, TAU),
        rotSpeed = rand(-1, 1),
        metal = randInt(3, 8),
        energy = randInt(2, 6),
        hp = 30,
    })
end

-- ============================================================================
-- 主更新循环（编排器）
-- ============================================================================
function Core.update(state, dt, inputState)
    if state.seasonOver then return end

    -- 时间缩放（来自时间减速技能）
    local scaledDt = dt * state.timeScale
    -- 技能冷却更新
    Core.updateSkills(state, scaledDt)
    -- P20: 能量回复（15/s，乘以元进度加成）
    if state.player.energy and state.player.energyMax then
        local regenRate = 12 * (state.stats.energyRegenBonus or 1)
        state.player.energy = math.min(state.player.energyMax, state.player.energy + regenRate * dt)
    end
    -- 连击衰减
    if state.comboRank.count > 0 then
        state.comboRank.decayTimer = state.comboRank.decayTimer - dt
        if state.comboRank.decayTimer <= 0 then
            state.comboRank.count = math.max(0, state.comboRank.count - 1)
            state.comboRank.decayTimer = 2.0
            Core.recomputeComboRank(state)
        end
    end
    -- 波次系统（在标准刷怪逻辑旁并行）
    Core.updateWaves(state, scaledDt)

    -- Phase 23: Camera FX update
    Core.updateCameraFX(state, dt)

    -- Phase 6: Hitstop - 击杀精英/Boss时短暂冻结
    if state.hitstop and state.hitstop > 0 then
        -- hitstop 期间仅衰减计时器和渲染特效，不更新游戏逻辑
        state.hitstop = state.hitstop - dt
        -- 允许粒子继续更新（视觉不冻结）
        World.updateParticles(state, dt * 0.3)
        Core.updateFloatingTexts(state, dt)
        return
    end

    -- 慢动作时间缩放
    local timeScale = Systems.updateSlowmo(dt)
    -- P7.3 时空裂缝：事件级时间缩放
    if state.timeSlowRemaining > 0 then
        state.timeSlowRemaining = state.timeSlowRemaining - dt
        if state.timeSlowRemaining <= 0 then
            state.timeScale = 1.0
            state.timeSlowRemaining = 0
            Core.addToast(state, S.get("hud_time_normal"), { 100, 200, 255 })
        end
    end
    local gdt = dt * timeScale * (state.timeScale or 1.0)

    -- P11: 模式特定逻辑
    if state.gameMode == "timeattack" then
        -- 限时挑战模式: 60秒倒计时
        state.dayTimer = state.dayTimer + dt
        if state.dayTimer >= state.timeAttackDuration then
            state.seasonOver = true
            Core.addToast(state, "⏱ 时间到!", { 255, 200, 50 })
            return
        end
        -- 每5秒加速刷怪
        local tick = math.floor(state.dayTimer / 5)
        if tick > (state._lastTimeAttackTick or 0) then
            state._lastTimeAttackTick = tick
            for i = 1, 2 + tick do
                Core.spawnEnemy(state, "drone", "middle")
            end
            -- 精英怪
            if tick % 3 == 0 then
                Core.spawnEnemy(state, "guard", "inner")
            end
        end
    elseif state.gameMode == "bullethell" then
        -- 弹幕生存模式: 无限弹幕
        state.dayTimer = state.dayTimer + dt
        -- 持续生成弹幕敌人
        if #state.enemies < 8 then
            Core.spawnEnemy(state, "drone", "middle")
        end
        -- 每波弹幕
        state._bulletWaveTimer = (state._bulletWaveTimer or 0) + dt
        if state._bulletWaveTimer > 3 then
            state._bulletWaveTimer = 0
            for _, e in ipairs(state.enemies) do
                if e and e.hp > 0 and not e.isBoss then
                    e.fireCd = 0  -- 触发弹幕
                end
            end
        end
    elseif state.gameMode == "bossrush" then
        -- Boss Rush模式: 检查Boss击杀后下一波
        local bossAlive = false
        for _, e in ipairs(state.enemies) do
            if e.isBoss and e.hp > 0 then bossAlive = true break end
        end
        if not bossAlive and not state.seasonOver then
            state._bossRushIndex = (state._bossRushIndex or 0) + 1
            local bossOrder = { "crystal", "hive", "titan", "void", "crystal", "hive" }
            if state._bossRushIndex <= #bossOrder then
                Core.spawnBoss(state, bossOrder[state._bossRushIndex])
                -- 恢复30% HP
                state.player.hp = math.min(state.player.hpMax, state.player.hp + state.player.hpMax * 0.3)
                state.player.shield = state.player.shieldMax
                Core.addToast(state, string.format("Boss %d/6: %s", state._bossRushIndex, bossOrder[state._bossRushIndex]), { 255, 100, 100 })
            else
                state.seasonOver = true
                Core.addToast(state, "🏆 Boss Rush 完成!", { 255, 215, 0 })
                return
            end
        end
    else
        -- 正常赛季/无尽模式天数逻辑
        state.dayTimer = state.dayTimer + dt
        if state.dayTimer >= state.dayLength then
            state.dayTimer = state.dayTimer - state.dayLength
            state.day = state.day + 1
            -- P14.2: 每周挑战 - day进度
            if state.weeklyChallenge and not state.weeklyChallenge.completed then
                if state.weeklyChallenge.type == "day" then
                    state.weeklyChallenge.progress = state.day
                    if state.weeklyChallenge.progress >= state.weeklyChallenge.target then
                        state.weeklyChallenge.completed = true
                        Core.addToast(state, "🎯 社区挑战完成: " .. state.weeklyChallenge.name, { 0, 255, 180 })
                    end
                end
            end
            if not state.isEndless and state.day > 30 then
                state.seasonOver = true
                Core.addToast(state, S.get("hud_season_end"), { 255, 215, 0 })
                return
            end
            Core.onNewDay(state)
        end
    end

    -- 输入桥接：将 inputState 存入 state 供 PlayerCtrl 读取
    local mx, my = 0, 0
    if inputState.up then my = my - 1 end
    if inputState.down then my = my + 1 end
    if inputState.left then mx = mx - 1 end
    if inputState.right then mx = mx + 1 end
    state.inputMoveX, state.inputMoveY = mx, my
    state.inputFire = inputState.fire
    state.inputAimX = inputState.aimX
    state.inputAimY = inputState.aimY

    -- === 子模块委托 ===
    PlayerCtrl.updatePlayer(state, Core, dt)
    EnemyAI.updateEnemies(state, Core, gdt)
    World.updateAllies(state, Core, gdt)
    Combat.updateBullets(state, gdt)
    World.updateAsteroids(state, gdt)
    World.updateParticles(state, gdt)
    World.updatePickups(state, Core, dt)
    World.updateRelicDrops(state, Core, dt)
    World.updatePowerups(state, Core, gdt)
    World.updateActivePowerups(state, Core, dt)
    World.updateWave(state, Core, dt)
    World.updateEvent(state, Core, dt)
    Combat.updateLaser(state, Core, gdt)
    Combat.updateMissiles(state, Core, gdt)
    Combat.updateSecondary(state, Core, gdt)
    Combat.updateBossEffects(state, Core, gdt)
    World.updateCollectAnims(state, dt)
    World.updateTutorial(state, dt)
    Core.updateToasts(state, dt)
    Core.updateFloatingTexts(state, dt)
    Combat.checkCollisions(state, Core)

    -- === 编排器内联逻辑 ===

    -- 护盾恢复
    if state.stats.shieldRegen > 0 and state.player.shield < state.player.shieldMax then
        state.player.shield = math.min(state.player.shieldMax,
            state.player.shield + state.stats.shieldRegen * dt)
    end

    -- 随机事件: 修复信号回血
    if state.activeEvent and state.activeEvent.effect == "repair" then
        state.player.hp = math.min(state.player.hpMax, state.player.hp + 12 * dt)
    end

    -- Combo里程碑: 持续回复buff
    if state.comboRegen then
        state.comboRegen.timer = state.comboRegen.timer - dt
        if state.comboRegen.timer <= 0 then
            state.comboRegen = nil
        else
            state.player.hp = math.min(state.player.hpMax,
                state.player.hp + state.comboRegen.rate * dt)
        end
    end

    -- Combo里程碑: 火力全开buff倒计时
    if state.comboOverdrive then
        state.comboOverdrive.timer = state.comboOverdrive.timer - dt
        if state.comboOverdrive.timer <= 0 then
            state.comboOverdrive = nil
        end
    end

    -- 中继站回复区域
    state.nearRelay = false
    for _, relay in ipairs(state.relayStations) do
        if dist(state.player.x, state.player.y, relay.x, relay.y) < 120 then
            state.nearRelay = true
            if state.player.shield < state.player.shieldMax then
                state.player.shield = math.min(state.player.shieldMax, state.player.shield + 10 * dt)
            end
            if state.player.hp < state.player.hpMax then
                state.player.hp = math.min(state.player.hpMax, state.player.hp + 3 * dt)
            end
            break
        end
    end

    -- 劫持冷却
    if state.hijackCd > 0 then state.hijackCd = state.hijackCd - dt end

    -- P10.2: 敌人重生（难度曲线调优）
    -- 前3天安全期: 间隔长/只有drone; Day 5+ 精英; Day 8 Boss; Day 15+ 环境危险
    local spawnInterval = state.day <= 3 and 12 or (state.day <= 7 and 9 or 7)
    local maxEnemies = state.day <= 3 and 6 or (state.day <= 7 and 10 or 14)
    state.spawnTimer = state.spawnTimer + dt
    if state.spawnTimer > spawnInterval then
        state.spawnTimer = 0
        if #state.enemies < maxEnemies then
            Core.spawnEnemy(state, "drone", "middle")
            if state.day > 3 then Core.spawnEnemy(state, "drone", "middle") end  -- Day 4+ 双drone
            if state.day > 5 then Core.spawnEnemy(state, "aberration", "inner") end
            if state.day > 7 then Core.spawnEnemy(state, "flanker", "middle") end
            if state.day > 10 then Core.spawnEnemy(state, "guard", "inner") end
            if state.day > 12 then Core.spawnEnemy(state, "cloaker", "middle") end
            if state.day > 15 then Core.spawnEnemy(state, "kamikaze", "middle") end
            if state.day > 18 then Core.spawnEnemy(state, "summoner", "inner") end
            if state.day > 14 then Core.spawnEnemy(state, "splitter", "middle") end
        end
    end

    -- 小行星重生
    if #state.asteroids < 30 then
        Core.spawnAsteroid(state, math.random() > 0.5 and "outer" or "middle")
    end

    -- 道具随机生成
    state.powerupSpawnTimer = (state.powerupSpawnTimer or 0) + dt
    if state.powerupSpawnTimer > 25 then
        state.powerupSpawnTimer = 0
        World.spawnPowerup(state)
    end

    -- 扩展系统更新
    Systems.updateCombo(gdt)
    Systems.updateHazards(state, gdt, dist)

    -- 隐藏Boss检查
    if Systems.HIDDEN_BOSS.triggerCheck(state) then
        Core.spawnBoss(state, "void")
    end

    -- 成就检测
    state._achCheckTimer = (state._achCheckTimer or 0) + dt
    if state._achCheckTimer >= 1.0 then
        state._achCheckTimer = 0
        Systems.checkAchievements(state)
    end

    -- 成就弹窗计时
    if state.achievementQueue then
        for i = #state.achievementQueue, 1, -1 do
            state.achievementQueue[i].timer = state.achievementQueue[i].timer - dt
            if state.achievementQueue[i].timer <= 0 then
                table.remove(state.achievementQueue, i)
            end
        end
    end

    -- 遗物：纳米修复
    if Systems.hasRelic(state, "r_regen") then
        state.player.hp = math.min(state.player.hpMax, state.player.hp + 2 * dt)
    end

    -- 任务检查
    World.checkQuests(state, Core)

    -- Phase 6.4: 改进屏幕震动 - 正弦波噪声 + 方向性
    if state.shakeTime and state.shakeTime > 0 then
        state.shakeTime = state.shakeTime - dt
        state.shakePhase = (state.shakePhase or 0) + dt * 45  -- 高频振动
        local progress = 1 - (state.shakeTime / state.shakeMaxTime)
        -- 使用平方衰减（开始强，快速弱化，更有冲击感）
        local decay = (1 - progress * progress)
        local intensity = state.shakeIntensity * decay
        -- 多频正弦组合（模拟噪声，比纯随机更自然平滑）
        local phase = state.shakePhase
        local noiseX = math.sin(phase) * 0.6 + math.sin(phase * 2.3) * 0.3 + math.sin(phase * 4.7) * 0.1
        local noiseY = math.cos(phase * 1.1) * 0.6 + math.cos(phase * 3.1) * 0.3 + math.cos(phase * 5.3) * 0.1
        -- 方向性震动加成（来源方向震动更强）
        local dirX = state.shakeDirX or 0
        local dirY = state.shakeDirY or 0
        local dirMag = math.sqrt(dirX * dirX + dirY * dirY)
        if dirMag > 0.01 then
            -- 方向性分量占30%，随机分量占70%
            noiseX = noiseX * 0.7 + (dirX / dirMag) * math.sin(phase * 3) * 0.3
            noiseY = noiseY * 0.7 + (dirY / dirMag) * math.sin(phase * 3) * 0.3
        end
        state.shakeOffX = noiseX * intensity
        state.shakeOffY = noiseY * intensity
    else
        state.shakeOffX = 0
        state.shakeOffY = 0
        state.shakePhase = 0
    end

    -- Phase 6: 受伤闪屏衰减
    if state.damageFlash and state.damageFlash > 0 then
        state.damageFlash = state.damageFlash - dt * 4
        if state.damageFlash < 0 then state.damageFlash = 0 end
    end


    -- Phase 6.4: 相机跟随 + 速度前瞻（相机微微超前移动方向）
    local p = state.player
    local lookAheadFactor = 0.12  -- 前瞻强度（玩家速度的12%作为偏移）
    local lookAheadSmooth = 3.0   -- 前瞻平滑度
    -- 目标前瞻位置
    local targetLAX = p.vx * lookAheadFactor
    local targetLAY = p.vy * lookAheadFactor
    -- 限制最大前瞻距离（避免高速时相机甩太远）
    local maxLA = 60
    local laMag = math.sqrt(targetLAX * targetLAX + targetLAY * targetLAY)
    if laMag > maxLA then
        targetLAX = targetLAX / laMag * maxLA
        targetLAY = targetLAY / laMag * maxLA
    end
    -- 平滑过渡前瞻偏移
    state.camLookAheadX = lerp(state.camLookAheadX or 0, targetLAX, dt * lookAheadSmooth)
    state.camLookAheadY = lerp(state.camLookAheadY or 0, targetLAY, dt * lookAheadSmooth)
    -- 相机目标 = 玩家位置 + 前瞻偏移
    local camTargetX = p.x + state.camLookAheadX
    local camTargetY = p.y + state.camLookAheadY
    -- 弹性跟随（近距离快，远距离不超追）
    local camSpeed = 5.0
    state.cam.x = lerp(state.cam.x, camTargetX, dt * camSpeed) + (state.shakeOffX or 0)
    state.cam.y = lerp(state.cam.y, camTargetY, dt * camSpeed) + (state.shakeOffY or 0)

    -- P13.3: r_shockwave - 每5秒释放周围冲击波
    if Systems.hasRelic(state, "r_shockwave") then
        state._shockwaveTimer = (state._shockwaveTimer or 0) + dt
        if state._shockwaveTimer >= 5.0 then
            state._shockwaveTimer = 0
            local p = state.player
            local shockwaveRange = 180
            for _, e in ipairs(state.enemies) do
                local d = dist(p.x, p.y, e.x, e.y)
                if d < shockwaveRange then
                    e.hp = e.hp - 15
                    e.hitFlash = 0.1
                    local knockback = (shockwaveRange - d) / shockwaveRange * 150
                    local toE = angleToward(p.x, p.y, e.x, e.y)
                    e.vx = e.vx + math.cos(toE) * knockback
                    e.vy = e.vy + math.sin(toE) * knockback
                end
            end
            Core.spawnParticles(state, p.x, p.y, { 255, 150, 100 }, 20)
            Core.addFloatingText(state, p.x, p.y - 20, "冲击波!", { 255, 150, 100 }, 0.8)
        end
    end

    -- P12.2: Boss对话更新
    if state._bossDialogue then
        state._bossDialogue.timer = state._bossDialogue.timer - dt
        if state._bossDialogue.timer <= 0 then
            state._bossDialogue = nil
        end
    end

    -- P14.2: 每周挑战 - damage/resource 更新
    if state.weeklyChallenge and not state.weeklyChallenge.completed then
        if state.weeklyChallenge.type == "damage" then
            state.weeklyChallenge.progress = math.floor(state.totalDmgDealt or 0)
            if state.weeklyChallenge.progress >= state.weeklyChallenge.target then
                state.weeklyChallenge.completed = true
                Core.addToast(state, "🎯 社区挑战完成: " .. state.weeklyChallenge.name, { 0, 255, 180 })
            end
        elseif state.weeklyChallenge.type == "resource" then
            local tc = state.totalCollected or {}
            state.weeklyChallenge.progress = (tc.metal or 0) + (tc.energy or 0)
            if state.weeklyChallenge.progress >= state.weeklyChallenge.target then
                state.weeklyChallenge.completed = true
                Core.addToast(state, "🎯 社区挑战完成: " .. state.weeklyChallenge.name, { 0, 255, 180 })
            end
        end
    end

    -- Phase 9.1: 动态BGM系统 - 根据战斗状态切换BGM
    state._bgmCheckTimer = (state._bgmCheckTimer or 0) + dt
    if state._bgmCheckTimer >= 0.5 then
        state._bgmCheckTimer = 0
        local targetBGM = "cruise"  -- 默认巡航BGM
        local enemyCount = #state.enemies
        local bossCount = 0
        for _, e in ipairs(state.enemies) do
            if e.isBoss then bossCount = bossCount + 1 end
        end
        local combatIntensity = enemyCount + bossCount * 3  -- Boss权重更高
        if bossCount > 0 then
            targetBGM = "boss"
        elseif combatIntensity >= 6 then
            targetBGM = "battle"
        else
            targetBGM = "cruise"
        end
        -- 调用Audio系统切换BGM
        local Audio = require("game.Audio")
        Audio.setBGM(targetBGM)
    end

    -- 玩家死亡
    if state.player.hp <= 0 then
        state.seasonOver = true
        state.playerDied = true
        Core.addToast(state, S.get("hud_ship_crashed"), { 255, 58, 92 })
    end
end

function Core.onNewDay(state)
    -- 正常赛季Boss（任务触发）
    for _, q in ipairs(Data.QUESTS) do
        if q.bossSpawn and state.day >= q.bossSpawn.day then
            if not state.bossesSpawned[q.bossSpawn.id] and not state.bossesKilled[q.bossSpawn.id] then
                Core.spawnBoss(state, q.bossSpawn.id)
            end
        end
    end

    -- P7.2 无尽模式：每10天生成一个Boss（30天后开始循环）
    if state.isEndless and state.day > 30 and state.day % 10 == 0 then
        local bossList = { "crystal", "hive", "titan", "void" }
        local cycle = math.floor((state.day - 30) / 10)
        local bossIdx = ((cycle - 1) % #bossList) + 1
        local bossId = bossList[bossIdx]
        Core.spawnBoss(state, bossId)
        Core.addToast(state, S.get("hud_boss_incoming"), { 255, 60, 60 })
    end

    -- 无尽模式：天数越高，每天额外刷怪
    if state.isEndless and state.day > 30 then
        local extraWaves = math.floor((state.day - 30) / 5)
        for _ = 1, extraWaves do
            Core.spawnEnemy(state, "guard", "inner")
            Core.spawnEnemy(state, "flanker", "middle")
        end
    end

    -- P12.3: 星海编年史解锁（按天数解锁）
    state.chronoUnlocked = state.chronoUnlocked or {}
    for _, c in ipairs(Data.CHRONICLES) do
        if c.unlockDay and state.day >= c.unlockDay and not state.chronoUnlocked[c.id] then
            state.chronoUnlocked[c.id] = true
            Core.addFloatingText(state, state.player.x, state.player.y - 40,
                "📖 新资料解锁: " .. c.title, { 255, 220, 100 }, 2.0)
            Core.addToast(state, "📖 新资料: " .. c.title, { 255, 220, 100 })
        end
    end

    Core.addToast(state, S.get("hud_day", state.day), { 200, 220, 255 })
end

-- ============================================================================
-- 科技升级
-- ============================================================================
function Core.unlockTech(state, techId)
    local tech = Data.getTech(techId)
    if not tech then return false end
    for _, id in ipairs(state.ownedTech) do
        if id == techId then return false end
    end
    if not Data.requirementsMet(tech, state.ownedTech) then return false end
    if not Data.canAfford(tech.cost, state.resources) then return false end
    for k, v in pairs(tech.cost) do
        state.resources[k] = state.resources[k] - v
    end
    table.insert(state.ownedTech, techId)
    Core.recomputeStats(state)
    -- P9: 解锁音效
    local Audio = require("game.Audio")
    Audio.playUnlock()
    Core.addToast(state, S.get("hud_unlock_tech", tech.name), { 0, 255, 180 })
    return true
end

-- ============================================================================
-- 共享工具函数（子模块通过 Core 引用调用）
-- ============================================================================

function Core.addFloatingText(state, x, y, text, color, scale)
    table.insert(state.floatingTexts, {
        x = x, y = y,
        text = text,
        color = color or { 255, 255, 255 },
        life = 1.0, maxLife = 1.0,
        vy = -60,
        scale = scale or 1.0,
    })
end

function Core.updateFloatingTexts(state, dt)
    for i = #state.floatingTexts, 1, -1 do
        local ft = state.floatingTexts[i]
        ft.life = ft.life - dt
        ft.y = ft.y + ft.vy * dt
        ft.vy = ft.vy * 0.96
        if ft.life <= 0 then table.remove(state.floatingTexts, i) end
    end
end

function Core.addToast(state, text, color)
    table.insert(state.toasts, {
        text = text,
        color = color or { 255, 255, 255 },
        life = 3.0, maxLife = 3.0,
    })
end

function Core.updateToasts(state, dt)
    for i = #state.toasts, 1, -1 do
        state.toasts[i].life = state.toasts[i].life - dt
        if state.toasts[i].life <= 0 then table.remove(state.toasts, i) end
    end
end

-- P10.3 & P17.1: 粒子上限 + 距离剔除
local MAX_PARTICLES = 200
local PARTICLE_CULL_DIST = 1200
local FAR_DIST = 800

-- P17.2: 空间分区碰撞检测 - Grid尺寸
local GRID_CELL = 200

function Core.spawnParticles(state, x, y, color, count)
    -- P17.1: 距离剔除 - 只有靠近玩家的粒子才被生成
    if state.player then
        local dx = x - state.player.x
        local dy = y - state.player.y
        if dx * dx + dy * dy > PARTICLE_CULL_DIST * PARTICLE_CULL_DIST then
            count = math.floor((count or 6) * 0.3)
        end
    end
    for i = 1, (count or 6) do
        if #state.particles >= MAX_PARTICLES then break end
        local a = rand(0, TAU)
        local spd = rand(40, 150)
        table.insert(state.particles, {
            x = x, y = y,
            vx = math.cos(a) * spd,
            vy = math.sin(a) * spd,
            life = rand(0.3, 0.8),
            maxLife = 0.8,
            alpha = 1,
            size = rand(2, 5),
            color = color,
        })
    end
end

function Core.spawnExplosion(state, x, y, color, count, spd)
    count = count or 20
    spd = spd or 250
    -- P17.1: 距离剔除 - 远处爆炸粒子减少
    if state.player then
        local dx = x - state.player.x
        local dy = y - state.player.y
        if dx * dx + dy * dy > FAR_DIST * FAR_DIST then
            count = math.floor(count * 0.5)
        end
    end
    for i = 1, count do
        if #state.particles >= MAX_PARTICLES then break end
        local a = rand(0, TAU)
        local speed = rand(spd * 0.3, spd)
        table.insert(state.particles, {
            x = x + rand(-5, 5), y = y + rand(-5, 5),
            vx = math.cos(a) * speed,
            vy = math.sin(a) * speed,
            life = rand(0.4, 1.2),
            maxLife = 1.2,
            alpha = 1,
            size = rand(3, 8),
            color = color,
        })
    end
end

function Core.shake(state, intensity, duration, dirX, dirY)
    -- 允许叠加（取较大值而非覆盖）
    if (state.shakeTime or 0) > 0 and intensity <= state.shakeIntensity then
        -- 当前震动更强，只延长时间
        state.shakeTime = math.max(state.shakeTime, duration * 0.5)
        return
    end
    state.shakeIntensity = intensity
    state.shakeTime = duration
    state.shakeMaxTime = duration
    -- Phase 6.4: 可选方向性（从伤害来源方向震动更强）
    state.shakeDirX = dirX or 0
    state.shakeDirY = dirY or 0
end

function Core.hasPowerup(state, kind)
    for _, ap in ipairs(state.activePowerups) do
        if ap.kind == kind then return true end
    end
    return false
end

function Core.addCollectAnim(state, x, y, color)
    table.insert(state.collectAnims, { x = x, y = y, timer = 0.5, maxTime = 0.5, color = color })
end

function Core.getDifficultyScale(state)
    local day = state.day
    local D = Data.DIFFICULTY

    -- 基础缩放（前30天）
    local baseDay = math.min(day, 30)
    local hp = 1 + (baseDay - 1) * D.enemyHpScale
    local dmg = 1 + (baseDay - 1) * D.enemyDmgScale
    local speed = 1 + (baseDay - 1) * D.enemySpeedScale
    local spawnRate = 1 + (baseDay - 1) * D.spawnRateScale
    local bossHp = 1 + (baseDay - 1) * D.bossHpScale

    -- P7.2 无尽模式：30天后加速缩放
    if state.isEndless and day > 30 then
        local extra = day - 30
        hp = hp + extra * D.enemyHpScale * 2
        dmg = dmg + extra * D.enemyDmgScale * 1.5
        speed = speed + extra * D.enemySpeedScale * 1.2
        spawnRate = spawnRate + extra * D.spawnRateScale * 1.5
        bossHp = bossHp + extra * D.bossHpScale * 2.5
    end

    -- P19: 应用难度选择倍率（新手/标准/困难/虚空）
    if state.difficultyMul then
        hp = hp * (state.difficultyMul.enemyHp or 1)
        dmg = dmg * (state.difficultyMul.enemyDmg or 1)
        speed = speed * (state.difficultyMul.enemySpeed or 1)
        spawnRate = spawnRate * (state.difficultyMul.spawnRate or 1)
        bossHp = bossHp * (state.difficultyMul.enemyHp or 1)
    end

    return {
        hp = hp,
        dmg = dmg,
        speed = speed,
        spawnRate = spawnRate,
        bossHp = bossHp,
    }
end

-- ============================================================================
-- Combo里程碑奖励
-- ============================================================================
function Core.applyComboMilestone(state, milestone)
    local p = state.player
    local reward = milestone.reward

    Core.addToast(state, S.get("hud_combo_milestone", milestone.at, milestone.desc), { 255, 200, 0 })
    for i = 1, 15 do
        if #state.particles >= MAX_PARTICLES then break end
        local ang = rand(0, TAU)
        local spd = rand(100, 250)
        table.insert(state.particles, {
            x = p.x, y = p.y,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = rand(0.5, 1.0), maxLife = 1.0,
            r = 255, g = 200, b = 0, size = rand(3, 5), alpha = 1,
        })
    end

    if reward == "shield" then
        p.shield = math.min(p.shieldMax or 50, p.shield + 20)
        Core.addFloatingText(state, p.x, p.y - 20, "+20护盾", { 100, 200, 255 })
    elseif reward == "slowmo" then
        Systems.triggerSlowmo(2.0, 0.3)
    elseif reward == "aoe" then
        local aoeRange = 200
        for _, enemy in ipairs(state.enemies) do
            local d = dist(p.x, p.y, enemy.x, enemy.y)
            if d < aoeRange then
                enemy.hp = enemy.hp - 30
                enemy.hitFlash = 0.15
                Core.addFloatingText(state, enemy.x, enemy.y - 10, "30", { 255, 180, 0 })
                if enemy.hp <= 0 then
                    EnemyAI.onEnemyKilled(state, Core, enemy)
                end
            end
        end
        for i = #state.enemies, 1, -1 do
            if state.enemies[i].hp <= 0 then table.remove(state.enemies, i) end
        end
        Core.spawnExplosion(state, p.x, p.y, { 255, 200, 50 }, 25, aoeRange)
        Core.shake(state, 6, 0.4)
    elseif reward == "regen" then
        state.comboRegen = { timer = 5.0, rate = 8 }
        Core.addFloatingText(state, p.x, p.y - 20, "回复中!", { 100, 255, 100 })
    elseif reward == "overdrive" then
        state.comboOverdrive = { timer = 5.0 }
        Core.addFloatingText(state, p.x, p.y - 20, "火力全开!", { 255, 100, 0 })
        Core.shake(state, 8, 0.5)
    end
end

-- ============================================================================
-- 委托桥接函数（外部代码通过 Core.xxx 调用，内部委托到子模块）
-- ============================================================================

function Core.spawnEnemy(state, kind, zone)
    EnemyAI.spawnEnemy(state, Core, kind, zone)
end

function Core.spawnBoss(state, bossId)
    EnemyAI.spawnBoss(state, Core, bossId)
end

function Core.damagePlayer(state, rawDmg, srcX, srcY)
    PlayerCtrl.damagePlayer(state, Core, rawDmg, srcX, srcY)
end

function Core.onEnemyKilled(state, e)
    Core.incrementCombo(state)
    EnemyAI.onEnemyKilled(state, Core, e)
end

function Core.dropResources(state, x, y, metal, energy, blueprint, key)
    World.dropResources(state, x, y, metal, energy, blueprint, key)
end

function Core.toggleLaser(state)
    Combat.toggleLaser(state)
end

function Core.fireMissile(state)
    Combat.fireMissile(state, Core)
end

function Core.fireSecondary(state)
    Combat.fireSecondary(state, Core)
end

function Core.switchSecondary(state)
    Combat.switchSecondary(state, Core)
end

function Core.attemptHijack(state)
    World.attemptHijack(state, Core)
end

function Core.cycleAllyMode(state)
    World.cycleAllyMode(state, Core)
end

function Core.selectEventChoice(state, index)
    World.selectEventChoice(state, Core, index)
end

function Core.buildRelay(state)
    return World.buildRelay(state, Core)
end

function Core.getActiveQuests(state)
    return World.getActiveQuests(state)
end

function Core.checkCollisions(state)
    Combat.checkCollisions(state, Core)
end

-- P3.8 盟友模式常量
Core.ALLY_MODES = { "attack", "follow", "guard" }

-- ============================================================================
-- P18/P19: 难度应用与元进度
-- ============================================================================
function Core.applyDifficulty(state)
    local diff = Data.getDifficultyLevel(state.difficultyId)
    if not diff or not diff.multipliers then return end
    local m = diff.multipliers
    state.difficultyMul = {
        enemyHp = m.enemyHp or 1,
        enemyDmg = m.enemyDmg or 1,
        enemySpeed = m.enemySpeed or 1,
        spawnRate = m.spawnRate or 1,
        resource = m.resourceGain or 1,
        blueprint = m.blueprintGain or 1,
        playerDmg = m.playerDmg or 1,
        playerHp = m.playerHp or 1,
    }
    -- 以难度倍率 + 元进度 hpBonus 联合计算 HP
    local baseHp = 100
    local metaHpBonus = state.stats and state.stats.maxHpBonus or 1
    state.player.hpMax = math.floor(baseHp * metaHpBonus * (m.playerHp or 1))
    state.player.hp = state.player.hpMax
    -- 难度对玩家伤害倍率（在 stats.dmgMul 基础上叠加）
    local metaDmgBonus = state.stats and state.stats.dmgBonus or 1
    state.stats.dmgMul = metaDmgBonus * (m.playerDmg or 1)
end

function Core.applyMetaUpgrades(state)
    if not state.meta or not state.meta.upgrades then return end
    -- 先重置所有元进度加成到基准值，防止多次调用造成累积
    state.stats.maxHpBonus = 1
    state.stats.dmgBonus = 1
    state.stats.energyRegenBonus = 1
    state.stats.resourceBonus = 1
    state.stats.startingShields = 0
    state.stats.extraRelicSlots = 0
    for id, lvl in pairs(state.meta.upgrades) do
        if lvl and lvl > 0 then
            local up = Data.getMetaUpgrade(id)
            if up and up.apply then up.apply(state, lvl) end
        end
    end
    -- 不再在此处直接修改 player.hpMax（由 applyDifficulty 统一计算）
    -- 起始护盾仍由元进度设置
    if state.stats.startingShields and state.stats.startingShields > 0 then
        state.player.shield = state.stats.startingShields * 20
        state.player.shieldMax = math.max(state.player.shieldMax or 0, state.player.shield)
    end
end

function Core.addMetaXp(state, amount)
    if not state.meta then return end
    state.meta.xp = state.meta.xp + amount
end

-- ============================================================================
-- P20.1: 主动技能系统
-- ============================================================================
function Core.updateSkills(state, dt)
    local sk = state.skills
    if sk.slowRemaining and sk.slowRemaining > 0 then
        sk.slowRemaining = sk.slowRemaining - dt
        if sk.slowRemaining <= 0 then
            state.timeScale = 1.0
        end
    end
    if sk.invulnRemaining and sk.invulnRemaining > 0 then
        sk.invulnRemaining = sk.invulnRemaining - dt
    end
    for id, cd in pairs(sk.cooldowns) do
        if cd > 0 then
            sk.cooldowns[id] = math.max(0, cd - dt)
        end
    end
end

function Core.canUseSkill(state, skillId)
    local sk = Data.getActiveSkill(skillId)
    if not sk then return false end
    if not state.skills.unlocked[skillId] then return false end
    local cd = state.skills.cooldowns[skillId] or 0
    if cd > 0 then return false end
    if (state.player.energy or 100) < (sk.energyCost or 0) then return false end
    return true
end

function Core.useSkill(state, skillId)
    if not Core.canUseSkill(state, skillId) then return false end
    local sk = Data.getActiveSkill(skillId)
    if not sk then return false end
    state.player.energy = (state.player.energy or 100) - (sk.energyCost or 0)
    state.skills.cooldowns[skillId] = sk.cooldown

    if skillId == "skill_dash" then
        local dx, dy = (state.inputMoveX or 0), (state.inputMoveY or 0)
        if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then
            dx = math.cos(state.player.angle)
            dy = math.sin(state.player.angle)
        end
        local mag = math.sqrt(dx * dx + dy * dy)
        if mag > 0.01 then
            dx, dy = dx / mag, dy / mag
        end
        state.player.x = state.player.x + dx * 200
        state.player.y = state.player.y + dy * 200
        state.skills.invulnRemaining = 0.8
        Core.spawnParticles(state, state.player.x, state.player.y, sk.color, 20)
        Core.addToast(state, "量子冲刺！", sk.color)
    elseif skillId == "skill_shock" then
        local r = sk.range
        for _, e in ipairs(state.enemies) do
            local d = Core.dist(e.x - state.player.x, e.y - state.player.y)
            if d < r then
                local pushed = (1 - d / r)
                local a = math.atan2(e.y - state.player.y, e.x - state.player.x)
                e.x = e.x + math.cos(a) * 80 * pushed
                e.y = e.y + math.sin(a) * 80 * pushed
                e.hp = e.hp - sk.damage
                if e.hp <= 0 then
                    Core.onEnemyKilled(state, e)
                end
            end
        end
        Core.spawnExplosion(state, state.player.x, state.player.y, sk.color, 30, 300)
        Core.shake(state, 0.4, 0.3)
        Core.addToast(state, "冲击波释放！", sk.color)
    elseif skillId == "skill_slow" then
        state.timeScale = 1 - sk.slowFactor + 0.2  -- 约 0.7
        state.skills.slowRemaining = sk.duration
        Core.addToast(state, "时间扭曲生效 " .. sk.duration .. "秒", sk.color)
    elseif skillId == "skill_shield" then
        state.player.hp = math.min(state.player.hpMax, state.player.hp + sk.healAmount)
        state.player.shield = state.player.shield + 1
        state.skills.tempShieldExpire = os and os.clock and os.clock() + sk.shieldDuration or nil
        Core.addToast(state, "护盾充能 +" .. sk.healAmount .. " HP", sk.color)
    elseif skillId == "skill_strike" then
        local tx, ty = (state.inputAimX or state.player.x), (state.inputAimY or state.player.y)
        local r = sk.range
        for _, e in ipairs(state.enemies) do
            if Core.dist(e.x - tx, e.y - ty) < r then
                e.hp = e.hp - sk.damage
                if e.hp <= 0 then Core.onEnemyKilled(state, e) end
            end
        end
        Core.spawnExplosion(state, tx, ty, sk.color, 50, 400)
        Core.shake(state, 1.0, 0.5)
        Core.addToast(state, "轨道打击！", sk.color)
    end
    return true
end

-- ============================================================================
-- P20.2: 连击等级系统
-- ============================================================================
function Core.recomputeComboRank(state)
    local rank = Data.getComboRank(state.comboRank.count)
    state.comboRank.rank = rank.rank
    state.comboRank.color = rank.color
    state.stats.comboDmgMul = rank.dmgMul
    if state.comboRank.count > state.comboRank.maxThisRun then
        state.comboRank.maxThisRun = state.comboRank.count
    end
end

function Core.incrementCombo(state)
    state.comboRank.count = state.comboRank.count + 1
    state.comboRank.decayTimer = 3.0
    local oldRank = state.comboRank.rank
    Core.recomputeComboRank(state)
    if oldRank ~= state.comboRank.rank then
        Core.addToast(state, "连击等级提升：" .. state.comboRank.rank, state.comboRank.color)
        -- Phase 26: SSS 等级触发屏幕特效（粒子爆发 + 屏幕震动 + 闪屏）
        if state.comboRank.rank == "SSS" then
            Core.spawnExplosion(state, state.player.x, state.player.y, state.comboRank.color, 60, 420)
            Core.spawnParticles(state, state.player.x, state.player.y, { 255, 255, 255 }, 30)
            Core.shake(state, 3, 0.4)
            Core.screenFlash(state, state.comboRank.color, 0.25, 0.3)
        elseif state.comboRank.rank == "SS" then
            Core.spawnExplosion(state, state.player.x, state.player.y, state.comboRank.color, 40, 350)
            Core.shake(state, 2, 0.3)
        elseif state.comboRank.rank == "S" then
            Core.spawnParticles(state, state.player.x, state.player.y, state.comboRank.color, 20)
            Core.shake(state, 1.2, 0.2)
        end
    end
end

-- ============================================================================
-- P21.2: 波次系统升级
-- ============================================================================
function Core.updateWaves(state, dt)
    local w = state.wave
    w.nextWaveTimer = w.nextWaveTimer - dt
    if w.pattern then
        w.timeInPattern = w.timeInPattern + dt
        if w.pattern.spawnInterval and w.pattern.spawnInterval > 0 then
            w.spawnAccumulator = w.spawnAccumulator + dt
            while w.spawnAccumulator >= w.pattern.spawnInterval and
                  (w.pattern._spawned or 0) < (w.pattern.enemyCount or 0) do
                w.spawnAccumulator = w.spawnAccumulator - w.pattern.spawnInterval
                w.pattern._spawned = (w.pattern._spawned or 0) + 1
                local kind = w.pattern.enemyType
                if kind == "mixed" then
                    local mix = { "drone", "fighter", "cruiser" }
                    kind = mix[math.random(#mix)]
                end
                Core.spawnEnemy(state, kind)
            end
        end
        if w.pattern.duration > 0 and w.timeInPattern >= w.pattern.duration then
            -- 波次奖励
            if w.pattern.reward then
                local r = w.pattern.reward
                Core.dropResources(state, state.player.x, state.player.y,
                    r.metal or 0, r.energy or 0, r.blueprint or 0)
                Core.addToast(state, "波次完成：" .. (w.pattern.name or "Wave"), { 200, 220, 255 })
            end
            w.pattern = nil
            w.timeInPattern = 0
            w.spawnAccumulator = 0
            w.nextWaveTimer = math.random(25, 45)
        end
    elseif w.nextWaveTimer <= 0 then
        local pat = Data.getRandomWavePattern()
        state.wave.pattern = pat
        state.wave.timeInPattern = 0
        state.wave.pattern._spawned = 0
        Core.addToast(state, "⚠ 波次开始：" .. (pat.name or "Wave"), { 255, 200, 100 })
    end
end

-- ============================================================================
-- P21.3: 神秘地点生成与交互
-- ============================================================================
function Core.generateMysteries(state)
    state.mysteries = {}
    local count = math.random(2, 4)
    for i = 1, count do
        local def = Data.MYSTERY_LOCATIONS[math.random(#Data.MYSTERY_LOCATIONS)]
        local ang = math.random() * math.pi * 2
        local r = math.random(400, 1800)
        table.insert(state.mysteries, {
            def = def,
            id = def.id .. "_" .. i,
            x = math.cos(ang) * r,
            y = math.sin(ang) * r,
            visited = false,
            pulsePhase = math.random() * math.pi * 2,
        })
    end
end

function Core.checkMysteryInteraction(state)
    if not state.mysteries then return end
    for _, m in ipairs(state.mysteries) do
        if not m.visited then
            local d = Core.dist(m.x - state.player.x, m.y - state.player.y)
            if d < 80 then
                m.visited = true
                if m.def and m.def.onVisit then
                    local ok, err = pcall(m.def.onVisit, state)
                    if not ok then
                        Core.addToast(state, "神秘地点异常：" .. tostring(err), { 255, 100, 100 })
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- P12.4: NPC 对话触发
-- ============================================================================
function Core.triggerNPCLine(state, npcId)
    local line, npc = Data.getNPCLine(npcId, state.npcProgress[npcId] or 0)
    if line then
        state.npcProgress[npcId] = (state.npcProgress[npcId] or 0) + 1
        Core.addToast(state, (npc and npc.name or "NPC") .. "：" .. line,
            npc and { 200, 220, 255 } or { 255, 255, 255 })
    end
end

-- ============================================================================
-- Phase 23: 屏幕震动分级与连击视觉特效
-- ============================================================================

-- 震动强度预设（用于不同事件调用 Core.shake(state, intensity, duration)）
Core.SHAKE_PRESETS = {
    light =   { intensity = 0.3, duration = 0.15 },  -- 小撞击/拾取
    medium =  { intensity = 0.6, duration = 0.25 },  -- 普通敌人击杀/子弹命中
    heavy =   { intensity = 1.2, duration = 0.35 },  -- 精英敌人击杀/护盾破碎
    impact =  { intensity = 2.0, duration = 0.45 },  -- 爆炸/轨道打击
    bossHit = { intensity = 3.5, duration = 0.6 },  -- Boss 阶段切换
    death =   { intensity = 5.0, duration = 0.8 },  -- 玩家死亡
}

-- 连击等级对应的粒子爆发规模
function Core.getComboBurstScale(rank)
    local scales = { C = 1.0, B = 1.3, A = 1.6, S = 2.0, SS = 2.5, SSS = 3.0 }
    return scales[rank] or 1.0
end

-- 触发连击视觉爆发（在敌人位置产生分级粒子 + 屏幕文字）
function Core.triggerComboBurst(state, x, y, color)
    if not state.comboRank then return end
    local rank = state.comboRank.rank or "C"
    local scale = Core.getComboBurstScale(rank)
    local particleCount = math.floor(15 * scale)
    local spreadSpeed = 150 + 50 * scale
    Core.spawnExplosion(state, x or state.player.x, y or state.player.y,
        color or { 255, 220, 100 }, particleCount, spreadSpeed)
    -- S 级以上加额外外圈
    if scale >= 2.0 then
        Core.spawnParticles(state, x or state.player.x, y or state.player.y,
            { 255, 255, 255 }, math.floor(10 * scale))
    end
    -- SSS 级触发屏幕震动
    if rank == "SSS" then
        Core.shake(state, 1.5, 0.4)
    end
end

-- 屏幕彩色闪光（用于技能/状态切换时的视觉强调）
function Core.screenFlash(state, color, alpha, duration)
    state._screenFlash = state._screenFlash or {}
    table.insert(state._screenFlash, {
        color = color or { 255, 255, 255 },
        alpha = alpha or 0.3,
        duration = duration or 0.15,
        time = 0,
    })
end

-- ============================================================================
-- Phase 23: 摄像机追踪与屏幕震动衰减更新
-- ============================================================================
function Core.updateCameraFX(state, dt)
    -- 屏幕震动衰减
    if state.shakeTime and state.shakeTime > 0 then
        state.shakeTime = state.shakeTime - dt
        if state.shakeTime < 0 then
            state.shakeTime = 0
            state.shakeIntensity = 0
        end
    end
    -- 屏幕闪光衰减
    if state._screenFlash then
        for i = #state._screenFlash, 1, -1 do
            local f = state._screenFlash[i]
            f.time = f.time + dt
            if f.time >= f.duration then
                table.remove(state._screenFlash, i)
            end
        end
    end
end

-- ============================================================================
-- Phase 23: 时间缓动 / Hitstop 强化
-- ============================================================================
function Core.triggerHitstop(state, duration)
    state._hitstopTimer = duration or 0.1
    state.hitstop = state._hitstopTimer
end

function Core.updateHitstop(state, dt)
    if state._hitstopTimer and state._hitstopTimer > 0 then
        state._hitstopTimer = state._hitstopTimer - dt
        if state._hitstopTimer <= 0 then
            state._hitstopTimer = 0
            state.hitstop = 0
        end
    end
end

-- ============================================================================
-- Phase 24: 成就 → 永久升级 自动追踪与应用
-- ============================================================================
function Core.applyAchievementUnlocks(state, achievementIds)
    if not achievementIds or not state.meta then return 0 end
    if not state.meta.upgrades then state.meta.upgrades = {} end
    local unlockCount = 0
    for _, achId in ipairs(achievementIds) do
        local metaId, level = Data.getMetaUnlockForAchievement(achId)
        if metaId then
            local current = state.meta.upgrades[metaId] or 0
            local target = current + (level or 1)
            -- 检查上限（防止无限叠加）
            local def = Data.getMetaUpgrade(metaId)
            if def and target <= (def.maxLevel or 5) then
                state.meta.upgrades[metaId] = target
                unlockCount = unlockCount + 1
            elseif def and target > (def.maxLevel or 5) then
                state.meta.upgrades[metaId] = def.maxLevel
                unlockCount = unlockCount + 1
            end
        end
    end
    if unlockCount > 0 then
        -- 立即应用到当前局战斗
        Core.applyMetaUpgrades(state)
    end
    return unlockCount
end

-- 统计永久升级总加成，用于 HUD 或结算画面
function Core.getMetaUpgradeSummary(state)
    if not state.meta or not state.meta.upgrades then return {}, 0 end
    local summary = {}
    local totalLevels = 0
    for id, lvl in pairs(state.meta.upgrades) do
        local def = Data.getMetaUpgrade(id)
        if def then
            summary[id] = { level = lvl, max = def.maxLevel, name = def.name }
            totalLevels = totalLevels + lvl
        end
    end
    return summary, totalLevels
end

-- ============================================================================
-- Phase 24: 幽灵数据 (Ghost Data)
-- 玩家死后的"影子飞船"记录，可作为后续局的辅助 NPC 或排行参考
-- ============================================================================
function Core.recordGhostRun(state)
    local ghost = {
        timestamp = os and os.time and os.time() or 0,
        factionId = state.factionId,
        difficulty = state.difficultyId,
        daysSurvived = state.day,
        totalKills = state.totalKills or 0,
        maxCombo = state.comboRank and state.comboRank.maxThisRun or 0,
        score = state.score or 0,
        techCount = #(state.ownedTech or {}),
        relicCount = 0,
        playTime = state._playTime or 0,
    }
    -- 统计遗物
    if state.player and state.player.relics then
        ghost.relicCount = #state.player.relics
    end
    return ghost
end

function Core.compareGhostRun(current, previous)
    if not current or not previous then return {} end
    return {
        dayDelta = current.daysSurvived - previous.daysSurvived,
        killDelta = current.totalKills - previous.totalKills,
        scoreDelta = current.score - previous.score,
        comboDelta = current.maxCombo - previous.maxCombo,
        isNewRecord = current.score > previous.score,
    }
end

-- ============================================================================
-- Phase 24: 每日主题在游戏中的应用
-- ============================================================================
function Core.applyDailyTheme(state, theme)
    if not theme or not theme.mod then return end
    state.dailyTheme = theme
    local m = theme.mod
    -- 修改现有难度倍率（叠加）
    if not state.difficultyMul then
        state.difficultyMul = { enemyHp = 1, enemyDmg = 1, enemySpeed = 1,
            spawnRate = 1, resource = 1, blueprint = 1, playerDmg = 1, playerHp = 1 }
    end
    if m.enemyHpMul then state.difficultyMul.enemyHp = state.difficultyMul.enemyHp * m.enemyHpMul end
    if m.enemyDmgMul then state.difficultyMul.enemyDmg = state.difficultyMul.enemyDmg * m.enemyDmgMul end
    if m.enemySpeedMul then state.difficultyMul.enemySpeed = state.difficultyMul.enemySpeed * m.enemySpeedMul end
    if m.spawnRateMul then state.difficultyMul.spawnRate = state.difficultyMul.spawnRate * m.spawnRateMul end
    if m.resourceMul then state.difficultyMul.resource = state.difficultyMul.resource * m.resourceMul end
    if m.blueprintMul then state.difficultyMul.blueprint = state.difficultyMul.blueprint * m.blueprintMul end
    if m.playerHpMul then
        state.player.hpMax = math.floor(state.player.hpMax * m.playerHpMul)
        state.player.hp = math.min(state.player.hp, state.player.hpMax)
    end
    if m.energyRegenMul then
        state.stats.energyRegenBonus = (state.stats.energyRegenBonus or 1) * m.energyRegenMul
    end
    -- 连击衰减/倍率修饰
    if m.comboDecayMul then
        state._comboDecayMul = m.comboDecayMul
    end
    if m.comboDmgBonusMul then
        state._comboDmgBonusMul = m.comboDmgBonusMul
    end
end

return Core
