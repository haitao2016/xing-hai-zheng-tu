-- ============================================================================
-- 星海征途 - 玩家控制模块
-- 玩家移动、射击、受伤
-- ============================================================================

local Data = require("game.Data")
local Systems = require("game.Systems")
local Audio = require("game.Audio")
local U = require("game.CoreUtils")

local rand, dist, lerp, clamp, angleToward = U.rand, U.dist, U.lerp, U.clamp, U.angleToward
local TAU = U.TAU

local PlayerCtrl = {}

-- ============================================================================
-- 玩家移动 & 射击
-- ============================================================================
function PlayerCtrl.updatePlayer(state, Core, dt)
    local p = state.player
    -- 减速
    p.vx = p.vx * (1 - dt * 5)
    p.vy = p.vy * (1 - dt * 5)
    -- P3.4 速度加成
    local speedMul = 1.0
    if Core.hasPowerup(state, "speed_boost") then speedMul = 1.5 end
    -- 输入
    local moveX, moveY = state.inputMoveX or 0, state.inputMoveY or 0
    local moveLen = math.sqrt(moveX * moveX + moveY * moveY)
    if moveLen > 0.01 then
        moveX, moveY = moveX / moveLen, moveY / moveLen
        local spd = p.speed * speedMul
        p.vx = p.vx + moveX * spd * dt * 12
        p.vy = p.vy + moveY * spd * dt * 12
    end
    -- 限速
    local curSpd = math.sqrt(p.vx * p.vx + p.vy * p.vy)
    local maxSpd = p.speed * speedMul * 1.2
    if curSpd > maxSpd then
        p.vx = p.vx / curSpd * maxSpd
        p.vy = p.vy / curSpd * maxSpd
    end
    -- 位置更新
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    -- 世界边界（圆形）
    local wr = Data.WORLD.outerR
    local pd = math.sqrt(p.x * p.x + p.y * p.y)
    if pd > wr then
        p.x = p.x / pd * wr
        p.y = p.y / pd * wr
    end
    -- 角度指向鼠标
    if state.inputAimX and state.inputAimY then
        p.angle = math.atan(state.inputAimY - p.y, state.inputAimX - p.x)
    end
    -- 闪烁恢复
    p.hitFlash = math.max(0, p.hitFlash - dt)
    -- 自动射击
    p.fireCd = p.fireCd - dt
    -- P3.4 射速加成
    local fireRateMul = 1.0
    if Core.hasPowerup(state, "fire_rate") then fireRateMul = 0.5 end
    -- P7.4 遗物: r_overclock (射速+50%但过热停火)
    if Systems.hasRelic(state, "r_overclock") then
        if (state.overclockHeat or 0) >= 1.0 then
            -- 过热状态，等待冷却
            state.overclockCooldown = (state.overclockCooldown or 0) - dt
            if (state.overclockCooldown or 0) <= 0 then
                state.overclockHeat = 0
                state.overclockCooldown = 0
            end
            fireRateMul = 999  -- 停火
        else
            fireRateMul = fireRateMul * 0.5  -- 射速+50% (间隔×0.5)
        end
    end
    -- Combo火力全开
    if state.comboOverdrive and state.comboOverdrive.timer > 0 then
        fireRateMul = fireRateMul * 0.33
        state.comboOverdrive.timer = state.comboOverdrive.timer - dt
        if state.comboOverdrive.timer <= 0 then state.comboOverdrive = nil end
    end
    if p.fireCd <= 0 then
        PlayerCtrl.playerFire(state, Core)
        p.fireCd = p.fireRate * fireRateMul
        -- r_overclock 积累热量
        if Systems.hasRelic(state, "r_overclock") and (state.overclockHeat or 0) < 1.0 then
            state.overclockHeat = (state.overclockHeat or 0) + 0.08
            if state.overclockHeat >= 1.0 then
                state.overclockHeat = 1.0
                state.overclockCooldown = 2.0
                Core.addToast(state, "武器过热!", { 255, 60, 0 })
            end
        end
    end
    -- r_overclock 被动散热
    if Systems.hasRelic(state, "r_overclock") and (state.overclockHeat or 0) > 0 and (state.overclockCooldown or 0) <= 0 then
        state.overclockHeat = math.max(0, (state.overclockHeat or 0) - dt * 0.15)
    end
    -- Combo回复buff
    if state.comboRegen and state.comboRegen.timer > 0 then
        state.comboRegen.timer = state.comboRegen.timer - dt
        p.hp = math.min(p.hpMax, p.hp + state.comboRegen.rate * dt)
        if state.comboRegen.timer <= 0 then state.comboRegen = nil end
    end
    -- 引擎拖尾粒子 (P10.3: 200上限)
    if curSpd > 30 and #state.particles < 200 then
        local trailAng = math.atan(p.vy, p.vx) + math.pi
        table.insert(state.particles, {
            x = p.x + math.cos(trailAng) * 12 + rand(-3, 3),
            y = p.y + math.sin(trailAng) * 12 + rand(-3, 3),
            vx = math.cos(trailAng) * rand(20, 60),
            vy = math.sin(trailAng) * rand(20, 60),
            life = rand(0.2, 0.5),
            maxLife = 0.5,
            alpha = 0.8,
            size = rand(2, 4),
            color = state.skinColor or { 100, 200, 255 },
        })
    end
    -- 护盾回复
    if state.stats.shieldRegen and state.stats.shieldRegen > 0 then
        p.shield = math.min(p.shieldMax or 0, p.shield + state.stats.shieldRegen * dt)
    end
end

function PlayerCtrl.playerFire(state, Core)
    local p = state.player
    local bulletSpeed = 600
    -- P3.4 伤害加成
    local dmgMul = state.stats.dmgMul or 1.0
    if Core.hasPowerup(state, "dmg_boost") then dmgMul = dmgMul * 1.8 end
    local baseDmg = math.floor(state.stats.dmg * dmgMul)
    -- 暴击
    local critChance = state.stats.critChance or 0
    -- P7.4 遗物: r_lucky (暴击+10%)
    if Systems.hasRelic(state, "r_lucky") then critChance = critChance + 0.10 end
    local crit = math.random() < critChance
    local dmg = crit and math.floor(baseDmg * (state.stats.critMul or 2.0)) or baseDmg
    -- 主弹
    local muzzleX = p.x + math.cos(p.angle) * 16
    local muzzleY = p.y + math.sin(p.angle) * 16
    table.insert(state.bullets, {
        x = muzzleX, y = muzzleY,
        vx = math.cos(p.angle) * bulletSpeed,
        vy = math.sin(p.angle) * bulletSpeed,
        life = 1.5, dmg = dmg,
        pierce = state.stats.pierce or 0,
        crit = crit,
    })
    -- P9: 射击音效
    Audio.playShoot()
    -- Phase 6: 射击后坐力（玩家微微后退）
    local recoilForce = 35
    p.vx = p.vx - math.cos(p.angle) * recoilForce
    p.vy = p.vy - math.sin(p.angle) * recoilForce
    -- Phase 6: 枪口火焰粒子 (P10.3: 上限)
    for i = 1, 3 do
        if #state.particles >= 200 then break end
        local spread = rand(-0.3, 0.3)
        local spd = rand(80, 180)
        table.insert(state.particles, {
            x = muzzleX, y = muzzleY,
            vx = math.cos(p.angle + spread) * spd,
            vy = math.sin(p.angle + spread) * spd,
            life = rand(0.08, 0.2), maxLife = 0.2,
            alpha = 1, size = rand(2, 4),
            color = { 255, 200, 80 },
        })
    end
    -- 分裂弹 (splitShot 配置)
    local splits = state.stats.splitShot or 0
    if splits > 0 then
        for i = 1, splits do
            local offset = (i - splits / 2 - 0.5) * 0.15
            local ang = p.angle + offset
            table.insert(state.bullets, {
                x = p.x + math.cos(ang) * 16,
                y = p.y + math.sin(ang) * 16,
                vx = math.cos(ang) * bulletSpeed * 0.95,
                vy = math.sin(ang) * bulletSpeed * 0.95,
                life = 1.2, dmg = math.floor(dmg * 0.6),
                pierce = 0, crit = false,
            })
        end
    end
    -- P7.4 遗物: r_multishot (额外2发散射, 伤害-20%)
    if Systems.hasRelic(state, "r_multishot") then
        for i = 1, 2 do
            local spread = (i == 1) and -0.2 or 0.2
            local ang = p.angle + spread
            table.insert(state.bullets, {
                x = p.x + math.cos(ang) * 14,
                y = p.y + math.sin(ang) * 14,
                vx = math.cos(ang) * bulletSpeed * 0.9,
                vy = math.sin(ang) * bulletSpeed * 0.9,
                life = 1.0, dmg = math.floor(dmg * 0.8),
                pierce = 0, crit = false,
            })
        end
    end
end

function PlayerCtrl.damagePlayer(state, Core, rawDmg, srcX, srcY)
    local p = state.player
    -- P3.4 无敌加成
    if Core.hasPowerup(state, "invincible") then
        Core.addFloatingText(state, p.x, p.y - 20, "无敌!", { 255, 255, 100 }, 0.8)
        return
    end
    -- 遗物：相位闪避 (r_dodge: 15%概率闪避)
    if Systems.rollDodge(state) then
        Core.addFloatingText(state, p.x, p.y - 20, "闪避!", { 180, 180, 255 }, 0.8)
        return
    end
    local dmg = rawDmg * (1 - state.stats.dmgReduce)
    if p.shield > 0 then
        local absorbed = math.min(p.shield, dmg)
        p.shield = p.shield - absorbed
        dmg = dmg - absorbed
        -- 护盾碎裂视觉效果（护盾被打破时）
        if p.shield <= 0 then
            Audio.playShieldBreak()
            -- 碎片粒子向外飞散 (P10.3: 上限)
            for i = 1, 12 do
                if #state.particles >= 200 then break end
                local a = (i / 12) * TAU + rand(-0.2, 0.2)
                local spd = rand(80, 200)
                table.insert(state.particles, {
                    x = p.x + math.cos(a) * 18,
                    y = p.y + math.sin(a) * 18,
                    vx = math.cos(a) * spd,
                    vy = math.sin(a) * spd,
                    life = rand(0.4, 0.8),
                    maxLife = 0.8,
                    alpha = 1,
                    size = rand(2, 5),
                    color = { 60, 160, 255 },
                    shieldShard = true,
                })
            end
            Core.shake(state, 6, 0.3)
        end
        -- 遗物：护盾爆发 (r_shield_burst: 护盾破碎时AOE)
        if p.shield <= 0 and Systems.hasRelic(state, "r_shield_burst") then
            for _, e in ipairs(state.enemies) do
                local d = dist(p.x, p.y, e.x, e.y)
                if d < 120 then
                    e.hp = e.hp - 30
                    e.hitFlash = 0.2
                    Core.spawnParticles(state, e.x, e.y, {0, 180, 255}, 4)
                end
            end
            Core.spawnExplosion(state, p.x, p.y, {0, 180, 255}, 15, 200)
            Core.addFloatingText(state, p.x, p.y - 30, "护盾爆发!", {0, 180, 255})
        end
    end
    p.hp = p.hp - dmg
    p.hitFlash = 0.15
    -- Phase 6: 受伤红色闪屏（强度与伤害比例相关）
    local flashIntensity = math.min(1.0, dmg / (p.hpMax * 0.3))
    state.damageFlash = math.max(state.damageFlash or 0, 0.25 + flashIntensity * 0.15)
    -- Boss战不受伤标记清除
    state.bossNoHitFlag = false
    -- 遗物：反伤甲 (r_thorns: 反弹30%)
    local reflectRate = 0
    if Systems.hasRelic(state, "r_thorns") then reflectRate = 0.3 end
    -- P7.3: reflect powerup (反弹50%)
    if Core.hasPowerup(state, "reflect") then reflectRate = math.max(reflectRate, 0.5) end
    if reflectRate > 0 then
        local nearest, nearDist = nil, 150
        for _, e in ipairs(state.enemies) do
            local d = dist(p.x, p.y, e.x, e.y)
            if d < nearDist then nearest = e; nearDist = d end
        end
        if nearest then
            local reflectDmg = math.floor(dmg * reflectRate)
            nearest.hp = nearest.hp - reflectDmg
            nearest.hitFlash = 0.1
            Core.addFloatingText(state, nearest.x, nearest.y - 15, "-" .. reflectDmg, {200, 100, 255})
        end
    end
    -- P3.2 统计
    state.totalDmgTaken = state.totalDmgTaken + dmg
    -- Phase 6.4: 方向性受伤震动（从伤害来源方向震动）
    local shakeDirX, shakeDirY = 0, 0
    if srcX and srcY then
        shakeDirX = p.x - srcX
        shakeDirY = p.y - srcY
    end
    -- Phase 6.1: 大额伤害增强震动
    local shakeIntensity, shakeDuration = 3, 0.15
    if dmg > 30 then
        shakeIntensity = 4
        shakeDuration = 0.3
    end
    Core.shake(state, shakeIntensity, shakeDuration, shakeDirX, shakeDirY)
    -- 飘字
    Core.addFloatingText(state, p.x, p.y - 20, string.format("-%d", math.floor(dmg)), { 255, 80, 80 })
end

return PlayerCtrl
