-- ============================================================================
-- 星海征途 - 扩展系统模块
-- 遗物、精英词缀、连击、成就、每日挑战、飞船外观、统计
-- ============================================================================

local Data = require("game.Data")
local Systems = {}

-- ============================================================================
-- Phase 1.3: 慢动作系统
-- ============================================================================
Systems.slowmo = {
    active = false,
    scale = 1.0,     -- 当前时间缩放
    target = 1.0,    -- 目标缩放
    duration = 0,    -- 剩余持续时间
}

function Systems.triggerSlowmo(duration, scale)
    Systems.slowmo.active = true
    Systems.slowmo.scale = scale or 0.2
    Systems.slowmo.target = scale or 0.2
    Systems.slowmo.duration = duration or 0.5
end

function Systems.updateSlowmo(dt)
    local sm = Systems.slowmo
    if sm.duration > 0 then
        sm.duration = sm.duration - dt
        if sm.duration <= 0 then
            sm.active = false
            sm.scale = 1.0
            sm.target = 1.0
        else
            -- 缓动回1.0（最后30%加速恢复）
            local ratio = sm.duration / 0.5
            if ratio < 0.3 then
                sm.scale = sm.target + (1.0 - sm.target) * (1 - ratio / 0.3)
            end
        end
    end
    return sm.scale
end

-- ============================================================================
-- Phase 2.3: 连击Combo系统
-- ============================================================================
Systems.combo = {
    count = 0,       -- 当前连击数
    timer = 0,       -- 连击衰减计时
    maxTimer = 2.5,  -- 连击衰减时间窗口
    bestCombo = 0,   -- 本局最高连击
    multiplier = 1.0,-- 当前分数倍率
    displayTimer = 0,-- 显示动画计时
}

-- Combo里程碑奖励定义
Systems.COMBO_MILESTONES = {
    { at = 5,  reward = "shield",  desc = "护盾恢复+20" },
    { at = 10, reward = "slowmo",  desc = "子弹时间2秒" },
    { at = 20, reward = "aoe",     desc = "冲击波爆发" },
    { at = 35, reward = "regen",   desc = "持续回复5秒" },
    { at = 50, reward = "overdrive", desc = "火力全开5秒" },
}

function Systems.onKill()
    local c = Systems.combo
    c.count = c.count + 1
    c.timer = c.maxTimer
    c.displayTimer = 0.5  -- 显示动画
    if c.count > c.bestCombo then c.bestCombo = c.count end
    -- 倍率计算：5连=1.5x, 10连=2x, 20连=3x, 50连=5x
    if c.count >= 50 then c.multiplier = 5.0
    elseif c.count >= 20 then c.multiplier = 3.0
    elseif c.count >= 10 then c.multiplier = 2.0
    elseif c.count >= 5 then c.multiplier = 1.5
    else c.multiplier = 1.0 end
    -- 检查里程碑（精确命中才触发，避免重复）
    local milestone = nil
    for _, m in ipairs(Systems.COMBO_MILESTONES) do
        if c.count == m.at then
            milestone = m
            break
        end
    end
    return c.multiplier, milestone
end

function Systems.updateCombo(dt)
    local c = Systems.combo
    if c.count > 0 then
        c.timer = c.timer - dt
        c.displayTimer = math.max(0, c.displayTimer - dt)
        if c.timer <= 0 then
            c.count = 0
            c.multiplier = 1.0
        end
    end
end

function Systems.resetCombo()
    Systems.combo.count = 0
    Systems.combo.timer = 0
    Systems.combo.multiplier = 1.0
    Systems.combo.bestCombo = 0
    Systems.combo.displayTimer = 0
end

-- ============================================================================
-- Phase 2.2: 精英词缀系统
-- ============================================================================
Systems.AFFIXES = {
    {
        id = "swift", name = "迅捷",
        color = { 100, 255, 100 },
        apply = function(e) e.cfg = setmetatable({speed = e.cfg.speed * 1.6}, {__index = e.cfg}); e.affix = "swift" end,
    },
    {
        id = "vampiric", name = "吸血",
        color = { 255, 50, 80 },
        apply = function(e) e.affix = "vampiric"; e.vampHeal = 0.15 end,
    },
    {
        id = "splitting", name = "分裂",
        color = { 255, 200, 0 },
        apply = function(e) e.affix = "splitting"; e.splitOnDeath = true end,
    },
    {
        id = "deflector", name = "偏转",
        color = { 80, 180, 255 },
        apply = function(e) e.affix = "deflector"; e.deflectChance = 0.3 end,
    },
    {
        id = "berserker", name = "狂暴",
        color = { 255, 120, 0 },
        apply = function(e)
            e.affix = "berserker"
            e.cfg = setmetatable({fire = e.cfg.fire * 0.5, dmg = math.floor(e.cfg.dmg * 1.4)}, {__index = e.cfg})
        end,
    },
}

--- 尝试为敌人附加精英词缀（day >= 5 后概率触发）
function Systems.tryApplyAffix(enemy, day)
    if enemy.isBoss then return end
    -- 基础概率：day5=5%, day10=12%, day20=22%, day30=30%
    local chance = math.max(0, (day - 4) * 0.012)
    if math.random() < chance then
        local affix = Systems.AFFIXES[math.random(1, #Systems.AFFIXES)]
        affix.apply(enemy)
        enemy.affixName = affix.name
        enemy.affixColor = affix.color
        -- 精英额外奖励
        enemy.hpMax = math.floor(enemy.hpMax * 1.5)
        enemy.hp = enemy.hpMax
        enemy.eliteReward = true
    end
end

-- ============================================================================
-- Phase 2.1: 遗物系统
-- ============================================================================
Systems.RELICS = {
    { id = "r_crit", name = "暴击芯片", desc = "20%概率双倍伤害", color = {255,80,80}, icon = "⚡" },
    { id = "r_magnet", name = "永恒引力", desc = "拾取范围+80%", color = {0,255,180}, icon = "◎" },
    { id = "r_regen", name = "纳米修复", desc = "HP回复2/秒", color = {100,255,100}, icon = "♥" },
    { id = "r_dodge", name = "相位闪避", desc = "15%概率闪避伤害", color = {180,180,255}, icon = "◇" },
    { id = "r_bounty", name = "赏金猎人", desc = "击杀金属+50%", color = {255,200,0}, icon = "★" },
    { id = "r_thorns", name = "反伤甲", desc = "受伤时反弹30%伤害", color = {200,100,255}, icon = "✦" },
    { id = "r_chain", name = "连锁闪电", desc = "击杀后闪电链30%几率跳转", color = {100,200,255}, icon = "⚡" },
    { id = "r_shield_burst", name = "护盾爆发", desc = "护盾破碎时伤害周围敌人", color = {0,180,255}, icon = "◆" },
    { id = "r_xp_boost", name = "经验增幅", desc = "分数获取+30%", color = {255,255,100}, icon = "▲" },
    { id = "r_lifesteal", name = "生命汲取", desc = "造成伤害回复2%HP", color = {255,80,150}, icon = "♦" },
    -- P7.4 新遗物
    { id = "r_multishot", name = "分裂弹头", desc = "子弹+2发散射(伤害-20%)", color = {255,150,0}, icon = "✧" },
    { id = "r_slowfield", name = "引力阱", desc = "周围敌人减速30%", color = {100,0,200}, icon = "◉" },
    { id = "r_lucky", name = "幸运星", desc = "掉落率+40%,暴击+10%", color = {255,220,50}, icon = "☆" },
    { id = "r_overclock", name = "超频核心", desc = "射速+50%但过热时停火2秒", color = {255,60,0}, icon = "⚙" },
    { id = "r_echo", name = "回声弹", desc = "击杀时25%几率发射追踪弹", color = {0,200,180}, icon = "↺" },
}

Systems.MAX_RELIC_SLOTS = 3

function Systems.initRelics(state)
    state.relics = state.relics or {}        -- 已装备遗物id列表
    state.relicDropTimer = 0
end

function Systems.hasRelic(state, relicId)
    for _, r in ipairs(state.relics or {}) do
        if r == relicId then return true end
    end
    return false
end

function Systems.addRelic(state, relicId)
    if #(state.relics or {}) >= Systems.MAX_RELIC_SLOTS then return false end
    if Systems.hasRelic(state, relicId) then return false end
    table.insert(state.relics, relicId)
    return true
end

function Systems.getRelicDef(relicId)
    for _, r in ipairs(Systems.RELICS) do
        if r.id == relicId then return r end
    end
    return nil
end

--- 遗物掉落检查（不立即装备，返回遗物def供生成掉落实体。Boss=100%，精英=30%）
function Systems.checkRelicDrop(state, enemy)
    if #(state.relics or {}) >= Systems.MAX_RELIC_SLOTS then return end
    local chance = 0
    if enemy.isBoss then chance = 1.0
    elseif enemy.eliteReward then chance = 0.30
    else return end
    if math.random() > chance then return end
    -- 随机选择一个未拥有的遗物
    local available = {}
    for _, r in ipairs(Systems.RELICS) do
        if not Systems.hasRelic(state, r.id) then
            available[#available + 1] = r.id
        end
    end
    if #available == 0 then return end
    local chosen = available[math.random(1, #available)]
    local def = Systems.getRelicDef(chosen)
    return def  -- 返回遗物定义（不装备），由调用者生成掉落实体
end

--- 遗物效果：暴击判定
function Systems.rollCrit(state)
    if Systems.hasRelic(state, "r_crit") then
        return math.random() < 0.20
    end
    return false
end

--- 遗物效果：闪避判定
function Systems.rollDodge(state)
    if Systems.hasRelic(state, "r_dodge") then
        return math.random() < 0.15
    end
    return false
end

-- ============================================================================
-- Phase 2.4: Boss二阶段
-- ============================================================================
function Systems.checkBossPhase2(enemy)
    if not enemy.isBoss then return end
    if enemy.phase2 then return end  -- 已进入
    if enemy.hp <= enemy.hpMax * 0.5 then
        enemy.phase2 = true
        enemy.phase2Flash = 1.0  -- 闪白动画
        -- 增强属性
        enemy.cfg = setmetatable({
            speed = enemy.cfg.speed * 1.4,
            fire = enemy.cfg.fire * 0.6,
            dmg = math.floor(enemy.cfg.dmg * 1.5),
        }, {__index = enemy.cfg})
        return true  -- 通知调用者播放特效
    end
    return false
end

-- ============================================================================
-- Phase 3.1: 新敌人类型定义
-- ============================================================================
Systems.NEW_ENEMIES = {
    cloaker = {
        name = "幽影潜行者",
        hp = 80, speed = 100, size = 14,
        fire = 1.5, dmg = 15, range = 250,
        color = { 120, 80, 200 },
        score = 180, metal = 3, energy = 3, blueprint = 1,
        behavior = "cloak",  -- 周期性隐身
    },
    summoner = {
        name = "虫群母舰",
        hp = 200, speed = 40, size = 26,
        fire = 3.0, dmg = 8, range = 350,
        color = { 200, 150, 50 },
        score = 300, metal = 5, energy = 4, blueprint = 2,
        behavior = "summon",  -- 定期召唤drone
    },
    splitter = {
        name = "裂变球",
        hp = 120, speed = 90, size = 20,
        fire = 1.8, dmg = 12, range = 300,
        color = { 0, 255, 128 },
        score = 200, metal = 4, energy = 3, blueprint = 1,
        behavior = "split",  -- 死亡分裂为小型
    },
}

-- ============================================================================
-- Phase 3.2: 隐藏Boss
-- ============================================================================
Systems.HIDDEN_BOSS = {
    id = "void",
    name = "虚空吞噬者",
    color = { 40, 0, 80 },
    hp = 6000, speed = 55, fire = 1.0, dmg = 35,
    size = 70, range = 700, score = 15000,
    blueprint = 30, key = 8, zone = "inner",
    pattern = "void",
    -- 触发条件：day >= 25 且 三个boss都已击杀 且 total_kills >= 200
    triggerCheck = function(state)
        return state.day >= 25
            and state.bossesKilled.echo
            and state.bossesKilled.core
            and state.bossesKilled.eye
            and state.totalKills >= 200
            and not state.bossesSpawned.void
    end,
}

-- ============================================================================
-- Phase 3.3: 环境危害
-- ============================================================================
Systems.HAZARDS = {
    black_hole = {
        name = "微型黑洞",
        radius = 80,       -- 引力场半径
        pullForce = 200,   -- 引力强度
        dmgPerSec = 15,    -- 核心伤害
        coreRadius = 20,   -- 伤害核心
        lifetime = 20,
        color = { 60, 0, 120 },
    },
    ion_storm = {
        name = "离子风暴区",
        radius = 150,
        dmgPerSec = 8,
        slowFactor = 0.5,  -- 速度降低50%
        lifetime = 15,
        color = { 100, 200, 255 },
    },
    energy_wall = {
        name = "能量壁垒",
        length = 200,
        dmgOnTouch = 25,
        lifetime = 12,
        color = { 255, 60, 180 },
    },
}

function Systems.initHazards(state)
    state.hazards = state.hazards or {}
    state.hazardSpawnTimer = state.hazardSpawnTimer or 0
end

function Systems.spawnHazard(state, kind)
    local def = Systems.HAZARDS[kind]
    if not def then return end
    local ang = math.random() * math.pi * 2
    local r = 200 + math.random() * 1500
    local h = {
        kind = kind,
        x = math.cos(ang) * r,
        y = math.sin(ang) * r,
        life = def.lifetime,
        maxLife = def.lifetime,
        angle = math.random() * math.pi * 2,  -- for energy_wall direction
    }
    table.insert(state.hazards, h)
end

function Systems.updateHazards(state, dt, distFn)
    if not state.hazards then return end
    -- 每帧重置离子风暴标记
    state._inIonStorm = false
    -- 生成计时
    state.hazardSpawnTimer = (state.hazardSpawnTimer or 0) + dt
    if state.hazardSpawnTimer > 30 and state.day >= 8 then
        state.hazardSpawnTimer = 0
        local kinds = {"black_hole", "ion_storm", "energy_wall"}
        Systems.spawnHazard(state, kinds[math.random(1, #kinds)])
    end
    -- 更新
    local p = state.player
    for i = #state.hazards, 1, -1 do
        local h = state.hazards[i]
        h.life = h.life - dt
        if h.life <= 0 then
            table.remove(state.hazards, i)
        else
            local def = Systems.HAZARDS[h.kind]
            local d = distFn(p.x, p.y, h.x, h.y)
            if h.kind == "black_hole" then
                -- 引力拉扯
                if d < def.radius and d > 1 then
                    local force = def.pullForce * (1 - d / def.radius) * dt
                    local ax = (h.x - p.x) / d * force
                    local ay = (h.y - p.y) / d * force
                    p.vx = (p.vx or 0) + ax
                    p.vy = (p.vy or 0) + ay
                end
                -- 核心伤害
                if d < def.coreRadius then
                    p.hp = p.hp - def.dmgPerSec * dt
                end
            elseif h.kind == "ion_storm" then
                if d < def.radius then
                    p.hp = p.hp - def.dmgPerSec * dt
                    state._inIonStorm = true
                end
            elseif h.kind == "energy_wall" then
                -- 简化为圆形检测
                if d < def.length * 0.5 then
                    -- 仅首次接触伤害
                    if not h.hitPlayer then
                        p.hp = p.hp - def.dmgOnTouch
                        h.hitPlayer = true
                    end
                else
                    h.hitPlayer = false
                end
            end
        end
    end
end

-- ============================================================================
-- Phase 3.4: 成就系统
-- ============================================================================
Systems.ACHIEVEMENTS = {
    { id = "a_first_kill", name = "初次击杀", desc = "击杀第一个敌人", icon = "🎯" },
    { id = "a_kill_50", name = "猎手", desc = "累计击杀50个敌人", icon = "⚔" },
    { id = "a_kill_200", name = "歼灭者", desc = "累计击杀200个敌人", icon = "💀" },
    { id = "a_kill_500", name = "星际屠夫", desc = "累计击杀500个敌人", icon = "☠" },
    { id = "a_boss_echo", name = "回响终结", desc = "击败湍流尸骸", icon = "👑" },
    { id = "a_boss_core", name = "核心净化", desc = "击败畸变源核", icon = "👑" },
    { id = "a_boss_eye", name = "深渊凝视", desc = "击败深渊之眼", icon = "👑" },
    { id = "a_boss_void", name = "虚空征服", desc = "击败隐藏Boss", icon = "🏆" },
    { id = "a_combo_10", name = "连击高手", desc = "达成10连击", icon = "🔥" },
    { id = "a_combo_30", name = "连击大师", desc = "达成30连击", icon = "🔥" },
    { id = "a_combo_50", name = "连击之神", desc = "达成50连击", icon = "💥" },
    { id = "a_day_10", name = "存活10天", desc = "赛季存活10天", icon = "📅" },
    { id = "a_day_20", name = "存活20天", desc = "赛季存活20天", icon = "📅" },
    { id = "a_day_30", name = "赛季完成", desc = "存活30天完成赛季", icon = "🏅" },
    { id = "a_relic_1", name = "遗物收集者", desc = "获得第一个遗物", icon = "💎" },
    { id = "a_relic_3", name = "遗物满载", desc = "集齐3个遗物", icon = "💎" },
    { id = "a_tech_all", name = "科技全满", desc = "研发所有科技", icon = "🔬" },
    { id = "a_score_5k", name = "5000分", desc = "单局得分5000", icon = "⭐" },
    { id = "a_score_20k", name = "2万分", desc = "单局得分20000", icon = "⭐" },
    { id = "a_score_50k", name = "5万分", desc = "单局得分50000", icon = "🌟" },
    { id = "a_no_hit_boss", name = "完美击杀", desc = "Boss战不受伤", icon = "✨" },
    { id = "a_relay_3", name = "网络构建", desc = "建造3座中继站", icon = "📡" },
    { id = "a_hijack_5", name = "黑客大师", desc = "劫持5个敌人", icon = "🖥" },
    { id = "a_collect_100m", name = "矿业大亨", desc = "累计采集100金属", icon = "⛏" },
    { id = "a_elite_10", name = "精英猎人", desc = "击杀10个精英敌人", icon = "🛡" },
    { id = "a_missile_20", name = "导弹专家", desc = "导弹击杀20个敌人", icon = "🚀" },
    { id = "a_laser_kill", name = "激光战术", desc = "激光击杀10个敌人", icon = "⚡" },
    { id = "a_ally_mode", name = "指挥官", desc = "使用所有盟友模式", icon = "🎖" },
    { id = "a_hazard_survive", name = "险境生还", desc = "在环境危害中存活30秒", icon = "🌪" },
    { id = "a_speed_clear", name = "闪电战", desc = "3天内击杀首个Boss", icon = "⚡" },
}

function Systems.initAchievements(state)
    state.achievements = state.achievements or {}
    state.achievementQueue = state.achievementQueue or {}  -- 待显示队列
    state.achStats = state.achStats or {
        eliteKills = 0, missileKills = 0, laserKills = 0,
        hijackCount = 0, hazardTime = 0, allyModesUsed = {},
    }
end

function Systems.unlockAchievement(state, achId)
    if not state.achievements then state.achievements = {} end
    for _, a in ipairs(state.achievements) do
        if a == achId then return false end  -- 已解锁
    end
    table.insert(state.achievements, achId)
    -- P9: 播放成就音效
    local Audio = require("game.Audio")
    Audio.playAchievement()
    -- 加入显示队列
    for _, def in ipairs(Systems.ACHIEVEMENTS) do
        if def.id == achId then
            state.achievementQueue = state.achievementQueue or {}
            table.insert(state.achievementQueue, { def = def, timer = 3.0 })
            break
        end
    end
    return true
end

function Systems.checkAchievements(state)
    local kills = state.totalKills or 0
    local score = state.score or 0
    local day = state.day or 1
    if kills >= 1 then Systems.unlockAchievement(state, "a_first_kill") end
    if kills >= 50 then Systems.unlockAchievement(state, "a_kill_50") end
    if kills >= 200 then Systems.unlockAchievement(state, "a_kill_200") end
    if kills >= 500 then Systems.unlockAchievement(state, "a_kill_500") end
    if state.bossesKilled and state.bossesKilled.echo then Systems.unlockAchievement(state, "a_boss_echo") end
    if state.bossesKilled and state.bossesKilled.core then Systems.unlockAchievement(state, "a_boss_core") end
    if state.bossesKilled and state.bossesKilled.eye then Systems.unlockAchievement(state, "a_boss_eye") end
    if state.bossesKilled and state.bossesKilled.void then Systems.unlockAchievement(state, "a_boss_void") end
    if Systems.combo.bestCombo >= 10 then Systems.unlockAchievement(state, "a_combo_10") end
    if Systems.combo.bestCombo >= 30 then Systems.unlockAchievement(state, "a_combo_30") end
    if Systems.combo.bestCombo >= 50 then Systems.unlockAchievement(state, "a_combo_50") end
    if day >= 10 then Systems.unlockAchievement(state, "a_day_10") end
    if day >= 20 then Systems.unlockAchievement(state, "a_day_20") end
    if day >= 30 then Systems.unlockAchievement(state, "a_day_30") end
    if #(state.relics or {}) >= 1 then Systems.unlockAchievement(state, "a_relic_1") end
    if #(state.relics or {}) >= 3 then Systems.unlockAchievement(state, "a_relic_3") end
    if score >= 5000 then Systems.unlockAchievement(state, "a_score_5k") end
    if score >= 20000 then Systems.unlockAchievement(state, "a_score_20k") end
    if score >= 50000 then Systems.unlockAchievement(state, "a_score_50k") end
    if (state.relayCount or 0) >= 3 then Systems.unlockAchievement(state, "a_relay_3") end
    if (state.achStats and state.achStats.eliteKills or 0) >= 10 then Systems.unlockAchievement(state, "a_elite_10") end
    if (state.achStats and state.achStats.missileKills or 0) >= 20 then Systems.unlockAchievement(state, "a_missile_20") end
    if (state.achStats and state.achStats.laserKills or 0) >= 10 then Systems.unlockAchievement(state, "a_laser_kill") end
    if (state.achStats and state.achStats.hijackCount or 0) >= 5 then Systems.unlockAchievement(state, "a_hijack_5") end
    if (state.totalCollected and state.totalCollected.metal or 0) >= 100 then Systems.unlockAchievement(state, "a_collect_100m") end
    if #(state.ownedTech or {}) >= #Data.TECH_TREE then Systems.unlockAchievement(state, "a_tech_all") end
end

-- ============================================================================
-- Phase 4.1: 每日挑战
-- ============================================================================
Systems.dailyChallenge = {
    -- 修饰符池
    modifiers = {
        { id = "fast_enemies", name = "敌速×2", apply = function(s) s._dailyEnemySpeed = 2.0 end },
        { id = "no_shield", name = "无护盾", apply = function(s) s.player.shieldMax = 0; s.player.shield = 0 end },
        { id = "glass_cannon", name = "玻璃大炮", apply = function(s) s.player.hpMax = 50; s.player.hp = 50; s.stats.dmgMul = s.stats.dmgMul * 2 end },
        { id = "bullet_hell", name = "弹幕地狱", apply = function(s) s._dailyFireRate = 0.4 end },
        { id = "rich_start", name = "资源丰富", apply = function(s) s.resources.metal = 50; s.resources.energy = 50; s.resources.blueprint = 10 end },
        { id = "short_season", name = "闪电赛季", apply = function(s) s.dayLength = 12 end },
    },
}

function Systems.getDailySeed()
    -- 基于日期生成种子
    local date = os.date("*t")
    return date.year * 10000 + date.month * 100 + date.day
end

function Systems.getDailyModifiers()
    local seed = Systems.getDailySeed()
    math.randomseed(seed)
    local mods = Systems.dailyChallenge.modifiers
    -- 每天选2个修饰符
    local idx1 = math.random(1, #mods)
    local idx2 = idx1
    while idx2 == idx1 do idx2 = math.random(1, #mods) end
    math.randomseed(os.time())  -- 恢复随机
    return { mods[idx1], mods[idx2] }
end

-- ============================================================================
-- Phase 4.2: 飞船外观
-- ============================================================================
Systems.SHIP_SKINS = {
    { id = "default", name = "标准型", color = {0, 200, 255}, unlock = "default" },
    { id = "crimson", name = "赤红战鹰", color = {255, 60, 60}, unlock = "a_kill_200" },
    { id = "phantom", name = "幽灵涂装", color = {180, 100, 255}, unlock = "a_boss_eye" },
    { id = "golden", name = "黄金猎手", color = {255, 200, 0}, unlock = "a_score_50k" },
    { id = "void", name = "虚空征服者", color = {60, 0, 120}, unlock = "a_boss_void" },
}

function Systems.getUnlockedSkins(achievements)
    local unlocked = {}
    for _, skin in ipairs(Systems.SHIP_SKINS) do
        if skin.unlock == "default" then
            unlocked[#unlocked + 1] = skin
        else
            for _, a in ipairs(achievements or {}) do
                if a == skin.unlock then
                    unlocked[#unlocked + 1] = skin
                    break
                end
            end
        end
    end
    return unlocked
end

-- ============================================================================
-- Phase 4.3: 永久统计
-- ============================================================================
Systems.STAT_KEYS = {
    "totalGames", "totalKills", "totalScore", "totalDays",
    "bestScore", "bestCombo", "bestDay", "bossKills",
    "totalPlayTime", "totalMetalCollected", "totalEnergyCollected",
}

function Systems.initPersistentStats()
    -- 从文件加载（简化：使用state中存储）
    return {
        totalGames = 0, totalKills = 0, totalScore = 0, totalDays = 0,
        bestScore = 0, bestCombo = 0, bestDay = 0, bossKills = 0,
        totalPlayTime = 0, totalMetalCollected = 0, totalEnergyCollected = 0,
    }
end

function Systems.updatePersistentStats(pStats, gameState)
    pStats.totalGames = pStats.totalGames + 1
    pStats.totalKills = pStats.totalKills + (gameState.totalKills or 0)
    pStats.totalScore = pStats.totalScore + (gameState.score or 0)
    pStats.totalDays = pStats.totalDays + (gameState.day or 0)
    if (gameState.score or 0) > pStats.bestScore then pStats.bestScore = gameState.score end
    if (Systems.combo.bestCombo or 0) > pStats.bestCombo then pStats.bestCombo = Systems.combo.bestCombo end
    if (gameState.day or 0) > pStats.bestDay then pStats.bestDay = gameState.day end
    local bk = 0
    if gameState.bossesKilled then
        for _, _ in pairs(gameState.bossesKilled) do bk = bk + 1 end
    end
    pStats.bossKills = pStats.bossKills + bk
    pStats.totalMetalCollected = pStats.totalMetalCollected + (gameState.totalCollected and gameState.totalCollected.metal or 0)
    pStats.totalEnergyCollected = pStats.totalEnergyCollected + (gameState.totalCollected and gameState.totalCollected.energy or 0)
end

-- ============================================================================
-- 永久升级系统（跨局持久化强化）
-- ============================================================================
Systems.UPGRADES = {
    { id = "u_hp",       name = "船体强化",   desc = "初始HP+10",       maxLv = 10, costBase = 100,  costScale = 1.5, effect = "hp",        perLv = 10 },
    { id = "u_shield",   name = "护盾改造",   desc = "初始护盾+15",     maxLv = 8,  costBase = 150,  costScale = 1.5, effect = "shield",    perLv = 15 },
    { id = "u_dmg",      name = "武器校准",   desc = "伤害+5%",         maxLv = 8,  costBase = 200,  costScale = 1.6, effect = "dmg",       perLv = 0.05 },
    { id = "u_speed",    name = "引擎调校",   desc = "移动速度+4%",     maxLv = 6,  costBase = 120,  costScale = 1.4, effect = "speed",     perLv = 0.04 },
    { id = "u_firerate", name = "射速增幅",   desc = "射速+5%",         maxLv = 6,  costBase = 180,  costScale = 1.5, effect = "firerate",  perLv = 0.05 },
    { id = "u_luck",     name = "幸运加持",   desc = "掉落率+5%",       maxLv = 5,  costBase = 250,  costScale = 1.6, effect = "luck",      perLv = 0.05 },
    { id = "u_regen",    name = "纳米修复",   desc = "HP回复+0.5/秒",   maxLv = 5,  costBase = 300,  costScale = 1.7, effect = "regen",     perLv = 0.5 },
    { id = "u_crit",     name = "致命打击",   desc = "暴击率+3%",       maxLv = 5,  costBase = 350,  costScale = 1.8, effect = "crit",      perLv = 0.03 },
}

--- 获取升级价格（当前等级 → 下一级的价格）
function Systems.getUpgradeCost(upgradeDef, currentLv)
    return math.floor(upgradeDef.costBase * (upgradeDef.costScale ^ currentLv))
end

--- 初始化升级数据
function Systems.initUpgrades()
    local upgrades = {}
    for _, def in ipairs(Systems.UPGRADES) do
        upgrades[def.id] = 0
    end
    return upgrades
end

--- 尝试购买升级（返回 true/false）
function Systems.buyUpgrade(upgradeId, upgrades, starDust)
    local def
    for _, u in ipairs(Systems.UPGRADES) do
        if u.id == upgradeId then def = u; break end
    end
    if not def then return false, starDust end
    local lv = upgrades[def.id] or 0
    if lv >= def.maxLv then return false, starDust end
    local cost = Systems.getUpgradeCost(def, lv)
    if starDust < cost then return false, starDust end
    starDust = starDust - cost
    upgrades[def.id] = lv + 1
    return true, starDust
end

--- 将永久升级应用到游戏状态
function Systems.applyUpgrades(state, upgrades)
    if not upgrades then return end
    local p = state.player
    for _, def in ipairs(Systems.UPGRADES) do
        local lv = upgrades[def.id] or 0
        if lv > 0 then
            local val = def.perLv * lv
            if def.effect == "hp" then
                p.hpMax = (p.hpMax or 100) + val
                p.hp = p.hpMax
            elseif def.effect == "shield" then
                p.shieldMax = (p.shieldMax or 0) + val
                p.shield = p.shieldMax
            elseif def.effect == "dmg" then
                state._permDmgMul = 1 + val
            elseif def.effect == "speed" then
                state._permSpeedMul = 1 + val
            elseif def.effect == "firerate" then
                state._permFireRateMul = 1 + val
            elseif def.effect == "luck" then
                state._permLuckMul = 1 + val
            elseif def.effect == "regen" then
                state._permRegen = val
            elseif def.effect == "crit" then
                state._permCritBonus = val
            end
        end
    end
end

--- 计算本局获得的星尘（游戏内货币，用于永久升级）
function Systems.calcStarDust(gameState)
    local base = math.floor((gameState.score or 0) / 10)
    local dayBonus = (gameState.day or 1) * 2
    local bossBonus = 0
    for _ in pairs(gameState.bossesKilled or {}) do bossBonus = bossBonus + 50 end
    return base + dayBonus + bossBonus
end

return Systems
