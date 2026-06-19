-- ============================================================================
-- 星海征途 - 世界实体渲染（星空/玩家/敌人/子弹/小行星/拾取物/中继站等）
-- ============================================================================
local Data = require("game.Data")
local Sprites = require("game.Sprites")
local Systems = require("game.Systems")
local RU = require("game.RenderUtils")

local C = RU.C
local rgba = RU.rgba
local worldToScreen = RU.worldToScreen
local TAU = RU.TAU
local WORLD = Data.WORLD

local M = {}

-- ============================================================================
-- 绘制星空背景（三层视差）
-- ============================================================================
function M.drawStars(vg, state, sw, sh)
    local cam = state.cam

    -- Phase B: 根据当前区域绘制背景色
    local bg = { 10, 12, 20 }
    if state and state.currentZone and state.currentZone.bgTint then
        bg = state.currentZone.bgTint
    elseif state and state.currentZoneId and Data.getZone then
        local z = Data.getZone(state.currentZoneId)
        if z and z.bgTint then bg = z.bgTint end
    end
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillColor(vg, nvgRGBA(bg[1], bg[2], bg[3], 255))
    nvgFill(vg)

    -- 第0层：space_bg 贴图铺底（缓慢视差，像远处恒星场）
    local bgImg = Sprites.images["space_bg"]
    if bgImg then
        local parallax0 = 0.02
        local bgOX = -(cam.x * parallax0) % sw
        local bgOY = -(cam.y * parallax0) % sh
        for dx = -1, 1 do
            for dy = -1, 1 do
                local px = bgOX + dx * sw
                local py = bgOY + dy * sh
                if px > -sw and px < sw * 2 and py > -sh and py < sh * 2 then
                    nvgBeginPath(vg)
                    nvgRect(vg, px, py, sw, sh)
                    local paint = nvgImagePattern(vg, px, py, sw, sh, 0, bgImg, 0.6)
                    nvgFillPaint(vg, paint)
                    nvgFill(vg)
                end
            end
        end
    end

    -- 第1层：星云团（中速视差，半透明装饰渐变）
    local t = (state.dayTimer or 0) * 0.02
    local nebulae = {
        { ox = 400, oy = -300, r = 280, color = { 40, 10, 80 }, alpha = 22 },
        { ox = -600, oy = 500, r = 350, color = { 10, 30, 60 }, alpha = 16 },
        { ox = 200, oy = 800, r = 220, color = { 60, 15, 30 }, alpha = 18 },
        { ox = -300, oy = -700, r = 300, color = { 15, 40, 50 }, alpha = 14 },
        { ox = 900, oy = 200, r = 260, color = { 20, 8, 50 }, alpha = 15 },
    }
    local parallax1 = 0.15
    for _, neb in ipairs(nebulae) do
        local nx = neb.ox + math.sin(t + neb.ox * 0.001) * 50
        local ny = neb.oy + math.cos(t + neb.oy * 0.001) * 40
        local sx = (nx - cam.x * parallax1) + sw * 0.5
        local sy = (ny - cam.y * parallax1) + sh * 0.5
        if sx > -neb.r and sx < sw + neb.r and sy > -neb.r and sy < sh + neb.r then
            local paint = nvgRadialGradient(vg, sx, sy, neb.r * 0.2, neb.r,
                nvgRGBA(neb.color[1], neb.color[2], neb.color[3], neb.alpha),
                nvgRGBA(neb.color[1], neb.color[2], neb.color[3], 0))
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, neb.r)
            nvgFillPaint(vg, paint)
            nvgFill(vg)
        end
    end

    -- 第2层：近景星星（三层视差）
    for _, star in ipairs(state.stars) do
        local p = 0.3 + star.layer * 0.25
        local sx = ((star.x - cam.x * p) % sw + sw) % sw
        local sy = ((star.y - cam.y * p) % sh + sh) % sh
        local alpha = math.floor(star.brightness * 255)
        if star.size > 1.8 then
            local glow = star.size * 3
            local ga = math.floor(alpha * 0.3)
            nvgBeginPath(vg)
            nvgRect(vg, sx - glow, sy - 0.5, glow * 2, 1)
            nvgFillColor(vg, nvgRGBA(200, 220, 255, ga))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRect(vg, sx - 0.5, sy - glow, 1, glow * 2)
            nvgFillColor(vg, nvgRGBA(200, 220, 255, ga))
            nvgFill(vg)
        end
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, star.size)
        nvgFillColor(vg, nvgRGBA(200, 210, 255, alpha))
        nvgFill(vg)
    end
end

-- ============================================================================
-- 绘制世界环形边界（含发光外晕）
-- ============================================================================
function M.drawWorldRings(vg, state, sw, sh)
    local cam = state.cam
    local cx, cy = worldToScreen(0, 0, cam, sw, sh)

    local glowW = 30
    local paintInner = nvgRadialGradient(vg, cx, cy,
        WORLD.innerR - glowW, WORLD.innerR + glowW,
        nvgRGBA(255, 40, 40, 12), nvgRGBA(255, 40, 40, 0))
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, WORLD.innerR + glowW)
    nvgFillPaint(vg, paintInner)
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, WORLD.innerR)
    nvgStrokeColor(vg, rgba(C.innerRing))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    local paintMiddle = nvgRadialGradient(vg, cx, cy,
        WORLD.middleR - glowW, WORLD.middleR + glowW,
        nvgRGBA(255, 160, 0, 8), nvgRGBA(255, 160, 0, 0))
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, WORLD.middleR + glowW)
    nvgFillPaint(vg, paintMiddle)
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, WORLD.middleR)
    nvgStrokeColor(vg, rgba(C.middleRing))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    local paintOuter = nvgRadialGradient(vg, cx, cy,
        WORLD.outerR - glowW, WORLD.outerR + glowW,
        nvgRGBA(40, 150, 255, 6), nvgRGBA(40, 150, 255, 0))
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, WORLD.outerR + glowW)
    nvgFillPaint(vg, paintOuter)
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, WORLD.outerR)
    nvgStrokeColor(vg, rgba(C.outerRing))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    local labelY = cy - WORLD.innerR - 14
    if labelY > 0 and labelY < sh then
        nvgFillColor(vg, nvgRGBA(255, 80, 80, 100))
        nvgText(vg, cx, labelY, "⚠ 核心深渊")
    end
    labelY = cy - WORLD.middleR - 14
    if labelY > 0 and labelY < sh then
        nvgFillColor(vg, nvgRGBA(255, 180, 0, 80))
        nvgText(vg, cx, labelY, "湍流区")
    end
    labelY = cy - WORLD.outerR - 14
    if labelY > 0 and labelY < sh then
        nvgFillColor(vg, nvgRGBA(80, 180, 255, 70))
        nvgText(vg, cx, labelY, "碎片浅滩")
    end
end

-- ============================================================================
-- 绘制玩家飞船
-- ============================================================================
function M.drawPlayer(vg, state, sw, sh)
    local p = state.player
    local sx, sy = worldToScreen(p.x, p.y, state.cam, sw, sh)
    if sx < -50 or sx > sw + 50 or sy < -50 or sy > sh + 50 then return end

    local size = 36
    if p.hitFlash > 0 then
        Sprites.drawTinted(vg, "player_ship", sx, sy, size, size,
            p.angle + math.pi / 2, nvgRGBA(255, 100, 100, 255))
    elseif state.shipColor then
        local sc = state.shipColor
        Sprites.drawTinted(vg, "player_ship", sx, sy, size, size,
            p.angle + math.pi / 2, nvgRGBA(sc[1], sc[2], sc[3], 255))
    else
        Sprites.draw(vg, "player_ship", sx, sy, size, size,
            p.angle + math.pi / 2, 1.0)
    end

    if p.shield > 0 then
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, 22)
        nvgStrokeColor(vg, rgba(C.shield))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
    end

    -- P7.4: r_slowfield 引力阱视觉效果
    if Systems.hasRelic(state, "r_slowfield") then
        local pulse = math.sin(state.time * 2.5) * 0.3 + 0.7
        local fieldR = 200 * (state.cam.scale or 1.0)
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, fieldR)
        nvgStrokeColor(vg, nvgRGBA(100, 0, 200, math.floor(25 * pulse)))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)
    end
end

-- ============================================================================
-- 绘制敌人
-- ============================================================================
function M.drawEnemies(vg, state, sw, sh)
    local cam = state.cam
    for _, e in ipairs(state.enemies) do
        local cloakAlpha = 1.0
        if e.cloaked then cloakAlpha = 0.15 end
        local sx, sy = worldToScreen(e.x, e.y, cam, sw, sh)
        if sx > -60 and sx < sw + 60 and sy > -60 and sy < sh + 60 then
            if e.isBoss then
                local r = e.radius or 30
                local size = r * 2.2
                Sprites.draw(vg, "boss_ship", sx, sy, size, size, 0, 1.0)
                nvgBeginPath(vg)
                nvgCircle(vg, sx, sy, r + 8)
                nvgStrokeColor(vg, rgba(C.boss, 60))
                nvgStrokeWidth(vg, 3)
                nvgStroke(vg)
            else
                local r = e.radius or 12
                local size = r * 2.2
                local spriteName = Sprites.enemyTypeMap[e.type] or "enemy_scout"
                Sprites.draw(vg, spriteName, sx, sy, size, size, 0, cloakAlpha)
            end

            if e.affix then
                local affixDef = nil
                for _, af in ipairs(Systems.AFFIXES) do
                    if af.id == e.affix then affixDef = af; break end
                end
                if affixDef then
                    local ac = affixDef.color or { 255, 200, 0 }
                    nvgBeginPath(vg)
                    nvgCircle(vg, sx, sy, (e.radius or 12) + 5)
                    nvgStrokeColor(vg, nvgRGBA(ac[1], ac[2], ac[3], 120))
                    nvgStrokeWidth(vg, 2)
                    nvgStroke(vg)
                    nvgFontFace(vg, "sans")
                    nvgFontSize(vg, 9)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
                    nvgFillColor(vg, nvgRGBA(ac[1], ac[2], ac[3], 200))
                    nvgText(vg, sx, sy - (e.radius or 12) - 12, affixDef.name)
                end
            end

            if e.isBoss and e.phase2Flash and e.phase2Flash > 0 then
                nvgBeginPath(vg)
                nvgCircle(vg, sx, sy, (e.radius or 30) + 12)
                nvgFillColor(vg, nvgRGBA(255, 80, 255, math.floor(e.phase2Flash * 180)))
                nvgFill(vg)
                e.phase2Flash = e.phase2Flash - 0.016
            end

            if e.hp < e.hpMax then
                local barW = (e.isBoss and 50 or 24)
                local ratio = e.hp / e.hpMax
                nvgBeginPath(vg)
                nvgRect(vg, sx - barW / 2, sy - (e.radius or 12) - 8, barW, 3)
                nvgFillColor(vg, nvgRGBA(40, 40, 40, 160))
                nvgFill(vg)
                nvgBeginPath(vg)
                nvgRect(vg, sx - barW / 2, sy - (e.radius or 12) - 8, barW * ratio, 3)
                nvgFillColor(vg, nvgRGBA(255, 60, 60, 220))
                nvgFill(vg)
            end
        end
    end
end

-- ============================================================================
-- 绘制子弹
-- ============================================================================
function M.drawBullets(vg, state, sw, sh)
    local cam = state.cam
    for _, b in ipairs(state.bullets) do
        local sx, sy = worldToScreen(b.x, b.y, cam, sw, sh)
        if sx > -10 and sx < sw + 10 and sy > -10 and sy < sh + 10 then
            local bc = b.color or { 0, 240, 255 }
            if b.pierce and b.pierce > 0 then
                local speed = math.sqrt(b.vx * b.vx + b.vy * b.vy)
                local dx = (speed > 0) and (b.vx / speed) or 0
                local dy = (speed > 0) and (b.vy / speed) or 0
                nvgBeginPath(vg)
                nvgMoveTo(vg, sx - dx * 10, sy - dy * 10)
                nvgLineTo(vg, sx + dx * 4, sy + dy * 4)
                nvgStrokeColor(vg, nvgRGBA(bc[1], bc[2], bc[3], 120))
                nvgStrokeWidth(vg, 3)
                nvgStroke(vg)
                nvgBeginPath(vg)
                nvgCircle(vg, sx, sy, 3.5)
                nvgFillColor(vg, nvgRGBA(bc[1], bc[2], bc[3], 255))
                nvgFill(vg)
                nvgBeginPath(vg)
                nvgCircle(vg, sx, sy, 6)
                nvgFillColor(vg, nvgRGBA(bc[1], bc[2], bc[3], 40))
                nvgFill(vg)
            elseif bc[1] > 50 then
                nvgBeginPath(vg)
                nvgMoveTo(vg, sx, sy - 4)
                nvgLineTo(vg, sx + 2.5, sy)
                nvgLineTo(vg, sx, sy + 4)
                nvgLineTo(vg, sx - 2.5, sy)
                nvgClosePath(vg)
                nvgFillColor(vg, nvgRGBA(bc[1], bc[2], bc[3], 220))
                nvgFill(vg)
            else
                nvgBeginPath(vg)
                nvgCircle(vg, sx, sy, 3)
                nvgFillColor(vg, nvgRGBA(bc[1], bc[2], bc[3], 255))
                nvgFill(vg)
            end
        end
    end
    for _, b in ipairs(state.enemyBullets) do
        local sx, sy = worldToScreen(b.x, b.y, cam, sw, sh)
        if sx > -10 and sx < sw + 10 and sy > -10 and sy < sh + 10 then
            local r = b.radius or 4
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, r + 3)
            nvgFillColor(vg, nvgRGBA(255, 60, 60, 30))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, r)
            nvgFillColor(vg, rgba(C.enemyBullet))
            nvgFill(vg)
        end
    end
end

-- ============================================================================
-- 绘制小行星
-- ============================================================================
function M.drawAsteroids(vg, state, sw, sh)
    local cam = state.cam
    for i, a in ipairs(state.asteroids) do
        local sx, sy = worldToScreen(a.x, a.y, cam, sw, sh)
        if sx > -40 and sx < sw + 40 and sy > -40 and sy < sh + 40 then
            local size = a.radius * 2.2
            local spriteName = (i % 2 == 0) and "asteroid_2" or "asteroid_1"
            Sprites.draw(vg, spriteName, sx, sy, size, size, (a.x + a.y) * 0.01, 1.0)
        end
    end
end

-- ============================================================================
-- 绘制拾取物
-- ============================================================================
function M.drawPickups(vg, state, sw, sh)
    local cam = state.cam
    for _, pk in ipairs(state.pickups) do
        local sx, sy = worldToScreen(pk.x, pk.y, cam, sw, sh)
        if sx > -20 and sx < sw + 20 and sy > -20 and sy < sh + 20 then
            local pulse = 0.7 + 0.3 * math.sin(pk.life * 8)
            local size = 16 * pulse
            local spriteName = Sprites.pickupTypeMap[pk.kind] or "pickup_scrap"
            Sprites.draw(vg, spriteName, sx, sy, size, size, 0, pulse)
        end
    end
end

-- ============================================================================
-- 绘制遗物掉落实体
-- ============================================================================
function M.drawRelicDrops(vg, state, sw, sh)
    local cam = state.cam
    local drops = state.relicDrops
    if not drops then return end
    local t = state.dayTimer or 0

    for _, drop in ipairs(drops) do
        local sx, sy = worldToScreen(drop.x, drop.y, cam, sw, sh)
        if sx > -40 and sx < sw + 40 and sy > -40 and sy < sh + 40 then
            local visible = true
            if drop.life < 5 then
                visible = math.floor(drop.life * 6) % 2 == 0
            end
            if not visible then goto continue end

            nvgSave(vg)
            nvgTranslate(vg, sx, sy)

            local scale = 1.0
            if drop.spawnTime < 0.3 then
                scale = 0.5 + 0.5 * (drop.spawnTime / 0.3)
            end

            local bob = math.sin(t * 3 + drop.bobPhase) * 4
            nvgTranslate(vg, 0, bob)
            nvgScale(vg, scale, scale)

            local glowPulse = 0.5 + 0.5 * math.sin(t * 4 + drop.bobPhase)
            local glowR = 18 + 6 * glowPulse
            nvgBeginPath(vg)
            nvgCircle(vg, 0, 0, glowR)
            local glowPaint = nvgRadialGradient(vg, 0, 0, 4, glowR,
                nvgRGBA(255, 200, 50, math.floor(120 * glowPulse)),
                nvgRGBA(255, 150, 0, 0))
            nvgFillPaint(vg, glowPaint)
            nvgFill(vg)

            local rot = t * 2 + drop.bobPhase
            nvgSave(vg)
            nvgRotate(vg, rot)
            nvgBeginPath(vg)
            nvgMoveTo(vg, 0, -10)
            nvgLineTo(vg, 8, 0)
            nvgLineTo(vg, 0, 10)
            nvgLineTo(vg, -8, 0)
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(255, 215, 0, 230))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 200, 200))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
            nvgRestore(vg)

            nvgBeginPath(vg)
            nvgCircle(vg, 0, 0, 3)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(200 * glowPulse)))
            nvgFill(vg)

            nvgRestore(vg)
            ::continue::
        end
    end
end

-- ============================================================================
-- 绘制数据中继站
-- ============================================================================
function M.drawRelays(vg, state, sw, sh)
    local cam = state.cam
    local relays = state.relayStations or {}
    for _, r in ipairs(relays) do
        local sx, sy = worldToScreen(r.x, r.y, cam, sw, sh)
        if sx > -150 and sx < sw + 150 and sy > -150 and sy < sh + 150 then
            local pulse = 0.6 + 0.4 * math.sin(state.dayTimer * 3)
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, 120)
            nvgStrokeColor(vg, nvgRGBA(0, 255, 200, math.floor(25 * pulse)))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)

            Sprites.draw(vg, "relay_station", sx, sy, 32, 32, 0, 1.0)

            if state.nearRelay then
                nvgFontFace(vg, "sans")
                nvgFontSize(vg, 10)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(0, 255, 200, 180))
                nvgText(vg, sx, sy + 22, "♥ 修复中")
            end
        end
    end
end

-- ============================================================================
-- 绘制道具实体
-- ============================================================================
function M.drawPowerups(vg, state, sw, sh)
    local cam = state.cam
    for _, pw in ipairs(state.powerups) do
        local sx, sy = worldToScreen(pw.x, pw.y, cam, sw, sh)
        if sx > -30 and sx < sw + 30 and sy > -30 and sy < sh + 30 then
            local def = Data.POWERUP_TYPES[pw.kind]
            if def then
                local pulse = 1 + math.sin(pw.life * 4) * 0.15
                local size = 24 * pulse
                nvgBeginPath(vg)
                nvgCircle(vg, sx, sy, size * 0.6 + 4)
                nvgFillColor(vg, nvgRGBA(def.color[1], def.color[2], def.color[3], 40))
                nvgFill(vg)
                local spriteName = Sprites.powerupTypeMap[pw.kind] or "powerup_shield"
                Sprites.draw(vg, spriteName, sx, sy, size, size, 0, 1.0)
            end
        end
    end
end

-- ============================================================================
-- 友军渲染
-- ============================================================================
function M.drawAllies(vg, state, sw, sh)
    local cam = state.cam
    for _, ally in ipairs(state.allies) do
        local sx, sy = worldToScreen(ally.x, ally.y, cam, sw, sh)
        if sx > -40 and sx < sw + 40 and sy > -40 and sy < sh + 40 then
            local r = (ally.cfg.size or 12) * 0.8
            local size = r * 2.4

            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, size * 0.55 + 4)
            nvgStrokeColor(vg, nvgRGBA(0, 220, 200, 120))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)

            Sprites.draw(vg, "ally_ship", sx, sy, size, size, 0, 1.0)

            nvgFontFace(vg, "sans")
            nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(0, 255, 200, 200))
            nvgText(vg, sx, sy - size * 0.5 - 2, "友军")

            local ratio = ally.lifespan / 20
            nvgBeginPath(vg)
            nvgRect(vg, sx - r, sy + size * 0.5 + 2, r * 2 * ratio, 2)
            nvgFillColor(vg, nvgRGBA(0, 220, 200, 180))
            nvgFill(vg)
        end
    end
end

-- ============================================================================
-- 激光武器渲染
-- ============================================================================
function M.drawLaser(vg, state, sw, sh)
    local laser = state.laser
    if not laser or not laser.active or laser.charge < 0.3 then return end

    local p = state.player
    local cam = state.cam
    local sx, sy = worldToScreen(p.x, p.y, cam, sw, sh)

    local angle = laser.angle
    local len = 500 * math.min(1, laser.charge)
    local ex = sx + math.cos(angle) * len
    local ey = sy + math.sin(angle) * len

    local heatRatio = laser.heat or 0
    local r = math.floor(50 + 205 * heatRatio)
    local g = math.floor(200 - 150 * heatRatio)
    local b = math.floor(255 - 200 * heatRatio)

    local glowWidth = 6 + 4 * laser.charge
    nvgBeginPath(vg)
    nvgMoveTo(vg, sx, sy)
    nvgLineTo(vg, ex, ey)
    nvgStrokeColor(vg, nvgRGBA(r, g, b, 40))
    nvgStrokeWidth(vg, glowWidth * 2)
    nvgStroke(vg)

    nvgBeginPath(vg)
    nvgMoveTo(vg, sx, sy)
    nvgLineTo(vg, ex, ey)
    nvgStrokeColor(vg, nvgRGBA(r, g, b, 120))
    nvgStrokeWidth(vg, glowWidth)
    nvgStroke(vg)

    nvgBeginPath(vg)
    nvgMoveTo(vg, sx, sy)
    nvgLineTo(vg, ex, ey)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    nvgBeginPath(vg)
    nvgCircle(vg, sx, sy, 4 + 2 * math.sin(state.dayTimer * 20))
    nvgFillColor(vg, nvgRGBA(r, g, b, 180))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgCircle(vg, ex, ey, 6)
    nvgFillColor(vg, nvgRGBA(r, g, b, 100))
    nvgFill(vg)

    if laser.heat > 0.1 then
        local barW = 40
        local barH = 4
        local barX = sx - barW / 2
        local barY = sy + 22
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW, barH, 2)
        nvgFillColor(vg, nvgRGBA(40, 40, 40, 150))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW * heatRatio, barH, 2)
        nvgFillColor(vg, nvgRGBA(255, math.floor(100 * (1 - heatRatio)), 0, 200))
        nvgFill(vg)
    end
end

-- ============================================================================
-- 追踪导弹渲染
-- ============================================================================
function M.drawMissiles(vg, state, sw, sh)
    local cam = state.cam
    for _, m in ipairs(state.missiles) do
        local sx, sy = worldToScreen(m.x, m.y, cam, sw, sh)
        if sx > -30 and sx < sw + 30 and sy > -30 and sy < sh + 30 then
            local speed = math.sqrt(m.vx * m.vx + m.vy * m.vy)
            local dx = (speed > 0) and (m.vx / speed) or 0
            local dy = (speed > 0) and (m.vy / speed) or 0

            for j = 1, 4 do
                local tx = sx - dx * j * 5
                local ty = sy - dy * j * 5
                local ta = math.floor(150 - j * 35)
                nvgBeginPath(vg)
                nvgCircle(vg, tx, ty, 2.5 - j * 0.4)
                nvgFillColor(vg, nvgRGBA(255, 150 - j * 20, 0, ta))
                nvgFill(vg)
            end

            local angle = math.atan(m.vy, m.vx) + math.pi / 2
            Sprites.draw(vg, "missile", sx, sy, 14, 14, angle, 1.0)

            if m.target then
                local tx, ty = worldToScreen(m.target.x, m.target.y, cam, sw, sh)
                nvgBeginPath(vg)
                nvgCircle(vg, tx, ty, 12)
                nvgStrokeColor(vg, nvgRGBA(255, 100, 50, 80))
                nvgStrokeWidth(vg, 1)
                nvgStroke(vg)
            end
        end
    end
end

-- ============================================================================
-- 环境危害渲染
-- ============================================================================
function M.drawHazards(vg, state, sw, sh)
    if not state.hazards or #state.hazards == 0 then return end
    local cam = state.cam

    for _, h in ipairs(state.hazards) do
        local sx, sy = worldToScreen(h.x, h.y, cam, sw, sh)
        if sx < -200 or sx > sw + 200 or sy < -200 or sy > sh + 200 then goto next_haz end

        local lifeAlpha = math.min(1.0, h.life / 3.0)
        local alpha = math.floor(lifeAlpha * 180)

        if h.kind == "black_hole" then
            local def = Systems.HAZARDS.black_hole
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, def.radius)
            nvgStrokeColor(vg, nvgRGBA(60, 0, 120, alpha))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, def.coreRadius)
            nvgFillColor(vg, nvgRGBA(20, 0, 40, alpha))
            nvgFill(vg)
            local t = (state.dayTimer or 0) * 2
            for i = 0, 5 do
                local a = t + i * (TAU / 6)
                nvgBeginPath(vg)
                nvgMoveTo(vg, sx + math.cos(a) * def.coreRadius, sy + math.sin(a) * def.coreRadius)
                nvgLineTo(vg, sx + math.cos(a) * def.radius * 0.7, sy + math.sin(a) * def.radius * 0.7)
                nvgStrokeColor(vg, nvgRGBA(100, 0, 200, math.floor(alpha * 0.5)))
                nvgStrokeWidth(vg, 1)
                nvgStroke(vg)
            end
        elseif h.kind == "ion_storm" then
            local def = Systems.HAZARDS.ion_storm
            local flicker = 0.7 + 0.3 * math.sin((state.dayTimer or 0) * 5)
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, def.radius)
            nvgFillColor(vg, nvgRGBA(100, 200, 255, math.floor(30 * flicker * lifeAlpha)))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 200, 255, math.floor(alpha * 0.6)))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(150, 220, 255, alpha))
            nvgText(vg, sx, sy, "⚡ 离子风暴")
        elseif h.kind == "energy_wall" then
            local def = Systems.HAZARDS.energy_wall
            local halfLen = def.length / 2
            nvgBeginPath(vg)
            nvgMoveTo(vg, sx - halfLen, sy)
            nvgLineTo(vg, sx + halfLen, sy)
            nvgStrokeColor(vg, nvgRGBA(255, 60, 180, alpha))
            nvgStrokeWidth(vg, 4)
            nvgStroke(vg)
            nvgBeginPath(vg)
            nvgMoveTo(vg, sx - halfLen, sy)
            nvgLineTo(vg, sx + halfLen, sy)
            nvgStrokeColor(vg, nvgRGBA(255, 60, 180, math.floor(alpha * 0.3)))
            nvgStrokeWidth(vg, 10)
            nvgStroke(vg)
        end

        ::next_haz::
    end
end

-- ============================================================================
-- 回旋镖渲染
-- ============================================================================
function M.drawBoomerangs(vg, state, sw, sh)
    if not state.boomerangs or #state.boomerangs == 0 then return end
    local cam = state.cam
    local t = state.dayTimer or 0

    for _, b in ipairs(state.boomerangs) do
        local sx, sy = worldToScreen(b.x, b.y, cam, sw, sh)
        if sx < -50 or sx > sw + 50 or sy < -50 or sy > sh + 50 then goto next_boom end

        local spin = t * 12  -- 快速旋转
        local size = 12

        nvgSave(vg)
        nvgTranslate(vg, sx, sy)
        nvgRotate(vg, spin)

        -- 三叶回旋镖形状
        for i = 0, 2 do
            local angle = i * (TAU / 3)
            local ax = math.cos(angle) * size
            local ay = math.sin(angle) * size
            nvgBeginPath(vg)
            nvgMoveTo(vg, 0, 0)
            nvgLineTo(vg, ax, ay)
            nvgLineTo(vg, math.cos(angle + 0.4) * size * 0.6, math.sin(angle + 0.4) * size * 0.6)
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(0, 255, 200, 220))
            nvgFill(vg)
        end

        -- 发光外圈
        nvgBeginPath(vg)
        nvgCircle(vg, 0, 0, size + 3)
        nvgStrokeColor(vg, nvgRGBA(0, 255, 200, 60))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)

        nvgRestore(vg)

        -- 返回阶段的拖尾
        if b.phase == "returning" then
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, size + 5)
            nvgStrokeColor(vg, nvgRGBA(0, 200, 180, 40))
            nvgStrokeWidth(vg, 3)
            nvgStroke(vg)
        end

        ::next_boom::
    end
end

-- ============================================================================
-- 地雷渲染
-- ============================================================================
function M.drawMines(vg, state, sw, sh)
    if not state.mines or #state.mines == 0 then return end
    local cam = state.cam
    local t = state.dayTimer or 0

    for _, m in ipairs(state.mines) do
        local sx, sy = worldToScreen(m.x, m.y, cam, sw, sh)
        if sx < -100 or sx > sw + 100 or sy < -100 or sy > sh + 100 then goto next_mine end

        local armed = m.armTimer <= 0
        local pulse = 0.7 + 0.3 * math.sin(t * (armed and 8 or 3))

        -- 爆炸范围指示圈（半透明）
        if armed then
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, m.radius * pulse * 0.3)
            nvgFillColor(vg, nvgRGBA(200, 50, 255, 15))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 50, 255, math.floor(40 * pulse)))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)
        end

        -- 地雷核心
        local coreSize = armed and 8 or 6
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, coreSize)
        if armed then
            nvgFillColor(vg, nvgRGBA(200, 50, 255, math.floor(200 * pulse)))
        else
            nvgFillColor(vg, nvgRGBA(120, 30, 150, 150))
        end
        nvgFill(vg)

        -- 外环
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, coreSize + 3)
        nvgStrokeColor(vg, nvgRGBA(200, 100, 255, armed and 180 or 80))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)

        -- 未激活标记
        if not armed then
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, 8)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 120))
            nvgText(vg, sx, sy, "●")
        end

        ::next_mine::
    end
end

return M
