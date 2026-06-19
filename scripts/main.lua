-- ============================================================================
-- 星海征途 (Star Sea Expedition) - 主入口
-- NanoVG 2D 太空射击探索游戏
-- ============================================================================

require "LuaScripts/Utilities/Sample"

local Core = require("game.Core")
local Render = require("game.Render")
local Data = require("game.Data")
local Leaderboard = require("game.Leaderboard")
local Sprites = require("game.Sprites")
local GameAudio = require("game.Audio")
local Systems = require("game.Systems")
local SaveSystem = require("game.SaveSystem")
local S = require("game.Strings")

-- ============================================================================
-- 全局变量
-- ============================================================================
---@type NVGContextWrapper
local vg = nil
local fontNormal = -1

-- 游戏状态机
local STATE_MENU = "menu"
local STATE_GAME = "game"
local STATE_TECH = "tech"
local STATE_OVER = "gameover"
local STATE_RANK = "leaderboard"
local STATE_STATS = "stats"

local currentState = STATE_MENU
local gameState = nil

-- 菜单状态
local selectedFaction = "merchants"
local selectedSkinIdx = 1       -- 飞船皮肤索引
local isDailyChallenge = false  -- 当前是否每日挑战模式
local isWeeklyChallenge = false -- 当前是否每周挑战模式
local isEndless = false         -- 当前是否无尽模式
local dailyChallengeCompleted = false  -- P8.3: 今日挑战是否已完成
local dailyChallengeScore = 0          -- P8.3: 今日挑战分数
local persistentStats = Systems.initPersistentStats()  -- 永久统计
local savedAchievements = {}    -- 持久化成就列表（跨局保留）

-- 屏幕尺寸
local screenW = 0
local screenH = 0

-- 输入状态
local mouseX, mouseY = 0, 0
local mousePressed = false
local mouseJustPressed = false

-- 广告复活状态
local adReviveUsed = false       -- 本局是否已使用过广告复活
local showRevivePrompt = false   -- 是否显示复活提示
local reviveCountdown = 10.0     -- 复活倒计时（秒）

-- 永久升级系统
local playerUpgrades = Systems.initUpgrades()  -- 升级等级表
local starDust = 0                             -- 星尘（升级货币）
local STATE_UPGRADE = "upgrade"                -- 升级界面状态
local adDoubleUsed = false                     -- 本局是否已使用广告双倍星尘

-- ============================================================================
-- Start() - 引擎入口
-- ============================================================================
function Start()
    -- NanoVG 上下文
    vg = nvgCreate(1)  -- 1 = NVG_ANTIALIAS
    if not vg then
        log:Write(LOG_ERROR, "Failed to create NanoVG context")
        return
    end

    -- 创建字体
    fontNormal = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
    if fontNormal < 0 then
        log:Write(LOG_ERROR, "Failed to load font")
    end

    -- 初始化精灵贴图
    Sprites.init(vg)

    -- 获取屏幕尺寸
    screenW = graphics:GetWidth()
    screenH = graphics:GetHeight()

    -- 订阅事件
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")

    -- 初始化排行榜
    Leaderboard.init()

    -- 初始化音效系统
    GameAudio.init()

    -- P8.1: 加载本地存档
    local loadedData = SaveSystem.load()
    if loadedData then
        local restored = SaveSystem.applyLoadedData(loadedData)
        persistentStats = restored.stats
        savedAchievements = restored.achievements
        selectedSkinIdx = restored.selectedSkin
        playerUpgrades = restored.upgrades
        starDust = restored.starDust
        log:Write(LOG_INFO, "[SaveSystem] Restored: games=" .. persistentStats.totalGames
            .. " achievements=" .. #savedAchievements .. " skin=" .. selectedSkinIdx
            .. " starDust=" .. starDust)
    end

    -- P8.3: 检查今日是否已完成每日挑战
    local todayFlag = SaveSystem.loadDailyFlag(os.date("%Y%m%d"))
    if todayFlag then
        dailyChallengeCompleted = true
        dailyChallengeScore = todayFlag.score or 0
    end

    log:Write(LOG_INFO, "[StarSea] Game initialized, screen: " .. screenW .. "x" .. screenH)
end

-- ============================================================================
-- 事件处理
-- ============================================================================

---@param eventType string
---@param eventData ScreenModeEventData
function HandleScreenMode(eventType, eventData)
    screenW = eventData:GetInt("Width")
    screenH = eventData:GetInt("Height")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")

    -- P9: 音频系统每帧更新（处理BGM crossfade）
    GameAudio.update(dt)

    -- P9: 动态BGM切换
    if currentState == STATE_MENU then
        GameAudio.setBGM("cruise")
    elseif currentState == STATE_GAME and gameState then
        -- 根据游戏阶段切换BGM
        local hasBoss = false
        for _, e in ipairs(gameState.enemies or {}) do
            if e.isBoss then hasBoss = true; break end
        end
        if hasBoss then
            GameAudio.setBGM("boss")
        elseif #(gameState.enemies or {}) > 3 then
            GameAudio.setBGM("battle")
        else
            GameAudio.setBGM("cruise")
        end
    elseif currentState == STATE_OVER then
        GameAudio.setBGM("")
    end

    if currentState == STATE_GAME and gameState then
        -- 构建输入
        local dpr = graphics:GetDPR()
        local logW = screenW / dpr
        local logH = screenH / dpr
        -- 鼠标屏幕坐标 → 世界坐标（用于瞄准）
        local aimWorldX = (mouseX / dpr) - logW * 0.5 + gameState.cam.x
        local aimWorldY = (mouseY / dpr) - logH * 0.5 + gameState.cam.y
        local inp = {
            up = false, down = false, left = false, right = false,
            aimX = aimWorldX, aimY = aimWorldY,
            fire = input:GetMouseButtonDown(MOUSEB_LEFT) or mousePressed,
            screenW = logW, screenH = logH,
        }

        -- WASD
        if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then inp.up = true end
        if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then inp.down = true end
        if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then inp.left = true end
        if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then inp.right = true end

        -- 更新游戏
        Core.update(gameState, dt, inp)

        -- 复活倒计时更新
        if showRevivePrompt then
            reviveCountdown = reviveCountdown - dt
            if reviveCountdown <= 0 then
                -- 倒计时结束，跳过复活
                showRevivePrompt = false
            end
        end

        -- 检查死亡
        if gameState.player.hp <= 0 or gameState.seasonOver then
            -- 如果是玩家死亡（非30天赛季自然结束）且未用过复活，显示复活提示
            if not adReviveUsed and gameState.playerDied and not showRevivePrompt then
                showRevivePrompt = true
                reviveCountdown = 10.0
                return  -- 暂停，等待玩家选择
            end
            if showRevivePrompt then
                return  -- 仍在等待玩家选择
            end
            currentState = STATE_OVER
            -- 更新永久统计
            Systems.updatePersistentStats(persistentStats, gameState)
            -- P8.1: 合并本局成就到持久化列表
            for _, achId in ipairs(gameState.achievements or {}) do
                local found = false
                for _, saved in ipairs(savedAchievements) do
                    if saved == achId then found = true; break end
                end
                if not found then
                    savedAchievements[#savedAchievements + 1] = achId
                end
            end
            -- 发放星尘
            local earnedDust = Systems.calcStarDust(gameState)
            starDust = starDust + earnedDust
            gameState._earnedStarDust = earnedDust  -- 存到state供结算UI显示
            -- P8.1: 保存存档
            SaveSystem.save(persistentStats, savedAchievements, selectedSkinIdx, playerUpgrades, starDust)
            -- 提交分数到云端排行榜
            if gameState.isDailyChallenge then
                -- P8.3: 每日挑战使用日期key的独立排行榜
                local dailyKey = "daily_" .. os.date("%Y%m%d")
                Leaderboard.submitScore(gameState.score, dailyKey)
                -- 记录今日已挑战
                dailyChallengeCompleted = true
                dailyChallengeScore = gameState.score
                -- 保存到存档
                SaveSystem.saveDailyFlag(os.date("%Y%m%d"), gameState.score)
            elseif gameState.isWeeklyChallenge then
                local weekKey = "weekly_" .. math.floor(os.time() / (7 * 24 * 3600))
                Leaderboard.submitScore(gameState.score, weekKey)
            elseif gameState.isEndless then
                Leaderboard.submitScore(gameState.score, "endless_score")
            else
                Leaderboard.submitScore(gameState.score)
            end
            isDailyChallenge = false
            isWeeklyChallenge = false
            isEndless = false
        end
    end

    -- 重置 mouseJustPressed
    mouseJustPressed = false
end

---@param eventType string
---@param eventData MouseButtonDownEventData
function HandleMouseDown(eventType, eventData)
    local button = eventData:GetInt("Button")
    if button == MOUSEB_LEFT then
        mousePressed = true
        mouseJustPressed = true
        HandleClick(mouseX, mouseY)
    end
end

---@param eventType string
---@param eventData MouseButtonUpEventData
function HandleMouseUp(eventType, eventData)
    local button = eventData:GetInt("Button")
    if button == MOUSEB_LEFT then
        mousePressed = false
    end
end

---@param eventType string
---@param eventData MouseMoveEventData
function HandleMouseMove(eventType, eventData)
    mouseX = eventData:GetInt("X")
    mouseY = eventData:GetInt("Y")
end

-- 触摸事件：桥接到鼠标状态，支持手机操作
function HandleTouchBegin(eventType, eventData)
    mouseX = eventData:GetInt("X")
    mouseY = eventData:GetInt("Y")
    mousePressed = true
    mouseJustPressed = true
    HandleClick(mouseX, mouseY)
end

function HandleTouchMove(eventType, eventData)
    mouseX = eventData:GetInt("X")
    mouseY = eventData:GetInt("Y")
end

function HandleTouchEnd(eventType, eventData)
    mousePressed = false
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData:GetInt("Key")

    if currentState == STATE_GAME then
        if key == KEY_T then
            -- 切换科技树
            currentState = STATE_TECH
        elseif key == KEY_R then
            -- 建造中继站
            if gameState then
                Core.buildRelay(gameState)
            end
        elseif key == KEY_H then
            -- 劫持敌人（权限系统）
            if gameState then
                Core.attemptHijack(gameState)
            end
        elseif key == KEY_F then
            -- 切换盟友模式（攻击/跟随/护卫）
            if gameState then
                Core.cycleAllyMode(gameState)
            end
        elseif key == KEY_Q then
            -- 发射追踪导弹
            if gameState then
                Core.fireMissile(gameState)
            end
        elseif key == KEY_V then
            -- 激光武器开关
            if gameState then
                Core.toggleLaser(gameState)
            end
        elseif key == KEY_TAB then
            -- 切换副武器
            if gameState then
                Core.switchSecondary(gameState)
            end
        elseif key == KEY_SPACE then
            -- 发射副武器
            if gameState then
                Core.fireSecondary(gameState)
            end
        end
    elseif currentState == STATE_TECH then
        if key == KEY_T or key == KEY_ESCAPE then
            currentState = STATE_GAME
        end
    elseif currentState == STATE_OVER then
        if key == KEY_ESCAPE then
            currentState = STATE_MENU
        elseif key == KEY_L then
            Leaderboard.fetchRankList()
            currentState = STATE_RANK
        end
    elseif currentState == STATE_RANK then
        if key == KEY_ESCAPE or key == KEY_L then
            currentState = STATE_MENU
        end
    elseif currentState == STATE_STATS then
        if key == KEY_ESCAPE then
            currentState = STATE_MENU
        end
    elseif currentState == STATE_UPGRADE then
        if key == KEY_ESCAPE then
            currentState = STATE_MENU
        end
    end

    -- 从菜单进入排行榜/统计
    if currentState == STATE_MENU and key == KEY_L then
        GameAudio.playClick()
        Leaderboard.fetchRankList()
        currentState = STATE_RANK
    end
end

-- ============================================================================
-- 点击处理
-- ============================================================================
function HandleClick(cx, cy)
    if currentState == STATE_MENU then
        -- 检测阵营卡片点击（匹配新布局: cardW=130, gap=20, centered）
        local factionIds = { "merchants", "warband", "scholars" }
        local cardW = 130
        local cardH = 75
        local gap = 20
        local totalW = 3 * cardW + 2 * gap
        local baseX = (screenW - totalW) / 2
        local fy = screenH * 0.50
        for i = 1, 3 do
            local fx = baseX + (i - 1) * (cardW + gap) + cardW / 2
            if cx > fx - cardW / 2 and cx < fx + cardW / 2 and cy > fy - cardH / 2 and cy < fy + cardH / 2 then
                selectedFaction = factionIds[i]
                GameAudio.playClick()
                return
            end
        end

        -- 检测开始按钮（匹配新布局: btnW=170, btnH=48）
        local btnX = screenW / 2 - 85
        local btnY = screenH * 0.76
        if cx > btnX and cx < btnX + 170 and cy > btnY and cy < btnY + 48 then
            isDailyChallenge = false
            isEndless = false
            StartGame()
        end

        -- 每日挑战按钮（开始按钮下方: btnH=48 + gap=16）
        local dcBtnY = screenH * 0.76 + 64
        local dcBtnW = 140
        local dcBtnH2 = 36
        local dcBtnX = screenW / 2 - dcBtnW / 2
        if cx > dcBtnX and cx < dcBtnX + dcBtnW and cy > dcBtnY and cy < dcBtnY + dcBtnH2 then
            isDailyChallenge = true
            isEndless = false
            StartGame()
        end

        -- 无尽模式按钮（每日挑战按钮下方）
        local endBtnY = dcBtnY + dcBtnH2 + 12
        local endBtnW = 140
        local endBtnH3 = 36
        local endBtnX = screenW / 2 - endBtnW / 2
        if cx > endBtnX and cx < endBtnX + endBtnW and cy > endBtnY and cy < endBtnY + endBtnH3 then
            isDailyChallenge = false
            isWeeklyChallenge = false
            isEndless = true
            StartGame()
        end

        -- 每周挑战按钮（无尽模式按钮下方）
        local wkBtnY = endBtnY + endBtnH3 + 12
        local wkBtnW = 140
        local wkBtnH4 = 36
        local wkBtnX = screenW / 2 - wkBtnW / 2
        if cx > wkBtnX and cx < wkBtnX + wkBtnW and cy > wkBtnY and cy < wkBtnY + wkBtnH4 then
            isDailyChallenge = false
            isWeeklyChallenge = true
            isEndless = false
            StartGame()
        end

        -- 统计按钮（左下角）
        local statBtnX = 10
        local statBtnY = screenH - 46
        if cx > statBtnX and cx < statBtnX + 80 and cy > statBtnY and cy < statBtnY + 32 then
            GameAudio.playClick()
            currentState = STATE_STATS
        end

        -- 升级按钮（右下角）
        local upgBtnX = screenW - 90
        local upgBtnY = screenH - 46
        if cx > upgBtnX and cx < upgBtnX + 80 and cy > upgBtnY and cy < upgBtnY + 32 then
            GameAudio.playClick()
            currentState = STATE_UPGRADE
        end

        -- 皮肤切换箭头（开始按钮右侧: btnX中心+85+20=105, 箭头在+64偏移处）
        local skinArrowX = screenW / 2 + 105 + 64
        local skinArrowY = screenH * 0.76 + 8
        if cx > skinArrowX and cx < skinArrowX + 26 and cy > skinArrowY and cy < skinArrowY + 30 then
            -- P8.2: 只循环已解锁的皮肤
            local unlockedSkins = Systems.getUnlockedSkins(savedAchievements)
            if #unlockedSkins > 1 then
                -- 找到当前皮肤在解锁列表中的位置
                local curIdx = 1
                for i, s in ipairs(unlockedSkins) do
                    if s.id == Systems.SHIP_SKINS[selectedSkinIdx].id then
                        curIdx = i
                        break
                    end
                end
                -- 切换到下一个解锁皮肤
                local nextIdx = curIdx % #unlockedSkins + 1
                -- 找到它在全局列表中的索引
                for i, s in ipairs(Systems.SHIP_SKINS) do
                    if s.id == unlockedSkins[nextIdx].id then
                        selectedSkinIdx = i
                        GameAudio.playClick()
                        break
                    end
                end
            end
        end

    elseif currentState == STATE_GAME then
        -- 广告复活弹窗点击检测
        if showRevivePrompt then
            local dpr = graphics:GetDPR()
            local sw = screenW / dpr
            local sh = screenH / dpr
            local lcx = cx / dpr
            local lcy = cy / dpr
            -- 弹窗尺寸与渲染一致
            local popW = 280
            local popH = 200
            local popX = (sw - popW) / 2
            local popY = (sh - popH) / 2
            -- "看广告复活" 按钮
            local adBtnW = popW * 0.7
            local adBtnH = 44
            local adBtnX = (sw - adBtnW) / 2
            local adBtnY = popY + 110
            if lcx > adBtnX and lcx < adBtnX + adBtnW and lcy > adBtnY and lcy < adBtnY + adBtnH then
                GameAudio.playClick()
                -- 调用激励视频广告
                ---@diagnostic disable-next-line: undefined-global
                sdk:ShowRewardVideoAd(function(result)
                    if result.success then
                        -- 广告观看成功，复活玩家
                        showRevivePrompt = false
                        adReviveUsed = true
                        if gameState then
                            gameState.player.hp = math.ceil(gameState.player.hpMax * 0.5)
                            gameState.seasonOver = false  -- 重置结束标记
                            gameState.playerDied = false  -- 重置死亡标记
                            log:Write(LOG_INFO, "[StarSea] Ad revive: HP restored to " .. gameState.player.hp)
                        end
                    else
                        -- 广告观看失败/取消，跳过复活
                        log:Write(LOG_INFO, "[StarSea] Ad revive cancelled: " .. (result.msg or "unknown"))
                        showRevivePrompt = false
                    end
                end)
                return
            end
            -- "跳过" 按钮
            local skipBtnW = popW * 0.5
            local skipBtnH = 32
            local skipBtnX = (sw - skipBtnW) / 2
            local skipBtnY = adBtnY + adBtnH + 14
            if lcx > skipBtnX and lcx < skipBtnX + skipBtnW and lcy > skipBtnY and lcy < skipBtnY + skipBtnH then
                GameAudio.playClick()
                showRevivePrompt = false
                return
            end
            return  -- 复活弹窗显示时，屏蔽其他游戏点击
        end

        -- 事件选择弹窗点击检测（与 RenderUI.drawEventChoice 布局一致）
        if gameState and gameState.eventChoice then
            local dpr = graphics:GetDPR()
            local sw = screenW / dpr
            local sh = screenH / dpr
            local ec = gameState.eventChoice
            -- 弹窗尺寸（动画完成后 scale=1）
            local anim = math.min(1, (gameState.eventChoiceAnim or 0) * 3)
            if anim >= 0.8 then
                local scale = 0.5 + 0.5 * anim
                local popW = 320 * scale
                local popH = 220 * scale
                local popX = (sw - popW) / 2
                local popY = (sh - popH) / 2
                -- 按钮参数（与渲染一致）
                local optY = popY + 85
                local btnW = popW * 0.8
                local btnH = 50
                local btnGap = 12
                local lcx = cx / dpr
                local lcy = cy / dpr
                for i, _ in ipairs(ec.options) do
                    local bx = (sw - btnW) / 2
                    local by = optY + (i - 1) * (btnH + btnGap)
                    if lcx > bx and lcx < bx + btnW and lcy > by and lcy < by + btnH then
                        Core.selectEventChoice(gameState, i)
                        break
                    end
                end
            end
        end

    elseif currentState == STATE_TECH then
        -- 点击科技项解锁
        if gameState then
            HandleTechClick(cx, cy)
        end

    elseif currentState == STATE_OVER then
        -- 点击重新开始按钮（与 RenderUI.drawGameOver 布局一致）
        local dpr = graphics:GetDPR()
        local sw = screenW / dpr
        local sh = screenH / dpr
        local lcx = cx / dpr
        local lcy = cy / dpr

        -- 广告双倍星尘按钮
        if not adDoubleUsed and gameState and (gameState._earnedStarDust or 0) > 0 then
            local adBtnW = 130
            local adBtnH = 28
            local adBtnX = (sw - adBtnW) / 2
            local adBtnY = sh * 0.79 + 10
            if lcx > adBtnX and lcx < adBtnX + adBtnW and lcy > adBtnY and lcy < adBtnY + adBtnH then
                GameAudio.playClick()
                ---@diagnostic disable-next-line: undefined-global
                sdk:ShowRewardVideoAd(function(result)
                    if result.success then
                        local bonus = gameState._earnedStarDust or 0
                        starDust = starDust + bonus
                        gameState._earnedStarDust = bonus * 2  -- 更新显示为翻倍后的值
                        adDoubleUsed = true
                        SaveSystem.save(persistentStats, savedAchievements, selectedSkinIdx, playerUpgrades, starDust)
                        log:Write(LOG_INFO, "[StarSea] Ad double: +" .. bonus .. " starDust")
                    end
                end)
                return
            end
        end

        local btnX = sw / 2 - 70
        local btnY = sh * 0.84
        if lcx > btnX and lcx < btnX + 140 and lcy > btnY and lcy < btnY + 36 then
            GameAudio.playClick()
            currentState = STATE_MENU
        end

    elseif currentState == STATE_UPGRADE then
        local dpr = graphics:GetDPR()
        local sw = screenW / dpr
        local lcx = cx / dpr
        local lcy = cy / dpr
        local startY = 80
        local itemH = 52
        local listW = math.min(sw * 0.85, 340)
        local listX = (sw - listW) / 2

        -- 点击升级项
        for i, def in ipairs(Systems.UPGRADES) do
            local y = startY + (i - 1) * itemH
            if lcx > listX and lcx < listX + listW and lcy > y and lcy < y + itemH - 4 then
                local success, newDust = Systems.buyUpgrade(def.id, playerUpgrades, starDust)
                if success then
                    starDust = newDust
                    GameAudio.playClick()
                    SaveSystem.save(persistentStats, savedAchievements, selectedSkinIdx, playerUpgrades, starDust)
                end
                return
            end
        end

        -- 返回按钮
        local backY = startY + #Systems.UPGRADES * itemH + 10
        if lcx > sw / 2 - 50 and lcx < sw / 2 + 50 and lcy > backY and lcy < backY + 32 then
            GameAudio.playClick()
            currentState = STATE_MENU
        end
    end
end

-- ============================================================================
-- 科技树点击
-- ============================================================================
function HandleTechClick(cx, cy)
    local categories = { S.get("tech_cat_weapon"), S.get("tech_cat_shield"), S.get("tech_cat_engine"), S.get("tech_cat_core"), S.get("tech_cat_auth") }
    local colW = screenW / 5

    for ci, cat in ipairs(categories) do
        local colX = (ci - 0.5) * colW
        local row = 0
        for _, tech in ipairs(Data.TECH_TREE) do
            if tech.cat == cat then
                row = row + 1
                local ty = 90 + row * 55
                if cx > colX - 55 and cx < colX + 55 and cy > ty and cy < ty + 45 then
                    -- 尝试解锁
                    local success = Core.unlockTech(gameState, tech.id)
                    if success then
                        log:Write(LOG_INFO, "[StarSea] Unlocked tech: " .. tech.name)
                    end
                    return
                end
            end
        end
    end
end

-- ============================================================================
-- 开始游戏
-- ============================================================================
function StartGame()
    -- P9: UI 点击音效
    GameAudio.playClick()
    -- P8.2: 安全检查 - 确保选中的皮肤已解锁，否则回退到默认
    local skin = Systems.SHIP_SKINS[selectedSkinIdx]
    if skin and skin.unlock ~= "default" then
        local unlocked = false
        for _, a in ipairs(savedAchievements) do
            if a == skin.unlock then unlocked = true; break end
        end
        if not unlocked then
            selectedSkinIdx = 1  -- 回退到默认皮肤
        end
    end

    gameState = Core.newGame(S.get("default_faction"), selectedFaction)
    -- 重置广告复活状态
    adReviveUsed = false
    showRevivePrompt = false
    adDoubleUsed = false
    -- 应用永久升级
    Systems.applyUpgrades(gameState, playerUpgrades)
    -- P8.1: 注入持久化成就（让本局内可检查历史成就解锁状态）
    for _, achId in ipairs(savedAchievements) do
        local found = false
        for _, a in ipairs(gameState.achievements or {}) do
            if a == achId then found = true; break end
        end
        if not found then
            gameState.achievements = gameState.achievements or {}
            gameState.achievements[#gameState.achievements + 1] = achId
        end
    end
    -- 应用飞船皮肤颜色
    local skin = Systems.SHIP_SKINS[selectedSkinIdx]
    if skin then
        gameState.shipColor = skin.color
    end
    -- 无尽模式
    if isEndless then
        gameState.isEndless = true
        log:Write(LOG_INFO, "[StarSea] Endless mode enabled")
    end
    -- 每日挑战修饰符
    if isDailyChallenge then
        gameState.isDailyChallenge = true
        local mods = Systems.getDailyModifiers()
        gameState.dailyMods = mods
        for _, m in ipairs(mods) do
            m.apply(gameState)
        end
        log:Write(LOG_INFO, "[StarSea] Daily challenge: " .. mods[1].name .. " + " .. mods[2].name)
    end
    -- 每周挑战（固定种子 + 增强难度）
    if isWeeklyChallenge then
        gameState.isWeeklyChallenge = true
        -- 使用本周时间戳作为种子确保全服一致
        local weekSeed = math.floor(os.time() / (7 * 24 * 3600))
        math.randomseed(weekSeed)
        -- 每周挑战强化难度
        gameState.player.hpMax = math.floor(gameState.player.hpMax * 0.8)
        gameState.player.hp = gameState.player.hpMax
        gameState.dayLength = 18  -- 更短的天数周期
        log:Write(LOG_INFO, "[StarSea] Weekly challenge, seed=" .. weekSeed)
    end
    currentState = STATE_GAME
    log:Write(LOG_INFO, "[StarSea] Game started, faction: " .. selectedFaction .. (isEndless and " [ENDLESS]" or ""))
end

-- ============================================================================
-- NanoVG 渲染
-- ============================================================================
function HandleNanoVGRender(eventType, eventData)
    if not vg then return end

    -- 更新屏幕尺寸（每帧从 graphics 读取）
    screenW = graphics:GetWidth()
    screenH = graphics:GetHeight()

    local dpr = graphics:GetDPR()
    nvgBeginFrame(vg, screenW / dpr, screenH / dpr, dpr)

    local sw = screenW / dpr
    local sh = screenH / dpr

    if currentState == STATE_MENU then
        Render.drawMenu(vg, sw, sh, selectedFaction, selectedSkinIdx, savedAchievements, dailyChallengeCompleted)

    elseif currentState == STATE_GAME and gameState then
        -- 清空背景（使用赛季主题色）
        local bgC = (gameState.seasonTheme and gameState.seasonTheme.bgColor) or { 8, 10, 20 }
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, sw, sh)
        nvgFillColor(vg, nvgRGBA(bgC[1], bgC[2], bgC[3], 255))
        nvgFill(vg)

        -- 绘制游戏世界
        Render.drawStars(vg, gameState, sw, sh)
        Render.drawRelays(vg, gameState, sw, sh)
        Render.drawAsteroids(vg, gameState, sw, sh)
        Render.drawPickups(vg, gameState, sw, sh)
        Render.drawRelicDrops(vg, gameState, sw, sh)
        Render.drawPowerups(vg, gameState, sw, sh)
        Render.drawBullets(vg, gameState, sw, sh)
        Render.drawLaser(vg, gameState, sw, sh)
        Render.drawMissiles(vg, gameState, sw, sh)
        Render.drawBoomerangs(vg, gameState, sw, sh)
        Render.drawMines(vg, gameState, sw, sh)
        Render.drawEnemies(vg, gameState, sw, sh)
        Render.drawHazards(vg, gameState, sw, sh)
        Render.drawAllies(vg, gameState, sw, sh)
        Render.drawPlayer(vg, gameState, sw, sh)
        Render.drawBossEffects(vg, gameState, sw, sh)
        Render.drawCollectAnims(vg, gameState, sw, sh)
        Render.drawParticles(vg, gameState, sw, sh)
        Render.drawFloatingTexts(vg, gameState, sw, sh)

        -- 慢动作全屏覆盖
        Render.drawSlowmoOverlay(vg, gameState, sw, sh)
        -- P7.3: 时间裂缝减速效果
        Render.drawTimeSlowFX(vg, gameState, sw, sh)
        -- Phase 6: 受伤红色闪屏
        Render.drawDamageFlash(vg, gameState, sw, sh)

        -- 覆盖层 UI（事件/波次/加成指示）
        Render.drawEventOverlay(vg, gameState, sw, sh)
        Render.drawWaveWarning(vg, gameState, sw, sh)
        Render.drawEventChoice(vg, gameState, sw, sh)
        Render.drawTutorial(vg, gameState, sw, sh)

        -- HUD 层
        Render.drawHUD(vg, gameState, sw, sh)
        Render.drawActivePowerups(vg, gameState, sw, sh)
        Render.drawAllyModeIndicator(vg, gameState, sw, sh)
        Render.drawCombo(vg, gameState, sw, sh)
        Render.drawRelicSlots(vg, gameState, sw, sh)
        Render.drawAchievementPopups(vg, gameState, sw, sh)
        Render.drawToasts(vg, gameState, sw, sh)

        -- 叙事文本
        if gameState.narrativeText and gameState.narrativeTimer and gameState.narrativeTimer > 0 then
            local alpha = math.min(1, gameState.narrativeTimer / 0.5) * math.min(1, (6 - (6 - gameState.narrativeTimer)) / 0.5)
            alpha = math.floor(alpha * 220)
            nvgFontFace(vg, "sans")
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 13)
            nvgFillColor(vg, nvgRGBA(200, 220, 255, alpha))
            nvgText(vg, sw / 2, sh * 0.18, gameState.narrativeText)
        end

        -- 广告复活弹窗
        if showRevivePrompt then
            -- 半透明遮罩
            nvgBeginPath(vg)
            nvgRect(vg, 0, 0, sw, sh)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
            nvgFill(vg)

            -- 弹窗
            local popW = 280
            local popH = 200
            local popX = (sw - popW) / 2
            local popY = (sh - popH) / 2

            nvgBeginPath(vg)
            nvgRoundedRect(vg, popX, popY, popW, popH, 14)
            local bgGrad = nvgLinearGradient(vg, popX, popY, popX, popY + popH,
                nvgRGBA(20, 30, 60, 240), nvgRGBA(10, 15, 35, 240))
            nvgFillPaint(vg, bgGrad)
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 200, 120, 200))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)

            -- 标题
            nvgFontFace(vg, "sans")
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(255, 220, 80, 255))
            nvgText(vg, sw / 2, popY + 35, "💀 飞船坠毁")

            -- 提示文字
            nvgFontSize(vg, 14)
            nvgFillColor(vg, nvgRGBA(200, 220, 240, 220))
            nvgText(vg, sw / 2, popY + 65, "观看广告可恢复50%能量复活！")

            -- 倒计时
            local cdText = string.format("剩余 %d 秒", math.ceil(reviveCountdown))
            nvgFontSize(vg, 12)
            nvgFillColor(vg, nvgRGBA(160, 180, 200, 180))
            nvgText(vg, sw / 2, popY + 88, cdText)

            -- "看广告复活" 按钮
            local adBtnW = popW * 0.7
            local adBtnH = 44
            local adBtnX = (sw - adBtnW) / 2
            local adBtnY = popY + 110
            nvgBeginPath(vg)
            nvgRoundedRect(vg, adBtnX, adBtnY, adBtnW, adBtnH, 8)
            local btnGrad = nvgLinearGradient(vg, adBtnX, adBtnY, adBtnX, adBtnY + adBtnH,
                nvgRGBA(40, 180, 80, 230), nvgRGBA(30, 130, 60, 230))
            nvgFillPaint(vg, btnGrad)
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 255, 140, 150))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)

            nvgFontSize(vg, 16)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, sw / 2, adBtnY + adBtnH / 2, "▶ 看广告复活")

            -- "跳过" 按钮
            local skipBtnW = popW * 0.5
            local skipBtnH = 32
            local skipBtnX = (sw - skipBtnW) / 2
            local skipBtnY = adBtnY + adBtnH + 14
            nvgBeginPath(vg)
            nvgRoundedRect(vg, skipBtnX, skipBtnY, skipBtnW, skipBtnH, 6)
            nvgFillColor(vg, nvgRGBA(60, 60, 80, 180))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 110, 140, 120))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)

            nvgFontSize(vg, 13)
            nvgFillColor(vg, nvgRGBA(160, 170, 190, 200))
            nvgText(vg, sw / 2, skipBtnY + skipBtnH / 2, "跳过")
        end

    elseif currentState == STATE_TECH and gameState then
        -- 先绘制游戏背景（半可见）
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, sw, sh)
        nvgFillColor(vg, nvgRGBA(8, 10, 20, 255))
        nvgFill(vg)
        Render.drawTechTree(vg, gameState, sw, sh)

    elseif currentState == STATE_OVER and gameState then
        Render.drawGameOver(vg, gameState, sw, sh)

        -- 星尘获得 + 广告双倍按钮（覆盖在结算卡片上）
        local earnedDust = gameState._earnedStarDust or 0
        if earnedDust > 0 then
            nvgFontFace(vg, "sans")
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 12)
            nvgFillColor(vg, nvgRGBA(255, 220, 80, 220))
            local dustText = adDoubleUsed
                and string.format("✦ +%d 星尘 (已翻倍!)", earnedDust)
                or string.format("✦ +%d 星尘", earnedDust)
            nvgText(vg, sw / 2, sh * 0.79, dustText)

            -- 未使用双倍时显示广告按钮
            if not adDoubleUsed then
                local adBtnW = 130
                local adBtnH = 28
                local adBtnX = (sw - adBtnW) / 2
                local adBtnY = sh * 0.79 + 10
                nvgBeginPath(vg)
                nvgRoundedRect(vg, adBtnX, adBtnY, adBtnW, adBtnH, 5)
                nvgFillColor(vg, nvgRGBA(180, 120, 0, 200))
                nvgFill(vg)
                nvgFontSize(vg, 11)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
                nvgText(vg, sw / 2, adBtnY + adBtnH / 2, "▶ 看广告翻倍星尘")
            end
        end

    elseif currentState == STATE_RANK then
        Render.drawLeaderboard(vg, sw, sh, Leaderboard)

    elseif currentState == STATE_STATS then
        Render.drawStats(vg, sw, sh, persistentStats)

    elseif currentState == STATE_UPGRADE then
        -- 升级界面
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, sw, sh)
        nvgFillColor(vg, nvgRGBA(5, 8, 18, 245))
        nvgFill(vg)

        nvgFontFace(vg, "sans")
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(0, 200, 255, 255))
        nvgText(vg, sw / 2, 30, "⚙ 永久强化")

        -- 星尘显示
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(255, 220, 80, 230))
        nvgText(vg, sw / 2, 55, "✦ 星尘: " .. starDust)

        -- 升级列表
        local startY = 80
        local itemH = 52
        local listW = math.min(sw * 0.85, 340)
        local listX = (sw - listW) / 2

        for i, def in ipairs(Systems.UPGRADES) do
            local y = startY + (i - 1) * itemH
            local lv = playerUpgrades[def.id] or 0
            local maxed = lv >= def.maxLv
            local cost = maxed and 0 or Systems.getUpgradeCost(def, lv)
            local canBuy = not maxed and starDust >= cost

            -- 背景条
            nvgBeginPath(vg)
            nvgRoundedRect(vg, listX, y, listW, itemH - 4, 6)
            if canBuy then
                nvgFillColor(vg, nvgRGBA(20, 40, 60, 200))
            else
                nvgFillColor(vg, nvgRGBA(15, 20, 30, 200))
            end
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(40, 80, 120, 120))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)

            -- 名称
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 13)
            nvgFillColor(vg, nvgRGBA(220, 240, 255, 240))
            nvgText(vg, listX + 10, y + 14, def.name)

            -- 描述
            nvgFontSize(vg, 10)
            nvgFillColor(vg, nvgRGBA(140, 170, 200, 180))
            nvgText(vg, listX + 10, y + 32, def.desc)

            -- 等级
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 11)
            if maxed then
                nvgFillColor(vg, nvgRGBA(0, 255, 200, 200))
                nvgText(vg, listX + listW - 10, y + 14, "MAX")
            else
                nvgFillColor(vg, nvgRGBA(180, 200, 220, 200))
                nvgText(vg, listX + listW - 10, y + 14, string.format("Lv.%d/%d", lv, def.maxLv))
            end

            -- 价格/按钮
            if not maxed then
                nvgFontSize(vg, 10)
                if canBuy then
                    nvgFillColor(vg, nvgRGBA(255, 220, 80, 220))
                else
                    nvgFillColor(vg, nvgRGBA(100, 100, 120, 180))
                end
                nvgText(vg, listX + listW - 10, y + 34, "✦" .. cost)
            end
        end

        -- 返回按钮
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local backY = startY + #Systems.UPGRADES * itemH + 10
        nvgBeginPath(vg)
        nvgRoundedRect(vg, sw / 2 - 50, backY, 100, 32, 6)
        nvgFillColor(vg, nvgRGBA(60, 60, 80, 200))
        nvgFill(vg)
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(200, 210, 230, 220))
        nvgText(vg, sw / 2, backY + 16, "← 返回")
    end

    nvgEndFrame(vg)
end
