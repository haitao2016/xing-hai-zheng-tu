-- ============================================================================
-- 星海征途 - 游戏数据模块
-- 科技树、阵营、敌人配置、Boss定义、任务系统
-- ============================================================================

local Data = {}

-- ============================================================================
-- 科技树 (5类15项)
-- ============================================================================
Data.TECH_TREE = {
    -- 武器
    { id = "w1", cat = "武器", name = "量子脉冲炮 I", effect = "基础脉冲", cost = { blueprint = 0 }, requires = {}, starter = true },
    { id = "w2", cat = "武器", name = "量子脉冲炮 II", effect = "伤害+25% 射速+20%", cost = { blueprint = 4 }, requires = { "w1" } },
    { id = "w3", cat = "武器", name = "裂变射线", effect = "射程+40% 穿透+1", cost = { blueprint = 8 }, requires = { "w2" } },
    { id = "w4", cat = "武器", name = "湮灭主炮", effect = "伤害+60% 子弹分裂", cost = { blueprint = 14, ancient_key = 1 }, requires = { "w3" } },
    -- 护盾
    { id = "d1", cat = "护盾", name = "基础能量护盾", effect = "护盾+60", cost = { blueprint = 3 }, requires = {} },
    { id = "d2", cat = "护盾", name = "相位护盾", effect = "护盾+120 自动回复", cost = { blueprint = 7 }, requires = { "d1" } },
    { id = "d3", cat = "护盾", name = "维度屏障", effect = "护盾+220 减伤20%", cost = { blueprint = 12, ancient_key = 1 }, requires = { "d2" } },
    -- 引擎
    { id = "e1", cat = "引擎", name = "离子推进", effect = "速度+25%", cost = { blueprint = 3 }, requires = {} },
    { id = "e2", cat = "引擎", name = "曲速引擎", effect = "速度+50% 转向+30%", cost = { blueprint = 8 }, requires = { "e1" } },
    -- 核心
    { id = "c1", cat = "核心", name = "AI核心 LV.2", effect = "HP+80 解锁中环", cost = { blueprint = 5 }, requires = {} },
    { id = "c2", cat = "核心", name = "AI核心 LV.3", effect = "HP+160 解锁内环", cost = { blueprint = 10 }, requires = { "c1" } },
    { id = "c3", cat = "核心", name = "AI核心 LV.4", effect = "HP+280 全属性+10%", cost = { blueprint = 18, ancient_key = 2 }, requires = { "c2" } },
    -- 权限
    { id = "s1", cat = "权限", name = "深度入侵 I", effect = "解锁权限劫持", cost = { blueprint = 6 }, requires = {} },
    { id = "s2", cat = "权限", name = "深度入侵 II", effect = "劫持范围+50%", cost = { blueprint = 12 }, requires = { "s1" } },
    -- P4.4 激光武器
    { id = "w5", cat = "武器", name = "聚能激光", effect = "持续射线 充能越久伤害越高", cost = { blueprint = 10, ancient_key = 1 }, requires = { "w3" } },
    -- P4.5 追踪导弹
    { id = "w6", cat = "武器", name = "追踪导弹", effect = "锁定目标 自动追踪爆炸", cost = { blueprint = 12, ancient_key = 2 }, requires = { "w4" } },
    -- P7.1 副武器系统
    { id = "w7", cat = "武器", name = "散射炮", effect = "3发扇形弹幕 近距高伤", cost = { blueprint = 6 }, requires = { "w2" } },
    { id = "w8", cat = "武器", name = "量子回旋镖", effect = "飞出后返回 双重命中", cost = { blueprint = 9 }, requires = { "w3" } },
    { id = "w9", cat = "武器", name = "等离子地雷", effect = "延时AOE 区域封锁", cost = { blueprint = 11, ancient_key = 1 }, requires = { "w3" } },
}

function Data.getTech(id)
    for _, t in ipairs(Data.TECH_TREE) do
        if t.id == id then return t end
    end
    return nil
end

function Data.techStats(owned)
    local s = {
        dmg = 10, critChance = 0.05, critMul = 2.0,
        dmgMul = 1, fireRateMul = 1, range = 460, pierce = 0, splitShot = 0,
        shieldMax = 0, shieldRegen = 0, dmgReduce = 0,
        speedMul = 1, turnMul = 1,
        hpBonus = 0, allBonus = 1,
        hijackUnlocked = false, hijackRange = 90, blueprintBonus = 0,
        aiCoreLevel = 1,
        laserUnlocked = false, missileUnlocked = false,
        shotgunUnlocked = false, boomerangUnlocked = false, mineUnlocked = false,
    }
    for _, id in ipairs(owned) do
        if id == "w2" then s.dmgMul = s.dmgMul * 1.25; s.fireRateMul = s.fireRateMul * 1.2 end
        if id == "w3" then s.range = 640; s.pierce = 1 end
        if id == "w4" then s.dmgMul = s.dmgMul * 1.6; s.splitShot = 2 end
        if id == "d1" then s.shieldMax = s.shieldMax + 60 end
        if id == "d2" then s.shieldMax = s.shieldMax + 120; s.shieldRegen = 4 end
        if id == "d3" then s.shieldMax = s.shieldMax + 220; s.shieldRegen = 6; s.dmgReduce = 0.2 end
        if id == "e1" then s.speedMul = s.speedMul * 1.25 end
        if id == "e2" then s.speedMul = s.speedMul * 1.5; s.turnMul = 1.3 end
        if id == "c1" then s.hpBonus = s.hpBonus + 80; s.aiCoreLevel = math.max(s.aiCoreLevel, 2) end
        if id == "c2" then s.hpBonus = s.hpBonus + 160; s.aiCoreLevel = math.max(s.aiCoreLevel, 3) end
        if id == "c3" then s.hpBonus = s.hpBonus + 280; s.allBonus = 1.1; s.aiCoreLevel = math.max(s.aiCoreLevel, 4) end
        if id == "s1" then s.hijackUnlocked = true end
        if id == "s2" then s.hijackRange = 135; s.blueprintBonus = 1 end
        if id == "w5" then s.laserUnlocked = true end
        if id == "w6" then s.missileUnlocked = true end
        if id == "w7" then s.shotgunUnlocked = true end
        if id == "w8" then s.boomerangUnlocked = true end
        if id == "w9" then s.mineUnlocked = true end
    end
    return s
end

function Data.canAfford(cost, resources)
    for k, v in pairs(cost) do
        if (resources[k] or 0) < v then return false end
    end
    return true
end

function Data.requirementsMet(tech, owned)
    for _, req in ipairs(tech.requires) do
        local found = false
        for _, o in ipairs(owned) do
            if o == req then found = true; break end
        end
        if not found then return false end
    end
    return true
end

-- ============================================================================
-- 阵营系统
-- ============================================================================
Data.FACTIONS = {
    {
        id = "merchants",
        name = "商盟",
        motto = "财富即数据",
        color = { 255, 184, 77 },
        bonuses = { tradeDiscount = 0.15, blueprintMul = 1.10 },
        desc = "交易价格-15%, 蓝图掉落+10%",
    },
    {
        id = "warband",
        name = "战团",
        motto = "以炮火铭刻边界",
        color = { 255, 58, 92 },
        bonuses = { dmgMul = 1.20, fireRateMul = 1.15 },
        desc = "伤害+20%, 射速+15%",
    },
    {
        id = "scholars",
        name = "学者会",
        motto = "理解即胜利",
        color = { 0, 240, 255 },
        bonuses = { shieldRegenAdd = 3, hijackBlueprint = 0.25 },
        desc = "护盾回复+3/秒, 劫持蓝图+25%",
    },
}

function Data.getFaction(id)
    for _, f in ipairs(Data.FACTIONS) do
        if f.id == id then return f end
    end
    return nil
end

-- ============================================================================
-- 敌人配置
-- ============================================================================
Data.ENEMY_TYPES = {
    drone = {
        name = "巡逻无人机",
        hp = 40, speed = 80, size = 12,
        fire = 1.2, dmg = 8, range = 280,
        color = { 122, 223, 255 },
        score = 50, metal = 2, energy = 1, blueprint = 0,
    },
    aberration = {
        name = "数据畸变体",
        hp = 90, speed = 60, size = 18,
        fire = 1.6, dmg = 14, range = 340,
        color = { 255, 142, 220 },
        score = 120, metal = 3, energy = 2, blueprint = 1,
    },
    guard = {
        name = "深渊守卫",
        hp = 160, speed = 45, size = 22,
        fire = 2.0, dmg = 22, range = 400,
        color = { 205, 166, 255 },
        score = 250, metal = 5, energy = 3, blueprint = 2,
    },
    -- P3.3 新增敌人
    kamikaze = {
        name = "自爆核弹",
        hp = 50, speed = 180, size = 10,
        fire = 99, dmg = 45, range = 30,  -- 无射击，靠近自爆
        color = { 255, 60, 20 },
        score = 80, metal = 1, energy = 2, blueprint = 0,
        behavior = "kamikaze",  -- 冲向玩家自爆
    },
    flanker = {
        name = "侧翼突袭者",
        hp = 70, speed = 120, size = 14,
        fire = 1.0, dmg = 10, range = 300,
        color = { 180, 255, 80 },
        score = 100, metal = 2, energy = 2, blueprint = 1,
        behavior = "flank",  -- 绕到侧面攻击
    },
    healer = {
        name = "修复无人机",
        hp = 60, speed = 70, size = 12,
        fire = 3.0, dmg = 5, range = 200,
        color = { 100, 255, 200 },
        score = 150, metal = 3, energy = 4, blueprint = 1,
        behavior = "healer",  -- 治疗附近友军
    },
    -- Phase 3 新增敌人
    cloaker = {
        name = "幽影潜伏者",
        hp = 55, speed = 100, size = 14,
        fire = 1.5, dmg = 18, range = 220,
        color = { 120, 80, 200 },
        score = 180, metal = 3, energy = 3, blueprint = 2,
        behavior = "cloaker",  -- 周期隐身，解隐后背刺
    },
    summoner = {
        name = "虫巢母体",
        hp = 200, speed = 35, size = 26,
        fire = 4.0, dmg = 10, range = 350,
        color = { 220, 180, 60 },
        score = 300, metal = 6, energy = 5, blueprint = 3,
        behavior = "summoner",  -- 定期召唤小兵，远离玩家
    },
    splitter = {
        name = "裂变核心",
        hp = 120, speed = 65, size = 20,
        fire = 1.8, dmg = 12, range = 280,
        color = { 60, 255, 120 },
        score = 200, metal = 4, energy = 3, blueprint = 2,
        behavior = "splitter",  -- 死亡时分裂为2个小型体
    },
    -- P13.1 新增敌人
    absorber = {
        name = "虚空吞噬者",
        hp = 80, speed = 70, size = 16,
        fire = 2.0, dmg = 8, range = 250,
        color = { 100, 0, 180 },
        score = 220, metal = 4, energy = 4, blueprint = 2,
        behavior = "absorber",  -- 吸收子弹转化为护盾
    },
    disruptor = {
        name = "电磁干扰器",
        hp = 65, speed = 90, size = 14,
        fire = 4.0, dmg = 0, range = 400,
        color = { 0, 200, 255 },
        score = 250, metal = 3, energy = 5, blueprint = 3,
        behavior = "disruptor",  -- 释放EMP脉冲禁用武器
    },
    warper = {
        name = "时空扭曲者",
        hp = 100, speed = 110, size = 15,
        fire = 3.0, dmg = 15, range = 300,
        color = { 200, 0, 255 },
        score = 280, metal = 4, energy = 5, blueprint = 3,
        behavior = "warper",  -- 瞬移到玩家背后
    },
    quantum = {
        name = "量子分裂体",
        hp = 90, speed = 80, size = 18,
        fire = 1.5, dmg = 10, range = 260,
        color = { 255, 150, 255 },
        score = 200, metal = 3, energy = 4, blueprint = 2,
        behavior = "quantum",  -- 被击杀后分裂为2个小敌人
    },
}

-- ============================================================================
-- 临时道具定义 (P3.4)
-- ============================================================================
Data.POWERUP_TYPES = {
    speed_boost = {
        name = "曲速引擎",
        color = { 80, 200, 255 },
        icon = "▲",
        duration = 8,
        desc = "速度+80%",
    },
    fire_rate = {
        name = "超频射击",
        color = { 255, 200, 0 },
        icon = "✦",
        duration = 6,
        desc = "射速×2",
    },
    invincible = {
        name = "维度护盾",
        color = { 180, 100, 255 },
        icon = "◆",
        duration = 5,
        desc = "无敌",
    },
    magnet = {
        name = "引力牵引",
        color = { 0, 255, 150 },
        icon = "◎",
        duration = 10,
        desc = "拾取范围×3",
    },
    dmg_boost = {
        name = "火力增幅",
        color = { 255, 100, 50 },
        icon = "☄",
        duration = 8,
        desc = "伤害×1.8",
    },
    reflect = {
        name = "反弹护盾",
        color = { 255, 180, 0 },
        icon = "⟲",
        duration = 10,
        desc = "反弹50%伤害",
    },
}

-- ============================================================================
-- 波次定义 (P4.1)
-- ============================================================================
Data.WAVES = {
    { day = 3,  name = "侦察波", enemies = { drone = 6 } },
    { day = 6,  name = "畸变潮", enemies = { aberration = 4, drone = 3 } },
    { day = 9,  name = "突袭编队", enemies = { flanker = 5, kamikaze = 3 } },
    { day = 12, name = "深渊来袭", enemies = { guard = 3, aberration = 4 } },
    { day = 16, name = "自爆群", enemies = { kamikaze = 8, drone = 4 } },
    { day = 20, name = "精锐小队", enemies = { guard = 4, flanker = 3, healer = 2 } },
    { day = 24, name = "终极风暴", enemies = { guard = 5, aberration = 5, kamikaze = 5 } },
    { day = 28, name = "末日之潮", enemies = { guard = 6, flanker = 4, kamikaze = 6, healer = 2 } },
}

-- ============================================================================
-- 随机事件定义 (P4.2)
-- ============================================================================
Data.RANDOM_EVENTS = {
    {
        id = "solar_storm",
        name = "太阳风暴",
        color = { 255, 160, 0 },
        desc = "能见度降低，敌人加速！",
        duration = 15,
        effect = "storm",  -- 敌人速度+50%，视野缩小
    },
    {
        id = "supply_drop",
        name = "补给投放",
        color = { 0, 255, 180 },
        desc = "紧急补给到达附近！",
        duration = 0,  -- 即时
        effect = "supply",  -- 生成大量资源
    },
    {
        id = "repair_signal",
        name = "修复信号",
        color = { 100, 220, 255 },
        desc = "纳米修复激活",
        duration = 8,
        effect = "repair",  -- 持续回复HP
    },
    {
        id = "emp_pulse",
        name = "EMP脉冲",
        color = { 200, 100, 255 },
        desc = "全屏EMP，敌人暂停！",
        duration = 4,
        effect = "emp",  -- 敌人停止移动和射击
    },
}

-- ============================================================================
-- Boss 定义
-- ============================================================================
Data.BOSS_DEFS = {
    echo = {
        name = "湍流尸骸",
        color = { 255, 107, 157 },
        hp = 1200, speed = 50, fire = 1.4, dmg = 18,
        size = 38, range = 460, score = 1500,
        blueprint = 5, key = 1, zone = "middle",
        pattern = "ring",
    },
    core = {
        name = "畸变源核",
        color = { 255, 61, 240 },
        hp = 2400, speed = 42, fire = 1.8, dmg = 24,
        size = 46, range = 540, score = 3000,
        blueprint = 10, key = 2, zone = "inner",
        pattern = "spread",
    },
    eye = {
        name = "深渊之眼",
        color = { 180, 108, 255 },
        hp = 4800, speed = 36, fire = 2.2, dmg = 30,
        size = 60, range = 620, score = 8000,
        blueprint = 20, key = 5, zone = "inner",
        pattern = "omni",
    },
    -- 隐藏Boss：虚空
    void = {
        name = "虚空裂隙",
        color = { 20, 0, 60 },
        hp = 6000, speed = 55, fire = 1.6, dmg = 35,
        size = 50, range = 700, score = 15000,
        blueprint = 30, key = 8, zone = "inner",
        pattern = "void",   -- 虚空弹幕：交替螺旋+传送偷袭
        hidden = true,      -- 隐藏Boss标记（不在任务链中出现）
    },
    -- P13.2: 新Boss - 星际仲裁者
    arbiter = {
        name = "星际仲裁者",
        color = { 255, 215, 0 },
        hp = 3500, speed = 48, fire = 1.2, dmg = 25,
        size = 44, range = 600, score = 5000,
        blueprint = 15, key = 3, zone = "inner",
        pattern = "arbiter",  -- 激光阵+召唤仲裁骑士
        hidden = false,
    },
    -- P13.2: 新Boss - 深渊巨口
    leviathan = {
        name = "深渊巨口",
        color = { 60, 20, 100 },
        hp = 4500, speed = 40, fire = 2.0, dmg = 28,
        size = 52, range = 650, score = 7000,
        blueprint = 18, key = 4, zone = "inner",
        pattern = "leviathan",  -- 吞噬小行星恢复HP+全屏黑洞吸附
        hidden = false,
    },
}

-- ============================================================================
-- 任务/章节系统
-- ============================================================================
Data.QUESTS = {
    { id = "q1", chapter = 1, name = "苏醒", desc = "采集30金属+30能源",
      days = { 1, 5 }, reward = { blueprint = 5 },
      check = function(ctx) return ctx.resources.metal >= 30 and ctx.resources.energy >= 30 end },
    { id = "q2", chapter = 2, name = "深渊回响", desc = "击败Boss「湍流尸骸」",
      days = { 8, 12 }, reward = { blueprint = 8, ancient_key = 1 },
      bossSpawn = { id = "echo", day = 8 },
      check = function(ctx) return ctx.bossesKilled.echo end },
    { id = "q3", chapter = 3, name = "古老低语", desc = "建造1座数据中继站(B键)",
      days = { 12, 16 }, reward = { metal = 15, energy = 10 },
      check = function(ctx) return ctx.relayCount >= 1 end },
    { id = "q4", chapter = 4, name = "数据畸变", desc = "击败Boss「畸变源核」",
      days = { 16, 21 }, reward = { blueprint = 12, ancient_key = 2 },
      bossSpawn = { id = "core", day = 16 },
      check = function(ctx) return ctx.bossesKilled.core end },
    { id = "q5", chapter = 5, name = "归航准备", desc = "AI核心升至LV.3+",
      days = { 21, 26 }, reward = { blueprint = 10 },
      check = function(ctx) return ctx.aiCoreLevel >= 3 end },
    { id = "q6", chapter = 6, name = "深渊之眼", desc = "击败终Boss「深渊之眼」",
      days = { 26, 30 }, reward = { blueprint = 25, ancient_key = 5, score = 5000 },
      bossSpawn = { id = "eye", day = 26 },
      check = function(ctx) return ctx.bossesKilled.eye end },
}

-- ============================================================================
-- P3.6 事件选择奖励池（正面/负面配对）
-- ============================================================================
Data.EVENT_CHOICES = {
    {
        title = "星际信号",
        desc = "截获一段来源不明的加密信号...",
        options = {
            { label = "解码信号", desc = "获得补给+修复", effect = "supply_heal" },
            { label = "忽略信号", desc = "短时无敌护盾", effect = "temp_shield" },
        },
    },
    {
        title = "时空裂隙",
        desc = "前方出现不稳定的维度裂缝！",
        options = {
            { label = "穿越裂隙", desc = "全屏EMP冻结敌人", effect = "emp" },
            { label = "绕行避险", desc = "加速+8秒", effect = "speed_boost" },
        },
    },
    {
        title = "遗迹探测",
        desc = "探测到远古科技遗迹的能量波动",
        options = {
            { label = "探索遗迹", desc = "获得蓝图×3", effect = "blueprint_drop" },
            { label = "回收能量", desc = "护盾全充+回复", effect = "shield_full" },
        },
    },
    {
        title = "舰队残骸",
        desc = "发现一支被摧毁的舰队残骸",
        options = {
            { label = "搜刮残骸", desc = "金属+能源大量", effect = "loot_drop" },
            { label = "分析数据", desc = "射速加倍6秒", effect = "fire_rate" },
        },
    },
    {
        title = "太阳耀斑",
        desc = "恒星正在释放强烈耀斑！",
        options = {
            { label = "借助耀斑", desc = "伤害+50% 8秒", effect = "dmg_boost" },
            { label = "启动护盾", desc = "无敌5秒", effect = "invincible" },
        },
    },
}

-- P7.3 特殊星际事件（比普通事件更强力，有额外视觉效果）
Data.SPECIAL_EVENTS = {
    {
        id = "temporal_rift",
        title = "时空裂缝",
        desc = "维度断层撕裂了空间，时间在此扭曲...",
        color = { 0, 200, 255 },
        options = {
            { label = "进入裂缝", desc = "时间减速5秒(全局0.3倍速)", effect = "time_slow" },
            { label = "汲取能量", desc = "全武器CD重置+超载", effect = "cd_reset" },
        },
    },
    {
        id = "solar_storm_heavy",
        title = "太阳风暴",
        desc = "超级太阳风暴来袭！能量场剧烈波动！",
        color = { 255, 120, 0 },
        options = {
            { label = "引导风暴", desc = "对全屏敌人造成50伤害", effect = "storm_damage" },
            { label = "储能护盾", desc = "护盾全充+反弹伤害10秒", effect = "storm_shield" },
        },
    },
    {
        id = "merchant_fleet",
        title = "商人舰队",
        desc = "流浪商人舰队路经此地，提供交易！",
        color = { 255, 220, 50 },
        options = {
            { label = "购买武器", desc = "消耗20金属 → 火力+30%持续15秒", effect = "buy_weapon" },
            { label = "出售资源", desc = "消耗15能量 → 获得8图纸", effect = "sell_energy" },
        },
    },
    {
        id = "wormhole",
        title = "虫洞",
        desc = "一个不稳定的虫洞在附近形成...",
        color = { 180, 0, 255 },
        options = {
            { label = "跃入虫洞", desc = "随机传送+获大量资源", effect = "wormhole_jump" },
            { label = "稳定虫洞", desc = "召唤友军×3 持续20秒", effect = "wormhole_allies" },
        },
    },
}

-- P6.2 难度曲线参数
Data.DIFFICULTY = {
    enemyHpScale = 0.04,     -- 每天敌人HP增加4%
    enemyDmgScale = 0.03,    -- 每天敌人DMG增加3%
    enemySpeedScale = 0.015, -- 每天敌人速度增加1.5%
    spawnRateScale = 0.02,   -- 每天刷怪频率增加2%
    bossHpScale = 0.05,      -- Boss每天额外HP+5%
}

-- ============================================================================
-- P7.1 副武器定义
-- ============================================================================
Data.SECONDARY_WEAPONS = {
    { id = "shotgun",   name = "散射炮",     techId = "w7", color = { 255, 200, 50 },  cooldown = 1.2 },
    { id = "boomerang", name = "量子回旋镖", techId = "w8", color = { 0, 255, 200 },   cooldown = 2.0 },
    { id = "mine",      name = "等离子地雷", techId = "w9", color = { 200, 50, 255 },   cooldown = 3.0 },
}

-- ============================================================================
-- P11: 游戏模式定义
-- ============================================================================
Data.GAME_MODES = {
    {
        id = "season",
        name = "赛季模式",
        nameEn = "SEASON MODE",
        desc = "30天赛季挑战",
        color = { 80, 200, 120 },
        icon = "⚔",
    },
    {
        id = "endless",
        name = "无尽模式",
        nameEn = "ENDLESS MODE",
        desc = "无限挑战，难度递增",
        color = { 180, 80, 255 },
        icon = "∞",
    },
    {
        id = "timeattack",
        name = "限时挑战",
        nameEn = "TIME ATTACK",
        desc = "60秒击杀挑战",
        color = { 255, 150, 50 },
        icon = "⏱",
    },
    {
        id = "bullethell",
        name = "弹幕生存",
        nameEn = "BULLET HELL",
        desc = "躲避弹幕生存",
        color = { 255, 80, 120 },
        icon = "💫",
    },
    {
        id = "bossrush",
        name = "Boss Rush",
        nameEn = "BOSS RUSH",
        desc = "连续挑战Boss",
        color = { 200, 50, 50 },
        icon = "👹",
    },
}

-- ============================================================================
-- 世界常量
-- ============================================================================
Data.WORLD = {
    innerR = 700,   -- 内环外边界 (核心深渊)
    middleR = 1500, -- 中环外边界 (湍流区)
    outerR = 2400,  -- 外环边界 (碎片浅滩-安全区)
}

return Data
