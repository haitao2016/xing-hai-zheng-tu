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
function Core.newGame(playerName, factionId)
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
        },
        -- 相机
        cam = { x = 0, y = 0 },
        -- 赛季
        day = 1, dayTimer = 0, dayLength = 22,
        score = 0, seasonOver = false,
        isEndless = false, -- P7.2 无尽模式标志
        -- 资源
        resources = { metal = 0, energy = 0, blueprint = 0, ancient_key = 0 },
        -- 科技
        ownedTech = { "w1" },
        stats = nil,
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
        -- 杂项
        name = playerName or "征途者",
        spawnTimer = 0,
        stars = {},
        floatingTexts = {},
        nearRelay = false,
        shakeTime = 0, shakeIntensity = 0, shakeMaxTime = 0,
        shakeOffX = 0, shakeOffY = 0, shakePhase = 0,
        shakeDirX = 0, shakeDirY = 0,  -- 方向性震动
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
    -- 初始化扩展系统
    Systems.initRelics(state)
    Systems.initHazards(state)
    Systems.initAchievements(state)
    Systems.resetCombo()
    state.bossNoHitFlag = true
    -- 生成初始实体
    Core.spawnInitial(state)
    -- 生成背景星星
    Core.generateStars(state)
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

    -- 赛季天数（用真实时间）
    state.dayTimer = state.dayTimer + dt
    if state.dayTimer >= state.dayLength then
        state.dayTimer = state.dayTimer - state.dayLength
        state.day = state.day + 1
        if not state.isEndless and state.day > 30 then
            state.seasonOver = true
            Core.addToast(state, S.get("hud_season_end"), { 255, 215, 0 })
            return
        end
        Core.onNewDay(state)
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

-- P10.3: 粒子上限
local MAX_PARTICLES = 200

function Core.spawnParticles(state, x, y, color, count)
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

return Core
