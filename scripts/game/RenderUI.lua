-- ============================================================================
-- RenderUI.lua - HUD / 菜单 / 全屏 UI 渲染
-- ============================================================================
local Data = require("game.Data")
local Systems = require("game.Systems")
local RenderUtils = require("game.RenderUtils")

local C = RenderUtils.C
local rgba = RenderUtils.rgba
local worldToScreen = RenderUtils.worldToScreen
local TAU = RenderUtils.TAU

local M = {}

-- 菜单动画状态（模块内部）
local menuTime = 0
local menuStars = nil

-- ============================================================================
-- HUD（血条/护盾/分数/资源）
-- ============================================================================
function M.drawHUD(vg, state, sw, sh)
    local p = state.player

    -- 左上：HP & Shield 条
    local barX, barY, barW, barH = 20, 20, 180, 14
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(30, 30, 40, 200))
    nvgFill(vg)
    local hpRatio = math.max(0, p.hp / p.hpMax)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW * hpRatio, barH, 3)
    nvgFillColor(vg, rgba(C.hpBar))
    nvgFill(vg)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, barX + barW / 2, barY + barH / 2, string.format("HP %d/%d", math.floor(p.hp), p.hpMax))

    if p.shieldMax > 0 then
        local sBarY = barY + barH + 4
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, sBarY, barW, barH, 3)
        nvgFillColor(vg, nvgRGBA(30, 30, 40, 200))
        nvgFill(vg)
        local shieldRatio = math.max(0, p.shield / p.shieldMax)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, sBarY, barW * shieldRatio, barH, 3)
        nvgFillColor(vg, rgba(C.shieldBar))
        nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
        nvgText(vg, barX + barW / 2, sBarY + barH / 2, string.format("盾 %d/%d", math.floor(p.shield), p.shieldMax))
    end

    -- 右上：分数 & 天数
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(vg, rgba(C.text))
    nvgText(vg, sw - 20, 20, string.format("分数: %d", state.score))
    nvgFontSize(vg, 13)
    if state.isEndless then
        -- 无尽模式：不显示总天数上限
        nvgFillColor(vg, nvgRGBA(180, 120, 255, 200))
        nvgText(vg, sw - 20, 42, string.format("∞ 第 %d 天", state.day))
    else
        nvgFillColor(vg, rgba(C.textDim))
        nvgText(vg, sw - 20, 42, string.format("第 %d / 30 天", state.day))
    end

    -- 每日挑战标识
    if state.isDailyChallenge and state.dailyMods then
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(255, 180, 40, 200))
        local modStr = "挑战: " .. state.dailyMods[1].name .. " + " .. state.dailyMods[2].name
        nvgText(vg, sw - 20, 60, modStr)
    end

    -- 左下：资源
    local res = state.resources
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_BOTTOM)
    local resY = sh - 60
    nvgFillColor(vg, rgba(C.metal))
    nvgText(vg, 20, resY, string.format("金属: %d", res.metal))
    nvgFillColor(vg, rgba(C.energy))
    nvgText(vg, 20, resY + 16, string.format("能量: %d", res.energy))
    nvgFillColor(vg, rgba(C.blueprint))
    nvgText(vg, 20, resY + 32, string.format("图纸: %d", res.blueprint))
    nvgFillColor(vg, rgba(C.ancientKey))
    nvgText(vg, 20, resY + 48, string.format("密钥: %d", res.ancient_key))

    -- 副武器HUD（左下，资源上方）
    M.drawSecondaryWeaponHUD(vg, state, sw, sh)

    -- 操作提示
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(100, 120, 160, 100))
    nvgText(vg, sw / 2, sh - 8, "WASD移动 | 左键射击 | Space副武器 | Tab切换 | T科技树 | Q导弹 | V激光")

    -- 任务面板（右侧中部）
    M.drawQuestPanel(vg, state, sw, sh)

    -- 小地图（右下角）
    M.drawMinimap(vg, state, sw, sh)
end

-- ============================================================================
-- 当前任务面板
-- ============================================================================
function M.drawQuestPanel(vg, state, sw, sh)
    local activeQuest = nil
    for _, q in ipairs(Data.QUESTS) do
        if state.day >= q.days[1] and state.day <= q.days[2] then
            activeQuest = q
            break
        end
    end
    if not activeQuest then return end

    local ctx = {
        resources = state.resources,
        bossesKilled = state.bossesKilled,
        relayCount = state.relayCount,
        aiCoreLevel = state.stats and state.stats.aiCoreLevel or 0,
    }
    local completed = activeQuest.check(ctx)

    local panelW = 160
    local panelH = 62
    local px = sw - panelW - 16
    local py = 65

    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, panelW, panelH, 5)
    nvgFillColor(vg, nvgRGBA(15, 20, 35, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, completed and nvgRGBA(80, 255, 80, 100) or nvgRGBA(60, 100, 180, 80))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(120, 160, 220, 180))
    nvgText(vg, px + 8, py + 5, string.format("章节%d", activeQuest.chapter))

    nvgFontSize(vg, 13)
    nvgFillColor(vg, completed and nvgRGBA(80, 255, 120, 240) or nvgRGBA(220, 230, 255, 230))
    nvgText(vg, px + 8, py + 19, activeQuest.name)

    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(160, 170, 200, 180))
    nvgText(vg, px + 8, py + 37, activeQuest.desc)

    if completed then
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(80, 255, 80, 220))
        nvgText(vg, px + panelW - 8, py + 5, "✓ 完成")
    else
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 160))
        nvgText(vg, px + panelW - 8, py + 5, string.format("D%d-%d", activeQuest.days[1], activeQuest.days[2]))
    end
end

-- ============================================================================
-- 小地图
-- ============================================================================
function M.drawMinimap(vg, state, sw, sh)
    local mmSize = 100
    local mmX = sw - mmSize - 16
    local mmY = sh - mmSize - 16
    local scale = mmSize / (2500 * 2.2)

    nvgBeginPath(vg)
    nvgCircle(vg, mmX + mmSize / 2, mmY + mmSize / 2, mmSize / 2)
    nvgFillColor(vg, nvgRGBA(10, 15, 30, 180))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 80, 120, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    local cx = mmX + mmSize / 2
    local cy = mmY + mmSize / 2

    -- 玩家
    local px = cx + state.player.x * scale
    local py = cy + state.player.y * scale
    nvgBeginPath(vg)
    nvgCircle(vg, px, py, 2.5)
    nvgFillColor(vg, rgba(C.player))
    nvgFill(vg)

    -- 中继站
    for _, r in ipairs(state.relays or {}) do
        local rx = cx + r.x * scale
        local ry = cy + r.y * scale
        nvgBeginPath(vg)
        nvgRect(vg, rx - 1.5, ry - 1.5, 3, 3)
        nvgFillColor(vg, nvgRGBA(0, 255, 200, 180))
        nvgFill(vg)
    end

    -- 敌人
    for _, e in ipairs(state.enemies) do
        local ex = cx + e.x * scale
        local ey = cy + e.y * scale
        if e.isBoss then
            nvgBeginPath(vg)
            nvgCircle(vg, ex, ey, 2)
            nvgFillColor(vg, rgba(C.boss))
            nvgFill(vg)
        else
            nvgBeginPath(vg)
            nvgCircle(vg, ex, ey, 1)
            nvgFillColor(vg, nvgRGBA(255, 80, 80, 150))
            nvgFill(vg)
        end
    end

    -- 标签
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(140, 160, 200, 120))
    nvgText(vg, mmX + mmSize / 2, mmY + mmSize + 3, "星图")
end

-- ============================================================================
-- 菜单界面
-- ============================================================================
function M.drawMenu(vg, sw, sh, selectedFaction, selectedSkinIdx, savedAchievements, dailyChallengeCompleted)
    menuTime = menuTime + 0.016

    -- 初始化菜单星星
    if not menuStars then
        menuStars = {}
        for i = 1, 80 do
            menuStars[i] = {
                x = math.random() * 1.5 - 0.25,
                y = math.random(),
                r = math.random() * 1.2 + 0.3,
                speed = math.random() * 0.008 + 0.002,
                twinkle = math.random() * TAU,
            }
        end
    end

    -- 渐变背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    local bgPaint = nvgLinearGradient(vg, 0, 0, 0, sh,
        nvgRGBA(6, 8, 24, 255), nvgRGBA(18, 8, 32, 255))
    nvgFillPaint(vg, bgPaint)
    nvgFill(vg)

    -- 动态星空
    for _, s in ipairs(menuStars) do
        s.y = s.y + s.speed
        if s.y > 1.1 then s.y = -0.1; s.x = math.random() * 1.5 - 0.25 end
        local flicker = math.sin(menuTime * 3 + s.twinkle) * 0.3 + 0.7
        local alpha = math.floor(200 * flicker)
        nvgBeginPath(vg)
        nvgCircle(vg, s.x * sw, s.y * sh, s.r)
        nvgFillColor(vg, nvgRGBA(200, 220, 255, alpha))
        nvgFill(vg)
    end

    -- 流星
    local meteorPhase = math.sin(menuTime * 0.7) * 0.5 + 0.5
    if meteorPhase > 0.9 then
        local mx = sw * (0.2 + math.sin(menuTime * 1.3) * 0.3)
        local my = sh * (0.1 + math.cos(menuTime * 0.9) * 0.05)
        local len = 60
        nvgBeginPath(vg)
        nvgMoveTo(vg, mx, my)
        nvgLineTo(vg, mx + len, my + len * 0.4)
        nvgStrokeColor(vg, nvgRGBA(180, 220, 255, math.floor(200 * (meteorPhase - 0.9) * 10)))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)
    end

    -- 中央光晕
    nvgBeginPath(vg)
    nvgCircle(vg, sw / 2, sh * 0.2, 120)
    local glowAlpha = math.floor(20 + math.sin(menuTime * 1.5) * 10)
    local glow = nvgRadialGradient(vg, sw / 2, sh * 0.2, 10, 120,
        nvgRGBA(0, 180, 255, glowAlpha), nvgRGBA(0, 80, 180, 0))
    nvgFillPaint(vg, glow)
    nvgFill(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    local titlePulse = math.sin(menuTime * 2.0) * 0.15 + 0.85
    nvgFontSize(vg, 50)
    nvgFillColor(vg, nvgRGBA(0, 100, 200, math.floor(80 * titlePulse)))
    nvgText(vg, sw / 2 + 1, sh * 0.18 + 2, "星 海 征 途")

    nvgFontSize(vg, 48)
    local tAlpha = math.floor(220 + 35 * math.sin(menuTime * 2.0))
    nvgFillColor(vg, nvgRGBA(0, 220, 255, tAlpha))
    nvgText(vg, sw / 2, sh * 0.18, "星 海 征 途")

    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(140, 160, 200, 180))
    nvgText(vg, sw / 2, sh * 0.18 + 38, "S T A R   S E A   E X P E D I T I O N")

    -- 分隔线
    local lineY = sh * 0.33
    nvgBeginPath(vg)
    nvgMoveTo(vg, sw * 0.25, lineY)
    nvgLineTo(vg, sw * 0.75, lineY)
    nvgStrokeColor(vg, nvgRGBA(60, 120, 180, 80))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 阵营选择
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, 200))
    nvgText(vg, sw / 2, sh * 0.37, "— 选择你的阵营 —")

    local factionIds = { "merchants", "warband", "scholars" }
    local factionNames = { "星际商人联盟", "虚空战团", "远古学者会" }
    local factionIcons = { "💰", "⚔️", "📖" }
    local factionColors = {
        { 50, 200, 150 }, { 220, 80, 80 }, { 150, 100, 255 }
    }
    local cardW = 130
    local cardH = 75
    local gap = 20
    local totalW = 3 * cardW + 2 * gap
    local baseX = (sw - totalW) / 2

    for i = 1, 3 do
        local fx = baseX + (i - 1) * (cardW + gap) + cardW / 2
        local fy = sh * 0.50
        local isSelected = (selectedFaction == factionIds[i])
        local fc = factionColors[i]

        local yOff = 0
        if isSelected then
            yOff = math.sin(menuTime * 3 + i) * 3
        end

        nvgBeginPath(vg)
        nvgRoundedRect(vg, fx - cardW / 2, fy - cardH / 2 + yOff, cardW, cardH, 10)
        if isSelected then
            local cardGrad = nvgLinearGradient(vg, fx, fy - cardH / 2, fx, fy + cardH / 2,
                nvgRGBA(fc[1], fc[2], fc[3], 60), nvgRGBA(fc[1], fc[2], fc[3], 20))
            nvgFillPaint(vg, cardGrad)
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 200))
            nvgStrokeWidth(vg, 2)
        else
            nvgFillColor(vg, nvgRGBA(25, 30, 50, 200))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(60, 70, 100, 120))
            nvgStrokeWidth(vg, 1)
        end
        nvgStroke(vg)

        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        nvgText(vg, fx, fy - 14 + yOff, factionIcons[i])

        nvgFontSize(vg, 13)
        if isSelected then
            nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 255))
        else
            nvgFillColor(vg, rgba(C.text))
        end
        nvgText(vg, fx, fy + 8 + yOff, factionNames[i])

        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(140, 150, 180, 180))
        local f = Data.getFaction(factionIds[i])
        local desc = f and f.desc or ""
        nvgText(vg, fx, fy + 24 + yOff, desc)
    end

    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(120, 140, 170, 160))
    nvgText(vg, sw / 2, sh * 0.67, "点击卡片选择阵营")

    -- 开始按钮
    local btnX = sw / 2
    local btnY = sh * 0.76
    local btnW = 170
    local btnH = 48
    local btnPulse = math.sin(menuTime * 2.5) * 0.2 + 0.8

    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX - btnW / 2 - 4, btnY - 4, btnW + 8, btnH + 8, 12)
    nvgStrokeColor(vg, nvgRGBA(0, 180, 255, math.floor(80 * btnPulse)))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX - btnW / 2, btnY, btnW, btnH, 10)
    local btnGrad = nvgLinearGradient(vg, btnX, btnY, btnX, btnY + btnH,
        nvgRGBA(0, 120, 200, 220), nvgRGBA(0, 80, 160, 220))
    nvgFillPaint(vg, btnGrad)
    nvgFill(vg)

    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 245))
    nvgText(vg, btnX, btnY + btnH / 2, "开 始 征 途")

    -- 每日挑战按钮
    local dcBtnY = btnY + btnH + 16
    local dcBtnW = 140
    local dcBtnH = 36
    local dcBtnX = sw / 2 - dcBtnW / 2
    nvgBeginPath(vg)
    nvgRoundedRect(vg, dcBtnX, dcBtnY, dcBtnW, dcBtnH, 8)
    local dcGrad = nvgLinearGradient(vg, dcBtnX, dcBtnY, dcBtnX, dcBtnY + dcBtnH,
        nvgRGBA(180, 80, 0, 200), nvgRGBA(140, 50, 0, 200))
    nvgFillPaint(vg, dcGrad)
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 160, 40, 150))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 13)
    if dailyChallengeCompleted then
        -- P8.3: 已完成标记
        nvgFillColor(vg, nvgRGBA(120, 200, 80, 240))
        nvgText(vg, sw / 2, dcBtnY + dcBtnH / 2, "✓ 今日已挑战")
    else
        nvgFillColor(vg, nvgRGBA(255, 220, 100, 240))
        nvgText(vg, sw / 2, dcBtnY + dcBtnH / 2, "每日挑战")
    end

    -- 每日挑战修饰符预览
    local dailyMods = Systems.getDailyModifiers()
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 180, 60, 160))
    nvgText(vg, dcBtnX + dcBtnW + 8, dcBtnY + dcBtnH / 2,
        dailyMods[1].name .. " + " .. dailyMods[2].name)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 无尽模式按钮
    local endBtnY = dcBtnY + dcBtnH + 12
    local endBtnW = 140
    local endBtnH = 36
    local endBtnX = sw / 2 - endBtnW / 2
    nvgBeginPath(vg)
    nvgRoundedRect(vg, endBtnX, endBtnY, endBtnW, endBtnH, 8)
    local endGrad = nvgLinearGradient(vg, endBtnX, endBtnY, endBtnX, endBtnY + endBtnH,
        nvgRGBA(80, 0, 160, 200), nvgRGBA(50, 0, 120, 200))
    nvgFillPaint(vg, endGrad)
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 80, 255, 150))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(220, 160, 255, 240))
    nvgText(vg, sw / 2, endBtnY + endBtnH / 2, "∞ 无尽模式")

    -- 无尽模式描述
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 120, 255, 140))
    nvgText(vg, endBtnX + endBtnW + 8, endBtnY + endBtnH / 2, "30天后继续挑战")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 飞船皮肤指示器 (P8.2: 显示锁定状态)
    local skinAreaX = btnX + btnW / 2 + 20
    local skinAreaY = btnY + 8
    local skin = Systems.SHIP_SKINS[selectedSkinIdx or 1]
    if skin then
        -- 检查当前皮肤是否已解锁
        local isUnlocked = (skin.unlock == "default")
        if not isUnlocked and savedAchievements then
            for _, a in ipairs(savedAchievements) do
                if a == skin.unlock then isUnlocked = true; break end
            end
        end

        nvgBeginPath(vg)
        nvgRoundedRect(vg, skinAreaX, skinAreaY, 60, 30, 6)
        nvgFillColor(vg, nvgRGBA(20, 25, 40, 220))
        nvgFill(vg)

        if isUnlocked then
            nvgStrokeColor(vg, nvgRGBA(skin.color[1], skin.color[2], skin.color[3], 180))
        else
            nvgStrokeColor(vg, nvgRGBA(80, 80, 80, 180))
        end
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)

        nvgFontSize(vg, 10)
        if isUnlocked then
            nvgFillColor(vg, nvgRGBA(skin.color[1], skin.color[2], skin.color[3], 230))
            nvgText(vg, skinAreaX + 30, skinAreaY + 15, skin.name)
        else
            nvgFillColor(vg, nvgRGBA(100, 100, 100, 200))
            nvgText(vg, skinAreaX + 30, skinAreaY + 15, "🔒 " .. skin.name)
        end

        -- 切换箭头
        nvgBeginPath(vg)
        nvgRoundedRect(vg, skinAreaX + 64, skinAreaY, 26, 30, 5)
        nvgFillColor(vg, nvgRGBA(40, 50, 70, 200))
        nvgFill(vg)
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(200, 220, 255, 200))
        nvgText(vg, skinAreaX + 77, skinAreaY + 15, ">")

        -- P8.2: 锁定皮肤显示解锁条件
        if not isUnlocked then
            local unlockDesc = ""
            for _, ach in ipairs(Systems.ACHIEVEMENTS) do
                if ach.id == skin.unlock then
                    unlockDesc = ach.icon .. " " .. ach.desc
                    break
                end
            end
            if unlockDesc ~= "" then
                nvgFontSize(vg, 9)
                nvgFillColor(vg, nvgRGBA(200, 160, 60, 180))
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgText(vg, skinAreaX, skinAreaY + 40, "解锁: " .. unlockDesc)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            end
        end
    end

    -- 统计按钮
    local statBtnX = 10
    local statBtnY = sh - 46
    local statBtnW = 80
    local statBtnH = 32
    nvgBeginPath(vg)
    nvgRoundedRect(vg, statBtnX, statBtnY, statBtnW, statBtnH, 6)
    nvgFillColor(vg, nvgRGBA(30, 40, 60, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 140, 200, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(150, 180, 220, 220))
    nvgText(vg, statBtnX + statBtnW / 2, statBtnY + statBtnH / 2, "生涯统计")

    -- 底部按键提示
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(100, 120, 150, 140))
    nvgText(vg, sw / 2, sh * 0.93, "WASD移动 | 鼠标瞄准 | 左键射击 | T科技树 | R中继站 | H劫持 | Q导弹 | V激光 | F盟友")

    -- 版本信息
    nvgFontSize(vg, 9)
    nvgFillColor(vg, nvgRGBA(80, 90, 110, 120))
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    nvgText(vg, sw - 10, sh - 6, "v0.6.0")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

-- ============================================================================
-- 科技树界面
-- ============================================================================
function M.drawTechTree(vg, state, sw, sh)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillColor(vg, nvgRGBA(5, 8, 15, 230))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, rgba(C.text))
    nvgText(vg, sw / 2, 30, "科 技 树")

    local categories = { "武器", "护盾", "引擎", "核心", "权限" }
    local catColors = {
        nvgRGBA(0, 200, 255, 200),
        nvgRGBA(80, 180, 255, 200),
        nvgRGBA(100, 255, 100, 200),
        nvgRGBA(255, 200, 80, 200),
        nvgRGBA(200, 150, 255, 200),
    }
    local colW = sw / 5
    nvgFontSize(vg, 13)

    for ci, cat in ipairs(categories) do
        local cx = (ci - 0.5) * colW
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, catColors[ci])
        nvgText(vg, cx, 65, cat)

        local row = 0
        for _, tech in ipairs(Data.TECH_TREE) do
            if tech.cat == cat then
                row = row + 1
                local ty = 90 + row * 55
                local owned = false
                for _, oid in ipairs(state.ownedTech) do
                    if oid == tech.id then owned = true; break end
                end
                local canBuy = Data.canAfford(tech.cost, state.resources) and Data.requirementsMet(tech, state.ownedTech)

                nvgBeginPath(vg)
                nvgRoundedRect(vg, cx - 55, ty, 110, 45, 4)
                if owned then
                    nvgFillColor(vg, nvgRGBA(0, 80, 60, 160))
                elseif canBuy then
                    nvgFillColor(vg, nvgRGBA(40, 60, 100, 160))
                else
                    nvgFillColor(vg, nvgRGBA(30, 30, 40, 160))
                end
                nvgFill(vg)
                nvgStrokeColor(vg, owned and nvgRGBA(0, 200, 100, 180) or nvgRGBA(60, 70, 90, 120))
                nvgStrokeWidth(vg, 1)
                nvgStroke(vg)

                nvgFontSize(vg, 11)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, owned and nvgRGBA(100, 255, 150, 255) or rgba(C.text))
                nvgText(vg, cx, ty + 14, tech.name)

                nvgFontSize(vg, 9)
                nvgFillColor(vg, rgba(C.textDim))
                if owned then
                    nvgText(vg, cx, ty + 32, "✓ 已研发")
                else
                    local costStr = ""
                    if tech.cost.blueprint then costStr = "图纸:" .. tech.cost.blueprint end
                    if tech.cost.ancient_key then costStr = costStr .. " 密钥:" .. tech.cost.ancient_key end
                    nvgText(vg, cx, ty + 32, costStr)
                end
            end
        end
    end

    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, rgba(C.textDim))
    nvgText(vg, sw / 2, sh - 20, "按 T 关闭科技树 | 点击可购买的科技解锁")
end

-- ============================================================================
-- 游戏结束界面
-- ============================================================================
function M.drawGameOver(vg, state, sw, sh)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillColor(vg, nvgRGBA(5, 5, 10, 230))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    if state.isEndless then
        nvgFontSize(vg, 32)
        nvgFillColor(vg, nvgRGBA(180, 80, 255, 255))
        nvgText(vg, sw / 2, sh * 0.15, "无尽征途终结")
    elseif state.seasonOver then
        nvgFontSize(vg, 32)
        nvgFillColor(vg, nvgRGBA(0, 255, 200, 255))
        nvgText(vg, sw / 2, sh * 0.15, "赛季完成！")
    else
        nvgFontSize(vg, 32)
        nvgFillColor(vg, nvgRGBA(255, 80, 80, 255))
        nvgText(vg, sw / 2, sh * 0.15, "飞船损毁")
    end

    nvgFontSize(vg, 20)
    nvgFillColor(vg, rgba(C.text))
    nvgText(vg, sw / 2, sh * 0.24, string.format("最终得分: %d", state.score))

    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local statY = sh * 0.32
    local lineH = 18
    local stats = {
        { "存活天数", tostring(state.day), C.text },
        { "总击杀", tostring(state.totalKills or 0), { 255, 160, 80 } },
        { "总伤害输出", tostring(math.floor(state.totalDmgDealt or 0)), { 255, 220, 80 } },
        { "总受到伤害", tostring(math.floor(state.totalDmgTaken or 0)), { 255, 100, 100 } },
        { "金属采集", tostring((state.totalCollected or {}).metal or 0), { 180, 180, 220 } },
        { "能源采集", tostring((state.totalCollected or {}).energy or 0), { 100, 255, 100 } },
        { "图纸采集", tostring((state.totalCollected or {}).blueprint or 0), { 200, 150, 255 } },
    }
    local bossKillCount = 0
    for _ in pairs(state.bossesKilled or {}) do bossKillCount = bossKillCount + 1 end
    stats[#stats + 1] = { "Boss击杀", tostring(bossKillCount), { 255, 40, 100 } }
    stats[#stats + 1] = { "任务完成", tostring(#(state.completedQuests or {})), { 0, 255, 200 } }

    for i, s in ipairs(stats) do
        local y = statY + (i - 1) * lineH
        nvgFillColor(vg, rgba(C.textDim))
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, sw / 2 - 10, y, s[1])
        nvgFillColor(vg, nvgRGBA(s[3][1], s[3][2], s[3][3], 255))
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(vg, sw / 2 + 10, y, s[2])
    end

    -- 评分
    local rating = "D"
    local sc = state.score
    if sc >= 15000 then rating = "S"
    elseif sc >= 10000 then rating = "A"
    elseif sc >= 6000 then rating = "B"
    elseif sc >= 3000 then rating = "C"
    end
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 40)
    local ratingColors = { S = { 255, 215, 0 }, A = { 0, 255, 200 }, B = { 100, 200, 255 }, C = { 200, 200, 200 }, D = { 150, 150, 150 } }
    local rc = ratingColors[rating] or ratingColors.D
    nvgFillColor(vg, nvgRGBA(rc[1], rc[2], rc[3], 255))
    nvgText(vg, sw / 2, sh * 0.76, rating)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, rgba(C.textDim))
    nvgText(vg, sw / 2, sh * 0.76 + 24, "综合评价")

    -- P8.4: 分享卡片边框装饰（让整个画面成为可截图分享的卡片）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, sw * 0.05, sh * 0.04, sw * 0.9, sh * 0.72, 12)
    nvgStrokeWidth(vg, 1.5)
    local borderGrad = nvgLinearGradient(vg, sw * 0.05, sh * 0.04, sw * 0.95, sh * 0.76,
        nvgRGBA(0, 200, 255, 60), nvgRGBA(180, 80, 255, 60))
    nvgStrokePaint(vg, borderGrad)
    nvgStroke(vg)

    -- 卡片底部水印
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 9)
    nvgFillColor(vg, nvgRGBA(100, 120, 160, 100))
    nvgText(vg, sw / 2, sh * 0.78, "⭐ 星海征途 · 战绩卡片 ⭐")

    -- 重新开始按钮
    nvgBeginPath(vg)
    nvgRoundedRect(vg, sw / 2 - 70, sh * 0.84, 140, 36, 6)
    nvgFillColor(vg, nvgRGBA(0, 140, 200, 200))
    nvgFill(vg)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 15)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
    nvgText(vg, sw / 2, sh * 0.84 + 18, "再次出发")

    nvgFontSize(vg, 11)
    nvgFillColor(vg, rgba(C.textDim))
    nvgText(vg, sw / 2, sh * 0.93, "截图分享你的战绩 · 点击按钮返回")
end

-- ============================================================================
-- 活跃加成状态条
-- ============================================================================
function M.drawActivePowerups(vg, state, sw, sh)
    if #state.activePowerups == 0 then return end
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    local x = 10
    local y = sh - 30
    for i, ap in ipairs(state.activePowerups) do
        local def = Data.POWERUP_TYPES[ap.kind]
        if def then
            local ratio = ap.remaining / (def.duration or 1)
            local barW = 60
            nvgBeginPath(vg)
            nvgRoundedRect(vg, x, y, barW, 14, 3)
            nvgFillColor(vg, nvgRGBA(20, 20, 30, 180))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, x, y, barW * ratio, 14, 3)
            nvgFillColor(vg, nvgRGBA(def.color[1], def.color[2], def.color[3], 180))
            nvgFill(vg)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
            nvgText(vg, x + 3, y + 7, def.icon .. " " .. string.format("%.0f", ap.remaining))
            x = x + 70
        end
    end
end

-- ============================================================================
-- 排行榜界面
-- ============================================================================
function M.drawLeaderboard(vg, sw, sh, leaderboard)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    local bgGrad = nvgLinearGradient(vg, 0, 0, 0, sh,
        nvgRGBA(6, 8, 24, 255), nvgRGBA(12, 6, 28, 255))
    nvgFillPaint(vg, bgGrad)
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgFontSize(vg, 32)
    nvgFillColor(vg, nvgRGBA(255, 215, 0, 240))
    nvgText(vg, sw / 2, 50, "🏆 星海排行榜")

    nvgFontSize(vg, 14)
    if leaderboard.myRank then
        nvgFillColor(vg, nvgRGBA(0, 220, 255, 200))
        nvgText(vg, sw / 2, 85, string.format("我的排名: #%d  最高分: %d", leaderboard.myRank, leaderboard.myBest))
    else
        nvgFillColor(vg, nvgRGBA(140, 150, 180, 160))
        nvgText(vg, sw / 2, 85, "完成一局游戏即可上榜")
    end

    nvgBeginPath(vg)
    nvgMoveTo(vg, sw * 0.2, 105)
    nvgLineTo(vg, sw * 0.8, 105)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 160, 80))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    if leaderboard.loading then
        nvgFontSize(vg, 18)
        nvgFillColor(vg, nvgRGBA(180, 200, 230, 180))
        nvgText(vg, sw / 2, sh * 0.45, "加载中...")
    elseif #leaderboard.rankList == 0 then
        nvgFontSize(vg, 16)
        nvgFillColor(vg, nvgRGBA(140, 150, 180, 160))
        nvgText(vg, sw / 2, sh * 0.45, "暂无数据，快去闯关吧！")
    else
        local startY = 125
        local rowH = 36

        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(140, 160, 200, 160))
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(vg, sw * 0.15, startY, "排名")
        nvgText(vg, sw * 0.28, startY, "玩家")
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, sw * 0.72, startY, "分数")
        nvgText(vg, sw * 0.88, startY, "场次")

        for i, entry in ipairs(leaderboard.rankList) do
            local y = startY + i * rowH
            if y > sh - 60 then break end

            local rankColors = {
                { 255, 215, 0 },
                { 200, 200, 210 },
                { 205, 127, 50 },
            }
            local rc = rankColors[i] or { 180, 200, 230 }

            if i % 2 == 0 then
                nvgBeginPath(vg)
                nvgRect(vg, sw * 0.1, y - rowH / 2 + 2, sw * 0.8, rowH - 4)
                nvgFillColor(vg, nvgRGBA(30, 40, 60, 60))
                nvgFill(vg)
            end

            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 16)
            nvgFillColor(vg, nvgRGBA(rc[1], rc[2], rc[3], 240))
            local rankStr = (i <= 3) and ({ "🥇", "🥈", "🥉" })[i] or ("#" .. i)
            nvgText(vg, sw * 0.15, y, rankStr)

            nvgFontSize(vg, 13)
            nvgFillColor(vg, nvgRGBA(220, 230, 255, 220))
            local displayName = entry.nickname or ("玩家" .. i)
            if #displayName > 12 then displayName = displayName:sub(1, 12) .. ".." end
            nvgText(vg, sw * 0.28, y, displayName)

            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 14)
            nvgFillColor(vg, nvgRGBA(0, 220, 200, 240))
            nvgText(vg, sw * 0.72, y, tostring(entry.score))

            nvgFontSize(vg, 12)
            nvgFillColor(vg, nvgRGBA(140, 160, 200, 160))
            nvgText(vg, sw * 0.88, y, tostring(entry.playCount or 0))
        end
    end

    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(100, 120, 150, 140))
    nvgText(vg, sw / 2, sh - 30, "按 ESC 或 L 返回")
end

-- ============================================================================
-- 随机事件选择弹窗
-- ============================================================================
function M.drawEventChoice(vg, state, sw, sh)
    local ec = state.eventChoice
    if not ec then return end

    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
    nvgFill(vg)

    local anim = math.min(1, state.eventChoiceAnim * 3)
    local scale = 0.5 + 0.5 * anim
    local popAlpha = math.floor(anim * 255)

    local popW = 320 * scale
    local popH = 220 * scale
    local popX = (sw - popW) / 2
    local popY = (sh - popH) / 2

    -- P7.3: 特殊事件使用事件自带颜色
    local ecColor = ec.color or { 60, 120, 200 }
    local isSpecial = state.eventIsSpecial

    nvgBeginPath(vg)
    nvgRoundedRect(vg, popX, popY, popW, popH, 12 * scale)
    local bgGrad
    if isSpecial then
        bgGrad = nvgLinearGradient(vg, popX, popY, popX, popY + popH,
            nvgRGBA(30, 15, 50, popAlpha), nvgRGBA(15, 8, 35, popAlpha))
    else
        bgGrad = nvgLinearGradient(vg, popX, popY, popX, popY + popH,
            nvgRGBA(20, 25, 50, popAlpha), nvgRGBA(10, 12, 30, popAlpha))
    end
    nvgFillPaint(vg, bgGrad)
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(ecColor[1], ecColor[2], ecColor[3], math.floor(popAlpha * 0.85)))
    nvgStrokeWidth(vg, isSpecial and 3 or 2)
    nvgStroke(vg)

    if anim < 0.8 then return end

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, isSpecial and 20 or 18)
    nvgFillColor(vg, nvgRGBA(ecColor[1], ecColor[2], ecColor[3], popAlpha))
    local prefix = isSpecial and "⚡ " or "◈ "
    nvgText(vg, sw / 2, popY + 30, prefix .. (ec.title or "事件"))

    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, math.floor(popAlpha * 0.8)))
    nvgText(vg, sw / 2, popY + 55, ec.desc or "")

    local optY = popY + 85
    local btnW = popW * 0.8
    local btnH = 50
    local btnGap = 12

    for i, opt in ipairs(ec.options) do
        local bx = (sw - btnW) / 2
        local by = optY + (i - 1) * (btnH + btnGap)

        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, btnW, btnH, 8)
        local optGrad = nvgLinearGradient(vg, bx, by, bx + btnW, by,
            nvgRGBA(30, 60, 100, math.floor(popAlpha * 0.8)),
            nvgRGBA(20, 40, 70, math.floor(popAlpha * 0.8)))
        nvgFillPaint(vg, optGrad)
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 160, 255, math.floor(popAlpha * 0.5)))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 240, 255, popAlpha))
        nvgText(vg, sw / 2, by + 18, opt.label or "")

        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(140, 180, 220, math.floor(popAlpha * 0.7)))
        nvgText(vg, sw / 2, by + 36, opt.desc or "")
    end

    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(100, 130, 170, math.floor(popAlpha * 0.5)))
    nvgText(vg, sw / 2, popY + popH - 12, "点击选项做出选择")
end

-- ============================================================================
-- 盟友模式指示器
-- ============================================================================
-- ============================================================================
-- 副武器 HUD（显示当前副武器 + 冷却指示）
-- ============================================================================
function M.drawSecondaryWeaponHUD(vg, state, sw, sh)
    local Combat = require("game.Combat")
    local unlocked = Combat.getUnlockedSecondaries(state)
    if #unlocked == 0 then return end

    local weapons = Data.SECONDARY_WEAPONS
    local curIdx = state.secondaryIdx or 1
    local curWeapon = weapons[curIdx]
    if not curWeapon then return end

    -- 位置：左侧，资源面板上方
    local baseX = 20
    local baseY = sh - 120

    -- 背景面板
    local panelW = 130
    local panelH = 36
    nvgBeginPath(vg)
    nvgRoundedRect(vg, baseX, baseY, panelW, panelH, 4)
    nvgFillColor(vg, nvgRGBA(15, 20, 35, 200))
    nvgFill(vg)

    -- 武器颜色
    local wc = curWeapon.color

    -- 冷却比例
    local cdRatio = 0
    if state.secondaryCd and state.secondaryCd > 0 then
        cdRatio = math.min(1, state.secondaryCd / curWeapon.cooldown)
    end

    -- 冷却条背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, baseX, baseY + panelH - 4, panelW, 4, 2)
    nvgFillColor(vg, nvgRGBA(30, 30, 50, 200))
    nvgFill(vg)

    -- 冷却条（从满到空表示冷却中）
    if cdRatio > 0 then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, baseX, baseY + panelH - 4, panelW * (1 - cdRatio), 4, 2)
        nvgFillColor(vg, nvgRGBA(wc[1], wc[2], wc[3], 200))
        nvgFill(vg)
    else
        -- 就绪 - 满条
        nvgBeginPath(vg)
        nvgRoundedRect(vg, baseX, baseY + panelH - 4, panelW, 4, 2)
        nvgFillColor(vg, nvgRGBA(wc[1], wc[2], wc[3], 220))
        nvgFill(vg)
    end

    -- 武器图标（小彩色圆）
    nvgBeginPath(vg)
    nvgCircle(vg, baseX + 14, baseY + 15, 6)
    nvgFillColor(vg, nvgRGBA(wc[1], wc[2], wc[3], cdRatio > 0 and 120 or 240))
    nvgFill(vg)

    -- 武器名称
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 230, 255, cdRatio > 0 and 120 or 230))
    nvgText(vg, baseX + 26, baseY + 12, curWeapon.name)

    -- 操作提示
    nvgFontSize(vg, 9)
    nvgFillColor(vg, nvgRGBA(140, 150, 180, 140))
    nvgText(vg, baseX + 26, baseY + 26, "Space发射 | Tab切换")

    -- 就绪/冷却状态
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 10)
    if cdRatio > 0 then
        nvgFillColor(vg, nvgRGBA(180, 100, 100, 180))
        nvgText(vg, baseX + panelW - 6, baseY + 12, string.format("%.1fs", state.secondaryCd))
    else
        nvgFillColor(vg, nvgRGBA(80, 255, 120, 200))
        nvgText(vg, baseX + panelW - 6, baseY + 12, "就绪")
    end

    -- 边框高亮（就绪时）
    if cdRatio <= 0 then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, baseX, baseY, panelW, panelH, 4)
        nvgStrokeColor(vg, nvgRGBA(wc[1], wc[2], wc[3], 80))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
    end
end

function M.drawAllyModeIndicator(vg, state, sw, sh)
    if #state.allies == 0 then return end

    local modeLabels = { attack = "攻击", follow = "跟随", guard = "护卫" }
    local modeColors = {
        attack = { 255, 80, 80 },
        follow = { 80, 200, 255 },
        guard = { 255, 200, 0 },
    }
    local mode = state.allyMode or "attack"
    local label = modeLabels[mode] or "攻击"
    local color = modeColors[mode] or { 255, 80, 80 }

    local x = 20
    local y = 78

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], 200))
    nvgText(vg, x, y, string.format("友军[F]: %s (%d)", label, #state.allies))
end

-- ============================================================================
-- Combo 连击 HUD
-- ============================================================================
function M.drawCombo(vg, state, sw, sh)
    local c = Systems.combo
    if c.count < 2 then return end

    local cx = sw * 0.5
    local cy = 50
    local scale = 1.0 + c.displayTimer * 0.5
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgFontSize(vg, math.floor(28 * scale))
    local comboAlpha = math.floor(200 + c.displayTimer * 55)
    nvgFillColor(vg, nvgRGBA(255, 200, 50, math.min(255, comboAlpha)))
    nvgText(vg, cx, cy, string.format("%dx COMBO", c.count))

    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(255, 150, 0, 200))
    nvgText(vg, cx, cy + 20, string.format("x%.1f 分数倍率", c.multiplier))

    local barW = 100
    local barH = 4
    local ratio = c.timer / c.maxTimer
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - barW / 2, cy + 32, barW, barH, 2)
    nvgFillColor(vg, nvgRGBA(40, 40, 60, 160))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - barW / 2, cy + 32, barW * ratio, barH, 2)
    local rg = ratio > 0.3 and 255 or 255
    local gg = ratio > 0.3 and 200 or 60
    nvgFillColor(vg, nvgRGBA(rg, gg, 0, 220))
    nvgFill(vg)
end

-- ============================================================================
-- 遗物槽位 UI
-- ============================================================================
function M.drawRelicSlots(vg, state, sw, sh)
    local relics = state.relics
    if not relics or #relics == 0 then return end

    local startX = 20
    local startY = sh - 120
    local slotSize = 28
    local gap = 4

    nvgFontFace(vg, "sans")
    for i, relicId in ipairs(relics) do
        local x = startX + (i - 1) * (slotSize + gap)
        local y = startY
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, y, slotSize, slotSize, 4)
        nvgFillColor(vg, nvgRGBA(30, 20, 50, 200))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 120, 255, 150))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
        local relicDef = nil
        for _, r in ipairs(Systems.RELICS or {}) do
            if r.id == relicId then relicDef = r; break end
        end
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
        nvgText(vg, x + slotSize / 2, y + slotSize / 2, relicDef and relicDef.icon or "?")
    end

    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(180, 120, 255, 160))
    nvgText(vg, startX, startY - 12, "遗物")
end

-- ============================================================================
-- 统计面板
-- ============================================================================
function M.drawStats(vg, sw, sh, stats)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillColor(vg, nvgRGBA(8, 10, 24, 250))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgFontSize(vg, 32)
    nvgFillColor(vg, nvgRGBA(0, 200, 255, 230))
    nvgText(vg, sw / 2, sh * 0.08, "生涯统计")

    local items = {
        { "总局数", stats.totalGames },
        { "总击杀", stats.totalKills },
        { "总得分", stats.totalScore },
        { "总存活天数", stats.totalDays },
        { "最高单局分数", stats.bestScore },
        { "最长连击", stats.bestCombo },
        { "最长存活天", stats.bestDay },
        { "Boss击杀数", stats.bossKills },
        { "采集金属总量", stats.totalMetalCollected },
        { "采集能源总量", stats.totalEnergyCollected },
    }

    local startY = sh * 0.18
    local rowH = (sh * 0.72) / #items

    for i, item in ipairs(items) do
        local y = startY + (i - 1) * rowH + rowH / 2

        if i % 2 == 0 then
            nvgBeginPath(vg)
            nvgRect(vg, sw * 0.15, y - rowH / 2 + 2, sw * 0.7, rowH - 4)
            nvgFillColor(vg, nvgRGBA(20, 30, 50, 80))
            nvgFill(vg)
        end

        nvgFontSize(vg, 15)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 180, 210, 200))
        nvgText(vg, sw * 0.2, y, item[1])

        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(0, 220, 255, 255))
        nvgFontSize(vg, 16)
        nvgText(vg, sw * 0.8, y, tostring(item[2]))
    end

    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(100, 120, 150, 160))
    nvgText(vg, sw / 2, sh * 0.95, "按 ESC 返回")
end

return M
