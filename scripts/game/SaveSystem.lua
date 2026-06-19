-- ============================================================================
-- 星海征途 - 存档系统
-- 本地持久化: 永久统计、成就、皮肤解锁、最佳记录
-- ============================================================================

local Systems = require("game.Systems")
local SaveSystem = {}

local SAVE_FILE = "star_sea_save.json"
local SAVE_VERSION = 1

-- ============================================================================
-- 保存
-- ============================================================================
function SaveSystem.save(persistentStats, achievements, selectedSkinIdx, upgrades, starDust)
    local saveData = {
        version = SAVE_VERSION,
        stats = persistentStats,
        achievements = achievements or {},
        selectedSkin = selectedSkinIdx or 1,
        upgrades = upgrades or {},
        starDust = starDust or 0,
        savedAt = os.time(),
    }

    local ok, encoded = pcall(cjson.encode, saveData)
    if not ok then
        log:Write(LOG_ERROR, "[SaveSystem] Failed to encode save data: " .. tostring(encoded))
        return false
    end

    local file = File(SAVE_FILE, FILE_WRITE)
    if not file:IsOpen() then
        log:Write(LOG_ERROR, "[SaveSystem] Failed to open save file for writing")
        return false
    end
    file:WriteString(encoded)
    file:Close()
    log:Write(LOG_INFO, "[SaveSystem] Game saved successfully")
    return true
end

-- ============================================================================
-- 加载
-- ============================================================================
function SaveSystem.load()
    if not fileSystem:FileExists(SAVE_FILE) then
        log:Write(LOG_INFO, "[SaveSystem] No save file found, starting fresh")
        return nil
    end

    local file = File(SAVE_FILE, FILE_READ)
    if not file:IsOpen() then
        log:Write(LOG_ERROR, "[SaveSystem] Failed to open save file for reading")
        return nil
    end

    local raw = file:ReadString()
    file:Close()

    if not raw or raw == "" then
        log:Write(LOG_WARNING, "[SaveSystem] Save file is empty")
        return nil
    end

    local ok, data = pcall(cjson.decode, raw)
    if not ok then
        log:Write(LOG_ERROR, "[SaveSystem] Failed to decode save data: " .. tostring(data))
        return nil
    end

    -- 版本迁移（预留）
    if data.version and data.version < SAVE_VERSION then
        data = SaveSystem.migrate(data)
    end

    log:Write(LOG_INFO, "[SaveSystem] Save loaded, totalGames=" .. (data.stats and data.stats.totalGames or 0))
    return data
end

-- ============================================================================
-- 版本迁移
-- ============================================================================
function SaveSystem.migrate(data)
    -- 未来版本升级时在此处理数据结构变更
    data.version = SAVE_VERSION
    return data
end

-- ============================================================================
-- 应用加载数据
-- ============================================================================

--- 从存档恢复persistentStats，返回恢复后的stats和achievements以及selectedSkin
function SaveSystem.applyLoadedData(loadedData)
    local result = {
        stats = Systems.initPersistentStats(),
        achievements = {},
        selectedSkin = 1,
        upgrades = Systems.initUpgrades(),
        starDust = 0,
    }

    if not loadedData then return result end

    -- 恢复永久统计
    if loadedData.stats then
        for _, key in ipairs(Systems.STAT_KEYS) do
            if loadedData.stats[key] then
                result.stats[key] = loadedData.stats[key]
            end
        end
    end

    -- 恢复成就
    if loadedData.achievements then
        result.achievements = loadedData.achievements
    end

    -- 恢复皮肤选择
    if loadedData.selectedSkin then
        result.selectedSkin = math.max(1, math.min(loadedData.selectedSkin, #Systems.SHIP_SKINS))
    end

    -- 恢复永久升级
    if loadedData.upgrades then
        for k, v in pairs(loadedData.upgrades) do
            result.upgrades[k] = v
        end
    end
    result.starDust = loadedData.starDust or 0

    return result
end

-- ============================================================================
-- P8.3: 每日挑战标记（独立小文件，避免频繁读写大存档）
-- ============================================================================
local DAILY_FILE = "daily_challenge.json"

--- 保存今日挑战完成标记
function SaveSystem.saveDailyFlag(dateStr, score)
    local data = { date = dateStr, score = score, completedAt = os.time() }
    local ok, encoded = pcall(cjson.encode, data)
    if not ok then return false end
    local file = File(DAILY_FILE, FILE_WRITE)
    if not file:IsOpen() then return false end
    file:WriteString(encoded)
    file:Close()
    return true
end

--- 加载每日挑战标记（返回nil表示今天未挑战）
function SaveSystem.loadDailyFlag(todayStr)
    if not fileSystem:FileExists(DAILY_FILE) then return nil end
    local file = File(DAILY_FILE, FILE_READ)
    if not file:IsOpen() then return nil end
    local raw = file:ReadString()
    file:Close()
    if not raw or raw == "" then return nil end
    local ok, data = pcall(cjson.decode, raw)
    if not ok then return nil end
    -- 检查是否是今天的记录
    if data.date == todayStr then
        return data
    end
    return nil  -- 过期的记录
end

return SaveSystem
