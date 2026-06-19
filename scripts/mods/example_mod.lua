-- ============================================================================
-- 星海征途 - Mod 示例文件
-- 将此文件放入 mods/ 目录后重启游戏即可加载
-- 你可以基于此模板创建自己的 Mod
-- ============================================================================

local example_mod = {
    id = "example_mod",
    name = "银河扩展包",
    version = "1.0.0",
    author = "Star Sea Team",
    description = "一个完整的 Mod 示例。\n添加了 2 种新敌人、1 名新 Boss、\n3 件新遗物和 2 个每日主题。",
    enabled = true,

    -- ============================================================
    -- 新增敌人类型
    -- ============================================================
    enemies = {
        nova_scout = {
            name = "新星斥候",
            hp = 150, speed = 140, size = 13,
            fire = 0.8, dmg = 12, range = 340,
            color = { 255, 180, 60 },
            score = 180, metal = 3, energy = 4, blueprint = 1,
        },
        void_ripper = {
            name = "虚空撕裂者",
            hp = 260, speed = 70, size = 20,
            fire = 2.5, dmg = 18, range = 380,
            color = { 180, 80, 255 },
            score = 350, metal = 6, energy = 5, blueprint = 3,
        },
    },

    -- ============================================================
    -- 新增遗物
    -- ============================================================
    relics = {
        {
            id = "r_galactic_core",
            name = "银河核心",
            icon = "◉",
            rarity = "legendary",
            desc = "最大生命 +25%，能量回复 +15%。",
            apply = function(state)
                if state.stats then
                    state.stats.hpBonus = (state.stats.hpBonus or 1) * 1.25
                    state.stats.energyRegenBonus = (state.stats.energyRegenBonus or 1) * 1.15
                end
            end,
        },
        {
            id = "r_quantum_shard",
            name = "量子碎片",
            icon = "◇",
            rarity = "rare",
            desc = "主动技能冷却时间缩短 20%。",
            apply = function(state)
                if state.skills then
                    state.skills.cooldownMultiplier = 0.8
                end
            end,
        },
        {
            id = "r_nova_blade",
            name = "新星之刃",
            icon = "✦",
            rarity = "epic",
            desc = "主武器伤害 +15%，连击等级起始为 B。",
            apply = function(state)
                if state.stats then
                    state.stats.dmgMul = (state.stats.dmgMul or 1) * 1.15
                end
                if state.comboRank then
                    state.comboRank.rank = "B"
                    state.comboRank.count = 5
                end
            end,
        },
    },

    -- ============================================================
    -- 新增每日主题
    -- ============================================================
    themes = {
        {
            id = "theme_aurora",
            name = "极光之境",
            desc = "所有敌人 HP -20%，速度 +25%。",
            mod = { enemyHpMul = 0.8, enemySpeedMul = 1.25 },
            color = { 120, 220, 255 },
        },
        {
            id = "theme_storm",
            name = "星核风暴",
            desc = "生成率 +40%，但蓝图掉落 +100%。",
            mod = { spawnRateMul = 1.4, blueprintMul = 2.0 },
            color = { 255, 100, 80 },
        },
    },
}

return example_mod
