-- ============================================================================
-- 星海征途 - 世界系统模块
-- 小行星、拾取物、粒子、道具、波次、事件、友军、科技、任务、教程
-- ============================================================================

local Data = require("game.Data")
local Systems = require("game.Systems")
local Audio = require("game.Audio")
local CoreUtils = require("game.CoreUtils")
local rand, randInt, dist, lerp, clamp, angleToward, TAU =
    CoreUtils.rand, CoreUtils.randInt, CoreUtils.dist, CoreUtils.lerp,
    CoreUtils.clamp, CoreUtils.angleToward, CoreUtils.TAU

local World = {}

-- ============================================================================
-- 小行星
-- ============================================================================
function World.updateAsteroids(state, dt)
    for _, a in ipairs(state.asteroids) do
        a.rotation = a.rotation + a.rotSpeed * dt
    end
end

-- ============================================================================
-- 拾取物（资源）
-- ============================================================================
function World.updatePickups(state, Core, dt)
    local p = state.player
    local baseRange = 80
    if Systems.hasRelic(state, "r_magnet") then baseRange = 160 end
    -- P13.3: r_resource_magnet - 资源拾取范围翻倍
    if Systems.hasRelic(state, "r_resource_magnet") then baseRange = baseRange * 2 end
    local magnetRange = Core.hasPowerup(state, "magnet") and (baseRange * 3) or baseRange

    for i = #state.pickups, 1, -1 do
        local pk = state.pickups[i]
        pk.life = pk.life - dt
        local d = dist(pk.x, pk.y, p.x, p.y)
        if d < magnetRange then
            local pull = math.min(400, 200 / math.max(d, 1)) * dt
            local ang = angleToward(pk.x, pk.y, p.x, p.y)
            pk.x = pk.x + math.cos(ang) * pull * 60
            pk.y = pk.y + math.sin(ang) * pull * 60
        end
        if d < 20 then
            if pk.kind == "metal" then state.resources.metal = state.resources.metal + pk.amount end
            if pk.kind == "energy" then state.resources.energy = state.resources.energy + pk.amount end
            if pk.kind == "blueprint" then state.resources.blueprint = state.resources.blueprint + pk.amount end
            if pk.kind == "ancient_key" then state.resources.ancient_key = state.resources.ancient_key + pk.amount end
            if state.totalCollected[pk.kind] then
                state.totalCollected[pk.kind] = state.totalCollected[pk.kind] + pk.amount
            end
            local pickColor = { 180, 180, 220 }
            local pickName = "+" .. pk.amount .. " 金属"
            if pk.kind == "energy" then pickColor = { 100, 255, 100 }; pickName = "+" .. pk.amount .. " 能量" end
            if pk.kind == "blueprint" then pickColor = { 200, 150, 255 }; pickName = "+" .. pk.amount .. " 图纸" end
            if pk.kind == "ancient_key" then pickColor = { 255, 215, 0 }; pickName = "+" .. pk.amount .. " 密钥" end
            Core.addFloatingText(state, pk.x, pk.y - 10, pickName, pickColor)
            Core.addCollectAnim(state, pk.x, pk.y, pickColor)
            Audio.playPickup()
            table.remove(state.pickups, i)
        elseif pk.life <= 0 then
            table.remove(state.pickups, i)
        end
    end
end

-- ============================================================================
-- 遗物掉落实体
-- ============================================================================
function World.updateRelicDrops(state, Core, dt)
    local p = state.player
    local drops = state.relicDrops
    if not drops then return end

    for i = #drops, 1, -1 do
        local drop = drops[i]
        drop.life = drop.life - dt
        drop.spawnTime = drop.spawnTime + dt

        -- 弹出动画
        if drop.spawnTime < 0.3 then
            drop.y = drop.y - 120 * dt * (1 - drop.spawnTime / 0.3)
        end

        -- 玩家吸引
        local d = dist(drop.x, drop.y, p.x, p.y)
        if d < 120 then
            local pull = math.min(600, 300 / math.max(d, 1)) * dt
            local ang = angleToward(drop.x, drop.y, p.x, p.y)
            drop.x = drop.x + math.cos(ang) * pull * 60
            drop.y = drop.y + math.sin(ang) * pull * 60
            d = dist(drop.x, drop.y, p.x, p.y)
        end

        if d < 25 then
            -- 装备遗物
            local equipped = Systems.equipRelic(state, drop.relicId)
            if equipped then
                local relic = Systems.getRelicDef(drop.relicId)
                Core.addToast(state, "获得遗物: " .. (relic and relic.name or drop.relicId), { 255, 200, 50 })
                Core.addFloatingText(state, drop.x, drop.y - 10, "遗物!", { 255, 200, 50 }, 1.3)
                Core.spawnParticles(state, drop.x, drop.y, { 255, 200, 50 }, 12)
                Audio.playPickup()
            end
            table.remove(drops, i)
        elseif drop.life <= 0 then
            table.remove(drops, i)
        end
    end
end

-- ============================================================================
-- 粒子
-- ============================================================================
function World.updateParticles(state, dt)
    -- P10.3: 对远离相机视口的粒子加速消亡，减少无意义计算
    local camX, camY = state.cam.x, state.cam.y
    local cullDist = 1200  -- 超出此距离的粒子加速衰减

    for i = #state.particles, 1, -1 do
        local pt = state.particles[i]
        pt.x = pt.x + pt.vx * dt
        pt.y = pt.y + pt.vy * dt

        -- 超出视口距离的粒子加速3x消亡
        local dx, dy = pt.x - camX, pt.y - camY
        local d2 = dx * dx + dy * dy
        if d2 > cullDist * cullDist then
            pt.life = pt.life - dt * 3
        else
            pt.life = pt.life - dt
        end

        pt.alpha = math.max(0, pt.life / pt.maxLife)
        if pt.life <= 0 then table.remove(state.particles, i) end
    end
end

-- ============================================================================
-- 资源掉落
-- ============================================================================
function World.dropResources(state, x, y, metal, energy, blueprint, key)
    metal = metal or 0
    energy = energy or 0
    blueprint = blueprint or 0
    key = key or 0
    if metal > 0 then
        table.insert(state.pickups, { x = x + rand(-10, 10), y = y + rand(-10, 10), kind = "metal", amount = metal, life = 12 })
    end
    if energy > 0 then
        table.insert(state.pickups, { x = x + rand(-10, 10), y = y + rand(-10, 10), kind = "energy", amount = energy, life = 12 })
    end
    if blueprint > 0 then
        table.insert(state.pickups, { x = x + rand(-10, 10), y = y + rand(-10, 10), kind = "blueprint", amount = blueprint, life = 15 })
    end
    if key > 0 then
        table.insert(state.pickups, { x = x + rand(-10, 10), y = y + rand(-10, 10), kind = "ancient_key", amount = key, life = 20 })
    end
end

-- ============================================================================
-- 道具系统
-- ============================================================================
function World.spawnPowerup(state)
    local kinds = {}
    for k, _ in pairs(Data.POWERUP_TYPES) do kinds[#kinds + 1] = k end
    local kind = kinds[randInt(1, #kinds)]
    local p = state.player
    local ang = rand(0, TAU)
    local r = rand(200, 500)
    table.insert(state.powerups, {
        x = p.x + math.cos(ang) * r,
        y = p.y + math.sin(ang) * r,
        kind = kind,
        life = 20,
    })
end

function World.updatePowerups(state, Core, dt)
    local p = state.player
    local magnetActive = false
    for _, ap in ipairs(state.activePowerups) do
        if ap.kind == "magnet" then magnetActive = true; break end
    end
    local pickRange = magnetActive and 60 or 24

    for i = #state.powerups, 1, -1 do
        local pw = state.powerups[i]
        pw.life = pw.life - dt
        local d = dist(pw.x, pw.y, p.x, p.y)
        if magnetActive and d < 200 then
            local ang = angleToward(pw.x, pw.y, p.x, p.y)
            pw.x = pw.x + math.cos(ang) * 300 * dt
            pw.y = pw.y + math.sin(ang) * 300 * dt
        end
        if d < pickRange then
            World.activatePowerup(state, Core, pw.kind)
            table.remove(state.powerups, i)
        elseif pw.life <= 0 then
            table.remove(state.powerups, i)
        end
    end
end

function World.activatePowerup(state, Core, kind)
    local def = Data.POWERUP_TYPES[kind]
    if not def then return end
    for _, ap in ipairs(state.activePowerups) do
        if ap.kind == kind then
            ap.remaining = def.duration
            Core.addToast(state, def.name .. " 续期!", def.color)
            return
        end
    end
    table.insert(state.activePowerups, {
        kind = kind,
        remaining = def.duration,
        duration = def.duration,
    })
    Core.addToast(state, def.icon .. " " .. def.name .. " 激活!", def.color)
    Core.addFloatingText(state, state.player.x, state.player.y - 30, def.name, def.color, 1.2)
end

function World.updateActivePowerups(state, Core, dt)
    for i = #state.activePowerups, 1, -1 do
        local ap = state.activePowerups[i]
        ap.remaining = ap.remaining - dt
        if ap.remaining <= 0 then
            local def = Data.POWERUP_TYPES[ap.kind]
            Core.addToast(state, (def and def.name or ap.kind) .. " 已结束", { 180, 180, 180 })
            table.remove(state.activePowerups, i)
        end
    end
end

-- ============================================================================
-- 波次系统
-- ============================================================================
function World.updateWave(state, Core, dt)
    for _, wave in ipairs(Data.WAVES) do
        if state.day >= wave.day and not state.wavesTriggered[wave.day] then
            state.wavesTriggered[wave.day] = true
            state.waveActive = true
            state.waveTimer = 3.0
            state.waveName = wave.name
            state.pendingWave = wave
            Core.addToast(state, "⚠ 警告: " .. wave.name .. " 来袭!", { 255, 80, 80 })
            Core.shake(state, 5, 0.4)
            break
        end
    end
    if state.waveActive and state.pendingWave then
        state.waveTimer = state.waveTimer - dt
        if state.waveTimer <= 0 then
            local wave = state.pendingWave
            for kind, count in pairs(wave.enemies) do
                for i = 1, count do
                    Core.spawnEnemy(state, kind, "middle")
                end
            end
            state.pendingWave = nil
            state.waveActive = false
            Core.addToast(state, wave.name .. " 已抵达!", { 255, 160, 0 })
        end
    end
end

-- ============================================================================
-- 随机事件系统
-- ============================================================================
function World.updateEvent(state, Core, dt)
    if state.eventChoice then
        state.eventChoiceAnim = math.min(1, state.eventChoiceAnim + dt * 3)
        return
    end
    if state.activeEvent then
        state.eventRemaining = state.eventRemaining - dt
        if state.eventRemaining <= 0 then
            Core.addToast(state, state.activeEvent.name .. " 已结束", { 180, 180, 180 })
            state.activeEvent = nil
            state.eventRemaining = 0
        end
        return
    end
    state.eventTimer = state.eventTimer - dt
    if state.eventTimer <= 0 then
        state.eventTimer = rand(25, 45)
        World.triggerEventChoice(state, Core)
    end
end

function World.triggerEventChoice(state, Core)
    -- P7.3: 15%概率触发特殊事件（天数>10后提高到25%）
    local specialChance = state.day > 10 and 0.25 or 0.15
    if math.random() < specialChance and #Data.SPECIAL_EVENTS > 0 then
        local ev = Data.SPECIAL_EVENTS[randInt(1, #Data.SPECIAL_EVENTS)]
        state.eventChoice = ev
        state.eventChoiceAnim = 0
        state.eventIsSpecial = true
        Core.shake(state, 5, 0.4)
        Core.addToast(state, "⚡ 特殊事件!", ev.color or { 255, 200, 0 })
    else
        local choices = Data.EVENT_CHOICES
        local ev = choices[randInt(1, #choices)]
        state.eventChoice = ev
        state.eventChoiceAnim = 0
        state.eventIsSpecial = false
        Core.shake(state, 3, 0.2)
    end
end

function World.selectEventChoice(state, Core, index)
    if not state.eventChoice then return end
    local option = state.eventChoice.options[index]
    if not option then return end
    World.applyEventEffect(state, Core, option.effect)
    Core.addToast(state, "✓ " .. option.label .. ": " .. option.desc, { 0, 220, 180 })
    state.eventChoice = nil
    state.eventChoiceAnim = 0
end

function World.applyEventEffect(state, Core, effect)
    local p = state.player
    if effect == "supply_heal" then
        p.hp = math.min(p.hpMax, p.hp + math.floor(p.hpMax * 0.4))
        for i = 1, 4 do
            local ang = rand(0, TAU)
            local r = rand(60, 180)
            local kinds = { "metal", "energy", "blueprint" }
            table.insert(state.pickups, {
                x = p.x + math.cos(ang) * r, y = p.y + math.sin(ang) * r,
                kind = kinds[randInt(1, 3)], amount = randInt(3, 8), life = 15,
            })
        end
        Core.addFloatingText(state, p.x, p.y - 20, "+修复", { 0, 255, 150 }, 1.2)
    elseif effect == "temp_shield" then
        table.insert(state.activePowerups, { kind = "invincible", remaining = 6 })
        Core.addFloatingText(state, p.x, p.y - 20, "无敌护盾!", { 255, 220, 50 }, 1.2)
    elseif effect == "emp" then
        state.activeEvent = { name = "EMP脉冲", effect = "emp", color = { 80, 200, 255 } }
        state.eventRemaining = 5
        Core.shake(state, 6, 0.4)
    elseif effect == "storm" then
        state.activeEvent = { name = "太阳风暴", effect = "storm", color = { 255, 160, 0 } }
        state.eventRemaining = 15
        Core.shake(state, 8, 0.5)
        Core.addFloatingText(state, p.x, p.y - 20, "太阳风暴!", { 255, 160, 0 }, 1.8)
    elseif effect == "speed_boost" then
        table.insert(state.activePowerups, { kind = "speed_boost", remaining = 8 })
    elseif effect == "blueprint_drop" then
        for i = 1, 3 do
            local ang = rand(0, TAU)
            local r = rand(40, 120)
            table.insert(state.pickups, {
                x = p.x + math.cos(ang) * r, y = p.y + math.sin(ang) * r,
                kind = "blueprint", amount = 1, life = 15,
            })
        end
    elseif effect == "shield_full" then
        p.shield = p.shieldMax
        table.insert(state.activePowerups, { kind = "invincible", remaining = 2 })
        Core.addFloatingText(state, p.x, p.y - 20, "护盾全充!", { 80, 200, 255 }, 1.2)
    elseif effect == "loot_drop" then
        for i = 1, 8 do
            local ang = rand(0, TAU)
            local r = rand(50, 200)
            local kinds = { "metal", "metal", "energy", "energy" }
            table.insert(state.pickups, {
                x = p.x + math.cos(ang) * r, y = p.y + math.sin(ang) * r,
                kind = kinds[randInt(1, 4)], amount = randInt(5, 12), life = 15,
            })
        end
    elseif effect == "fire_rate" then
        table.insert(state.activePowerups, { kind = "fire_rate", remaining = 6 })
    elseif effect == "dmg_boost" then
        table.insert(state.activePowerups, { kind = "dmg_boost", remaining = 8 })
    elseif effect == "invincible" then
        table.insert(state.activePowerups, { kind = "invincible", remaining = 5 })
    -- P7.3 特殊事件效果
    elseif effect == "time_slow" then
        state.timeScale = 0.3
        state.timeSlowRemaining = 5.0
        Core.addFloatingText(state, p.x, p.y - 20, "时间扭曲!", { 0, 200, 255 }, 1.5)
        Core.shake(state, 8, 0.5)
    elseif effect == "cd_reset" then
        state.fireCd = 0
        state.missileCd = 0
        state.laserCd = 0
        state.secondaryCd = 0
        table.insert(state.activePowerups, { kind = "fire_rate", remaining = 5 })
        table.insert(state.activePowerups, { kind = "dmg_boost", remaining = 5 })
        Core.addFloatingText(state, p.x, p.y - 20, "武器超载!", { 255, 100, 0 }, 1.5)
    elseif effect == "storm_damage" then
        -- 对所有可见敌人造成50伤害
        for _, e in ipairs(state.enemies) do
            e.hp = e.hp - 50
            Core.addFloatingText(state, e.x, e.y - 10, "-50", { 255, 120, 0 }, 0.8)
        end
        Core.shake(state, 10, 0.6)
        Core.addFloatingText(state, p.x, p.y - 20, "风暴打击!", { 255, 160, 0 }, 1.5)
    elseif effect == "storm_shield" then
        p.shield = p.shieldMax
        table.insert(state.activePowerups, { kind = "reflect", remaining = 10 })
        Core.addFloatingText(state, p.x, p.y - 20, "反弹护盾!", { 255, 180, 0 }, 1.5)
    elseif effect == "buy_weapon" then
        if state.resources.metal >= 20 then
            state.resources.metal = state.resources.metal - 20
            table.insert(state.activePowerups, { kind = "dmg_boost", remaining = 15 })
            table.insert(state.activePowerups, { kind = "fire_rate", remaining = 15 })
            Core.addFloatingText(state, p.x, p.y - 20, "武器强化!", { 255, 220, 50 }, 1.5)
        else
            Core.addToast(state, "金属不足！需要20", { 255, 80, 80 })
        end
    elseif effect == "sell_energy" then
        if state.resources.energy >= 15 then
            state.resources.energy = state.resources.energy - 15
            state.resources.blueprint = state.resources.blueprint + 8
            Core.addFloatingText(state, p.x, p.y - 20, "+8图纸", { 200, 150, 255 }, 1.5)
        else
            Core.addToast(state, "能量不足！需要15", { 255, 80, 80 })
        end
    elseif effect == "wormhole_jump" then
        -- 随机传送到新位置 + 大量资源
        p.x = rand(-800, 800)
        p.y = rand(-800, 800)
        for i = 1, 6 do
            local ang = rand(0, TAU)
            local r = rand(40, 150)
            local kinds = { "metal", "energy", "blueprint" }
            table.insert(state.pickups, {
                x = p.x + math.cos(ang) * r, y = p.y + math.sin(ang) * r,
                kind = kinds[randInt(1, 3)], amount = randInt(8, 15), life = 15,
            })
        end
        Core.shake(state, 12, 0.8)
        Core.addFloatingText(state, p.x, p.y - 20, "虫洞跃迁!", { 180, 0, 255 }, 1.8)
    elseif effect == "wormhole_allies" then
        -- 召唤3个友军
        for i = 1, 3 do
            local ang = rand(0, TAU)
            local r = rand(80, 180)
            table.insert(state.allies, {
                x = p.x + math.cos(ang) * r, y = p.y + math.sin(ang) * r,
                hp = 80, hpMax = 80, life = 20,
                speed = 120, fireCd = 0, fireInterval = 0.8,
                dmg = 12, color = { 100, 0, 255 },
            })
        end
        Core.addFloatingText(state, p.x, p.y - 20, "友军增援!", { 100, 0, 255 }, 1.5)
    -- P13.4 新增事件效果
    elseif effect == "rescue_ship" then
        if state.resources.energy >= 30 then
            state.resources.energy = state.resources.energy - 30
            -- 掉落一个随机未拥有的遗物
            local available = {}
            for _, r in ipairs(Systems.RELICS) do
                if not Systems.hasRelic(state, r.id) then
                    table.insert(available, r.id)
                end
            end
            if #available > 0 then
                local chosen = available[math.random(1, #available)]
                state.relicDrops = state.relicDrops or {}
                table.insert(state.relicDrops, {
                    x = p.x, y = p.y,
                    relicId = chosen,
                    def = Systems.getRelicDef(chosen),
                    life = 30,
                    spawnTime = 0,
                    bobPhase = rand(0, TAU),
                })
                Core.addFloatingText(state, p.x, p.y - 20, "救援成功!", { 0, 200, 100 }, 1.5)
            else
                Core.addFloatingText(state, p.x, p.y - 20, "遗物已满!", { 200, 200, 100 }, 1.2)
                state.resources.energy = state.resources.energy + 30
            end
        else
            Core.addToast(state, "能量不足！需要30", { 255, 80, 80 })
        end
    elseif effect == "ignore_rescue" then
        state.resources.metal = state.resources.metal + 10
        Core.addFloatingText(state, p.x, p.y - 20, "+10金属", { 200, 180, 100 }, 1.2)
    elseif effect == "meteor_safe" then
        -- 安全区域：10秒无敌
        table.insert(state.activePowerups, { kind = "invincible", remaining = 10 })
        Core.addFloatingText(state, p.x, p.y - 20, "进入安全区!", { 255, 200, 100 }, 1.2)
    elseif effect == "meteor_risk" then
        -- 穿过陨石雨获得大量资源
        for i = 1, 10 do
            local ang = rand(0, TAU)
            local r = rand(40, 120)
            local kinds = { "metal", "metal", "energy", "energy", "blueprint" }
            table.insert(state.pickups, {
                x = p.x + math.cos(ang) * r, y = p.y + math.sin(ang) * r,
                kind = kinds[randInt(1, 5)], amount = randInt(6, 12), life = 15,
            })
        end
        Core.addFloatingText(state, p.x, p.y - 20, "穿越成功!", { 255, 150, 50 }, 1.5)
    elseif effect == "portal_jump" then
        -- 传送到中继站附近
        p.x = rand(-300, 300)
        p.y = rand(-300, 300)
        Core.addFloatingText(state, p.x, p.y - 20, "传送完成!", { 100, 200, 255 }, 1.5)
        Core.shake(state, 6, 0.4)
    elseif effect == "portal_charge" then
        if state.resources.energy >= 20 then
            state.resources.energy = state.resources.energy - 20
            p.shieldMax = p.shieldMax * 1.5
            p.shield = p.shieldMax
            table.insert(state.activePowerups, { kind = "shield_boost", remaining = 20 })
            Core.addFloatingText(state, p.x, p.y - 20, "护盾充能!", { 100, 200, 255 }, 1.5)
        else
            Core.addToast(state, "能量不足！需要20", { 255, 80, 80 })
        end
    elseif effect == "virus_quarantine" then
        -- 禁用一项随机科技10秒
        local techs = { "dmg", "hp", "shield", "fireRate", "splitShot", "pierce", "laser", "missile" }
        local disabled = techs[math.random(1, #techs)]
        state.virusDisabledTech = disabled
        state.virusDisabledTimer = 10
        Core.addFloatingText(state, p.x, p.y - 20, "系统隔离!", { 150, 50, 100 }, 1.2)
    elseif effect == "virus_reset" then
        if state.resources.energy >= 15 then
            state.resources.energy = state.resources.energy - 15
            state.virusDisabledTech = nil
            state.virusDisabledTimer = 0
            Core.addFloatingText(state, p.x, p.y - 20, "病毒清除!", { 50, 150, 100 }, 1.2)
        else
            Core.addToast(state, "能量不足！需要15", { 255, 80, 80 })
        end
    end
end

-- ============================================================================
-- 劫持 & 友军系统
-- ============================================================================
function World.attemptHijack(state, Core)
    if state.hijackCd > 0 then
        Core.addToast(state, string.format("劫持冷却中(%.0fs)", state.hijackCd), { 200, 200, 200 })
        return false
    end
    local p = state.player
    local bestIdx, bestDist = nil, 150
    for i, e in ipairs(state.enemies) do
        if not e.isBoss then
            local d = dist(p.x, p.y, e.x, e.y)
            if d < bestDist then
                bestDist = d
                bestIdx = i
            end
        end
    end
    if not bestIdx then
        Core.addToast(state, "范围内无可劫持目标", { 200, 200, 200 })
        return false
    end
    local e = state.enemies[bestIdx]
    table.insert(state.allies, {
        x = e.x, y = e.y,
        vx = e.vx, vy = e.vy,
        angle = e.angle,
        hp = e.hp, hpMax = e.hpMax,
        cfg = e.cfg,
        fireCd = 0,
        lifespan = 20,
    })
    table.remove(state.enemies, bestIdx)
    state.hijackCd = 12
    Core.addToast(state, "✓ 劫持成功: " .. (e.cfg.name or e.kind), { 0, 255, 200 })
    Core.addFloatingText(state, e.x, e.y, "HACKED!", { 0, 255, 200 }, 1.4)
    Core.spawnParticles(state, e.x, e.y, { 0, 255, 200 }, 10)
    return true
end

function World.updateAllies(state, Core, dt)
    local p = state.player
    local mode = state.allyMode or "attack"
    for i = #state.allies, 1, -1 do
        local ally = state.allies[i]
        ally.lifespan = ally.lifespan - dt
        if ally.lifespan <= 0 then
            Core.spawnParticles(state, ally.x, ally.y, { 100, 200, 255 }, 6)
            Core.addFloatingText(state, ally.x, ally.y, "链接断开", { 180, 180, 180 })
            table.remove(state.allies, i)
        else
            if mode == "follow" then
                local followDist = 60 + i * 30
                local followAngle = p.angle + math.pi + (i - 1) * 0.4 - (#state.allies - 1) * 0.2
                local tx = p.x + math.cos(followAngle) * followDist
                local ty = p.y + math.sin(followAngle) * followDist
                local toTarget = angleToward(ally.x, ally.y, tx, ty)
                local dTarget = dist(ally.x, ally.y, tx, ty)
                local spd = math.min(dTarget * 3, 300)
                ally.vx = lerp(ally.vx, math.cos(toTarget) * spd, dt * 5)
                ally.vy = lerp(ally.vy, math.sin(toTarget) * spd, dt * 5)
                ally.angle = p.angle
                local bestEnemy, bestD = nil, 120
                for _, e in ipairs(state.enemies) do
                    local d2 = dist(ally.x, ally.y, e.x, e.y)
                    if d2 < bestD then bestD = d2; bestEnemy = e end
                end
                if bestEnemy then
                    ally.fireCd = ally.fireCd - dt
                    if ally.fireCd <= 0 then
                        ally.fireCd = (ally.cfg.fire or 1.0) * 1.5
                        local toE = angleToward(ally.x, ally.y, bestEnemy.x, bestEnemy.y)
                        table.insert(state.bullets, {
                            x = ally.x, y = ally.y,
                            vx = math.cos(toE) * 400, vy = math.sin(toE) * 400,
                            life = 1.0, dmg = math.floor((ally.cfg.dmg or 8) * 0.5),
                            pierce = 0, color = { 0, 220, 200 }, isAlly = true,
                        })
                    end
                end
            elseif mode == "guard" then
                local orbitAngle = (state.dayTimer * 1.5) + (i - 1) * (TAU / math.max(#state.allies, 1))
                local orbitR = 70
                local tx = p.x + math.cos(orbitAngle) * orbitR
                local ty = p.y + math.sin(orbitAngle) * orbitR
                ally.vx = lerp(ally.vx, (tx - ally.x) * 5, dt * 8)
                ally.vy = lerp(ally.vy, (ty - ally.y) * 5, dt * 8)
                ally.angle = orbitAngle + math.pi * 0.5
                local bestEnemy, bestD = nil, 160
                for _, e in ipairs(state.enemies) do
                    local d2 = dist(p.x, p.y, e.x, e.y)
                    if d2 < bestD then bestD = d2; bestEnemy = e end
                end
                if bestEnemy then
                    ally.fireCd = ally.fireCd - dt
                    if ally.fireCd <= 0 then
                        ally.fireCd = (ally.cfg.fire or 1.0) * 0.8
                        local toE = angleToward(ally.x, ally.y, bestEnemy.x, bestEnemy.y)
                        table.insert(state.bullets, {
                            x = ally.x, y = ally.y,
                            vx = math.cos(toE) * 450, vy = math.sin(toE) * 450,
                            life = 0.8, dmg = math.floor((ally.cfg.dmg or 8) * 0.9),
                            pierce = 0, color = { 0, 220, 200 }, isAlly = true,
                        })
                    end
                end
            else
                -- attack 模式
                local bestEnemy, bestD = nil, 300
                for _, e in ipairs(state.enemies) do
                    local d2 = dist(ally.x, ally.y, e.x, e.y)
                    if d2 < bestD then bestD = d2; bestEnemy = e end
                end
                if bestEnemy then
                    local toE = angleToward(ally.x, ally.y, bestEnemy.x, bestEnemy.y)
                    ally.angle = toE
                    local spd = (ally.cfg.speed or 80) * 0.8
                    ally.vx = ally.vx + math.cos(toE) * spd * dt * 2
                    ally.vy = ally.vy + math.sin(toE) * spd * dt * 2
                    ally.fireCd = ally.fireCd - dt
                    if ally.fireCd <= 0 and bestD < (ally.cfg.range or 250) then
                        ally.fireCd = (ally.cfg.fire or 1.0) * 1.2
                        table.insert(state.bullets, {
                            x = ally.x, y = ally.y,
                            vx = math.cos(toE) * 400, vy = math.sin(toE) * 400,
                            life = 1.2, dmg = math.floor((ally.cfg.dmg or 8) * 0.7),
                            pierce = 0, color = { 0, 220, 200 }, isAlly = true,
                        })
                    end
                end
            end
            -- 移动
            ally.vx = ally.vx * (1 - dt * 3)
            ally.vy = ally.vy * (1 - dt * 3)
            ally.x = ally.x + ally.vx * dt
            ally.y = ally.y + ally.vy * dt
        end
    end
end

function World.cycleAllyMode(state, Core)
    local modes = { "attack", "follow", "guard" }
    local modeNames = { attack = "进攻", follow = "跟随", guard = "护卫" }
    for i, m in ipairs(modes) do
        if m == state.allyMode then
            state.allyMode = modes[(i % #modes) + 1]
            Core.addToast(state, "盟友模式: " .. modeNames[state.allyMode], { 0, 220, 200 })
            return
        end
    end
    state.allyMode = "attack"
end

-- ============================================================================
-- 科技 & 建造
-- ============================================================================
function World.unlockTech(state, Core)
    -- 由 Core 代理调用，保持原签名兼容
end

function World.buildRelay(state, Core)
    if state.relayCount >= 3 then
        Core.addToast(state, "中继站已达上限", { 255, 200, 100 })
        return false
    end
    local discount = 1 - (state.tradeDiscount or 0)
    local metalCost = math.floor(20 * discount)
    local energyCost = math.floor(15 * discount)
    if state.resources.metal < metalCost or state.resources.energy < energyCost then
        Core.addToast(state, string.format("资源不足(需%d金属+%d能源)", metalCost, energyCost), { 255, 100, 100 })
        return false
    end
    state.resources.metal = state.resources.metal - metalCost
    state.resources.energy = state.resources.energy - energyCost
    state.relayCount = state.relayCount + 1
    table.insert(state.relayStations, { x = state.player.x, y = state.player.y })
    Core.addToast(state, "数据中继站已建造!", { 0, 255, 200 })
    return true
end

-- ============================================================================
-- 任务
-- ============================================================================
function World.checkQuests(state, Core)
    local completed = {}
    local ctx = {
        resources = state.resources,
        bossesKilled = state.bossesKilled,
        relayCount = state.relayCount,
        aiCoreLevel = state.stats.aiCoreLevel,
    }
    for _, q in ipairs(Data.QUESTS) do
        local alreadyDone = false
        for _, cid in ipairs(state.completedQuests) do
            if cid == q.id then alreadyDone = true; break end
        end
        if not alreadyDone and state.day >= q.days[1] and q.check(ctx) then
            table.insert(state.completedQuests, q.id)
            for k, v in pairs(q.reward) do
                if k == "score" then
                    state.score = state.score + v
                else
                    state.resources[k] = (state.resources[k] or 0) + v
                end
            end
            Core.addToast(state, "任务完成: " .. q.name, { 255, 215, 0 })
            table.insert(completed, q)
        end
    end
    return completed
end

function World.getActiveQuests(state)
    local active = {}
    for _, q in ipairs(Data.QUESTS) do
        local alreadyDone = false
        for _, cid in ipairs(state.completedQuests) do
            if cid == q.id then alreadyDone = true; break end
        end
        if not alreadyDone and state.day >= q.days[1] then
            table.insert(active, q)
        end
    end
    return active
end

-- ============================================================================
-- 收集动画
-- ============================================================================
function World.updateCollectAnims(state, dt)
    for i = #state.collectAnims, 1, -1 do
        local a = state.collectAnims[i]
        a.timer = a.timer - dt
        if a.timer <= 0 then table.remove(state.collectAnims, i) end
    end
end

function World.addCollectAnim(state, x, y, color)
    table.insert(state.collectAnims, { x = x, y = y, timer = 0.5, maxTime = 0.5, color = color })
end

-- ============================================================================
-- 教程（P10: 扩展为8步）
-- ============================================================================
function World.updateTutorial(state, dt)
    if state.tutorialStep >= 99 then return end
    state.tutorialTimer = state.tutorialTimer + dt
    if state.tutorialStep == 0 and state.tutorialTimer > 1.0 then
        state.tutorialStep = 1
        state.tutorialTimer = 0
    elseif state.tutorialStep == 1 then
        -- 移动飞船
        local p = state.player
        if math.abs(p.vx) > 30 or math.abs(p.vy) > 30 then
            state.tutorialStep = 2
            state.tutorialTimer = 0
        end
    elseif state.tutorialStep == 2 then
        -- 射击敌人
        if state.totalKills > 0 or state.tutorialTimer > 8 then
            state.tutorialStep = 3
            state.tutorialTimer = 0
        end
    elseif state.tutorialStep == 3 then
        -- 收集资源
        if (state.resources.metal > 0 or state.resources.energy > 0) or state.tutorialTimer > 10 then
            state.tutorialStep = 4
            state.tutorialTimer = 0
        end
    elseif state.tutorialStep == 4 then
        -- 科技树
        if #state.ownedTech > 1 or state.tutorialTimer > 8 then
            state.tutorialStep = 5
            state.tutorialTimer = 0
        end
    elseif state.tutorialStep == 5 then
        -- 护盾能量
        if state.player.shield < (state.player.shieldMax or 0) * 0.9 or state.tutorialTimer > 8 then
            state.tutorialStep = 6
            state.tutorialTimer = 0
        end
    elseif state.tutorialStep == 6 then
        -- 连击系统
        if (Systems.combo.count or 0) >= 2 or state.tutorialTimer > 10 then
            state.tutorialStep = 7
            state.tutorialTimer = 0
        end
    elseif state.tutorialStep == 7 then
        -- 技能武器
        if state.laser.active or #(state.missiles or {}) > 0 or state.tutorialTimer > 10 then
            state.tutorialStep = 8
            state.tutorialTimer = 0
        end
    elseif state.tutorialStep == 8 then
        -- 最终提示
        if state.tutorialTimer > 5 then
            state.tutorialStep = 99
        end
    end
end

-- ============================================================================
return World
