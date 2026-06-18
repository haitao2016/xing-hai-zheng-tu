-- ============================================================================
-- 星海征途 - 云端排行榜模块
-- 使用 clientCloud API 实现分数上传与排行榜查询
-- ============================================================================

local Leaderboard = {}

-- 排行榜缓存
Leaderboard.rankList = {}     -- { {userId, nickname, score, rank}, ... }
Leaderboard.myRank = nil      -- 我的排名
Leaderboard.myBest = 0        -- 我的最高分
Leaderboard.loading = false   -- 加载中
Leaderboard.lastFetch = 0     -- 上次刷新时间

-- ============================================================================
-- 提交分数（游戏结束时调用）
-- ============================================================================
function Leaderboard.submitScore(score, scoreKey)
    if not clientCloud then return end

    local key = scoreKey or "high_score"
    -- 使用 SetInt 写入可排行的整数分数（排行榜只能基于 iscores）
    clientCloud:SetInt(key, score, {
        ok = function()
            log:Write(LOG_INFO, "[Leaderboard] Score submitted (" .. key .. "): " .. score)
            -- 提交成功后刷新我的排名
            Leaderboard.fetchMyRank()
        end,
        error = function(code, reason)
            log:Write(LOG_WARNING, "[Leaderboard] Submit failed: " .. tostring(reason))
        end,
    })

    -- 同时记录游戏次数
    clientCloud:Add("play_count", 1, {
        ok = function() end,
        error = function() end,
    })
end

-- ============================================================================
-- 获取排行榜（前10名）
-- ============================================================================
function Leaderboard.fetchRankList()
    if not clientCloud then return end
    if Leaderboard.loading then return end

    Leaderboard.loading = true
    -- 降序获取前10名，附带play_count
    clientCloud:GetRankList("high_score", 0, 10, {
        ok = function(rankList)
            Leaderboard.loading = false
            Leaderboard.rankList = {}
            -- 收集userId列表用于批量查昵称
            local userIds = {}
            for i, item in ipairs(rankList) do
                local entry = {
                    userId = item.player,
                    nickname = "玩家" .. tostring(item.player):sub(-4),
                    score = (item.iscore and item.iscore.high_score) or 0,
                    playCount = (item.iscore and item.iscore.play_count) or 0,
                    rank = i,
                }
                Leaderboard.rankList[i] = entry
                userIds[#userIds + 1] = item.player
            end
            -- 批量查询昵称
            if #userIds > 0 and GetUserNickname then
                GetUserNickname({
                    userIds = userIds,
                    onSuccess = function(nickMap)
                        for _, entry in ipairs(Leaderboard.rankList) do
                            if nickMap[entry.userId] then
                                entry.nickname = nickMap[entry.userId]
                            end
                        end
                    end,
                    onError = function() end,
                })
            end
            log:Write(LOG_INFO, "[Leaderboard] Fetched " .. #rankList .. " entries")
        end,
        error = function(code, reason)
            Leaderboard.loading = false
            log:Write(LOG_WARNING, "[Leaderboard] Fetch failed: " .. tostring(reason))
        end,
    }, "play_count")
end

-- ============================================================================
-- 获取我的排名
-- ============================================================================
function Leaderboard.fetchMyRank()
    if not clientCloud then return end

    local myId = clientCloud.userId
    if not myId then return end

    clientCloud:GetUserRank(myId, "high_score", {
        ok = function(rank, scoreValue)
            Leaderboard.myRank = rank
            Leaderboard.myBest = scoreValue or 0
        end,
        error = function() end,
    })
end

-- ============================================================================
-- 初始化（游戏启动时调用一次）
-- ============================================================================
function Leaderboard.init()
    if not clientCloud then
        log:Write(LOG_INFO, "[Leaderboard] clientCloud not available, leaderboard disabled")
        return
    end
    -- 拉取排行榜和我的排名
    Leaderboard.fetchRankList()
    Leaderboard.fetchMyRank()
end

return Leaderboard
