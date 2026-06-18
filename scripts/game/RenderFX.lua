-- ============================================================================
-- RenderFX.lua - 特效/覆盖层/动画渲染
-- ============================================================================
local RenderUtils = require("game.RenderUtils")
local Systems = require("game.Systems")
local S = require("game.Strings")

local C = RenderUtils.C
local rgba = RenderUtils.rgba
local worldToScreen = RenderUtils.worldToScreen
local TAU = RenderUtils.TAU

local M = {}

-- ============================================================================
-- 粒子特效（世界坐标）
-- ============================================================================
function M.drawParticles(vg, state, sw, sh)
    local cam = state.cam
    for _, p in ipairs(state.particles) do
        local sx, sy = worldToScreen(p.x, p.y, cam, sw, sh)
        if sx > -10 and sx < sw + 10 and sy > -10 and sy < sh + 10 then
            local alpha = math.floor((p.alpha or p.life) * 255)
            local pc = p.color or { 255, 150, 50 }
            local sz = p.size * (p.life / (p.maxLife or 1))

            if p.trail then
                -- 尾焰粒子：带发光的柔和圆点
                local glowR = sz * 2.5
                nvgBeginPath(vg)
                nvgCircle(vg, sx, sy, glowR)
                nvgFillPaint(vg, nvgRadialGradient(vg, sx, sy, sz * 0.3, glowR,
                    nvgRGBA(pc[1], pc[2], pc[3], alpha),
                    nvgRGBA(pc[1], pc[2], pc[3], 0)))
                nvgFill(vg)
                -- 内核亮点
                nvgBeginPath(vg)
                nvgCircle(vg, sx, sy, sz * 0.5)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(alpha * 0.8)))
                nvgFill(vg)
            elseif p.shieldShard then
                -- 护盾碎片：旋转的小方块
                nvgSave(vg)
                nvgTranslate(vg, sx, sy)
                nvgRotate(vg, (p.life or 0) * 12)
                nvgBeginPath(vg)
                nvgRect(vg, -sz, -sz * 0.5, sz * 2, sz)
                nvgFillColor(vg, nvgRGBA(pc[1], pc[2], pc[3], alpha))
                nvgFill(vg)
                -- 高光边缘
                nvgStrokeColor(vg, nvgRGBA(200, 240, 255, math.floor(alpha * 0.6)))
                nvgStrokeWidth(vg, 1)
                nvgStroke(vg)
                nvgRestore(vg)
            else
                -- 默认圆形粒子
                nvgBeginPath(vg)
                nvgCircle(vg, sx, sy, sz)
                nvgFillColor(vg, nvgRGBA(pc[1], pc[2], pc[3], alpha))
                nvgFill(vg)
            end
        end
    end
end

-- ============================================================================
-- 飘字渲染（世界坐标）
-- ============================================================================
function M.drawFloatingTexts(vg, state, sw, sh)
    local cam = state.cam
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, ft in ipairs(state.floatingTexts) do
        local sx, sy = worldToScreen(ft.x, ft.y, cam, sw, sh)
        if sx > -100 and sx < sw + 100 and sy > -50 and sy < sh + 50 then
            local alpha = math.floor((ft.life / ft.maxLife) * 255)
            local scale = ft.scale * (1 + (1 - ft.life / ft.maxLife) * 0.3)
            nvgFontSize(vg, 13 * scale)
            local c = ft.color
            nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], alpha))
            nvgText(vg, sx, sy, ft.text)
        end
    end
end

-- ============================================================================
-- Toast 通知（屏幕空间）
-- ============================================================================
function M.drawToasts(vg, state, sw, sh)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    local y = 80
    for _, t in ipairs(state.toasts) do
        local alpha = math.floor(math.min(1, t.life * 2) * 220)
        nvgFillColor(vg, nvgRGBA(255, 220, 100, alpha))
        nvgText(vg, sw / 2, y, t.text or "")
        y = y + 22
    end
end

-- ============================================================================
-- 事件覆盖层（全屏色调）
-- ============================================================================
function M.drawEventOverlay(vg, state, sw, sh)
    if not state.activeEvent then return end
    local ev = state.activeEvent
    local alpha = math.floor(math.min(1, state.eventRemaining * 0.5) * 40)

    if ev.effect == "storm" then
        local paint = nvgBoxGradient(vg, 0, 0, sw, sh, sw * 0.3, sw * 0.4,
            nvgRGBA(0, 0, 0, 0), nvgRGBA(255, 100, 0, alpha))
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, sw, sh)
        nvgFillPaint(vg, paint)
        nvgFill(vg)
    elseif ev.effect == "emp" then
        local flicker = math.floor(math.abs(math.sin(state.eventRemaining * 8)) * 30)
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, sw, sh)
        nvgFillColor(vg, nvgRGBA(120, 60, 255, flicker))
        nvgFill(vg)
    elseif ev.effect == "repair" then
        local pulse = math.floor(math.abs(math.sin(state.eventRemaining * 3)) * 20)
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, sw, sh)
        nvgFillColor(vg, nvgRGBA(0, 255, 150, pulse))
        nvgFill(vg)
    end

    -- 事件信息显示
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(ev.color[1], ev.color[2], ev.color[3], 220))
    nvgText(vg, sw / 2, 54, string.format("⚡ %s (%.0fs)", ev.name, state.eventRemaining))
end

-- ============================================================================
-- 波次预警
-- ============================================================================
function M.drawWaveWarning(vg, state, sw, sh)
    if not state.waveActive or not state.pendingWave then return end
    local t = state.waveTimer
    local alpha = math.floor(math.min(1, t) * 255)
    local pulse = 1 + math.sin(t * 6) * 0.2

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 22 * pulse)
    nvgFillColor(vg, nvgRGBA(255, 80, 80, alpha))
    nvgText(vg, sw / 2, sh * 0.2, S.get("hud_wave", state.waveName, t))
end

-- ============================================================================
-- Boss 特效（激光 + 预警圈）
-- ============================================================================
function M.drawBossEffects(vg, state, sw, sh)
    local cam = state.cam

    -- Boss 扫射激光
    for _, bl in ipairs(state.bossLasers) do
        local sx, sy = worldToScreen(bl.x, bl.y, cam, sw, sh)
        local ex = sx + math.cos(bl.angle) * 600
        local ey = sy + math.sin(bl.angle) * 600

        if bl.life > 0.8 then
            local flicker = math.floor(math.abs(math.sin(bl.life * 30)) * 200)
            nvgBeginPath(vg)
            nvgMoveTo(vg, sx, sy)
            nvgLineTo(vg, ex, ey)
            nvgStrokeColor(vg, nvgRGBA(255, 40, 40, flicker))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)
        else
            nvgBeginPath(vg)
            nvgMoveTo(vg, sx, sy)
            nvgLineTo(vg, ex, ey)
            nvgStrokeColor(vg, nvgRGBA(255, 40, 80, 50))
            nvgStrokeWidth(vg, 16)
            nvgStroke(vg)

            nvgBeginPath(vg)
            nvgMoveTo(vg, sx, sy)
            nvgLineTo(vg, ex, ey)
            nvgStrokeColor(vg, nvgRGBA(255, 100, 100, 150))
            nvgStrokeWidth(vg, 6)
            nvgStroke(vg)

            nvgBeginPath(vg)
            nvgMoveTo(vg, sx, sy)
            nvgLineTo(vg, ex, ey)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 220, 220))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
        end
    end

    -- 预警圈（落点标记）
    for _, w in ipairs(state.bossWarnings) do
        local sx, sy = worldToScreen(w.x, w.y, cam, sw, sh)
        local pulse = math.abs(math.sin(w.life * 8))
        local alpha = math.floor(120 + 80 * pulse)

        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, w.radius * (1.2 - 0.2 * pulse))
        nvgStrokeColor(vg, nvgRGBA(255, 60, 60, alpha))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)

        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, w.radius * (1.2 - 0.2 * pulse))
        nvgFillColor(vg, nvgRGBA(255, 40, 40, math.floor(alpha * 0.15)))
        nvgFill(vg)

        -- 十字线
        nvgBeginPath(vg)
        nvgMoveTo(vg, sx - w.radius, sy)
        nvgLineTo(vg, sx + w.radius, sy)
        nvgMoveTo(vg, sx, sy - w.radius)
        nvgLineTo(vg, sx, sy + w.radius)
        nvgStrokeColor(vg, nvgRGBA(255, 80, 80, math.floor(alpha * 0.5)))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
    end
end

-- ============================================================================
-- 收集动画（光环脉冲）
-- ============================================================================
function M.drawCollectAnims(vg, state, sw, sh)
    local cam = state.cam
    for _, ca in ipairs(state.collectAnims) do
        local sx, sy = worldToScreen(ca.x, ca.y, cam, sw, sh)
        if sx > -50 and sx < sw + 50 and sy > -50 and sy < sh + 50 then
            local progress = 1 - ca.timer / ca.maxTime
            local alpha = math.floor((1 - progress) * 200)

            -- 多层脉冲环
            for ring = 1, 3 do
                local ringProgress = math.max(0, progress - (ring - 1) * 0.2)
                if ringProgress > 0 then
                    local ringRadius = 5 + ringProgress * 35
                    local ringAlpha = math.floor(alpha * (1 - (ring - 1) * 0.3))
                    nvgBeginPath(vg)
                    nvgCircle(vg, sx, sy, ringRadius)
                    nvgStrokeColor(vg, nvgRGBA(ca.color[1], ca.color[2], ca.color[3], ringAlpha))
                    nvgStrokeWidth(vg, 2 * (1 - ringProgress))
                    nvgStroke(vg)
                end
            end

            -- 内部脉冲闪光
            local flashScale = 1 + math.sin(progress * TAU * 4) * 0.3
            local flashRadius = 6 * flashScale * (1 - progress * 0.5)
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, flashRadius)
            local flashAlpha = math.floor((1 - progress) * 180)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, flashAlpha))
            nvgFill(vg)

            -- 向玩家方向汇聚的粒子
            local px, py = worldToScreen(state.player.x, state.player.y, cam, sw, sh)
            local dx = px - sx
            local dy = py - sy
            local distToPlayer = math.sqrt(dx * dx + dy * dy)
            for j = 0, 7 do
                local angle = j * TAU / 8 + progress * TAU * 0.5
                local moveDist = progress * distToPlayer * 0.3
                local pr = 12 + progress * 8
                local px2 = sx + math.cos(angle) * pr + dx / distToPlayer * moveDist
                local py2 = sy + math.sin(angle) * pr + dy / distToPlayer * moveDist
                nvgBeginPath(vg)
                nvgCircle(vg, px2, py2, 2.5 * (1 - progress * 0.7))
                nvgFillColor(vg, nvgRGBA(ca.color[1], ca.color[2], ca.color[3], math.floor(alpha * 0.7)))
                nvgFill(vg)
            end
        end
    end
end

-- ============================================================================
-- 新手教程覆盖层
-- ============================================================================
function M.drawTutorial(vg, state, sw, sh)
    if state.tutorialStep <= 0 or state.tutorialStep > 8 then return end

    local step = state.tutorialStep
    -- P10.4: i18n - 教程文本从 Strings 模块获取
    local tutorials = S.getTutorials(sw, sh)
    local t = tutorials[step]
    if not t then return end

    -- 脉冲高亮圈
    local pulse = math.sin(state.tutorialTimer * 4) * 0.3 + 0.7
    nvgBeginPath(vg)
    nvgCircle(vg, t.hx, t.hy, 30 + 10 * pulse)
    nvgStrokeColor(vg, nvgRGBA(0, 200, 255, math.floor(120 * pulse)))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 指引箭头（从提示框指向高亮目标）
    local boxCenterX = sw / 2
    local boxCenterY = sh * 0.82
    local dx = t.hx - boxCenterX
    local dy = t.hy - boxCenterY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 80 then
        local arrowLen = 20
        local nx, ny = dx / dist, dy / dist
        local arrowX = boxCenterX + nx * 35
        local arrowY = boxCenterY + ny * 10
        nvgBeginPath(vg)
        nvgMoveTo(vg, arrowX, arrowY)
        nvgLineTo(vg, arrowX + nx * arrowLen, arrowY + ny * arrowLen)
        nvgStrokeColor(vg, nvgRGBA(0, 200, 255, math.floor(180 * pulse)))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
        -- 箭头尖
        local perpX, perpY = -ny, nx
        local tipX = arrowX + nx * arrowLen
        local tipY = arrowY + ny * arrowLen
        nvgBeginPath(vg)
        nvgMoveTo(vg, tipX, tipY)
        nvgLineTo(vg, tipX - nx * 6 + perpX * 4, tipY - ny * 6 + perpY * 4)
        nvgLineTo(vg, tipX - nx * 6 - perpX * 4, tipY - ny * 6 - perpY * 4)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(0, 200, 255, math.floor(180 * pulse)))
        nvgFill(vg)
    end

    -- 教程提示框
    local boxW = 280
    local boxH = 60
    local boxX = (sw - boxW) / 2
    local boxY = sh * 0.82

    nvgBeginPath(vg)
    nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 8)
    nvgFillColor(vg, nvgRGBA(10, 20, 40, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(0, 180, 255, 150))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 步骤指示器
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 9)
    nvgFillColor(vg, nvgRGBA(0, 180, 255, 180))
    nvgText(vg, sw / 2, boxY + 12, S.get("tutorial_title", step))

    -- 主文本
    nvgFontSize(vg, 15)
    nvgFillColor(vg, nvgRGBA(220, 240, 255, 240))
    nvgText(vg, sw / 2, boxY + 30, t.text)

    -- 副文本
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(140, 180, 220, 180))
    nvgText(vg, sw / 2, boxY + 48, t.sub)
end

-- ============================================================================
-- 成就弹窗（屏幕右上滑入）
-- ============================================================================
function M.drawAchievementPopups(vg, state, sw, sh)
    if not state.achievementQueue or #state.achievementQueue == 0 then return end

    local startY = 70
    for i, item in ipairs(state.achievementQueue) do
        local def = item.def
        if not def then goto next_ach end
        local y = startY + (i - 1) * 50
        local alpha = math.min(255, math.floor(item.timer * 120))
        -- 进入动画
        local slideX = 0
        if item.timer > 2.5 then
            slideX = math.floor((item.timer - 2.5) * 200)
        end

        -- 背景面板
        local px = sw - 220 + slideX
        nvgBeginPath(vg)
        nvgRoundedRect(vg, px, y, 200, 40, 6)
        nvgFillColor(vg, nvgRGBA(20, 20, 40, alpha))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 215, 0, alpha))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)

        -- 图标
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, alpha))
        nvgText(vg, px + 10, y + 20, def.icon or "★")

        -- 标题
        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(255, 215, 0, alpha))
        nvgText(vg, px + 35, y + 14, S.get("achievement_unlock"))
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(220, 220, 240, alpha))
        nvgText(vg, px + 35, y + 28, def.name or "")

        ::next_ach::
    end
end

-- ============================================================================
-- 子弹时间覆盖效果
-- ============================================================================
function M.drawSlowmoOverlay(vg, state, sw, sh)
    local sm = Systems.slowmo
    if not sm or not sm.active or sm.duration <= 0 then return end

    local alpha = math.floor(math.min(1.0, sm.duration / 0.3) * 60)
    -- 四角暗紫色暗角
    local grad = nvgRadialGradient(vg, sw / 2, sh / 2, sw * 0.3, sw * 0.7,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(80, 0, 120, alpha))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillPaint(vg, grad)
    nvgFill(vg)

    -- "SLOW" 文字
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(200, 100, 255, math.floor(alpha * 3)))
    nvgText(vg, sw / 2, 8, "▶ BULLET TIME")
end

-- ============================================================================
-- P7.3: 时间减速视觉效果
-- ============================================================================
function M.drawTimeSlowFX(vg, state, sw, sh)
    if (state.timeSlowRemaining or 0) <= 0 then return end
    -- 淡蓝色边缘光晕 + 轻微暗角
    local intensity = math.min(1.0, state.timeSlowRemaining / 2.0) -- 最后2秒渐消
    local alpha = math.floor(intensity * 80)
    local grad = nvgBoxGradient(vg, 0, 0, sw, sh, sw * 0.3, sw * 0.6,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 100, 200, alpha))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillPaint(vg, grad)
    nvgFill(vg)
    -- 顶部时间指示条
    local barW = sw * 0.3
    local barH = 3
    local barX = (sw - barW) / 2
    local pct = state.timeSlowRemaining / 5.0
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, 8, barW * pct, barH, 1.5)
    nvgFillColor(vg, nvgRGBA(0, 180, 255, math.floor(intensity * 200)))
    nvgFill(vg)
end

-- ============================================================================
-- Phase 6: 受伤红色闪屏
-- ============================================================================
function M.drawDamageFlash(vg, state, sw, sh)
    local flash = state.damageFlash or 0
    if flash <= 0 then return end
    -- 从边缘向内的红色渐变，中央保持可见
    local alpha = math.floor(flash * 400)
    alpha = math.min(alpha, 180)
    local grad = nvgBoxGradient(vg, 0, 0, sw, sh, sw * 0.25, sw * 0.5,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(200, 0, 0, alpha))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillPaint(vg, grad)
    nvgFill(vg)
    -- 顶部和底部边缘更亮的红线
    local edgeAlpha = math.floor(flash * 600)
    edgeAlpha = math.min(edgeAlpha, 200)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, 3)
    nvgFillColor(vg, nvgRGBA(255, 50, 50, edgeAlpha))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRect(vg, 0, sh - 3, sw, 3)
    nvgFillColor(vg, nvgRGBA(255, 50, 50, edgeAlpha))
    nvgFill(vg)
end

return M
