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
        story = [[
在星际文明的早期，商人们用最先进的加密技术保护交易数据。
他们发现，每一笔交易都是宇宙数据的一部分。
如今，商盟用贸易网络连接整个已知宇宙，
用数据编织着跨越星海的秩序。]],
        intro = "商人联盟:自由贸易倡导者",
        bossTitle = "金色王座",
    },
    {
        id = "warband",
        name = "战团",
        motto = "以炮火铭刻边界",
        color = { 255, 58, 92 },
        bonuses = { dmgMul = 1.20, fireRateMul = 1.15 },
        desc = "伤害+20%, 射速+15%",
        story = [[
战团起源于第一次星际战争的老兵。
他们拒绝放下武器，因为宇宙从来没有真正的和平。
每一个边界都是他们用炮火铭刻的宣言，
每一次战斗都是他们对生存的证明。]],
        intro = "战争兵团:纯粹的战争艺术",
        bossTitle = "铁血指挥",
    },
    {
        id = "scholars",
        name = "学者会",
        motto = "理解即胜利",
        color = { 0, 240, 255 },
        bonuses = { shieldRegenAdd = 3, hijackBlueprint = 0.25 },
        desc = "护盾回复+3/秒, 劫持蓝图+25%",
        story = [[
学者会守护着宇宙中最古老的知识。
他们相信，理解敌人的系统比任何武器都更强大。
他们的护盾不是简单的能量屏障，而是基于对攻击的理解，
用最少的能量化解最大的威胁。]],
        intro = "学者议会:知识的守护者",
        bossTitle = "知识终端",
    },
}

-- ============================================================================
-- P12.2: Boss对话
-- ============================================================================
Data.BOSS_DIALOGUE = {
    crystal = {
        spawn = { "入侵者...检测到...", "开始净化程序..." },
        phase = { "护盾系统激活...", "核心能量重组..." },
        kill = { "净化程序...失败..." },
    },
    hive = {
        spawn = { "你惊动了蜂群...", "没有逃跑的机会了..." },
        phase = { "警告:蜂后觉醒..." },
        kill = { "蜂群...溃散..." },
    },
    titan = {
        spawn = { "泰坦级单位已启动", "准备进行毁灭打击..." },
        phase = { "泰坦装甲受损，进入狂怒模式" },
        kill = { "泰坦...已停机..." },
    },
    void = {
        spawn = { "你不该来到这里...", "虚空...会吞噬一切..." },
        phase = { "你以为你能赢吗？" },
        kill = { "这...只是开始..." },
    },
    arbiter = {
        spawn = { "仲裁协议:开启", "你的行为将受到审判..." },
        phase = { "召唤仲裁骑士团" },
        kill = { "协议...终止..." },
    },
    leviathan = {
        spawn = { "深渊苏醒", "你将成为我的养分..." },
        phase = { "吞噬小行星恢复中..." },
        kill = { "深渊...不会终结..." },
    },
}

-- ============================================================================
-- P12.3: 星海编年史 (Lore收集系统)
-- ============================================================================
Data.CHRONICLES = {
    {
        id = "c1",
        title = "起源:第一次星际远航",
        content = [[
公元2187年，人类首次突破光速屏障。
那艘名为"先驱者"的飞船，用了整整三代人的时间，
才抵达最近的恒星系统。
当他们终于接触到外星文明时，
他们发现，宇宙比想象中更加复杂，也更加危险。]],
        unlockDay = 1,
    },
    {
        id = "c2",
        title = "三大阵营的诞生",
        content = [[
星际战争结束后，幸存的人类分道扬镳。
商人们用贸易重建秩序，战士们用炮火守护边界，
学者们用知识寻找答案。
三大阵营的选择，决定了之后千年的文明走向。]],
        unlockDay = 3,
    },
    {
        id = "c3",
        title = "虚空裂隙的发现",
        content = [[
在星域的最边缘，空间本身似乎出了问题。
那些从裂隙中涌出的实体，不遵循任何已知的物理定律。
学者会将其称为"零维投影"，
而战团只是简单地称之为：威胁。]],
        unlockDay = 7,
    },
    {
        id = "c4",
        title = "中继站协议",
        content = [[
中继站是文明的灯塔。
它们在星海中建立了一张通讯网络，
让相隔数千光年的人们能够彼此联系。
保护中继站，就是保护文明本身。]],
        unlockDay = 5,
    },
    {
        id = "c5",
        title = "远古钥匙的秘密",
        content = [[
在某些古老的废墟中，
存在着一种被称为"远古钥匙"的装置。
它们似乎能打开通往其他维度的大门，
但这些大门背后究竟是什么，
至今没有人活着回来告诉我们答案。]],
        unlockDay = 10,
    },
    {
        id = "c6",
        title = "关于遗物",
        content = [[
遗物不是简单的装备。
它们是文明的结晶，是那些逝去的英雄们
用生命和智慧留下的礼物。
每一件遗物都承载着一段故事，
等待新的主人去发现、去延续。]],
        unlockAchievement = "a_relic_3",
    },
    {
        id = "c7",
        title = "隐藏Boss的真相",
        content = [[
据说在星域的最深处，存在着一个不属于这个维度的存在。
它没有名字，没有形态，只有无尽的虚无。
只有当你足够强大，
当你击败了所有的Boss之后，
它才会出现在你面前。
学者会称之为"虚空裂隙"，
而战团只是简单地称之为：最终审判。]],
        unlockBoss = "void",
    },
    {
        id = "c8",
        title = "每日挑战的起源",
        content = [[
每日挑战系统源于古代的"试炼协议"。
它会根据你最近的行为，
动态调整难度和规则，
让你永远无法预测下一次会面对什么。
这是宇宙对你的考验，
也是你证明自己的机会。]],
        unlockDay = 2,
    },
}

-- ============================================================================
-- P14.2: 社区挑战系统 (Weekly Community Challenges)
-- ============================================================================
Data.COMMUNITY_CHALLENGES = {
    {
        id = "cha_survivor",
        name = "生还者",
        desc = "存活15天",
        target = 15,
        type = "day",
        reward = { blueprint = 5, score = 2000 },
    },
    {
        id = "cha_hunter",
        name = "猎手",
        desc = "击杀100个敌人",
        target = 100,
        type = "kill",
        reward = { blueprint = 3, score = 1500 },
    },
    {
        id = "cha_boss",
        name = "弑神者",
        desc = "击败3个Boss",
        target = 3,
        type = "boss",
        reward = { ancient_key = 1, score = 3000 },
    },
    {
        id = "cha_combo",
        name = "连击大师",
        desc = "达成50连击",
        target = 50,
        type = "combo",
        reward = { blueprint = 4, score = 1800 },
    },
    {
        id = "cha_damage",
        name = "破坏之王",
        desc = "造成5000点伤害",
        target = 5000,
        type = "damage",
        reward = { blueprint = 6, score = 2500 },
    },
    {
        id = "cha_collector",
        name = "收集者",
        desc = "采集500单位资源",
        target = 500,
        type = "resource",
        reward = { blueprint = 4, energy = 200 },
    },
}

function Data.getWeeklyChallenge()
    local day = tonumber(os.date("%d")) or 1
    local idx = ((day - 1) % #Data.COMMUNITY_CHALLENGES) + 1
    return Data.COMMUNITY_CHALLENGES[idx]
end

function Data.getFaction(id)
    for _, f in ipairs(Data.FACTIONS) do
        if f.id == id then return f end
    end
    return nil
end

-- ============================================================================
-- P16.1: Mod支持 - 配置扩展系统
-- ============================================================================
function Data.registerEnemyType(key, def)
    if type(key) ~= "string" or type(def) ~= "table" then return false end
    Data.ENEMY_TYPES[key] = def
    return true
end

function Data.registerBoss(key, def)
    if type(key) ~= "string" or type(def) ~= "table" then return false end
    Data.BOSS_DEFS[key] = def
    return true
end

function Data.registerRelic(def)
    if type(def) ~= "table" or not def.id then return false end
    table.insert(Data.RELICS, def)
    return true
end

function Data.registerWeeklyChallenge(def)
    if type(def) ~= "table" or not def.id then return false end
    table.insert(Data.COMMUNITY_CHALLENGES, def)
    return true
end

function Data.loadMod(config)
    if type(config) ~= "table" then return end
    if config.enemies then
        for k, v in pairs(config.enemies) do Data.registerEnemyType(k, v) end
    end
    if config.bosses then
        for k, v in pairs(config.bosses) do Data.registerBoss(k, v) end
    end
    if config.relics then
        for _, v in ipairs(config.relics) do Data.registerRelic(v) end
    end
    if config.challenges then
        for _, v in ipairs(config.challenges) do Data.registerWeeklyChallenge(v) end
    end
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
    fighter = {
        name = "战斗舰",
        hp = 120, speed = 100, size = 16,
        fire = 1.0, dmg = 12, range = 320,
        color = { 255, 180, 80 },
        score = 150, metal = 3, energy = 3, blueprint = 1,
        behavior = "fighter",
    },
    cruiser = {
        name = "重型巡洋舰",
        hp = 280, speed = 55, size = 24,
        fire = 1.6, dmg = 20, range = 380,
        color = { 220, 220, 180 },
        score = 300, metal = 7, energy = 5, blueprint = 2,
        behavior = "cruiser",
    },
    phasePhaser = {
        name = "相位潜行者",
        hp = 90, speed = 110, size = 14,
        fire = 2.2, dmg = 16, range = 300,
        color = { 180, 120, 255 },
        score = 240, metal = 3, energy = 4, blueprint = 2,
        behavior = "phase",
    },
    energyLeech = {
        name = "能量吸取者",
        hp = 150, speed = 90, size = 18,
        fire = 1.4, dmg = 14, range = 280,
        color = { 100, 255, 150 },
        score = 260, metal = 2, energy = 6, blueprint = 2,
        behavior = "leech",
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
    -- P13.4 新增事件
    {
        id = "rescue",
        title = "星际救援",
        desc = "一艘遇险飞船发出求救信号...",
        color = { 0, 200, 100 },
        options = {
            { label = "救援行动", desc = "消耗30能量 → 获得稀有遗物", effect = "rescue_ship" },
            { label = "无视求救", desc = "获得10金属(飞船自爆残骸)", effect = "ignore_rescue" },
        },
    },
    {
        id = "meteor_shower",
        title = "陨石雨",
        desc = "大量小行星从深空坠落！",
        color = { 255, 120, 50 },
        options = {
            { label = "躲避", desc = "进入安全区域，等待陨石雨结束", effect = "meteor_safe" },
            { label = "穿越", desc = "穿过陨石雨，获得大量资源", effect = "meteor_risk" },
        },
    },
    {
        id = "portal",
        title = "空间传送门",
        desc = "一个稳定的传送门出现在附近...",
        color = { 100, 200, 255 },
        options = {
            { label = "传送", desc = "立即传送到中继站附近", effect = "portal_jump" },
            { label = "充能", desc = "消耗20能量 → 护盾+50%持续20秒", effect = "portal_charge" },
        },
    },
    {
        id = "virus",
        title = "病毒入侵",
        desc = "飞船系统检测到恶意代码入侵！",
        color = { 150, 50, 100 },
        options = {
            { label = "隔离", desc = "禁用一项随机科技10秒，清除病毒", effect = "virus_quarantine" },
            { label = "硬重置", desc = "消耗15能量 → 立即清除病毒", effect = "virus_reset" },
        },
    },
}

--- P6.2 难度曲线参数
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

-- ============================================================================
-- P18.1: 战役模式章节定义
-- ============================================================================
Data.CAMPAIGN = {
    {
        id = "ch1",
        title = "第一章 · 边境星域",
        titleEn = "Chapter 1 · Frontier",
        description = "星海联邦的边缘防线正遭受侵蚀。作为新晋指挥官，你必须在资源匮乏的边境站稳脚跟，击退第一波入侵。",
        days = 10,
        recommendedDays = 15,
        themeColor = { 80, 160, 255 },
        bossId = "void_leviathan",
        unlockRequires = nil,
        objectives = {
            { id = "survive10", type = "survive", target = 10, desc = "生存10天" },
            { id = "kill50", type = "kill", target = 50, desc = "击毁50艘敌舰" },
            { id = "collectMetal", type = "resource", target = 300, desc = "累计收集300金属" },
        },
        zoneId = "frontier",
    },
    {
        id = "ch2",
        title = "第二章 · 科技禁区",
        titleEn = "Chapter 2 · Forbidden Zone",
        description = "曾是联邦最机密的研究设施，如今已被未知能量污染。残存的自动防御系统将任何靠近者视为敌人。",
        days = 15,
        recommendedDays = 25,
        themeColor = { 200, 100, 255 },
        bossId = "corrupted_core",
        unlockRequires = { chapter = "ch1" },
        objectives = {
            { id = "survive25", type = "survive", target = 25, desc = "生存25天" },
            { id = "killBosses", type = "bossKill", target = 3, desc = "击败3名Boss" },
            { id = "techCount", type = "tech", target = 10, desc = "解锁10项科技" },
        },
        zoneId = "forbidden",
    },
    {
        id = "ch3",
        title = "第三章 · 虚空深处",
        titleEn = "Chapter 3 · The Void",
        description = "敌舰的源头——一片吞噬光与物质的扭曲空间。最终决战将在这里打响，你要面对的是来自虚空本身的意志。",
        days = 20,
        recommendedDays = 45,
        themeColor = { 255, 80, 80 },
        bossId = "void_overlord",
        unlockRequires = { chapter = "ch2" },
        objectives = {
            { id = "survive45", type = "survive", target = 45, desc = "生存45天" },
            { id = "maxCombo", type = "comboMax", target = 20, desc = "达成20连击" },
            { id = "relicCount", type = "relic", target = 8, desc = "收集8件遗物" },
        },
        zoneId = "void",
    },
}

function Data.getCampaignChapter(id)
    for _, ch in ipairs(Data.CAMPAIGN) do
        if ch.id == id then return ch end
    end
    return nil
end

-- ============================================================================
-- P19.1: 难度等级系统
-- ============================================================================
Data.DIFFICULTY_LEVELS = {
    {
        id = "rookie",
        name = "新手",
        nameEn = "ROOKIE",
        color = { 100, 255, 100 },
        desc = "舒缓的星海之旅，专注于探索与故事。",
        descEn = "A relaxed journey. Focus on exploration and story.",
        multipliers = {
            enemyHp = 0.7, enemyDmg = 0.6, enemySpeed = 0.85,
            spawnRate = 0.75, resourceGain = 1.3, blueprintGain = 1.2,
            playerDmg = 1.15, playerHp = 1.2,
        },
        unlockFlag = nil,
        metaXpGain = 1.0,
    },
    {
        id = "standard",
        name = "标准",
        nameEn = "STANDARD",
        color = { 100, 180, 255 },
        desc = "默认体验：平衡的挑战与回报。",
        descEn = "Default experience. Balanced challenge and reward.",
        multipliers = {
            enemyHp = 1.0, enemyDmg = 1.0, enemySpeed = 1.0,
            spawnRate = 1.0, resourceGain = 1.0, blueprintGain = 1.0,
            playerDmg = 1.0, playerHp = 1.0,
        },
        unlockFlag = nil,
        metaXpGain = 1.0,
    },
    {
        id = "hard",
        name = "困难",
        nameEn = "HARD",
        color = { 255, 160, 60 },
        desc = "敌舰更强更密集，资源更珍贵。献给追求挑战的指挥官。",
        descEn = "Stronger enemies, scarcer resources. For commanders seeking challenge.",
        multipliers = {
            enemyHp = 1.35, enemyDmg = 1.25, enemySpeed = 1.1,
            spawnRate = 1.2, resourceGain = 0.85, blueprintGain = 0.8,
            playerDmg = 1.0, playerHp = 0.9,
        },
        unlockFlag = { completedCh1 = true },
        metaXpGain = 1.5,
    },
    {
        id = "void",
        name = "虚空",
        nameEn = "VOID",
        color = { 220, 60, 220 },
        desc = "只有精英中的精英才能生还。一击失误，即是毁灭。",
        descEn = "Only the elite survive. One mistake, one death.",
        multipliers = {
            enemyHp = 1.8, enemyDmg = 1.6, enemySpeed = 1.2,
            spawnRate = 1.4, resourceGain = 0.7, blueprintGain = 0.6,
            playerDmg = 1.1, playerHp = 0.75,
        },
        unlockFlag = { completedCh2 = true, hardClear = true },
        metaXpGain = 2.5,
    },
}

function Data.getDifficultyLevel(id)
    for _, d in ipairs(Data.DIFFICULTY_LEVELS) do
        if d.id == id then return d end
    end
    return Data.DIFFICULTY_LEVELS[2]
end

-- ============================================================================
-- P19.2: 永久升级（元进度系统）
-- ============================================================================
Data.META_UPGRADES = {
    {
        id = "meta_hull",
        name = "舰体强化",
        icon = "🛡",
        maxLevel = 5,
        baseCost = 50,
        costGrowth = 1.5,
        desc = "每级最大生命 +10%",
        apply = function(state, lvl)
            state.stats.maxHpBonus = (state.stats.maxHpBonus or 1) * (1 + 0.10 * lvl)
        end,
    },
    {
        id = "meta_weapon",
        name = "武器校准",
        icon = "⚔",
        maxLevel = 5,
        baseCost = 50,
        costGrowth = 1.5,
        desc = "每级主武器伤害 +5%",
        apply = function(state, lvl)
            state.stats.dmgBonus = (state.stats.dmgBonus or 1) * (1 + 0.05 * lvl)
        end,
    },
    {
        id = "meta_reactor",
        name = "反应堆优化",
        icon = "⚡",
        maxLevel = 5,
        baseCost = 50,
        costGrowth = 1.5,
        desc = "每级能量回复 +8%",
        apply = function(state, lvl)
            state.stats.energyRegenBonus = (state.stats.energyRegenBonus or 1) * (1 + 0.08 * lvl)
        end,
    },
    {
        id = "meta_scanner",
        name = "扫描阵列",
        icon = "📡",
        maxLevel = 3,
        baseCost = 80,
        costGrowth = 1.8,
        desc = "每级资源掉落 +10%",
        apply = function(state, lvl)
            state.stats.resourceBonus = (state.stats.resourceBonus or 1) * (1 + 0.10 * lvl)
        end,
    },
    {
        id = "meta_shield",
        name = "护盾矩阵",
        icon = "🔷",
        maxLevel = 3,
        baseCost = 100,
        costGrowth = 1.8,
        desc = "每级开局护盾充能 +1 层",
        apply = function(state, lvl)
            state.stats.startingShields = (state.stats.startingShields or 0) + lvl
        end,
    },
    {
        id = "meta_cargo",
        name = "货舱扩展",
        icon = "📦",
        maxLevel = 3,
        baseCost = 70,
        costGrowth = 1.6,
        desc = "每级额外遗物槽 +1",
        apply = function(state, lvl)
            state.stats.extraRelicSlots = (state.stats.extraRelicSlots or 0) + lvl
        end,
    },
}

function Data.getMetaUpgrade(id)
    for _, m in ipairs(Data.META_UPGRADES) do
        if m.id == id then return m end
    end
    return nil
end

function Data.metaUpgradeCost(u, currentLvl)
    return math.floor(u.baseCost * (u.costGrowth ^ currentLvl))
end

-- ============================================================================
-- P20.1: 主动技能系统
-- ============================================================================
Data.ACTIVE_SKILLS = {
    {
        id = "skill_dash",
        name = "量子冲刺",
        key = "Q",
        energyCost = 30,
        cooldown = 2.0,
        desc = "向当前移动方向瞬移200距离，获得0.8秒无敌。",
        color = { 120, 220, 255 },
        icon = "➤",
    },
    {
        id = "skill_shock",
        name = "冲击波",
        key = "W",
        energyCost = 50,
        cooldown = 4.0,
        desc = "释放环形能量波，对范围内敌人造成60伤害并击退。",
        color = { 255, 200, 100 },
        icon = "◎",
        range = 220,
        damage = 60,
    },
    {
        id = "skill_slow",
        name = "时间减速",
        key = "E",
        energyCost = 70,
        cooldown = 8.0,
        desc = "扭曲局部时间，所有敌人减速50%，持续4秒。",
        color = { 200, 150, 255 },
        icon = "⏳",
        duration = 4.0,
        slowFactor = 0.5,
    },
    {
        id = "skill_shield",
        name = "护盾充能",
        key = "R",
        energyCost = 40,
        cooldown = 6.0,
        desc = "立即回复25最大生命，获得1层临时护盾持续3秒。",
        color = { 120, 255, 160 },
        icon = "🛡",
        healAmount = 25,
        shieldDuration = 3.0,
    },
    {
        id = "skill_strike",
        name = "轨道打击",
        key = "T",
        energyCost = 80,
        cooldown = 12.0,
        desc = "呼叫轨道炮，在鼠标位置落下毁灭性一击，造成200范围伤害。",
        color = { 255, 100, 100 },
        icon = "☄",
        range = 180,
        damage = 200,
    },
}

function Data.getActiveSkill(id)
    for _, s in ipairs(Data.ACTIVE_SKILLS) do
        if s.id == id then return s end
    end
    return nil
end

-- ============================================================================
-- P20.2: 连击等级视觉与奖励
-- ============================================================================
Data.COMBO_RANKS = {
    { rank = "C",   threshold = 0,  color = { 180, 180, 180 }, dmgMul = 1.00, spawnMul = 1.0 },
    { rank = "B",   threshold = 5,  color = { 100, 220, 120 }, dmgMul = 1.08, spawnMul = 1.0 },
    { rank = "A",   threshold = 10, color = { 100, 180, 255 }, dmgMul = 1.15, spawnMul = 1.1 },
    { rank = "S",   threshold = 15, color = { 255, 200, 80 },  dmgMul = 1.25, spawnMul = 1.2 },
    { rank = "SS",  threshold = 25, color = { 255, 120, 80 },  dmgMul = 1.40, spawnMul = 1.35 },
    { rank = "SSS", threshold = 40, color = { 255, 80, 200 },  dmgMul = 1.60, spawnMul = 1.5 },
}

function Data.getComboRank(comboCount)
    local rank = Data.COMBO_RANKS[1]
    for _, r in ipairs(Data.COMBO_RANKS) do
        if comboCount >= r.threshold then rank = r end
    end
    return rank
end

-- ============================================================================
-- P21.1: 世界区域定义
-- ============================================================================
Data.ZONES = {
    frontier = {
        id = "frontier",
        name = "边境星域",
        nameEn = "Frontier Sector",
        color = { 80, 160, 255 },
        bgTint = { 20, 25, 45 },
        starDensity = 1.0,
        asteroidRate = 1.0,
        enemyComposition = { drone = 0.6, fighter = 0.3, cruiser = 0.1 },
        maxEnemies = 12,
        description = "远离核心的防御前线，适合新手指挥官建立自信。",
    },
    forbidden = {
        id = "forbidden",
        name = "科技禁区",
        nameEn = "Forbidden Zone",
        color = { 200, 100, 255 },
        bgTint = { 35, 15, 55 },
        starDensity = 1.3,
        asteroidRate = 0.8,
        enemyComposition = { drone = 0.3, fighter = 0.4, cruiser = 0.2, phasePhaser = 0.1 },
        maxEnemies = 16,
        description = "被未知能量污染的旧联邦实验区，敌人更强大且种类更多。",
    },
    void = {
        id = "void",
        name = "虚空深处",
        nameEn = "The Void",
        color = { 255, 80, 80 },
        bgTint = { 40, 10, 30 },
        starDensity = 1.6,
        asteroidRate = 0.5,
        enemyComposition = { fighter = 0.3, cruiser = 0.3, phasePhaser = 0.2, energyLeech = 0.2 },
        maxEnemies = 20,
        description = "敌舰的源头——吞噬一切的扭曲空间，生存即是胜利。",
    },
    core = {
        id = "core",
        name = "核心战区",
        nameEn = "Core Warzone",
        color = { 255, 200, 80 },
        bgTint = { 50, 30, 15 },
        starDensity = 2.0,
        asteroidRate = 0.3,
        enemyComposition = { cruiser = 0.4, phasePhaser = 0.3, energyLeech = 0.3 },
        maxEnemies = 25,
        description = "星海联邦的心脏地带。只有最精锐的部队才被部署于此。",
    },
}

function Data.getZone(id)
    return Data.ZONES[id] or Data.ZONES.frontier
end

-- ============================================================================
-- P21.2: 波次系统升级 - 定时波次
-- ============================================================================
Data.WAVE_PATTERNS = {
    {
        id = "wave_swarm",
        name = "蜂群袭击",
        nameEn = "Swarm Attack",
        duration = 30,
        description = "无人机如蝗虫般出现，考验你清理弱小目标的能力。",
        enemyType = "drone",
        enemyCount = 20,
        spawnInterval = 0.8,
        reward = { metal = 80, energy = 60 },
    },
    {
        id = "wave_elite",
        name = "精英部队",
        nameEn = "Elite Force",
        duration = 45,
        description = "一小队精锐战斗机出现在战场上，装备更强护盾。",
        enemyType = "fighter",
        enemyCount = 8,
        spawnInterval = 2.5,
        reward = { metal = 100, energy = 80, blueprint = 1 },
    },
    {
        id = "wave_besiege",
        name = "围困战",
        nameEn = "Siege",
        duration = 60,
        description = "混合编队包围你——小心从各个方向逼近的威胁。",
        enemyType = "mixed",
        enemyCount = 15,
        spawnInterval = 2.0,
        reward = { metal = 150, energy = 120 },
    },
    {
        id = "wave_boss",
        name = "Boss 降临",
        nameEn = "Boss Descends",
        duration = 0,
        description = "一名强大的敌人出现了——击败它获得丰厚奖励。",
        isBoss = true,
        reward = { metal = 300, energy = 250, blueprint = 3 },
    },
    {
        id = "wave_calm",
        name = "寂静时刻",
        nameEn = "Calm Moment",
        duration = 20,
        description = "战斗暂时平息——是喘息，是补给，也可能是陷阱。",
        enemyCount = 0,
        spawnInterval = 0,
        reward = { metal = 30, energy = 30 },
        mysteryChance = 0.6,
    },
}

function Data.getRandomWavePattern(rng)
    local r = (rng or math.random)()
    if r < 0.35 then return Data.WAVE_PATTERNS[1]
    elseif r < 0.65 then return Data.WAVE_PATTERNS[2]
    elseif r < 0.85 then return Data.WAVE_PATTERNS[3]
    else return Data.WAVE_PATTERNS[5]
    end
end

-- ============================================================================
-- P21.3: 神秘地点
-- ============================================================================
Data.MYSTERY_LOCATIONS = {
    {
        id = "myst_wreck",
        name = "失事舰骸",
        icon = "🚀",
        description = "一艘受损的联邦飞船仍在发送求救信号。靠近它可能有意外收获——或者危险。",
        onVisit = function(state)
            local r = math.random()
            if r < 0.6 then
                local metal = math.random(50, 120)
                local energy = math.random(30, 80)
                Core.dropResources(state, state.player.x, state.player.y, metal, energy, math.random(0, 2))
                Core.addToast(state, "你从残骸中回收了物资！", { 150, 255, 150 })
            elseif r < 0.9 then
                local blueprint = math.random(1, 3)
                Core.dropResources(state, state.player.x, state.player.y, 0, 0, blueprint)
                Core.addToast(state, "蓝图！废弃飞船的设计图。", { 150, 200, 255 })
            else
                Core.damagePlayer(state, math.random(15, 35), state.player.x, state.player.y)
                Core.addToast(state, "残骸中潜伏的伏击者！", { 255, 120, 120 })
                for i = 1, 5 do Core.spawnEnemy(state, "drone") end
            end
        end,
    },
    {
        id = "myst_signal",
        name = "神秘信号",
        icon = "📡",
        description = "未知频率的信号不断重复着相同的代码。解码它也许能发现什么。",
        onVisit = function(state)
            state.player.blueprints = (state.player.blueprints or 0) + 2
            Core.addToast(state, "你解码了信号，获得2蓝图！", { 150, 200, 255 })
            if not state.flags.decodedSignal then
                state.flags.decodedSignal = true
                Core.unlockTech(state, "w10")
                Core.addToast(state, "隐藏科技解锁：量子隐身！", { 200, 150, 255 })
            end
        end,
    },
    {
        id = "myst_anomaly",
        name = "时空异常",
        icon = "🌀",
        description = "空间在此处出现了可见的扭曲。进入可能会——改变某些东西。",
        onVisit = function(state)
            local r = math.random()
            if r < 0.5 then
                state.player.hp = math.min(state.player.maxHp, state.player.hp + 40)
                Core.addToast(state, "异常能量修复了你的舰体！", { 150, 255, 200 })
            elseif r < 0.8 then
                state.stats.tempDmgMul = (state.stats.tempDmgMul or 1) + 0.2
                Core.addToast(state, "舰体共振，伤害临时 +20%！", { 255, 200, 100 })
            else
                state.player.energy = state.player.maxEnergy
                Core.addToast(state, "能量场充满了反应堆！", { 120, 200, 255 })
            end
        end,
    },
    {
        id = "myst_trader",
        name = "流浪商人",
        icon = "🛒",
        description = "一位自称商人的飞船示意你靠近。他的报价——公道，或者荒诞。",
        onVisit = function(state)
            if (state.player.metal or 0) >= 100 then
                state.player.metal = state.player.metal - 100
                state.player.blueprints = (state.player.blueprints or 0) + 3
                Core.addToast(state, "交易达成：100金属 换 3蓝图", { 220, 220, 140 })
            else
                Core.addToast(state, "金属不足（需100），商人离开了。", { 180, 180, 180 })
            end
        end,
    },
    {
        id = "myst_relic",
        name = "遗物碎片",
        icon = "💎",
        description = "一块散发奇异光辉的碎片。它的能量特征与你曾获得的遗物相似。",
        onVisit = function(state)
            if not state.flags.relicShard then
                state.flags.relicShard = true
                local relic = Data.RELICS[math.random(#Data.RELICS)]
                if relic then
                    table.insert(state.player.relics, relic)
                    Core.addToast(state, "获得遗物：" .. relic.name, { 255, 200, 255 })
                end
            else
                Core.dropResources(state, state.player.x, state.player.y, 0, 100, 1)
                Core.addToast(state, "又一块碎片转化为能量与蓝图。", { 200, 200, 150 })
            end
        end,
    },
}

-- ============================================================================
-- P12.4: NPC 对话与编年史
-- ============================================================================
Data.NPC_DIALOGUE = {
    commander = {
        name = "指挥官 · 艾琳·霍尔特",
        avatar = "👤",
        lines = {
            "指挥官，我们的前线正在收缩。你能守住阵地吗？",
            "我已经派遣了补给舰，但敌人的拦截越来越频繁。",
            "记住：你收集的每一份蓝图都是未来胜利的种子。",
            "敌人的Boss正在觉醒——你必须在它完成准备前做好准备。",
        },
    },
    engineer = {
        name = "工程师 · 卡尔",
        avatar = "🔧",
        lines = {
            "反应堆状态良好，但你要是再乱用护盾就不一定了。",
            "新武器系统已经校准完成——试试它的威力吧！",
            "我在残骸中发现了有趣的东西——如果你带回来更多，我们能造更强的装备。",
        },
    },
    scout = {
        name = "侦察兵 · 夜枭",
        avatar = "🦉",
        lines = {
            "我看到了——敌人的动向正在变化，有什么大事要发生。",
            "前方区域出现了异常能量读数。你应该去看看。",
            "那片扭曲空间不自然。它——它在吞噬什么东西。",
        },
    },
}

function Data.getNPCLine(npcId, index)
    local npc = Data.NPC_DIALOGUE[npcId]
    if not npc then return nil end
    local i = ((index or 0) % #npc.lines) + 1
    return npc.lines[i], npc
end

-- ============================================================================
-- Phase 24: 成就 → 永久升级 解锁映射
-- ============================================================================
Data.ACHIEVEMENT_META_UNLOCKS = {
    ach_first_blood = "meta_hull",         -- 首次击杀 → 舰体强化解锁
    ach_combo_10 = "meta_weapon",           -- 10 连击 → 武器校准解锁
    ach_combo_25 = "meta_weapon",           -- 25 连击 → 武器校准额外等级
    ach_boss_kill = "meta_shield",          -- 击败 Boss → 护盾矩阵解锁
    ach_30_days = "meta_reactor",           -- 生存 30 天 → 反应堆优化
    ach_100_kills = "meta_scanner",         -- 100 击杀 → 扫描阵列
    ach_no_damage_day = "meta_hull",        -- 无伤一天 → 额外舰体强化
    ach_tech_master = "meta_cargo",         -- 科技全开 → 货舱扩展
    ach_difficulty_void = "meta_shield",    -- 通关虚空难度 → 额外护盾
}

-- 成就完成时给予的固定等级加成
Data.ACHIEVEMENT_META_LEVELS = {
    ach_first_blood = 1,
    ach_combo_10 = 1,
    ach_combo_25 = 1,
    ach_boss_kill = 1,
    ach_30_days = 1,
    ach_100_kills = 2,
    ach_no_damage_day = 1,
    ach_tech_master = 2,
    ach_difficulty_void = 2,
}

function Data.getMetaUnlockForAchievement(achId)
    return Data.ACHIEVEMENT_META_UNLOCKS[achId], Data.ACHIEVEMENT_META_LEVELS[achId]
end

-- ============================================================================
-- Phase 24: 每日挑战主题池
-- ============================================================================
Data.DAILY_THEMES = {
    {
        id = "theme_elite",
        name = "精英部队",
        desc = "所有敌人 HP +30%，击杀奖励 +50%",
        mod = { enemyHpMul = 1.3, rewardMul = 1.5 },
        color = { 255, 180, 80 },
    },
    {
        id = "theme_ghost",
        name = "幽灵舰队",
        desc = "敌人移动速度 +40%，但生命 -20%",
        mod = { enemyHpMul = 0.8, enemySpeedMul = 1.4 },
        color = { 200, 180, 255 },
    },
    {
        id = "theme_rain",
        name = "弹幕之雨",
        desc = "敌人生成率 +60%，资源掉落 +30%",
        mod = { spawnRateMul = 1.6, resourceMul = 1.3 },
        color = { 255, 100, 150 },
    },
    {
        id = "theme_power",
        name = "能量溢涌",
        desc = "能量回复 +100%，但玩家生命 -20%",
        mod = { energyRegenMul = 2.0, playerHpMul = 0.8 },
        color = { 100, 220, 255 },
    },
    {
        id = "theme_apocalypse",
        name = "末日启示",
        desc = "敌人更强更多（全属性+50%），但蓝图掉落翻倍",
        mod = { enemyHpMul = 1.5, enemyDmgMul = 1.5, spawnRateMul = 1.3, blueprintMul = 2.0 },
        color = { 255, 80, 80 },
    },
    {
        id = "theme_peace",
        name = "宁静之日",
        desc = "敌人生成率 -40%，但资源也 -20%",
        mod = { spawnRateMul = 0.6, resourceMul = 0.8 },
        color = { 150, 255, 150 },
    },
    {
        id = "theme_combo",
        name = "连击狂热",
        desc = "连击衰减时间 +100%，连击伤害倍率额外 +20%",
        mod = { comboDecayMul = 2.0, comboDmgBonusMul = 1.2 },
        color = { 255, 200, 100 },
    },
}

function Data.getDailyTheme(seed)
    -- 使用日期种子稳定映射（seed 是 YYMMDD 的数字形式）
    local s = seed or 1
    local idx = (s % #Data.DAILY_THEMES) + 1
    return Data.DAILY_THEMES[idx]
end

function Data.getWeeklyThemeList(baseSeed)
    local out = {}
    for i = 1, 7 do
        out[i] = Data.getDailyTheme((baseSeed or 0) + i - 1)
    end
    return out
end

-- ============================================================================
-- Phase 26: Mod 注册表与加载器
-- ============================================================================
Data.MOD_REGISTRY = {
    loaded = {},
    enabled = {},
    totalCount = 0,
}

Data.MOD_SCHEMA = {
    required = { "id", "name", "version", "author" },
    optional = { "description", "enemies", "bosses", "relics", "tech", "difficulty", "themes" },
    maxVersionLength = 16,
    maxIdLength = 32,
}

function Data.validateMod(mod)
    if type(mod) ~= "table" then return false, "Mod must be a table" end
    for _, field in ipairs(Data.MOD_SCHEMA.required) do
        if not mod[field] then
            return false, "Missing required field: " .. field
        end
    end
    if type(mod.id) ~= "string" or #mod.id > Data.MOD_SCHEMA.maxIdLength then
        return false, "Invalid id length"
    end
    if type(mod.version) ~= "string" or #mod.version > Data.MOD_SCHEMA.maxVersionLength then
        return false, "Invalid version"
    end
    return true
end

function Data.registerMod(mod)
    local ok, err = Data.validateMod(mod)
    if not ok then return false, err end
    if Data.MOD_REGISTRY.loaded[mod.id] then
        return false, "Mod already loaded: " .. mod.id
    end
    Data.MOD_REGISTRY.loaded[mod.id] = mod
    Data.MOD_REGISTRY.enabled[mod.id] = mod.enabled ~= false
    Data.MOD_REGISTRY.totalCount = Data.MOD_REGISTRY.totalCount + 1
    if mod.enemies then
        for key, def in pairs(mod.enemies) do
            Data.ENEMY_TYPES[key] = def
        end
    end
    if mod.bosses then
        for key, def in pairs(mod.bosses) do
            Data.BOSS_DEFS[key] = def
        end
    end
    if mod.relics then
        for _, def in ipairs(mod.relics) do
            table.insert(Data.RELICS, def)
        end
    end
    if mod.tech then
        for _, def in ipairs(mod.tech) do
            table.insert(Data.TECH_TREE, def)
        end
    end
    if mod.difficulty then
        for _, def in ipairs(mod.difficulty) do
            table.insert(Data.DIFFICULTY_LEVELS, def)
        end
    end
    if mod.themes then
        for _, def in ipairs(mod.themes) do
            table.insert(Data.DAILY_THEMES, def)
        end
    end
    return true
end

function Data.listMods()
    local list = {}
    for id, mod in pairs(Data.MOD_REGISTRY.loaded) do
        table.insert(list, {
            id = id,
            name = mod.name,
            version = mod.version,
            author = mod.author,
            description = mod.description or "",
            enabled = Data.MOD_REGISTRY.enabled[id],
        })
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Data.toggleMod(modId)
    if Data.MOD_REGISTRY.loaded[modId] then
        Data.MOD_REGISTRY.enabled[modId] = not (Data.MOD_REGISTRY.enabled[modId] or false)
        return Data.MOD_REGISTRY.enabled[modId]
    end
    return false
end

Data.MOD_TEMPLATE = [[
local mod = {
    id = "example_mod",
    name = "示例模组",
    version = "1.0.0",
    author = "Your Name",
    description = "一个完整的 Mod 示例，演示如何添加新敌人、Boss 和遗物。",
    enabled = true,
    enemies = {
        custom_enemy = {
            name = "自定义敌人",
            hp = 200, speed = 90, size = 14,
            fire = 1.5, dmg = 15, range = 320,
            color = { 150, 255, 200 },
            score = 200, metal = 4, energy = 4, blueprint = 1,
        },
    },
    relics = {
        {
            id = "r_custom",
            name = "自定义遗物",
            icon = "★",
            rarity = "rare",
            desc = "这是一个由 Mod 提供的自定义遗物。",
            apply = function(state)
                state.stats.dmgMul = state.stats.dmgMul * 1.15
            end,
        },
    },
}
return mod
]]}

-- ============================================================================
-- Phase 27: 版本信息与版权声明
-- ============================================================================
Data.GAME_VERSION = "2.0.0"
Data.GAME_BUILD = 20260619
Data.GAME_NAME = "星海征途"
Data.GAME_NAME_EN = "Star Sea Expedition"
Data.GAME_COPYRIGHT = "(c) 2025-2026 Star Sea Team"

function Data.getVersionString()
    return Data.GAME_NAME .. " v" .. Data.GAME_VERSION .. " (Build " .. Data.GAME_BUILD .. ")"
end

function Data.getVersionInfo()
    return {
        name = Data.GAME_NAME,
        nameEn = Data.GAME_NAME_EN,
        version = Data.GAME_VERSION,
        build = Data.GAME_BUILD,
        copyright = Data.GAME_COPYRIGHT,
        versionMajor = 2,
        versionMinor = 0,
        versionPatch = 0,
    }
end

function Data.checkVersionCompatibility(otherVersion)
    if not otherVersion then return true end
    local om, omi, op = 0, 0, 0
    for a, b, c in string.gmatch(otherVersion, "(%d+)%.(%d+)%.(%d+)") do
        om, omi, op = tonumber(a), tonumber(b), tonumber(c)
    end
    if om ~= 2 then return false end
    return true
end

return Data
