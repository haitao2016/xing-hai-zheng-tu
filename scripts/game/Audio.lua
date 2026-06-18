-- ============================================================================
-- 星海征途 - 音效管理模块 (Phase 9: 完整音频系统)
-- ============================================================================

local Audio = {}

-- ========== 音效系统 ==========
local sounds = {}
local sourcePool = {}
local MAX_SOURCES = 10

-- 音量设置
Audio.masterVolume = 1.0
Audio.sfxVolume = 0.7
Audio.bgmVolume = 0.4

-- 音效文件映射
local SFX_MAP = {
    -- 射击
    shoot         = "audio/sfx/laser_shoot.ogg",
    laser_beam    = "audio/sfx/laser_beam.ogg",
    missile       = "audio/sfx/missile_launch.ogg",
    -- 爆炸
    explosion     = "audio/sfx/explosion_enemy.ogg",
    explosion_big = "audio/sfx/explosion_big.ogg",
    explosion_small = "audio/sfx/explosion_small.ogg",
    -- 拾取
    pickup        = "audio/sfx/pickup_collect.ogg",
    -- 环境
    shield_break  = "audio/sfx/shield_break.ogg",
    combo         = "audio/sfx/combo_hit.ogg",
    boss_alarm    = "audio/sfx/boss_alarm.ogg",
    -- UI
    ui_click      = "audio/sfx/ui_click.ogg",
    ui_unlock     = "audio/sfx/ui_unlock.ogg",
    ui_achievement = "audio/sfx/ui_achievement.ogg",
}

-- ========== BGM 系统 ==========
local BGM_MAP = {
    cruise = "audio/bgm/cruise.ogg",
    battle = "audio/bgm/battle.ogg",
    boss   = "audio/bgm/boss.ogg",
}

---@type Scene
local audioScene = nil
---@type SoundSource
local bgmSource = nil
---@type SoundSource
local bgmSourceB = nil  -- 用于淡入淡出切换
local currentBGM = ""
local targetBGM = ""
local crossfadeTimer = 0
local CROSSFADE_DURATION = 1.5  -- 淡入淡出时长（秒）
local isCrossfading = false
local bgmSounds = {}

-- ========== 初始化 ==========
function Audio.init()
    audioScene = Scene()
    audioScene:CreateComponent("Octree")

    -- 预加载所有音效
    local loadCount = 0
    for key, path in pairs(SFX_MAP) do
        local snd = cache:GetResource("Sound", path)
        if snd then
            sounds[key] = snd
            loadCount = loadCount + 1
        else
            print("[Audio] WARNING: SFX not found: " .. path)
        end
    end

    -- 预加载 BGM（设为循环）
    for key, path in pairs(BGM_MAP) do
        local snd = cache:GetResource("Sound", path)
        if snd then
            snd.looped = true
            bgmSounds[key] = snd
        else
            print("[Audio] WARNING: BGM not found: " .. path)
        end
    end

    -- 创建 SFX SoundSource 池
    for i = 1, MAX_SOURCES do
        local node = audioScene:CreateChild("SFX_" .. i)
        local src = node:CreateComponent("SoundSource")
        src:SetSoundType("Effect")
        src:SetGain(Audio.sfxVolume)
        sourcePool[i] = src
    end

    -- 创建 BGM 双轨道（用于 crossfade）
    local bgmNodeA = audioScene:CreateChild("BGM_A")
    bgmSource = bgmNodeA:CreateComponent("SoundSource")
    bgmSource:SetSoundType("Music")
    bgmSource:SetGain(Audio.bgmVolume * Audio.masterVolume)

    local bgmNodeB = audioScene:CreateChild("BGM_B")
    bgmSourceB = bgmNodeB:CreateComponent("SoundSource")
    bgmSourceB:SetSoundType("Music")
    bgmSourceB:SetGain(0)

    print("[Audio] Initialized: " .. loadCount .. " SFX, " .. #bgmSounds .. " BGM tracks")
end

-- ========== SFX 播放 ==========
local nextSource = 1
local function getSource()
    for i = 1, MAX_SOURCES do
        local idx = ((nextSource - 1 + i - 1) % MAX_SOURCES) + 1
        if not sourcePool[idx]:IsPlaying() then
            nextSource = idx + 1
            return sourcePool[idx]
        end
    end
    local src = sourcePool[nextSource]
    nextSource = (nextSource % MAX_SOURCES) + 1
    return src
end

--- 播放音效
---@param name string 音效名
---@param volume? number 音量倍率(0~1)
---@param pitch? number 音调倍率
---@param distance? number 距玩家距离（用于空间化音量衰减）
function Audio.play(name, volume, pitch, distance)
    local snd = sounds[name]
    if not snd then return end
    local src = getSource()
    if not src then return end

    local baseVol = (volume or 1.0) * Audio.sfxVolume * Audio.masterVolume

    if distance and distance > 0 then
        local maxDist = 600
        local minDist = 50
        if distance > maxDist then
            baseVol = baseVol * 0.15
        elseif distance > minDist then
            local ratio = (distance - minDist) / (maxDist - minDist)
            baseVol = baseVol * (1 - ratio * 0.85)
        end
    end

    src:SetGain(baseVol)
    local freq = 44100 * (pitch or 1.0)
    src:Play(snd, freq)
end

--- 射击音效（带随机音调）
function Audio.playShoot(weaponType)
    if weaponType == "laser" then
        Audio.play("laser_beam", 0.4, 0.95 + math.random() * 0.1)
    elseif weaponType == "missile" then
        Audio.play("missile", 0.6, 0.9 + math.random() * 0.2)
    else
        Audio.play("shoot", 0.5, 0.9 + math.random() * 0.2)
    end
end

--- 爆炸音效（分级）
function Audio.playExplosion(size)
    if size == "big" then
        Audio.play("explosion_big", 0.8, 0.85 + math.random() * 0.15)
    elseif size == "small" then
        Audio.play("explosion_small", 0.6, 0.9 + math.random() * 0.2)
    else
        Audio.play("explosion", 0.6, 0.85 + math.random() * 0.3)
    end
end

--- 拾取音效
function Audio.playPickup()
    Audio.play("pickup", 0.6, 0.95 + math.random() * 0.1)
end

--- 护盾碎裂
function Audio.playShieldBreak()
    Audio.play("shield_break", 0.8, 1.0)
end

--- 连杀音效（音调递增）
function Audio.playCombo(count)
    local p = math.min(1.5, 1.0 + (count or 1) * 0.05)
    Audio.play("combo", 0.5, p)
end

--- Boss 警报
function Audio.playBossAlarm()
    Audio.play("boss_alarm", 0.9, 1.0)
end

--- UI 点击
function Audio.playClick()
    Audio.play("ui_click", 0.5, 1.0)
end

--- 解锁音效
function Audio.playUnlock()
    Audio.play("ui_unlock", 0.7, 1.0)
end

--- 成就音效
function Audio.playAchievement()
    Audio.play("ui_achievement", 0.8, 1.0)
end

-- ========== BGM 系统 ==========

--- 切换 BGM（带淡入淡出）
---@param trackName string "cruise"|"battle"|"boss"|""
function Audio.setBGM(trackName)
    if trackName == currentBGM then return end
    if not bgmSource then return end

    targetBGM = trackName

    if currentBGM == "" then
        -- 当前没有音乐，直接播放
        local snd = bgmSounds[trackName]
        if snd then
            bgmSource:SetGain(Audio.bgmVolume * Audio.masterVolume)
            bgmSource:Play(snd)
            currentBGM = trackName
        end
    else
        -- 淡入淡出切换
        local snd = bgmSounds[trackName]
        if snd then
            bgmSourceB:SetGain(0)
            bgmSourceB:Play(snd)
            isCrossfading = true
            crossfadeTimer = 0
        elseif trackName == "" then
            -- 淡出到静音
            isCrossfading = true
            crossfadeTimer = 0
        end
    end
end

--- 停止 BGM
function Audio.stopBGM()
    Audio.setBGM("")
end

--- 每帧更新（处理 crossfade）
---@param dt number 帧时间
function Audio.update(dt)
    if not isCrossfading then return end

    crossfadeTimer = crossfadeTimer + dt
    local t = math.min(1.0, crossfadeTimer / CROSSFADE_DURATION)

    local maxVol = Audio.bgmVolume * Audio.masterVolume

    if targetBGM == "" then
        -- 只淡出
        bgmSource:SetGain(maxVol * (1 - t))
        if t >= 1.0 then
            bgmSource:Stop()
            currentBGM = ""
            isCrossfading = false
        end
    else
        -- 淡出 A / 淡入 B
        bgmSource:SetGain(maxVol * (1 - t))
        bgmSourceB:SetGain(maxVol * t)
        if t >= 1.0 then
            -- 交换引用
            bgmSource:Stop()
            local tmp = bgmSource
            bgmSource = bgmSourceB
            bgmSourceB = tmp
            currentBGM = targetBGM
            isCrossfading = false
        end
    end
end

--- 设置主音量
function Audio.setMasterVolume(v)
    Audio.masterVolume = math.max(0, math.min(1, v))
    -- 更新当前 BGM 音量
    if bgmSource and bgmSource:IsPlaying() and not isCrossfading then
        bgmSource:SetGain(Audio.bgmVolume * Audio.masterVolume)
    end
end

--- 设置 BGM 音量
function Audio.setBGMVolume(v)
    Audio.bgmVolume = math.max(0, math.min(1, v))
    if bgmSource and bgmSource:IsPlaying() and not isCrossfading then
        bgmSource:SetGain(Audio.bgmVolume * Audio.masterVolume)
    end
end

--- 设置音效音量
function Audio.setSFXVolume(v)
    Audio.sfxVolume = math.max(0, math.min(1, v))
end

--- 获取当前 BGM 名称
function Audio.getCurrentBGM()
    return currentBGM
end

return Audio
