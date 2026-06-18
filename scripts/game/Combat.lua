-- ============================================================================
-- 星海征途 - 战斗系统模块
-- 子弹更新、碰撞检测、激光、导弹、Boss技能
-- ============================================================================

local Data = require("game.Data")
local Systems = require("game.Systems")
local Audio = require("game.Audio")
local CoreUtils = require("game.CoreUtils")
local rand, randInt, dist, lerp, clamp, angleToward, TAU =
    CoreUtils.rand, CoreUtils.randInt, CoreUtils.dist, CoreUtils.lerp,
    CoreUtils.clamp, CoreUtils.angleToward, CoreUtils.TAU

local Combat = {}

-- ============================================================================
-- 子弹更新
-- ============================================================================
function Combat.updateBullets(state, dt)
    -- 玩家子弹
    for i = #state.bullets, 1, -1 do
        local b = state.bullets[i]
        -- P7.4: r_echo 追踪弹 - 缓慢转向最近敌人
        if b.homing then
            local nearest, nearDist = nil, 400
            for _, e in ipairs(state.enemies) do
                local d = dist(b.x, b.y, e.x, e.y)
                if d < nearDist then nearest = e; nearDist = d end
            end
            if nearest then
                local targetAng = math.atan(nearest.y - b.y, nearest.x - b.x)
                local curAng = math.atan(b.vy, b.vx)
                local diff = targetAng - curAng
                -- 角度归一化到 [-pi, pi]
                while diff > math.pi do diff = diff - 2 * math.pi end
                while diff < -math.pi do diff = diff + 2 * math.pi end
                local turnRate = 6.0 * dt
                curAng = curAng + math.max(-turnRate, math.min(turnRate, diff))
                local spd = math.sqrt(b.vx * b.vx + b.vy * b.vy)
                b.vx = math.cos(curAng) * spd
                b.vy = math.sin(curAng) * spd
            end
        end
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt
        if b.life <= 0 then table.remove(state.bullets, i) end
    end
    -- 敌方子弹
    for i = #state.enemyBullets, 1, -1 do
        local b = state.enemyBullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt
        if b.life <= 0 then table.remove(state.enemyBullets, i) end
    end
end

-- ============================================================================
-- 碰撞检测
-- ============================================================================
function Combat.checkCollisions(state, Core)
    local p = state.player
    -- 玩家子弹 vs 敌人
    for bi = #state.bullets, 1, -1 do
        local b = state.bullets[bi]
        local hit = false
        for ei = #state.enemies, 1, -1 do
            local e = state.enemies[ei]
            local d = dist(b.x, b.y, e.x, e.y)
            if d < (e.radius or 12) + 4 then
                -- 偏转词缀: 概率偏转子弹
                if e.deflectChance and math.random() < e.deflectChance then
                    b.vx = -b.vx + rand(-60, 60)
                    b.vy = -b.vy + rand(-60, 60)
                    Core.spawnParticles(state, b.x, b.y, { 80, 180, 255 }, 4)
                    Core.addFloatingText(state, e.x, e.y - 14, "偏转!", { 80, 180, 255 }, 0.6)
                    goto nextBullet
                end
                e.hp = e.hp - b.dmg
                e.hitFlash = 0.12
                -- 伤害统计
                state.totalDmgDealt = state.totalDmgDealt + b.dmg
                -- 遗物：生命汲取
                if Systems.hasRelic(state, "r_lifesteal") then
                    local heal = math.max(1, math.floor(b.dmg * 0.10))
                    p.hp = math.min(p.hp + heal, p.hpMax or 100)
                end
                Core.spawnParticles(state, b.x, b.y, e.cfg.color, 3)
                -- 伤害飘字
                local dmgColor = b.crit and { 255, 100, 0 } or { 255, 220, 80 }
                local dmgText = b.crit and ("暴击!" .. math.floor(b.dmg)) or tostring(math.floor(b.dmg))
                -- Phase 6: 暴击飘字更大更醒目
                local dmgScale = b.crit and 1.8 or 1.0
                Core.addFloatingText(state, e.x + rand(-8, 8), e.y - (e.radius or 12),
                    dmgText, dmgColor, dmgScale)
                if e.hp <= 0 then
                    Core.onEnemyKilled(state, e)
                    table.remove(state.enemies, ei)
                end
                if b.pierce <= 0 then
                    hit = true
                    break
                else
                    b.pierce = b.pierce - 1
                end
            end
        end
        ::nextBullet::
        if hit then table.remove(state.bullets, bi) end
    end
    -- 玩家子弹 vs 小行星
    for bi = #state.bullets, 1, -1 do
        local b = state.bullets[bi]
        for ai = #state.asteroids, 1, -1 do
            local a = state.asteroids[ai]
            local d = dist(b.x, b.y, a.x, a.y)
            if d < a.radius then
                a.hp = a.hp - b.dmg
                Core.spawnParticles(state, b.x, b.y, { 180, 160, 120 }, 2)
                if a.hp <= 0 then
                    Core.dropResources(state, a.x, a.y, a.metal, a.energy)
                    table.remove(state.asteroids, ai)
                end
                table.remove(state.bullets, bi)
                break
            end
        end
    end
    -- 敌方子弹 vs 玩家
    for i = #state.enemyBullets, 1, -1 do
        local b = state.enemyBullets[i]
        local d = dist(b.x, b.y, p.x, p.y)
        if d < 14 then
            Core.damagePlayer(state, b.dmg, b.x, b.y)
            Core.spawnParticles(state, b.x, b.y, { 255, 100, 100 }, 3)
            -- 吸血词缀: 命中时回复发射者HP
            if b.owner and b.owner.vampHeal and b.owner.hp and b.owner.hp > 0 then
                local heal = math.floor(b.dmg * b.owner.vampHeal)
                b.owner.hp = math.min(b.owner.hpMax, b.owner.hp + heal)
                Core.addFloatingText(state, b.owner.x, b.owner.y - 14,
                    "+" .. heal, { 255, 50, 80 }, 0.6)
            end
            table.remove(state.enemyBullets, i)
        end
    end
end

-- ============================================================================
-- 激光武器
-- ============================================================================
function Combat.updateLaser(state, Core, dt)
    local laser = state.laser
    if not state.stats.laserUnlocked then return end
    if laser.active then
        laser.charge = math.min(3.0, laser.charge + dt)
        laser.heat = math.min(1.0, laser.heat + dt * 0.25)
        laser.angle = state.player.angle
        -- 持续伤害射线检测
        local p = state.player
        local laserLen = 500 + laser.charge * 100
        local dmg = math.floor((8 + laser.charge * 12) * state.stats.dmgMul) * dt * 4
        for _, e in ipairs(state.enemies) do
            local dx = e.x - p.x
            local dy = e.y - p.y
            local proj = dx * math.cos(laser.angle) + dy * math.sin(laser.angle)
            if proj > 0 and proj < laserLen then
                local perpDist = math.abs(-dx * math.sin(laser.angle) + dy * math.cos(laser.angle))
                if perpDist < (e.radius or 12) + 6 then
                    e.hp = e.hp - dmg
                    e.hitFlash = 0.05
                    state.totalDmgDealt = state.totalDmgDealt + dmg
                    if e.hp <= 0 then
                        Core.onEnemyKilled(state, e)
                    end
                end
            end
        end
        -- 过热停止
        if laser.heat >= 1.0 then
            laser.active = false
            laser.charge = 0
            Core.addToast(state, "激光过热!", { 255, 100, 50 })
        end
    else
        laser.heat = math.max(0, laser.heat - dt * 0.4)
        laser.charge = 0
    end
end

function Combat.toggleLaser(state)
    if not state.stats.laserUnlocked then return end
    state.laser.active = not state.laser.active
    if state.laser.active then
        state.laser.charge = 0
        Audio.playShoot("laser")
    end
end

-- ============================================================================
-- 追踪导弹
-- ============================================================================
function Combat.updateMissiles(state, Core, dt)
    if not state.stats.missileUnlocked then return end
    state.missileCd = math.max(0, state.missileCd - dt)
    for i = #state.missiles, 1, -1 do
        local m = state.missiles[i]
        m.life = m.life - dt
        if m.life <= 0 then
            Core.spawnExplosion(state, m.x, m.y, { 255, 150, 50 }, 8, 120)
            table.remove(state.missiles, i)
        else
            -- 追踪目标
            if m.target then
                local alive = false
                for _, e in ipairs(state.enemies) do
                    if e == m.target then alive = true; break end
                end
                if not alive then m.target = nil end
            end
            if not m.target then
                local bestD = 400
                for _, e in ipairs(state.enemies) do
                    local d2 = dist(m.x, m.y, e.x, e.y)
                    if d2 < bestD then bestD = d2; m.target = e end
                end
            end
            if m.target then
                local desired = angleToward(m.x, m.y, m.target.x, m.target.y)
                local diff = desired - m.angle
                while diff > math.pi do diff = diff - TAU end
                while diff < -math.pi do diff = diff + TAU end
                m.angle = m.angle + clamp(diff, -4 * dt, 4 * dt)
            end
            local spd = 320
            m.vx = math.cos(m.angle) * spd
            m.vy = math.sin(m.angle) * spd
            m.x = m.x + m.vx * dt
            m.y = m.y + m.vy * dt
            -- 尾迹粒子 (P10.3: 上限检查)
            if #state.particles < 200 then
                table.insert(state.particles, {
                    x = m.x - m.vx * dt * 0.5, y = m.y - m.vy * dt * 0.5,
                    vx = rand(-20, 20), vy = rand(-20, 20),
                    life = rand(0.2, 0.4), maxLife = 0.4, alpha = 0.8,
                    size = rand(2, 4), color = { 255, 150, 50 },
                })
            end
            -- 命中检测
            for ei = #state.enemies, 1, -1 do
                local e = state.enemies[ei]
                if dist(m.x, m.y, e.x, e.y) < (e.radius or 12) + 8 then
                    local dmg = math.floor(35 * state.stats.dmgMul)
                    e.hp = e.hp - dmg
                    e.hitFlash = 0.2
                    state.totalDmgDealt = state.totalDmgDealt + dmg
                    Core.addFloatingText(state, e.x, e.y - 10, tostring(dmg), { 255, 180, 50 })
                    if e.hp <= 0 then Core.onEnemyKilled(state, e); table.remove(state.enemies, ei) end
                    Core.spawnExplosion(state, m.x, m.y, { 255, 180, 50 }, 12, 150)
                    Core.shake(state, 4, 0.2)
                    table.remove(state.missiles, i)
                    break
                end
            end
        end
    end
end

function Combat.fireMissile(state, Core)
    if not state.stats.missileUnlocked then return end
    if state.missileCd > 0 then return end
    state.missileCd = 2.5
    local p = state.player
    table.insert(state.missiles, {
        x = p.x, y = p.y,
        vx = math.cos(p.angle) * 200,
        vy = math.sin(p.angle) * 200,
        angle = p.angle,
        life = 4.0,
        target = nil,
    })
    Core.shake(state, 2, 0.1)
    Audio.playShoot("missile")
end

-- ============================================================================
-- P7.1 副武器系统
-- ============================================================================

-- 获取当前已解锁的副武器列表
function Combat.getUnlockedSecondaries(state)
    local unlocked = {}
    if state.stats.shotgunUnlocked then table.insert(unlocked, 1) end
    if state.stats.boomerangUnlocked then table.insert(unlocked, 2) end
    if state.stats.mineUnlocked then table.insert(unlocked, 3) end
    return unlocked
end

-- Tab切换副武器
function Combat.switchSecondary(state, Core)
    local unlocked = Combat.getUnlockedSecondaries(state)
    if #unlocked == 0 then
        Core.addToast(state, "未解锁副武器", { 200, 200, 200 })
        return
    end
    -- 在已解锁列表中循环切换
    local curIdx = state.secondaryIdx
    local found = false
    for i, idx in ipairs(unlocked) do
        if idx == curIdx then
            -- 切到下一个
            local nextI = (i % #unlocked) + 1
            state.secondaryIdx = unlocked[nextI]
            found = true
            break
        end
    end
    if not found then
        state.secondaryIdx = unlocked[1]
    end
    local wepDef = Data.SECONDARY_WEAPONS[state.secondaryIdx]
    Core.addToast(state, "副武器: " .. wepDef.name, wepDef.color)
end

-- 发射副武器
function Combat.fireSecondary(state, Core)
    local unlocked = Combat.getUnlockedSecondaries(state)
    if #unlocked == 0 then return end
    -- 检查当前选中是否已解锁
    local wepDef = Data.SECONDARY_WEAPONS[state.secondaryIdx]
    if not wepDef then return end
    local isUnlocked = false
    for _, idx in ipairs(unlocked) do
        if idx == state.secondaryIdx then isUnlocked = true; break end
    end
    if not isUnlocked then
        state.secondaryIdx = unlocked[1]
        wepDef = Data.SECONDARY_WEAPONS[state.secondaryIdx]
    end
    -- 冷却检查
    if state.secondaryCd > 0 then return end
    state.secondaryCd = wepDef.cooldown

    local p = state.player
    local dmgMul = state.stats.dmgMul or 1.0
    if Core.hasPowerup(state, "dmg_boost") then dmgMul = dmgMul * 1.8 end

    if wepDef.id == "shotgun" then
        -- 散射炮：3发扇形弹幕，短射程高伤害
        local bulletSpeed = 500
        local baseDmg = math.floor(18 * dmgMul)
        local spreadAngles = { -0.25, 0, 0.25 }  -- ±15°
        for _, offset in ipairs(spreadAngles) do
            local ang = p.angle + offset
            local muzzleX = p.x + math.cos(ang) * 16
            local muzzleY = p.y + math.sin(ang) * 16
            table.insert(state.bullets, {
                x = muzzleX, y = muzzleY,
                vx = math.cos(ang) * bulletSpeed,
                vy = math.sin(ang) * bulletSpeed,
                life = 0.6, dmg = baseDmg,
                pierce = 0, crit = false,
                color = { 255, 200, 50 },
                secondary = true,
            })
        end
        -- 后坐力
        p.vx = p.vx - math.cos(p.angle) * 80
        p.vy = p.vy - math.sin(p.angle) * 80
        Core.shake(state, 4, 0.15)
        -- 枪口火焰 (P10.3: 上限)
        for i = 1, 6 do
            if #state.particles >= 200 then break end
            local a = p.angle + rand(-0.4, 0.4)
            local spd = rand(100, 220)
            table.insert(state.particles, {
                x = p.x + math.cos(p.angle) * 16,
                y = p.y + math.sin(p.angle) * 16,
                vx = math.cos(a) * spd, vy = math.sin(a) * spd,
                life = rand(0.1, 0.3), maxLife = 0.3,
                alpha = 1, size = rand(3, 6),
                color = { 255, 200, 50 },
            })
        end

    elseif wepDef.id == "boomerang" then
        -- 回旋镖：飞出后返回，往返都能命中
        local ang = p.angle
        table.insert(state.boomerangs, {
            x = p.x + math.cos(ang) * 20,
            y = p.y + math.sin(ang) * 20,
            angle = ang,
            speed = 400,
            life = 2.5,
            phase = "outgoing",  -- outgoing → returning
            distTraveled = 0,
            maxDist = 280,
            dmg = math.floor(25 * dmgMul),
            hitEnemies = {},  -- 记录每phase击中的敌人（防重复）
            color = { 0, 255, 200 },
            spin = 0,
        })
        Core.spawnParticles(state, p.x, p.y, { 0, 255, 200 }, 4)

    elseif wepDef.id == "mine" then
        -- 等离子地雷：放置在玩家位置，延时后爆炸
        table.insert(state.mines, {
            x = p.x, y = p.y,
            armTimer = 1.0,    -- 1秒后武装
            lifeTimer = 6.0,   -- 6秒后自动引爆
            armed = false,
            radius = 80,       -- 触发/爆炸半径
            dmg = math.floor(50 * dmgMul),
            color = { 200, 50, 255 },
            pulse = 0,
        })
        Core.addFloatingText(state, p.x, p.y - 20, "地雷部署!", { 200, 50, 255 })
        Core.spawnParticles(state, p.x, p.y, { 200, 50, 255 }, 5)
    end
end

-- 更新副武器实体（回旋镖、地雷）
function Combat.updateSecondary(state, Core, dt)
    -- 副武器冷却
    if state.secondaryCd > 0 then
        state.secondaryCd = state.secondaryCd - dt
    end

    -- === 回旋镖更新 ===
    for i = #state.boomerangs, 1, -1 do
        local b = state.boomerangs[i]
        b.life = b.life - dt
        b.spin = b.spin + dt * 12  -- 旋转动画

        if b.life <= 0 then
            table.remove(state.boomerangs, i)
        else
            local p = state.player
            if b.phase == "outgoing" then
                -- 向前飞行
                b.x = b.x + math.cos(b.angle) * b.speed * dt
                b.y = b.y + math.sin(b.angle) * b.speed * dt
                b.distTraveled = b.distTraveled + b.speed * dt
                -- 减速
                b.speed = b.speed * (1 - dt * 2.0)
                -- 到达最大距离或速度过低→转为返回
                if b.distTraveled >= b.maxDist or b.speed < 80 then
                    b.phase = "returning"
                    b.hitEnemies = {}  -- 重置命中记录（返回时可再次命中）
                    b.speed = 100
                end
            else
                -- 返回玩家
                local toPlayerAng = math.atan(p.y - b.y, p.x - b.x)
                b.angle = toPlayerAng
                b.speed = math.min(600, b.speed + dt * 800)  -- 加速返回
                b.x = b.x + math.cos(b.angle) * b.speed * dt
                b.y = b.y + math.sin(b.angle) * b.speed * dt
                -- 接近玩家→消失
                local dToPlayer = dist(b.x, b.y, p.x, p.y)
                if dToPlayer < 20 then
                    table.remove(state.boomerangs, i)
                    goto nextBoomerang
                end
            end

            -- 回旋镖 vs 敌人碰撞
            for _, e in ipairs(state.enemies) do
                local d = dist(b.x, b.y, e.x, e.y)
                if d < (e.radius or 12) + 10 then
                    -- 检查是否已击中过（同phase内）
                    if not b.hitEnemies[e] then
                        b.hitEnemies[e] = true
                        e.hp = e.hp - b.dmg
                        e.hitFlash = 0.15
                        state.totalDmgDealt = state.totalDmgDealt + b.dmg
                        Core.addFloatingText(state, e.x, e.y - 10,
                            tostring(b.dmg), { 0, 255, 200 })
                        Core.spawnParticles(state, b.x, b.y, { 0, 255, 200 }, 3)
                        if e.hp <= 0 then
                            Core.onEnemyKilled(state, e)
                        end
                    end
                end
            end
            -- 清理死亡敌人
            for ei = #state.enemies, 1, -1 do
                if state.enemies[ei].hp <= 0 then table.remove(state.enemies, ei) end
            end

            -- 尾迹粒子 (P10.3: 上限)
            if #state.particles < 200 then
                table.insert(state.particles, {
                    x = b.x + rand(-4, 4), y = b.y + rand(-4, 4),
                    vx = rand(-30, 30), vy = rand(-30, 30),
                    life = rand(0.15, 0.3), maxLife = 0.3,
                    alpha = 0.7, size = rand(2, 4),
                    color = b.color,
                })
            end
        end
        ::nextBoomerang::
    end

    -- === 地雷更新 ===
    for i = #state.mines, 1, -1 do
        local m = state.mines[i]
        m.lifeTimer = m.lifeTimer - dt
        m.pulse = m.pulse + dt * 3  -- 脉冲动画

        if not m.armed then
            m.armTimer = m.armTimer - dt
            if m.armTimer <= 0 then
                m.armed = true
            end
        end

        local shouldExplode = false

        -- 超时引爆
        if m.lifeTimer <= 0 then
            shouldExplode = true
        end

        -- 敌人进入范围触发（仅武装后）
        if m.armed and not shouldExplode then
            for _, e in ipairs(state.enemies) do
                local d = dist(m.x, m.y, e.x, e.y)
                if d < m.radius * 0.6 then
                    shouldExplode = true
                    break
                end
            end
        end

        if shouldExplode then
            -- AOE爆炸
            for _, e in ipairs(state.enemies) do
                local d = dist(m.x, m.y, e.x, e.y)
                if d < m.radius then
                    -- 距离衰减伤害
                    local falloff = 1.0 - (d / m.radius) * 0.5
                    local dmg = math.floor(m.dmg * falloff)
                    e.hp = e.hp - dmg
                    e.hitFlash = 0.2
                    state.totalDmgDealt = state.totalDmgDealt + dmg
                    Core.addFloatingText(state, e.x, e.y - 10,
                        tostring(dmg), { 200, 50, 255 })
                    if e.hp <= 0 then
                        Core.onEnemyKilled(state, e)
                    end
                end
            end
            -- 清理死亡敌人
            for ei = #state.enemies, 1, -1 do
                if state.enemies[ei].hp <= 0 then table.remove(state.enemies, ei) end
            end
            -- 爆炸特效
            Core.spawnExplosion(state, m.x, m.y, { 200, 50, 255 }, 20, 200)
            Core.shake(state, 5, 0.3)
            table.remove(state.mines, i)
        end
    end
end

-- ============================================================================
-- Boss特殊技能
-- ============================================================================
function Combat.updateBossEffects(state, Core, dt)
    -- Boss激光扫射
    for i = #state.bossLasers, 1, -1 do
        local bl = state.bossLasers[i]
        bl.life = bl.life - dt
        bl.angle = bl.angle + bl.rotSpeed * dt
        if bl.life <= 0 then
            table.remove(state.bossLasers, i)
        else
            -- 伤害玩家
            local p = state.player
            local dx = p.x - bl.x
            local dy = p.y - bl.y
            local proj = dx * math.cos(bl.angle) + dy * math.sin(bl.angle)
            if proj > 0 and proj < 400 then
                local perpDist = math.abs(-dx * math.sin(bl.angle) + dy * math.cos(bl.angle))
                if perpDist < 18 then
                    Core.damagePlayer(state, 15 * dt, bl.x, bl.y)
                end
            end
        end
    end
    -- Boss预警圈
    for i = #state.bossWarnings, 1, -1 do
        local w = state.bossWarnings[i]
        w.life = w.life - dt
        if w.life <= 0 then table.remove(state.bossWarnings, i) end
    end
    -- 生成Boss技能
    for _, e in ipairs(state.enemies) do
        if e.isBoss and e.enraged then
            e.skillCd = (e.skillCd or 0) - dt
            if e.skillCd <= 0 then
                e.skillCd = rand(3, 5)
                local skill = randInt(1, 3)
                if skill == 1 then
                    table.insert(state.bossLasers, {
                        x = e.x, y = e.y, angle = e.angle,
                        rotSpeed = rand(0.8, 1.5) * (math.random() > 0.5 and 1 or -1),
                        life = 2.5, maxLife = 2.5,
                    })
                elseif skill == 2 then
                    local p = state.player
                    table.insert(state.bossWarnings, {
                        x = p.x + rand(-80, 80), y = p.y + rand(-80, 80),
                        radius = rand(50, 90), life = 1.5, maxLife = 1.5,
                    })
                else
                    Core.spawnEnemy(state, "kamikaze", "middle")
                    Core.spawnEnemy(state, "kamikaze", "middle")
                    Core.spawnEnemy(state, "kamikaze", "middle")
                    Core.addToast(state, "Boss 召唤自爆无人机!", { 255, 80, 80 })
                end
            end
        end
    end
end

return Combat
