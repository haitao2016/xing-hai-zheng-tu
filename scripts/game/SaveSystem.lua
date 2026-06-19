-- ============================================================================
-- 星海征途 - 存档系统
-- 本地持久化: 永久统计、成就、皮肤解锁、最佳记录
-- ============================================================================

local Systems = require("game.Systems")
local SaveSystem = {}
local M = SaveSystem

local SAVE_FILE = "star_sea_save.json"
local SAVE_VERSION = 1

-- ============================================================================
-- 保存
-- ============================================================================
function SaveSystem.save(persistentStats, achievements, selectedSkinIdx)
    local saveData = {
        version = SAVE_VERSION,
        stats = persistentStats,
        achievements = achievements or {},
        selectedSkin = selectedSkinIdx or 1,
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

-- ============================================================================
-- Phase 26: Mod 配置存档
-- ============================================================================
function SaveSystem.saveModConfig(modList)
    if not M.saveDirectory then
        M.init()
    end
    local success = pcall(function()
        local file = io.open(M.saveDirectory .. "/mod_config.json", "w")
        if file then
            local data = {
                formatVersion = 2,
                savedAt = os.date("%Y-%m-%d %H:%M:%S"),
                mods = modList or {},
            }
            local lines = { "{",
                '  "formatVersion": 2,',
                '  "savedAt": "' .. data.savedAt .. '",',
                '  "mods": ['
            }
            for i, m in ipairs(data.mods) do
                table.insert(lines, '    { "id": "' .. tostring(m.id) .. '", "enabled": ' .. tostring(m.enabled) .. ' }' .. (i < #data.mods and "," or ""))
            end
            table.insert(lines, "  ]")
            table.insert(lines, "}")
            file:write(table.concat(lines, "\n"))
            file:close()
        end
    end)
    return success
end

function SaveSystem.loadModConfig()
    if not M.saveDirectory then M.init() end
    local result = {}
    pcall(function()
        local file = io.open(M.saveDirectory .. "/mod_config.json", "r")
        if file then
            local content = file:read("*a")
            file:close()
            for id, enabled in string.gmatch(content, '"id"%s*:%s*"([^"]+)"[^}]*"enabled"%s*:%s*(%a+)') do
                result[id] = (enabled == "true")
            end
        end
    end)
    return result
end

-- ============================================================================
-- Phase 24: 幽灵数据存档
-- ============================================================================
function SaveSystem.saveGhost(ghostData)
    if not M.saveDirectory then M.init() end
    pcall(function()
        local file = io.open(M.saveDirectory .. "/ghost_runs.json", "w")
        if file and ghostData then
            local g = ghostData
            local lines = { "{",
                '  "timestamp": ' .. (g.timestamp or 0) .. ",",
                '  "factionId": "' .. tostring(g.factionId or "") .. '",',
                '  "difficulty": "' .. tostring(g.difficulty or "standard") .. '",',
                '  "daysSurvived": ' .. (g.daysSurvived or 0) .. ",",
                '  "totalKills": ' .. (g.totalKills or 0) .. ",",
                '  "maxCombo": ' .. (g.maxCombo or 0) .. ",",
                '  "score": ' .. (g.score or 0) .. ",",
                '  "techCount": ' .. (g.techCount or 0) .. ",",
                '  "relicCount": ' .. (g.relicCount or 0) .. ",",
                '  "playTime": ' .. (g.playTime or 0),
                "}"
            }
            file:write(table.concat(lines, "\n"))
            file:close()
        end

        -- Phase B: 同步更新最佳幽灵记录
        if ghostData and ghostData.score then
            local bestFile = io.open(M.saveDirectory .. "/ghost_best.json", "r")
            local curBest = nil
            if bestFile then
                local c = bestFile:read("*a")
                bestFile:close()
                local g = {}
                for key, val in string.gmatch(c, '"(%w+)"%s*:%s*([^,%s}]+)') do
                    if tonumber(val) then g[key] = tonumber(val) else g[key] = string.gsub(val, '"', '') end
                end
                curBest = g
            end
            if not curBest or not curBest.score or ghostData.score > curBest.score then
                local out = io.open(M.saveDirectory .. "/ghost_best.json", "w")
                if out then
                    local g = ghostData
                    local lines = { "{",
                        '  "timestamp": ' .. (g.timestamp or 0) .. ",",
                        '  "factionId": "' .. tostring(g.factionId or "") .. '",',
                        '  "difficulty": "' .. tostring(g.difficulty or "standard") .. '",',
                        '  "day": ' .. (g.daysSurvived or g.day or 0) .. ",",
                        '  "daysSurvived": ' .. (g.daysSurvived or g.day or 0) .. ",",
                        '  "totalKills": ' .. (g.totalKills or 0) .. ",",
                        '  "maxCombo": ' .. (g.maxCombo or 0) .. ",",
                        '  "score": ' .. (g.score or 0) .. ",",
                        '  "techCount": ' .. (g.techCount or 0) .. ",",
                        '  "relicCount": ' .. (g.relicCount or 0) .. ",",
                        '  "playTime": ' .. (g.playTime or 0),
                        "}"
                    }
                    out:write(table.concat(lines, "\n"))
                    out:close()
                end
            end
        end
    end)
end

function SaveSystem.loadBestGhost()
    if not M.saveDirectory then M.init() end
    local ok, val = pcall(function()
        local file = io.open(M.saveDirectory .. "/ghost_best.json", "r")
        if not file then return nil end
        local content = file:read("*a")
        file:close()
        local g = {}
        for key, val in string.gmatch(content, '"(%w+)"%s*:%s*([^,%s}]+)') do
            if tonumber(val) then g[key] = tonumber(val) else g[key] = string.gsub(val, '"', '') end
        end
        if g and g.score and type(g.score) == "number" and g.score > 0 then
            return g
        end
        return nil
    end)
    if ok and val and type(val) == "table" and val.score then
        return val
    end
    return nil
end

function SaveSystem.loadGhost()
    if not M.saveDirectory then M.init() end
    local ghost = nil
    pcall(function()
        local file = io.open(M.saveDirectory .. "/ghost_runs.json", "r")
        if file then
            local content = file:read("*a")
            file:close()
            local g = {}
            for key, val in string.gmatch(content, '"(%w+)"%s*:%s*([^,%s}]+)') do
                if tonumber(val) then g[key] = tonumber(val) else g[key] = string.gsub(val, '"', '') end
            end
            ghost = g
        end
    end)
    return ghost
end

-- ============================================================================
-- Phase 27: 存档版本迁移
-- ============================================================================
function SaveSystem.migrateSaveData(oldVersion, newVersion)
    if oldVersion == newVersion then return "up_to_date" end
    local major, minor = 0, 0
    if type(oldVersion) == "string" then
        for a, b in string.gmatch(oldVersion, "(%d+)%.(%d+)") do
            major, minor = tonumber(a), tonumber(b)
        end
    end
    if major < 2 or (major == 2 and minor < 0) then
        pcall(function()
            local file = io.open(M.saveDirectory .. "/star_sea_save.json", "r")
            if file then
                file:close()
            end
        end)
        return "migrated_from_v1"
    end
    return "no_migration_needed"
end

-- ============================================================================
-- Phase 24: 永久升级（元进度）跨局持久化
-- ============================================================================
function SaveSystem.saveMetaUpgrades(upgrades)
    if not M.saveDirectory then M.init() end
    if not upgrades then return false end
    pcall(function()
        local file = io.open(M.saveDirectory .. "/meta_upgrades.json", "w")
        if file then
            local lines = { "{", '  "formatVersion": 1,', '  "upgrades": {' }
            local keys = {}
            for k, _ in pairs(upgrades) do table.insert(keys, k) end
            table.sort(keys)
            for i, k in ipairs(keys) do
                local comma = i < #keys and "," or ""
                table.insert(lines, '    "' .. k .. '": ' .. tostring(upgrades[k] or 0) .. comma)
            end
            table.insert(lines, "  }")
            table.insert(lines, "}")
            file:write(table.concat(lines, "\n"))
            file:close()
        end
    end)
    return true
end

function SaveSystem.loadMetaUpgrades()
    if not M.saveDirectory then M.init() end
    local upgrades = {}
    pcall(function()
        local file = io.open(M.saveDirectory .. "/meta_upgrades.json", "r")
        if file then
            local content = file:read("*a")
            file:close()
            for key, val in string.gmatch(content, '"(%w+)"%s*:%s*(%d+)') do
                upgrades[key] = tonumber(val) or 0
            end
        end
    end)
    return upgrades
end

-- ============================================================================
-- Phase 24: 已解锁成就持久化（跨局保留，与成就系统同步）
-- ============================================================================
function SaveSystem.saveAchievements(achievementIds)
    if not M.saveDirectory then M.init() end
    if not achievementIds then return false end
    pcall(function()
        local file = io.open(M.saveDirectory .. "/achievements.json", "w")
        if file then
            local lines = { "{", '  "count": ' .. #achievementIds .. ',', '  "ids": [' }
            for i, id in ipairs(achievementIds) do
                local comma = i < #achievementIds and "," or ""
                table.insert(lines, '    "' .. tostring(id) .. '"' .. comma)
            end
            table.insert(lines, "  ]")
            table.insert(lines, "}")
            file:write(table.concat(lines, "\n"))
            file:close()
        end
    end)
    return true
end

function SaveSystem.loadAchievements()
    if not M.saveDirectory then M.init() end
    local ids = {}
    pcall(function()
        local file = io.open(M.saveDirectory .. "/achievements.json", "r")
        if file then
            local content = file:read("*a")
            file:close()
            for id in string.gmatch(content, '"([%w_]+)"') do
                if id ~= "formatVersion" and id ~= "count" and id ~= "ids" then
                    table.insert(ids, id)
                end
            end
        end
    end)
    return ids
end

return SaveSystem
