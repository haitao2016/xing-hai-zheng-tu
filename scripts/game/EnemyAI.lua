-- ============================================================================
-- 星海征途 - 敌人AI模块
-- 敌人生成、行为AI、射击模式、击杀处理
-- ============================================================================

local Data = require("game.Data")
local Systems = require("game.Systems")
local Audio = require("game.Audio")
local U = require("game.CoreUtils")
local S = require("game.Strings")

local rand, randInt, dist, lerp, clamp, angleToward = U.rand, U.randInt, U.dist, U.lerp, U.clamp, U.angleToward
local TAU = U.TAU

local EnemyAI = {}

-- ============================================================================
-- 敌人生成
-- ============================================================================
function EnemyAI.spawnEnemy(state, Core, kind, zone)
    local cfg = Data.ENEMY_TYPES[kind]
    if not cfg then return end
    local ang = rand(0, TAU)
    local r = rand(300, 2000)
    local diff = Core.getDifficultyScale(state)
    local scaledHp = math.floor(cfg.hp * diff.hp)
    local scaledDmg = math.floor(cfg.dmg * diff.dmg)
    -- 创建副本表，避免修改原始 Data.ENEMY_TYPES
    local eCfg = {
        hp = scaledHp,
        dmg = scaledDmg,
        speed = cfg.speed,
        size = cfg.size,
        color = cfg.color,
        fire = cfg.fire,
        bulletSpeed = cfg.bulletSpeed,
        range = cfg.range,
        behavior = cfg.behavior,
        reward = cfg.reward,
    }
    local e = {
        kind = kind, type = kind,
        x = math.cos(ang) * r,
        y = math.sin(ang) * r,
        vx = 0, vy = 0,
        angle = rand(0, TAU),
        hp = scaledHp, hpMax = scaledHp,
        radius = cfg.size or 12,
        cfg = eCfg,
        fireCd = rand(0, cfg.fire),
        hitFlash = 0,
        isBoss = false,
        dayScale = diff.hp,
        dmgScale = diff.dmg,
    }
    Systems.tryApplyAffix(e, state.day)
    table.insert(state.enemies, e)
end

function EnemyAI.spawnBoss(state, Core, bossId)
    local def = Data.BOSS_DEFS[bossId]
    if not def then return end
    if state.bossesSpawned[bossId] then return end
    state.bossesSpawned[bossId] = true
    local ang = rand(0, TAU)
    local r = rand(400, 800)
    local e = {
        kind = "boss", type = "boss", bossId = bossId,
        x = math.cos(ang) * r,
        y = math.sin(ang) * r,
        vx = 0, vy = 0,
        angle = rand(0, TAU),
        hp = def.hp, hpMax = def.hp,
        radius = def.size or 30,
        cfg = def,
        fireCd = 0, hitFlash = 0,
        isBoss = true,
        summonCd = 4,
    }
    table.insert(state.enemies, e)
    Core.addToast(state, "⚠ Boss: " .. def.name, def.color)
    Audio.playBossAlarm()
    -- Phase 6.1: Boss出场震动
    Core.shake(state, 6, 0.8)
    -- P12.2: Boss出场对话
    local dialogue = Data.BOSS_DIALOGUE[bossId]
    if dialogue and dialogue.spawn then
        local firstLine = dialogue.spawn[1]
        if firstLine then
            state._bossDialogue = {
                text = firstLine,
                color = def.color,
                timer = 3.0,
                alpha = 1.0,
            }
        end
    end
end

-- ============================================================================
-- 敌人主更新（行为AI）
-- ============================================================================
-- P10.3: 帧分割计数器
local frameCount = 0

function EnemyAI.updateEnemies(state, Core, dt)
    local p = state.player
    local empFrozen = (state.activeEvent and state.activeEvent.effect == "emp")
    local stormMul = (state.activeEvent and state.activeEvent.effect == "storm") and 1.5 or 1.0
    if state._dailyEnemySpeed then stormMul = stormMul * state._dailyEnemySpeed end
    local dailyFireMul = state._dailyFireRate or 1.0

    -- P7.4 遗物: r_slowfield (周围敌人减速30%)
    local hasSlowfield = Systems.hasRelic(state, "r_slowfield")

    -- P10.3: 帧分割 - 远距离敌人每2帧更新AI
    frameCount = frameCount + 1
    local FAR_DIST = 600  -- 超过此距离为"远处"

    for i = #state.enemies, 1, -1 do
        local e = state.enemies[i]
        local d = dist(e.x, e.y, p.x, p.y)

        -- P10.3: 远距离 & 奇数帧 → 只更新位置，跳过AI决策
        if d > FAR_DIST and not e.isBoss and frameCount % 2 == 0 then
            e.x = e.x + e.vx * dt
            e.y = e.y + e.vy * dt
            if e.hitFlash > 0 then e.hitFlash = e.hitFlash - dt end
            goto continue_enemy
        end

        local behavior = e.cfg.behavior or "default"
        local eFire = e.cfg.fire * dailyFireMul

        -- P7.4: r_slowfield 距离200以内减速30%
        local slowfieldMul = 1.0
        if hasSlowfield and d < 200 then
            slowfieldMul = 0.7
        end
        local spdMul = stormMul * slowfieldMul

        if empFrozen then
            e.vx = e.vx * 0.9
            e.vy = e.vy * 0.9
        elseif behavior == "kamikaze" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            e.angle = toPlayer
            local spd = e.cfg.speed * spdMul
            e.vx = math.cos(toPlayer) * spd
            e.vy = math.sin(toPlayer) * spd
            if d < 30 then
                Core.damagePlayer(state, e.cfg.dmg, e.x, e.y)
                Core.spawnExplosion(state, e.x, e.y, e.cfg.color, 15, 200)
                Core.shake(state, 6, 0.3, p.x - e.x, p.y - e.y)
                Core.addFloatingText(state, e.x, e.y, S.get("float_self_destruct"), e.cfg.color)
                table.remove(state.enemies, i)
                state.totalKills = state.totalKills + 1
                goto continue_enemy
            end
        elseif behavior == "flank" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            local flankAngle = toPlayer + math.pi * 0.5
            local spd = e.cfg.speed * spdMul
            if d > e.cfg.range * 0.6 then
                e.vx = e.vx + math.cos(toPlayer) * spd * dt * 2
                e.vy = e.vy + math.sin(toPlayer) * spd * dt * 2
            else
                e.vx = e.vx + math.cos(flankAngle) * spd * dt * 1.5
                e.vy = e.vy + math.sin(flankAngle) * spd * dt * 1.5
            end
            e.angle = toPlayer
            e.fireCd = e.fireCd - dt
            if e.fireCd <= 0 and d < e.cfg.range then
                e.fireCd = eFire
                EnemyAI.enemyFire(state, Core, e)
            end
        elseif behavior == "healer" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            if d < 200 then
                e.vx = e.vx - math.cos(toPlayer) * e.cfg.speed * slowfieldMul * dt * 2
                e.vy = e.vy - math.sin(toPlayer) * e.cfg.speed * slowfieldMul * dt * 2
            end
            e.angle = toPlayer
            e.fireCd = e.fireCd - dt
            if e.fireCd <= 0 then
                e.fireCd = eFire
                for _, ally in ipairs(state.enemies) do
                    if ally ~= e and ally.hp < ally.hpMax then
                        local ad = dist(e.x, e.y, ally.x, ally.y)
                        if ad < 150 then
                            ally.hp = math.min(ally.hpMax, ally.hp + 20)
                            Core.addFloatingText(state, ally.x, ally.y - 10, "+20", { 100, 255, 200 })
                            break
                        end
                    end
                end
            end
        elseif behavior == "cloaker" then
            e.cloakTimer = (e.cloakTimer or 0) + dt
            local cycleDuration = 4.0
            local phase = e.cloakTimer % cycleDuration
            local wasCloaked = e.cloaked
            e.cloaked = phase < 2.5
            if wasCloaked and not e.cloaked then
                Core.addFloatingText(state, e.x, e.y - 14, S.get("float_reveal"), { 120, 80, 200 }, 0.8)
                Core.spawnParticles(state, e.x, e.y, { 120, 80, 200 }, 8)
                for burst = 0, 2 do
                    local toP = angleToward(e.x, e.y, p.x, p.y) + (burst - 1) * 0.2
                    table.insert(state.enemyBullets, {
                        x = e.x, y = e.y,
                        vx = math.cos(toP) * 400,
                        vy = math.sin(toP) * 400,
                        life = 1.0, dmg = e.cfg.dmg,
                        color = e.cfg.color, owner = e,
                    })
                end
            end
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            e.angle = toPlayer
            local spd = e.cfg.speed * spdMul
            if e.cloaked then
                e.vx = e.vx + math.cos(toPlayer) * spd * 1.5 * dt
                e.vy = e.vy + math.sin(toPlayer) * spd * 1.5 * dt
            else
                e.vx = e.vx - math.cos(toPlayer) * spd * 0.5 * dt
                e.vy = e.vy - math.sin(toPlayer) * spd * 0.5 * dt
            end
        elseif behavior == "summoner" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            e.angle = toPlayer
            local spd = e.cfg.speed * spdMul
            if d < 250 then
                e.vx = e.vx - math.cos(toPlayer) * spd * 2 * dt
                e.vy = e.vy - math.sin(toPlayer) * spd * 2 * dt
            elseif d > 350 then
                e.vx = e.vx + math.cos(toPlayer) * spd * dt
                e.vy = e.vy + math.sin(toPlayer) * spd * dt
            end
            e.summonCd2 = (e.summonCd2 or 5.0) - dt
            if e.summonCd2 <= 0 then
                e.summonCd2 = 6.0
                local summonCount = math.min(2, 14 - #state.enemies)
                for sc = 1, summonCount do
                    local sa = TAU / summonCount * sc
                    local sx = e.x + math.cos(sa) * 40
                    local sy = e.y + math.sin(sa) * 40
                    local cfg = Data.ENEMY_TYPES["drone"]
                    local spawn = {
                        x = sx, y = sy, vx = 0, vy = 0,
                        hp = math.floor(cfg.hp * 0.6), hpMax = math.floor(cfg.hp * 0.6),
                        cfg = cfg, angle = 0,
                        fireCd = rand(0, cfg.fire),
                        hitFlash = 0, size = cfg.size,
                    }
                    table.insert(state.enemies, spawn)
                end
                Core.addFloatingText(state, e.x, e.y - 16, S.get("float_summon"), { 220, 180, 60 }, 0.8)
                Core.spawnParticles(state, e.x, e.y, { 220, 180, 60 }, 10)
            end
            e.fireCd = e.fireCd - dt
            if e.fireCd <= 0 and d < e.cfg.range then
                e.fireCd = eFire
                EnemyAI.enemyFire(state, Core, e)
            end
        elseif behavior == "splitter" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            e.angle = toPlayer
            local spd = e.cfg.speed * spdMul
            if d > e.cfg.range * 0.5 then
                e.vx = e.vx + math.cos(toPlayer) * spd * dt
                e.vy = e.vy + math.sin(toPlayer) * spd * dt
            end
            e.fireCd = e.fireCd - dt
            if e.fireCd <= 0 and d < e.cfg.range then
                e.fireCd = eFire
                EnemyAI.enemyFire(state, Core, e)
            end
        -- P13.1: 虚空吞噬者 - 吸收子弹转化为护盾
        elseif behavior == "absorber" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            e.angle = toPlayer
            local spd = e.cfg.speed * spdMul
            if d > e.cfg.range * 0.6 then
                e.vx = e.vx + math.cos(toPlayer) * spd * dt
                e.vy = e.vy + math.sin(toPlayer) * spd * dt
            elseif d < 100 then
                e.vx = e.vx - math.cos(toPlayer) * spd * dt
                e.vy = e.vy - math.sin(toPlayer) * spd * dt
            end
            -- 吸收玩家子弹（检查碰撞范围内）
            local absorbRange = 60
            for bi = #state.bullets, 1, -1 do
                local b = state.bullets[bi]
                local bd = dist(e.x, e.y, b.x, b.y)
                if bd < absorbRange then
                    table.remove(state.bullets, bi)
                    -- 转化为护盾
                    e.shieldAbsorb = (e.shieldAbsorb or 0) + 5
                    Core.spawnParticles(state, b.x, b.y, { 100, 0, 180 }, 3)
                end
            end
            -- 持续消耗吸收的能量生成护盾
            if e.shieldAbsorb and e.shieldAbsorb > 0 then
                local shieldDrain = math.min(e.shieldAbsorb, dt * 20)
                e.shieldAbsorb = e.shieldAbsorb - shieldDrain
                e.absorbedShield = (e.absorbedShield or 0) + shieldDrain
            end
        -- P13.1: 电磁干扰器 - 释放EMP脉冲禁用武器
        elseif behavior == "disruptor" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            e.angle = toPlayer
            local spd = e.cfg.speed * spdMul
            if d > 300 then
                e.vx = e.vx + math.cos(toPlayer) * spd * dt
                e.vy = e.vy + math.sin(toPlayer) * spd * dt
            end
            e.empCd = (e.empCd or 6.0) - dt
            if e.empCd <= 0 then
                e.empCd = 6.0
                -- 释放EMP脉冲
                local empRange = 400
                if d < empRange then
                    -- 禁用玩家武器2秒
                    state.weaponDisabled = 2.0
                    Core.addFloatingText(state, p.x, p.y - 30, "⚡武器被干扰!", { 0, 200, 255 }, 1.0)
                    Core.shake(state, 4, 0.3)
                    Core.spawnParticles(state, p.x, p.y, { 0, 200, 255 }, 20)
                end
                Core.spawnParticles(state, e.x, e.y, { 0, 200, 255 }, 15)
            end
        -- P13.1: 时空扭曲者 - 瞬移到玩家背后
        elseif behavior == "warper" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            e.angle = toPlayer
            local spd = e.cfg.speed * spdMul
            e.warpCd = (e.warpCd or 4.0) - dt
            if e.warpCd <= 0 and d < 500 then
                e.warpCd = 4.0
                -- 瞬移到玩家背后
                local behindAng = toPlayer + math.pi
                local warpDist = 80 + math.random() * 60
                local oldX, oldY = e.x, e.y
                e.x = p.x + math.cos(behindAng) * warpDist
                e.y = p.y + math.sin(behindAng) * warpDist
                Core.addFloatingText(state, oldX, oldY - 20, "瞬移!", { 200, 0, 255 }, 0.6)
                Core.spawnParticles(state, oldX, oldY, { 200, 0, 255 }, 12)
                Core.spawnParticles(state, e.x, e.y, { 200, 0, 255 }, 12)
            else
                e.vx = e.vx + math.cos(toPlayer) * spd * 0.3 * dt
                e.vy = e.vy + math.sin(toPlayer) * spd * 0.3 * dt
            end
            -- 从背后攻击伤害更高
            e.fireCd = e.fireCd - dt
            if e.fireCd <= 0 and d < e.cfg.range then
                e.fireCd = eFire
                EnemyAI.enemyFire(state, Core, e, 1.5)  -- 背后攻击1.5倍伤害
            end
        -- P13.1: 量子分裂体 - 被击杀后分裂
        elseif behavior == "quantum" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            e.angle = toPlayer
            local spd = e.cfg.speed * spdMul
            if d > e.cfg.range * 0.5 then
                e.vx = e.vx + math.cos(toPlayer) * spd * dt
                e.vy = e.vy + math.sin(toPlayer) * spd * dt
            end
            e.fireCd = e.fireCd - dt
            if e.fireCd <= 0 and d < e.cfg.range then
                e.fireCd = eFire
                EnemyAI.enemyFire(state, Core, e)
            end
            e._quantumSplit = true  -- 标记为可分裂
        elseif behavior == "fighter" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            local spd = e.cfg.speed * spdMul
            local desiredR = e.cfg.range * 0.75
            if d > desiredR then
                e.vx = math.cos(toPlayer) * spd
                e.vy = math.sin(toPlayer) * spd
            elseif d < desiredR * 0.6 then
                e.vx = -math.cos(toPlayer) * spd * 0.6
                e.vy = -math.sin(toPlayer) * spd * 0.6
            else
                e.vx = math.cos(toPlayer + math.pi * 0.5) * spd * 0.5
                e.vy = math.sin(toPlayer + math.pi * 0.5) * spd * 0.5
            end
            e.angle = toPlayer
            e.fireCd = e.fireCd - dt
            if e.fireCd <= 0 and d < e.cfg.range then
                e.fireCd = eFire
                EnemyAI.enemyFire(state, Core, e)
            end
        elseif behavior == "cruiser" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            local spd = e.cfg.speed * spdMul
            if d > e.cfg.range * 0.9 then
                e.vx = math.cos(toPlayer) * spd
                e.vy = math.sin(toPlayer) * spd
            else
                e.vx = math.cos(toPlayer + math.pi * 0.5) * spd * 0.4
                e.vy = math.sin(toPlayer + math.pi * 0.5) * spd * 0.4
            end
            e.angle = toPlayer
            e.fireCd = e.fireCd - dt
            if e.fireCd <= 0 and d < e.cfg.range then
                e.fireCd = eFire
                -- 三连发
                EnemyAI.enemyFire(state, Core, e)
                EnemyAI.enemyFire(state, Core, e)
                EnemyAI.enemyFire(state, Core, e)
            end
        elseif behavior == "phase" then
            e._phaseTimer = (e._phaseTimer or 0) + dt
            e._phased = e._phased or false
            if e._phaseTimer > 2.5 then
                e._phaseTimer = 0
                e._phased = not e._phased
                if e._phased then
                    Core.spawnParticles(state, e.x, e.y, e.cfg.color, 15)
                end
            end
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            local spd = e.cfg.speed * spdMul
            if e._phased then
                e.vx = math.cos(toPlayer) * spd * 1.4
                e.vy = math.sin(toPlayer) * spd * 1.4
            else
                e.vx = math.cos(toPlayer) * spd * 0.7
                e.vy = math.sin(toPlayer) * spd * 0.7
            end
            e.angle = toPlayer
            if not e._phased then
                e.fireCd = e.fireCd - dt
                if e.fireCd <= 0 and d < e.cfg.range then
                    e.fireCd = eFire
                    EnemyAI.enemyFire(state, Core, e)
                end
            end
        elseif behavior == "leech" then
            local toPlayer = angleToward(e.x, e.y, p.x, p.y)
            local spd = e.cfg.speed * spdMul
            if d > 200 then
                e.vx = math.cos(toPlayer) * spd
                e.vy = math.sin(toPlayer) * spd
            else
                e.vx = math.cos(toPlayer) * spd * 0.3
                e.vy = math.sin(toPlayer) * spd * 0.3
            end
            e.angle = toPlayer
            e.fireCd = e.fireCd - dt
            if e.fireCd <= 0 and d < e.cfg.range then
                e.fireCd = eFire
                EnemyAI.enemyFire(state, Core, e)
                if d < 250 then
                    state.player.energy = math.max(0, (state.player.energy or 100) - 2)
                    if not e.hpGained then e.hpGained = 0 end
                    e.hpGained = e.hpGained + 3
                end
            end
            if d < 220 then
                e.hp = math.min(e.hpMax, e.hp + 2 * dt)
            end
        else
            -- 默认AI
            local spd = e.cfg.speed * spdMul
            if d < e.cfg.range then
                local targetAngle = angleToward(e.x, e.y, p.x, p.y)
                e.angle = targetAngle
                e.fireCd = e.fireCd - dt
                if e.fireCd <= 0 then
                    e.fireCd = eFire
                    EnemyAI.enemyFire(state, Core, e)
                end
                if d < e.cfg.range * 0.4 then
                    e.vx = e.vx - math.cos(e.angle) * spd * dt
                    e.vy = e.vy - math.sin(e.angle) * spd * dt
                end
            else
                local toPlayer = angleToward(e.x, e.y, p.x, p.y)
                e.vx = e.vx + math.cos(toPlayer) * spd * 0.5 * dt
                e.vy = e.vy + math.sin(toPlayer) * spd * 0.5 * dt
            end
        end
        -- 速度衰减
        e.vx = e.vx * (1 - dt * 2)
        e.vy = e.vy * (1 - dt * 2)
        e.x = e.x + e.vx * dt
        e.y = e.y + e.vy * dt
        if e.hitFlash > 0 then e.hitFlash = e.hitFlash - dt end
        -- Boss特殊: Phase2 + 召唤 + 狂暴
        if e.isBoss then
            if Systems.checkBossPhase2(e) then
                Core.addToast(state, "⚠ " .. (e.cfg.name or "Boss") .. " Phase 2!", { 255, 80, 255 })
                Core.shake(state, 10, 0.6)
                Core.spawnExplosion(state, e.x, e.y, { 255, 80, 255 }, 20, 250)
                -- P12.2: Phase切换对话
                local dialogue = Data.BOSS_DIALOGUE[e.bossId]
                if dialogue and dialogue.phase then
                    state._bossDialogue = {
                        text = dialogue.phase[1],
                        color = e.cfg.color,
                        timer = 2.5,
                        alpha = 1.0,
                    }
                end
            end
            if e.hp < e.hpMax * 0.3 and not e.enraged then
                e.enraged = true
                e.cfg = setmetatable({ fire = e.cfg.fire * 0.5, speed = e.cfg.speed * 1.5 }, { __index = e.cfg })
                Core.addToast(state, S.get("hud_boss_rage", e.cfg.name or "Boss"), { 255, 40, 40 })
                Core.shake(state, 8, 0.5)
            end
            if e.summonCd then
                e.summonCd = e.summonCd - dt
                if e.summonCd <= 0 then
                    e.summonCd = e.enraged and 4 or 6
                    EnemyAI.spawnEnemy(state, Core, "drone", e.cfg.zone or "middle")
                end
            end
        end
        -- 狂暴词缀
        if e.affix == "berserker" and not e.isBoss and not e.berserkerRage then
            if e.hp < e.hpMax * 0.4 then
                e.berserkerRage = true
                e.cfg = setmetatable({
                    fire = e.cfg.fire * 0.4,
                    speed = e.cfg.speed * 1.8,
                }, { __index = e.cfg })
                Core.spawnExplosion(state, e.x, e.y, { 255, 120, 0 }, 10, 80)
                Core.addFloatingText(state, e.x, e.y - 16, S.get("float_rage"), { 255, 120, 0 }, 1.0)
            end
        end
        ::continue_enemy::
    end
end

-- ============================================================================
-- 敌人射击模式
-- ============================================================================
function EnemyAI.enemyFire(state, Core, e)
    local p = state.player
    local angle = angleToward(e.x, e.y, p.x, p.y)
    local speed = 350
    if e.isBoss then
        local pattern = e.cfg.pattern
        if pattern == "ring" then
            for i = 0, 7 do
                local a = (TAU / 8) * i
                table.insert(state.enemyBullets, {
                    x = e.x, y = e.y,
                    vx = math.cos(a) * speed * 0.8,
                    vy = math.sin(a) * speed * 0.8,
                    life = 2.0, dmg = e.cfg.dmg * 0.7,
                    color = e.cfg.color,
                })
            end
        elseif pattern == "spread" then
            for i = -2, 2 do
                local a = angle + i * 0.2
                table.insert(state.enemyBullets, {
                    x = e.x, y = e.y,
                    vx = math.cos(a) * speed,
                    vy = math.sin(a) * speed,
                    life = 1.5, dmg = e.cfg.dmg,
                    color = e.cfg.color,
                })
            end
        elseif pattern == "omni" then
            for i = 0, 11 do
                local a = (TAU / 12) * i + state.dayTimer * 0.5
                table.insert(state.enemyBullets, {
                    x = e.x, y = e.y,
                    vx = math.cos(a) * speed * 0.9,
                    vy = math.sin(a) * speed * 0.9,
                    life = 2.5, dmg = e.cfg.dmg,
                    color = e.cfg.color,
                })
            end
        elseif pattern == "void" then
            e.voidPhase = (e.voidPhase or 0) + 1
            if e.voidPhase % 3 == 0 then
                local teleAngle = rand(0, TAU)
                local teleDist = rand(150, 250)
                e.x = p.x + math.cos(teleAngle) * teleDist
                e.y = p.y + math.sin(teleAngle) * teleDist
                Core.spawnParticles(state, e.x, e.y, { 80, 0, 160 }, 12)
                for i = 0, 5 do
                    local a = (TAU / 6) * i
                    table.insert(state.enemyBullets, {
                        x = e.x, y = e.y,
                        vx = math.cos(a) * speed * 1.1,
                        vy = math.sin(a) * speed * 1.1,
                        life = 1.8, dmg = e.cfg.dmg,
                        color = { 100, 0, 200 },
                    })
                end
            else
                local spin = state.dayTimer * 2.5
                for i = 0, 7 do
                    local a = (TAU / 8) * i + spin
                    table.insert(state.enemyBullets, {
                        x = e.x, y = e.y,
                        vx = math.cos(a) * speed * 0.7,
                        vy = math.sin(a) * speed * 0.7,
                        life = 2.8, dmg = math.floor(e.cfg.dmg * 0.7),
                        color = { 60, 0, 120 },
                    })
                end
            end
        -- P13.2: 星际仲裁者 - 激光阵+召唤仲裁骑士
        elseif pattern == "arbiter" then
            e.arbiterPhase = (e.arbiterPhase or 0) + 1
            local phase = e.arbiterPhase % 4
            if phase == 0 then
                -- 激光阵：放射状弹幕
                for i = 0, 7 do
                    local a = (TAU / 8) * i
                    table.insert(state.enemyBullets, {
                        x = e.x, y = e.y,
                        vx = math.cos(a) * speed * 1.2,
                        vy = math.sin(a) * speed * 1.2,
                        life = 2.0, dmg = e.cfg.dmg,
                        color = { 255, 215, 0 },
                    })
                end
            elseif phase == 1 then
                -- 定向弹幕
                local toPlayer = angleToward(e.x, e.y, p.x, p.y)
                for i = -2, 2 do
                    local a = toPlayer + i * 0.15
                    table.insert(state.enemyBullets, {
                        x = e.x, y = e.y,
                        vx = math.cos(a) * speed * 1.0,
                        vy = math.sin(a) * speed * 1.0,
                        life = 1.8, dmg = e.cfg.dmg,
                        color = { 255, 180, 50 },
                    })
                end
            elseif phase == 2 then
                -- 召唤仲裁骑士
                if #state.enemies < 12 then
                    local summonAng = rand(0, TAU)
                    local cfg = Data.ENEMY_TYPES["guard"]
                    table.insert(state.enemies, {
                        x = e.x + math.cos(summonAng) * 60,
                        y = e.y + math.sin(summonAng) * 60,
                        vx = 0, vy = 0, angle = rand(0, TAU),
                        hp = math.floor(cfg.hp * 0.5), hpMax = math.floor(cfg.hp * 0.5),
                        cfg = cfg, radius = cfg.size, fireCd = rand(0, cfg.fire),
                        hitFlash = 0, size = cfg.size,
                        isBossMinion = true,
                    })
                    Core.spawnParticles(state, e.x, e.y, { 255, 215, 0 }, 15)
                end
            else
                -- 螺旋弹幕
                local spin = state.dayTimer * 3
                for i = 0, 5 do
                    local a = (TAU / 6) * i + spin
                    table.insert(state.enemyBullets, {
                        x = e.x, y = e.y,
                        vx = math.cos(a) * speed * 0.8,
                        vy = math.sin(a) * speed * 0.8,
                        life = 2.5, dmg = math.floor(e.cfg.dmg * 0.8),
                        color = { 255, 230, 100 },
                    })
                end
            end
        -- P13.2: 深渊巨口 - 吞噬小行星恢复HP+全屏黑洞吸附
        elseif pattern == "leviathan" then
            e.leviathanPhase = (e.leviathanPhase or 0) + 1
            local phase = e.leviathanPhase % 5
            if phase == 0 then
                -- 黑洞吸附效果：吸引玩家和子弹
                local d = dist(e.x, e.y, p.x, p.y)
                if d < 400 then
                    local pullStrength = (400 - d) * 30 * dt
                    local toE = angleToward(p.x, p.y, e.x, e.y)
                    p.vx = p.vx + math.cos(toE) * pullStrength
                    p.vy = p.vy + math.sin(toE) * pullStrength
                end
                -- 吸引子弹
                for bi = #state.bullets, 1, -1 do
                    local b = state.bullets[bi]
                    local bd = dist(e.x, e.y, b.x, b.y)
                    if bd < 300 and bd > 50 then
                        local toE = angleToward(b.x, b.y, e.x, e.y)
                        b.vx = b.vx + math.cos(toE) * 150 * dt
                        b.vy = b.vy + math.sin(toE) * 150 * dt
                    end
                end
            elseif phase == 1 or phase == 2 then
                -- 扇形弹幕
                local toPlayer = angleToward(e.x, e.y, p.x, p.y)
                for i = -3, 3 do
                    local a = toPlayer + i * 0.2
                    table.insert(state.enemyBullets, {
                        x = e.x, y = e.y,
                        vx = math.cos(a) * speed * 0.9,
                        vy = math.sin(a) * speed * 0.9,
                        life = 2.0, dmg = e.cfg.dmg,
                        color = { 100, 50, 150 },
                    })
                end
            else
                -- 吞噬小行星恢复HP
                for ai = #state.asteroids, 1, -1 do
                    local a = state.asteroids[ai]
                    local ad = dist(e.x, e.y, a.x, a.y)
                    if ad < 100 then
                        e.hp = math.min(e.hpMax, e.hp + 50)
                        table.remove(state.asteroids, ai)
                        Core.spawnParticles(state, e.x, e.y, { 150, 100, 200 }, 10)
                        break
                    end
                end
                -- 圆环弹幕
                for i = 0, 11 do
                    local a = (TAU / 12) * i
                    table.insert(state.enemyBullets, {
                        x = e.x, y = e.y,
                        vx = math.cos(a) * speed * 0.7,
                        vy = math.sin(a) * speed * 0.7,
                        life = 2.5, dmg = math.floor(e.cfg.dmg * 0.6),
                        color = { 80, 40, 120 },
                    })
                end
            end
        else
            table.insert(state.enemyBullets, {
                x = e.x, y = e.y,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                life = 1.5, dmg = e.cfg.dmg,
                color = e.cfg.color,
            })
        end
    else
        local scaledDmg = e.cfg.dmg * (e.dayScale or 1)
        table.insert(state.enemyBullets, {
            x = e.x, y = e.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 1.2, dmg = scaledDmg,
            color = e.cfg.color,
            owner = e,
        })
    end
end

-- ============================================================================
-- 敌人击杀处理
-- ============================================================================
function EnemyAI.onEnemyKilled(state, Core, e)
    Audio.playExplosion(e.isBoss and "big" or "small")
    if Systems.combo.count >= 3 then
        Audio.playCombo(Systems.combo.count)
    end
    local comboMul, milestone = Systems.onKill(state)
    if milestone then
        Core.applyComboMilestone(state, milestone)
    end
    local baseScore = e.cfg.score or 50
    if Systems.hasRelic(state, "r_xp_boost") then baseScore = math.floor(baseScore * 1.3) end
    state.score = state.score + math.floor(baseScore * comboMul)
    state.totalKills = state.totalKills + 1
    -- P14.2: 每周挑战进度更新 - kill
    if state.weeklyChallenge and not state.weeklyChallenge.completed then
        if state.weeklyChallenge.type == "kill" then
            state.weeklyChallenge.progress = state.weeklyChallenge.progress + 1
            if state.weeklyChallenge.progress >= state.weeklyChallenge.target then
                state.weeklyChallenge.completed = true
                Core.addToast(state, "🎯 社区挑战完成: " .. state.weeklyChallenge.name, { 0, 255, 180 })
            end
        end
    end
    if e.eliteReward then
        state.achStats = state.achStats or {}
        state.achStats.eliteKills = (state.achStats.eliteKills or 0) + 1
    end
    -- 遗物掉落
    local relicDrop = Systems.checkRelicDrop(state, e)
    if relicDrop then
        state.relicDrops = state.relicDrops or {}
        table.insert(state.relicDrops, {
            x = e.x, y = e.y,
            relicId = relicDrop.id,
            def = relicDrop,
            life = 30,
            spawnTime = 0,
            bobPhase = rand(0, TAU),
        })
    end
    -- P13.3: r_time_warp - 击杀时概率触发短暂慢动作
    if Systems.hasRelic(state, "r_time_warp") and math.random() < 0.25 then
        state.timeScale = 0.4
        state.slowmoTimer = 1.0
        Core.addFloatingText(state, e.x, e.y - 20, "时间扭曲!", { 100, 255, 255 }, 1.2)
    end
    -- 遗物：连锁闪电
    if Systems.hasRelic(state, "r_chain") and math.random() < 0.30 then
        local nearest, nearDist = nil, 200
        for _, ne in ipairs(state.enemies) do
            if ne ~= e then
                local d2 = dist(e.x, e.y, ne.x, ne.y)
                if d2 < nearDist then nearest = ne; nearDist = d2 end
            end
        end
        if nearest then
            nearest.hp = nearest.hp - 20
            nearest.hitFlash = 0.15
            Core.spawnParticles(state, nearest.x, nearest.y, {100, 200, 255}, 5)
            Core.addFloatingText(state, nearest.x, nearest.y - 15, "⚡20", {100, 200, 255})
        end
    end
    -- P7.4 遗物: r_echo (击杀时25%发射追踪弹)
    if Systems.hasRelic(state, "r_echo") and math.random() < 0.25 then
        local nearest, nearDist = nil, 400
        for _, ne in ipairs(state.enemies) do
            if ne ~= e then
                local d2 = dist(e.x, e.y, ne.x, ne.y)
                if d2 < nearDist then nearest = ne; nearDist = d2 end
            end
        end
        if nearest then
            local ang = angleToward(e.x, e.y, nearest.x, nearest.y)
            table.insert(state.bullets, {
                x = e.x, y = e.y,
                vx = math.cos(ang) * 350,
                vy = math.sin(ang) * 350,
                life = 2.0,
                dmg = math.floor((state.stats.dmg or 10) * 0.6),
                pierce = 0, crit = false,
                homing = true,
                color = { 0, 200, 180 },
            })
            Core.spawnParticles(state, e.x, e.y, { 0, 200, 180 }, 4)
        end
    end
    -- 遗物：赏金猎人
    local metalBonus = Systems.hasRelic(state, "r_bounty") and 1.5 or 1.0
    -- P7.4 遗物: r_lucky (掉落率+40%)
    if Systems.hasRelic(state, "r_lucky") then metalBonus = metalBonus * 1.4 end
    -- Boss击杀
    if e.isBoss and e.bossId then
        state.bossesKilled[e.bossId] = true
        state.bossKillCount = (state.bossKillCount or 0) + 1
        -- P14.2: 每周挑战 - boss
        if state.weeklyChallenge and not state.weeklyChallenge.completed then
            if state.weeklyChallenge.type == "boss" then
                state.weeklyChallenge.progress = state.bossKillCount
                if state.weeklyChallenge.progress >= state.weeklyChallenge.target then
                    state.weeklyChallenge.completed = true
                    Core.addToast(state, "🎯 社区挑战完成: " .. state.weeklyChallenge.name, { 0, 255, 180 })
                end
            end
        end
        Core.addToast(state, S.get("hud_boss_defeated", e.cfg.name), { 255, 215, 0 })
        Core.dropResources(state, e.x, e.y, 0, 0, e.cfg.blueprint or 5, e.cfg.key or 0)
        -- P12.3: Boss击杀解锁编年史
        state.chronoUnlocked = state.chronoUnlocked or {}
        for _, c in ipairs(Data.CHRONICLES) do
            if c.unlockBoss and c.unlockBoss == e.bossId and not state.chronoUnlocked[c.id] then
                state.chronoUnlocked[c.id] = true
                Core.addFloatingText(state, e.x, e.y - 30,
                    "📖 新资料解锁", { 255, 220, 100 }, 2.0)
                Core.addToast(state, "📖 新资料: " .. c.title, { 255, 220, 100 })
            end
        end
        -- P12.2: Boss击杀对话
        local dialogue = Data.BOSS_DIALOGUE[e.bossId]
        if dialogue and dialogue.kill then
            state._bossDialogue = {
                text = dialogue.kill[1],
                color = e.cfg.color,
                timer = 2.5,
                alpha = 1.0,
            }
        end
        -- Phase 6: Boss击杀增强爆炸 - 多层粒子
        Core.spawnExplosion(state, e.x, e.y, e.cfg.color, 45, 380)
        Core.spawnExplosion(state, e.x, e.y, { 255, 255, 200 }, 20, 200) -- 内层白色闪光
        Core.shake(state, 15, 0.7)
        Systems.triggerSlowmo(0.8, 0.15)
        -- Phase 6: Boss hitstop（冻结0.12秒，极致打击感）
        state.hitstop = 0.12
        if state.bossNoHitFlag then
            Systems.unlockAchievement(state, "a_no_hit_boss")
        end
        state.bossNoHitFlag = true
    else
        local bpChance = (e.cfg.blueprint or 0) > 0 and 0.6 or 0.15
        bpChance = bpChance * (state.blueprintMul or 1.0)
        local bp = math.random() < bpChance and 1 or 0
        local dropMetal = math.floor((e.cfg.metal or 1) * metalBonus)
        Core.dropResources(state, e.x, e.y, dropMetal, e.cfg.energy or 1, bp, 0)
        if e.eliteReward then
            Core.dropResources(state, e.x, e.y, 3, 3, 1, 0)
        end
        -- 分裂词缀
        if e.splitOnDeath then
            for i = 1, 2 do
                local ang = rand(0, TAU)
                local se = {
                    kind = e.kind, type = e.type,
                    x = e.x + math.cos(ang) * 20,
                    y = e.y + math.sin(ang) * 20,
                    vx = math.cos(ang) * 80, vy = math.sin(ang) * 80,
                    angle = rand(0, TAU),
                    hp = math.floor(e.hpMax * 0.35), hpMax = math.floor(e.hpMax * 0.35),
                    radius = math.floor((e.radius or 12) * 0.7),
                    cfg = e.cfg, fireCd = rand(0, 1.5), hitFlash = 0,
                    isBoss = false, dayScale = e.dayScale or 1,
                }
                table.insert(state.enemies, se)
            end
            Core.spawnExplosion(state, e.x, e.y, {255, 200, 0}, 8, 120)
        end
        -- 分裂者行为
        if e.cfg.behavior == "splitter" and not e.isSplitChild then
            for i = 1, 2 do
                local ang = TAU / 2 * i + rand(-0.3, 0.3)
                local childCfg = e.cfg
                local child = {
                    x = e.x + math.cos(ang) * 25,
                    y = e.y + math.sin(ang) * 25,
                    vx = math.cos(ang) * 100, vy = math.sin(ang) * 100,
                    angle = rand(0, TAU),
                    hp = math.floor(e.hpMax * 0.4), hpMax = math.floor(e.hpMax * 0.4),
                    cfg = setmetatable({
                        size = math.floor(childCfg.size * 0.6),
                        speed = childCfg.speed * 1.3,
                        score = math.floor(childCfg.score * 0.3),
                        metal = 1, energy = 1, blueprint = 0,
                    }, { __index = childCfg }),
                    fireCd = rand(0, 1.0), hitFlash = 0,
                    size = math.floor(childCfg.size * 0.6),
                    isSplitChild = true,
                }
                table.insert(state.enemies, child)
            end
            Core.spawnExplosion(state, e.x, e.y, { 60, 255, 120 }, 10, 100)
            Core.addFloatingText(state, e.x, e.y, S.get("float_split"), { 60, 255, 120 }, 0.8)
        end
        -- P13.1: 量子分裂体 - 击杀后分裂
        if e.cfg.behavior == "quantum" then
            for i = 1, 2 do
                local ang = TAU / 2 * i + rand(-0.4, 0.4)
                local childCfg = e.cfg
                local child = {
                    x = e.x + math.cos(ang) * 30,
                    y = e.y + math.sin(ang) * 30,
                    vx = math.cos(ang) * 120, vy = math.sin(ang) * 120,
                    angle = rand(0, TAU),
                    hp = math.floor(e.hpMax * 0.5), hpMax = math.floor(e.hpMax * 0.5),
                    cfg = setmetatable({
                        size = math.floor(childCfg.size * 0.65),
                        speed = childCfg.speed * 1.2,
                        dmg = math.floor(childCfg.dmg * 0.6),
                        score = math.floor(childCfg.score * 0.4),
                        metal = 1, energy = 1, blueprint = 0,
                    }, { __index = childCfg }),
                    fireCd = rand(0, 1.2), hitFlash = 0,
                    size = math.floor(childCfg.size * 0.65),
                    isSplitChild = true,
                }
                table.insert(state.enemies, child)
            end
            Core.spawnExplosion(state, e.x, e.y, { 255, 150, 255 }, 12, 120)
            Core.addFloatingText(state, e.x, e.y, "量子分裂!", { 255, 150, 255 }, 0.8)
        end
        -- Phase 6: 增强爆炸粒子（combo倍率更高，加入内核闪光）
        local cMul = math.min(4.0, 1.0 + (Systems.combo.count - 1) * 0.2)
        local pCount = math.floor(12 * cMul)
        local pSpd = math.floor(200 * cMul)
        Core.spawnExplosion(state, e.x, e.y, e.cfg.color, pCount, pSpd)
        -- 内核白色闪光（增强打击感）
        if cMul > 1.5 then
            Core.spawnExplosion(state, e.x, e.y, { 255, 255, 220 }, 4, 80)
        end
        if Systems.combo.count >= 5 then
            local ringColors = { {255,200,50}, {50,255,150}, {200,100,255} }
            local rc = ringColors[(Systems.combo.count % 3) + 1]
            Core.spawnExplosion(state, e.x, e.y, rc, 8, 130)
            -- Phase 6: 高combo时短暂hitstop
            if Systems.combo.count >= 10 then
                state.hitstop = math.max(state.hitstop or 0, 0.04)
            end
        end
        -- Phase 6: 精英击杀 hitstop
        if e.eliteReward then
            state.hitstop = math.max(state.hitstop or 0, 0.06)
            Core.shake(state, 7, 0.3)
        else
            Core.shake(state, 4, 0.2)
        end
    end
end

-- ============================================================================
return EnemyAI
