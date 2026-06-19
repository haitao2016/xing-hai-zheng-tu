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
local STATE_DIFFICULTY = "difficulty"  -- P18/P19: 难度选择
local STATE_CAMPAIGN = "campaign"      -- P18: 战役章节选择
local STATE_GAME = "game"
local STATE_TECH = "tech"
local STATE_OVER = "gameover"
local STATE_RANK = "leaderboard"
local STATE_STATS = "stats"
local STATE_SETTINGS = "settings"
local STATE_MODS = "mods"              -- Phase 26: Mod 管理器

local currentState = STATE_MENU
local gameState = nil

-- 菜单状态
local selectedFaction = "merchants"
local selectedSkinIdx = 1
local isDailyChallenge = false
local isEndless = false
local selectedGameMode = nil
local dailyChallengeCompleted = false
local dailyChallengeScore = 0
local persistentStats = Systems.initPersistentStats()
local savedAchievements = {}

-- Phase 26: Mod 选择索引
local _modSelectedIdx = 1

-- P18/P19: 难度与战役选择
local selectedDifficultyIdx = 2    -- 默认标准难度
local selectedChapterIdx = 1        -- 默认第一章
local chapterProgress = {           -- 战役进度解锁
    ch1 = false, ch2 = false, ch3 = false
}
-- P20.1: 主动技能映射 (数字键 1-5)
local SKILL_KEYS = {
    [KEY_1] = "skill_dash",
    [KEY_2] = "skill_shock",
    [KEY_3] = "skill_slow",
    [KEY_4] = "skill_shield",
    [KEY_5] = "skill_strike",
}
-- P21.3: 神秘地点交互冷却
local mysteryInteractCd = 0

-- P15: 设置菜单
local settings = {
    masterVolume = 1.0,
    bgmVolume = 0.8,
    sfxVolume = 1.0,
    shakeEnabled = true,
    shakeIntensity = 1.0,
    fpsLimit = 60,
}
local settingSliders = {
    { id = "masterVolume", label = "主音量", min = 0, max = 1, step = 0.05 },
    { id = "bgmVolume", label = "背景音乐", min = 0, max = 1, step = 0.05 },
    { id = "sfxVolume", label = "音效", min = 0, max = 1, step = 0.05 },
    { id = "shakeIntensity", label = "震动强度", min = 0, max = 2, step = 0.1 },
    { id = "fpsLimit", label = "帧率限制", min = 30, max = 120, step = 10 },
}

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
        log:Write(LOG_INFO, "[SaveSystem] Restored: games=" .. persistentStats.totalGames
            .. " achievements=" .. #savedAchievements .. " skin=" .. selectedSkinIdx)
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

    -- 全局计时器：神秘地点交互冷却
    if mysteryInteractCd > 0 then
        mysteryInteractCd = math.max(0, mysteryInteractCd - dt)
    end

    if currentState == STATE_GAME and gameState then
        local dpr = graphics:GetDPR()
        local logW = screenW / dpr
        local logH = screenH / dpr
        local aimWorldX = (mouseX / dpr) - logW * 0.5 + gameState.cam.x
        local aimWorldY = (mouseY / dpr) - logH * 0.5 + gameState.cam.y
        local inp = {
            up = false, down = false, left = false, right = false,
            aimX = aimWorldX, aimY = aimWorldY,
            fire = input:GetMouseButtonDown(MOUSEB_LEFT) or mousePressed,
            screenW = logW, screenH = logH,
        }
        if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then inp.up = true end
        if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then inp.down = true end
        if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then inp.left = true end
        if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then inp.right = true end

        Core.update(gameState, dt, inp)

        -- Phase 23: 摄像机特效、BGM 动态叠层、Hitstop
        Core.updateCameraFX(gameState, dt)
        Core.updateHitstop(gameState, dt)
        local enemyCount = #(gameState.enemies or {})
        local hasBoss = false
        for _, e in ipairs(gameState.enemies or {}) do
            if e.isBoss then hasBoss = true; break end
        end
        GameAudio.updateBGMIntensity(gameState.comboRank and gameState.comboRank.rank, enemyCount, hasBoss)
        GameAudio.updateBGLayers(dt)

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
            -- Phase 24: 记录本局幽灵数据用于排行与比较
            if Core.recordGhostRun and SaveSystem and SaveSystem.saveGhost then
                local ghost = Core.recordGhostRun(gameState)
                SaveSystem.saveGhost(ghost)
            end
            -- Phase 24: 保存永久升级进度（跨局保留）
            if SaveSystem and SaveSystem.saveMetaUpgrades and gameState.meta and gameState.meta.upgrades then
                SaveSystem.saveMetaUpgrades(gameState.meta.upgrades)
            end
            if SaveSystem and SaveSystem.saveAchievements and gameState.achievements then
                SaveSystem.saveAchievements(gameState.achievements)
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
            -- P8.1: 保存存档
            SaveSystem.save(persistentStats, savedAchievements, selectedSkinIdx)
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
            elseif gameState.isEndless then
                Leaderboard.submitScore(gameState.score, "endless_score")
            else
                Leaderboard.submitScore(gameState.score)
            end
            isDailyChallenge = false
            isEndless = false
            selectedGameMode = nil  -- P11: 重置游戏模式
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

    -- P18/P19: 难度选择界面
    if currentState == STATE_DIFFICULTY then
        if key == KEY_LEFT or key == KEY_A then
            selectedDifficultyIdx = math.max(1, selectedDifficultyIdx - 1)
            GameAudio.playClick()
        elseif key == KEY_RIGHT or key == KEY_D then
            selectedDifficultyIdx = math.min(4, selectedDifficultyIdx + 1)
            GameAudio.playClick()
        elseif key == KEY_ENTER or key == KEY_RETURN then
            GameAudio.playClick()
            currentState = STATE_CAMPAIGN  -- 进入战役章节选择
        elseif key == KEY_ESCAPE then
            currentState = STATE_MENU
        end
        return
    end

    -- P18: 战役章节选择界面
    if currentState == STATE_CAMPAIGN then
        if key == KEY_UP or key == KEY_W then
            selectedChapterIdx = math.max(1, selectedChapterIdx - 1)
            GameAudio.playClick()
        elseif key == KEY_DOWN or key == KEY_S then
            selectedChapterIdx = math.min(3, selectedChapterIdx + 1)
            GameAudio.playClick()
        elseif key == KEY_ENTER or key == KEY_RETURN then
            -- 检查是否解锁
            local unlocked = (selectedChapterIdx == 1) or chapterProgress["ch" .. (selectedChapterIdx - 1)]
            if unlocked then
                GameAudio.playClick()
                StartGame()
            else
                GameAudio.playClick()
            end
        elseif key == KEY_ESCAPE then
            currentState = STATE_MENU
        end
        return
    end

    if currentState == STATE_GAME then
        -- P20.1: 主动技能（数字键 1-5）
        if SKILL_KEYS[key] and gameState then
            Core.useSkill(gameState, SKILL_KEYS[key])
        elseif key == KEY_T then
            currentState = STATE_TECH
        elseif key == KEY_R then
            if gameState then Core.buildRelay(gameState) end
        elseif key == KEY_H then
            if gameState then Core.attemptHijack(gameState) end
        elseif key == KEY_F then
            if gameState then Core.cycleAllyMode(gameState) end
        elseif key == KEY_Q then
            if gameState then Core.fireMissile(gameState) end
        elseif key == KEY_V then
            if gameState then Core.toggleLaser(gameState) end
        elseif key == KEY_TAB then
            if gameState then Core.switchSecondary(gameState) end
        elseif key == KEY_SPACE then
            if gameState then Core.fireSecondary(gameState) end
        elseif key == KEY_E then
            -- P21.3: E键与神秘地点交互
            if gameState and mysteryInteractCd <= 0 then
                Core.checkMysteryInteraction(gameState)
                mysteryInteractCd = 0.5
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
    end

    if currentState == STATE_MENU and key == KEY_L then
        GameAudio.playClick()
        Leaderboard.fetchRankList()
        currentState = STATE_RANK
    end

    -- Phase 26: Mod 管理器按键处理
    if currentState == STATE_MODS then
        if key == KEY_ESCAPE then
            currentState = STATE_MENU
        elseif key == KEY_UP or key == KEY_W then
            _modSelectedIdx = math.max(1, (_modSelectedIdx or 1) - 1)
        elseif key == KEY_DOWN or key == KEY_S then
            local list = Data.listMods and Data.listMods() or {}
            _modSelectedIdx = math.min(#list, (_modSelectedIdx or 1) + 1)
        elseif key == KEY_ENTER or key == KEY_RETURN then
            local list = Data.listMods and Data.listMods() or {}
            if list[_modSelectedIdx or 1] then
                Data.toggleMod(list[_modSelectedIdx].id)
                if SaveSystem and SaveSystem.saveModConfig then
                    SaveSystem.saveModConfig(Data.listMods())
                end
            end
        end
        return
    end

    -- Phase 26: 菜单中 M 键进入 Mod 管理器
    if currentState == STATE_MENU and key == KEY_M then
        GameAudio.playClick()
        currentState = STATE_MODS
    end
end

-- ============================================================================
-- 点击处理
-- ============================================================================
function HandleClick(cx, cy)
    -- Phase 26: Mod 管理器不处理点击（按键驱动）
    if currentState == STATE_MODS then
        return
    end

    -- P19: 难度选择界面的卡片点击
    if currentState == STATE_DIFFICULTY then
        local dpr = graphics:GetDPR()
        local sw = screenW / dpr
        local sh = screenH / dpr
        local cardW = 180
        local cardH = 260
        local totalW = 4 * cardW + 3 * 20
        local startX = sw / 2 - totalW / 2
        for i = 1, 4 do
            local cx2 = startX + (i - 1) * (cardW + 20)
            if cx / dpr > cx2 and cx / dpr < cx2 + cardW and cy / dpr > sh * 0.4 and cy / dpr < sh * 0.4 + cardH then
                selectedDifficultyIdx = i
                GameAudio.playClick()
                currentState = STATE_CAMPAIGN
                return
            end
        end
        return
    end

    -- P18: 战役章节选择界面的卡片点击
    if currentState == STATE_CAMPAIGN then
        local dpr = graphics:GetDPR()
        local sw = screenW / dpr
        local sh = screenH / dpr
        local cardW = 520
        local cardH = 110
        local gap = 20
        local totalH = 3 * cardH + 2 * gap
        local startY = sh / 2 - totalH / 2
        for i = 1, 3 do
            local cy2 = startY + (i - 1) * (cardH + gap)
            local cx2 = sw / 2 - cardW / 2
            if cx / dpr > cx2 and cx / dpr < cx2 + cardW and cy / dpr > cy2 and cy / dpr < cy2 + cardH then
                local unlocked = (i == 1) or chapterProgress["ch" .. (i - 1)]
                if unlocked then
                    selectedChapterIdx = i
                    GameAudio.playClick()
                    StartGame()
                end
                return
            end
        end
        return
    end

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

        local btnX = screenW / 2 - 85
        local btnY = screenH * 0.76
        if cx > btnX and cx < btnX + 170 and cy > btnY and cy < btnY + 48 then
            isDailyChallenge = false
            isEndless = false
            GameAudio.playClick()
            currentState = STATE_DIFFICULTY
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
            isEndless = true
            selectedGameMode = nil
            StartGame()
        end

        -- P11: 新游戏模式按钮
        local modeBtnY = endBtnY + endBtnH3 + 12
        local modeBtnW = 120
        local modeBtnH = 32
        local modeGap = 8
        local totalWidth = 3 * modeBtnW + 2 * modeGap
        local modeStartX = screenW / 2 - totalWidth / 2
        local modes = {
            { id = "timeattack", x = modeStartX },
            { id = "bullethell", x = modeStartX + modeBtnW + modeGap },
            { id = "bossrush", x = modeStartX + 2 * (modeBtnW + modeGap) },
        }
        for _, mode in ipairs(modes) do
            if cx > mode.x and cx < mode.x + modeBtnW and cy > modeBtnY and cy < modeBtnY + modeBtnH then
                isDailyChallenge = false
                isEndless = false
                selectedGameMode = mode.id
                StartGame()
                break
            end
        end

        -- 统计按钮（左下角）
        local statBtnX = 10
        local statBtnY = screenH - 46
        if cx > statBtnX and cx < statBtnX + 80 and cy > statBtnY and cy < statBtnY + 32 then
            GameAudio.playClick()
            currentState = STATE_STATS
        end

        -- P15: 设置按钮（右下角）
        local setBtnX = screenW - 90
        local setBtnY = screenH - 46
        if cx > setBtnX and cx < setBtnX + 80 and cy > setBtnY and cy < setBtnY + 32 then
            GameAudio.playClick()
            currentState = STATE_SETTINGS
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
        local btnX = sw / 2 - 70
        local btnY = sh * 0.84
        if lcx > btnX and lcx < btnX + 140 and lcy > btnY and lcy < btnY + 36 then
            GameAudio.playClick()
            currentState = STATE_MENU
        end
    elseif currentState == STATE_SETTINGS then
        -- P15: 设置菜单点击处理
        local dpr = graphics:GetDPR()
        local sw = screenW / dpr
        local sh = screenH / dpr
        local lcx = cx / dpr
        local lcy = cy / dpr

        -- 返回按钮
        local backBtnX = sw / 2 - 60
        local backBtnY = sh * 0.85
        if lcx > backBtnX and lcx < backBtnX + 120 and lcy > backBtnY and lcy < backBtnY + 36 then
            GameAudio.playClick()
            currentState = STATE_MENU
            return
        end

        -- 滑动条点击
        local panelX = sw / 2 - 200
        local sliderY = 155
        for _, slider in ipairs(settingSliders) do
            local sliderW = 280
            local sliderX = panelX + 120
            if lcx > sliderX - 10 and lcx < sliderX + sliderW + 10 and lcy > sliderY - 15 and lcy < sliderY + 15 then
                local progress = (lcx - sliderX) / sliderW
                progress = math.max(0, math.min(1, progress))
                local value = slider.min + progress * (slider.max - slider.min)
                value = math.floor(value / slider.step) * slider.step
                settings[slider.id] = value
                GameAudio.playClick()
                return
            end
            sliderY = sliderY + 35
        end

        -- 震动开关
        local toggleX = sw / 2 + 140
        local toggleY = sliderY + 15
        if lcx > toggleX and lcx < toggleX + 40 and lcy > toggleY - 11 and lcy < toggleY + 11 then
            settings.shakeEnabled = not settings.shakeEnabled
            GameAudio.playClick()
            return
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
    GameAudio.playClick()
    -- P8.2: 安全检查 - 确保选中的皮肤已解锁
    local skin = Systems.SHIP_SKINS[selectedSkinIdx]
    if skin and skin.unlock ~= "default" then
        local unlocked = false
        for _, a in ipairs(savedAchievements) do
            if a == skin.unlock then unlocked = true; break end
        end
        if not unlocked then
            selectedSkinIdx = 1
        end
    end

    gameState = Core.newGame(S.get("default_faction"), selectedFaction, selectedGameMode)

    -- Phase 24: 加载已获得的永久升级等级
    if SaveSystem and SaveSystem.loadMetaUpgrades then
        local meta = SaveSystem.loadMetaUpgrades()
        if meta and next(meta) then
            if not gameState.meta then gameState.meta = {} end
            gameState.meta.upgrades = meta
            Core.applyMetaUpgrades(gameState)
        end
    end
    -- Phase 24: 加载已解锁的成就，触发永久升级
    if SaveSystem and SaveSystem.loadAchievements then
        local achs = SaveSystem.loadAchievements()
        if achs and #achs > 0 and Core.applyAchievementUnlocks then
            Core.applyAchievementUnlocks(gameState, achs)
        end
    end

    -- P18/P19: 应用难度与战役章节
    local difficultyIds = { "rookie", "standard", "hard", "void" }
    gameState.difficultyId = difficultyIds[selectedDifficultyIdx] or "standard"
    gameState.campaignId = "ch" .. selectedChapterIdx
    if Core.applyDifficulty then Core.applyDifficulty(gameState) end
    if Core.applyMetaUpgrades then Core.applyMetaUpgrades(gameState) end

    -- Phase 24: 应用每日主题（影响敌人/资源/连击等）
    local themeSeed = tonumber(os.date("%y%m%d")) or 1
    local theme = Data.getDailyTheme(themeSeed)
    if Core.applyDailyTheme and theme then
        Core.applyDailyTheme(gameState, theme)
        gameState.dailyTheme = theme
    end

    adReviveUsed = false
    showRevivePrompt = false

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
    local skin = Systems.SHIP_SKINS[selectedSkinIdx]
    if skin then
        gameState.shipColor = skin.color
    end
    if isEndless then
        gameState.isEndless = true
    end
    if selectedGameMode == "timeattack" then
        gameState.gameMode = "timeattack"
        gameState.timeAttackDuration = 60
        gameState.dayLength = 9999
    elseif selectedGameMode == "bullethell" then
        gameState.gameMode = "bullethell"
        gameState.dayLength = 9999
    elseif selectedGameMode == "bossrush" then
        gameState.gameMode = "bossrush"
        gameState.dayLength = 9999
        gameState._bossRushIndex = 0
    else
        gameState.gameMode = gameState.isEndless and "endless" or "season"
    end
    if isDailyChallenge then
        gameState.isDailyChallenge = true
        local mods = Systems.getDailyModifiers()
        gameState.dailyMods = mods
        for _, m in ipairs(mods) do
            m.apply(gameState)
        end
    end
    currentState = STATE_GAME
    log:Write(LOG_INFO, "[StarSea] Started: " .. gameState.difficultyId
        .. " | ch" .. selectedChapterIdx .. " | faction: " .. selectedFaction
        .. (isEndless and " [ENDLESS]" or ""))
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
        -- Phase 27: 版本号信息（右下角）
        if Data and Data.getVersionString then
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(100, 120, 160, 120))
            nvgText(vg, sw - 12, sh - 12, Data.getVersionString())
        end
        -- Phase 26: Mod 管理入口提示（左下角）
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_BOTTOM)
        nvgFillColor(vg, nvgRGBA(100, 140, 180, 120))
        nvgText(vg, 12, sh - 12, "按 M 打开 Mod 管理器  |  Enter 开始  |  ↑↓ 切换阵营")
    elseif currentState == STATE_DIFFICULTY then
        Render.drawDifficultySelect(vg, sw, sh, selectedDifficultyIdx)

    elseif currentState == STATE_CAMPAIGN then
        Render.drawCampaignSelect(vg, sw, sh, selectedChapterIdx, chapterProgress)

    elseif currentState == STATE_SETTINGS then
        Render.drawSettings(vg, sw, sh, settings, settingSliders)

    elseif currentState == STATE_MODS then
        local modList = Data.listMods and Data.listMods() or {}
        Render.drawModManager(vg, sw, sh, _modSelectedIdx or 1, modList)

    elseif currentState == STATE_GAME and gameState then
        -- 清空背景
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, sw, sh)
        nvgFillColor(vg, nvgRGBA(8, 10, 20, 255))
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

    elseif currentState == STATE_RANK then
        Render.drawLeaderboard(vg, sw, sh, Leaderboard)

    elseif currentState == STATE_STATS then
        Render.drawStats(vg, sw, sh, persistentStats)
    end

    nvgEndFrame(vg)
end
