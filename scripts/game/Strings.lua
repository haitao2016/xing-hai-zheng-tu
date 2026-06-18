-- ============================================================================
-- 星海征途 - i18n 字符串常量表
-- Phase 10.4: 集中管理所有 UI 显示文本，为未来国际化留接口
-- 用法: local S = require("game.Strings")
--       S.get("hud_day", day)   →  "第 3 天"
-- ============================================================================

local Strings = {}

-- 当前语言（预留切换接口）
local currentLang = "zh"

-- ============================================================================
-- 字符串定义表（中文）
-- ============================================================================
local zh = {
    -- === HUD / Toast ===
    hud_day             = "第 %d 天",
    hud_wave            = "⚠ %s 来袭! %.0f",
    hud_boss_incoming   = "⚠ 深空Boss来袭!",
    hud_boss_defeated   = "Boss 击败: %s",
    hud_boss_rage       = "⚠ %s 进入狂暴!",
    hud_ship_crashed    = "飞船坠毁...",
    hud_season_end      = "赛季结束!",
    hud_time_normal     = "时间恢复正常",
    hud_unlock_tech     = "解锁: %s",
    hud_combo_milestone = "%d连击! %s",
    hud_hp              = "HP %d/%d",
    hud_shield          = "盾 %d/%d",
    hud_score           = "分数: %d",
    hud_metal           = "金属: %d",
    hud_energy          = "能量: %d",
    hud_blueprint       = "图纸: %d",
    hud_ancient_key     = "密钥: %d",
    hud_combo           = "%dx COMBO",
    hud_combo_multiplier= "x%.1f 分数倍率",
    hud_relics          = "遗物",
    hud_allies          = "友军[F]: %s (%d)",
    hud_ally_attack     = "攻击",
    hud_ally_follow     = "跟随",
    hud_ally_guard      = "护卫",
    hud_daily_challenge = "挑战: %s + %s",

    -- === 浮动文本 ===
    float_self_destruct = "💥自爆!",
    float_reveal        = "现形!",
    float_summon        = "召唤!",
    float_rage          = "狂暴!",
    float_split         = "分裂!",
    float_shield_up     = "+20护盾",
    float_regen         = "回复中!",
    float_firepower     = "火力全开!",
    float_heal          = "+修复",
    float_weapon_boost  = "武器强化!",
    float_wormhole_jump = "虫洞跃迁!",
    float_allies        = "友军增援!",
    float_storm         = "太阳风暴!",
    float_storm_damage  = "风暴打击!",
    float_storm_shield  = "反弹护盾!",
    float_time_slow     = "时间扭曲!",
    float_cd_reset      = "武器超载!",
    float_overheat      = "武器过热!",

    -- === 游戏结束 ===
    gameover_endless    = "无尽征途终结",
    gameover_season     = "赛季完成！",
    gameover_destroyed  = "飞船损毁",
    gameover_score      = "最终得分: %d",
    gameover_stats      = "综合评价",
    gameover_share      = "⭐ 星海征途 · 战绩卡片 ⭐",
    gameover_restart    = "再次出发",
    gameover_share_hint = "截图分享你的战绩 · 点击按钮返回",
    stat_days           = "存活天数",
    stat_kills          = "总击杀",
    stat_dmg_dealt      = "总伤害输出",
    stat_dmg_taken      = "总受到伤害",
    stat_metal          = "金属采集",
    stat_energy         = "能源采集",
    stat_blueprint      = "图纸采集",
    stat_key            = "密钥获取",
    stat_boss_kills     = "Boss击杀",
    stat_quests         = "任务完成",
    stat_tech           = "科技解锁",
    stat_best_combo     = "最高连击",
    stat_relics         = "获得遗物",

    -- === 新手教程 ===
    tutorial_title      = "教程 %d/8",
    tut1_text           = "使用 WASD 移动飞船",
    tut1_sub            = "尝试向各方向移动",
    tut2_text           = "按住鼠标左键射击",
    tut2_sub            = "消灭敌人获取资源",
    tut3_text           = "收集掉落的资源",
    tut3_sub            = "金属和能量是升级的基础",
    tut4_text           = "按 T 打开科技树",
    tut4_sub            = "花费资源升级武器和护盾",
    tut5_text           = "注意护盾能量",
    tut5_sub            = "护盾耗尽后会直接扣血",
    tut6_text           = "保持连击获得加成",
    tut6_sub            = "连续击杀可提升得分倍率",
    tut7_text           = "解锁高级武器",
    tut7_sub            = "Q 激光束 / E 导弹齐射",
    tut8_text           = "祝你好运，舰长！",
    tut8_sub            = "探索星图，征服星海",

    -- === 成就 ===
    achievement_unlock  = "成就解锁!",

    -- === 科技树 ===
    tech_tree_title     = "科 技 树",
    tech_cat_weapon     = "武器",
    tech_cat_shield     = "护盾",
    tech_cat_engine     = "引擎",
    tech_cat_core       = "核心",
    tech_cat_auth       = "权限",
    tech_purchase_hint  = "按 T 关闭科技树 | 点击可购买的科技解锁",
    tech_owned          = "✓ 已研发",

    -- === 菜单 ===
    menu_title          = "星 海 征 途",
    menu_title_en       = "S T A R   S E A   E X P E D I T I O N",
    menu_faction_title  = "— 选择你的阵营 —",
    menu_faction_hint   = "点击卡片选择阵营",
    menu_start          = "开 始 征 途",
    menu_daily          = "每日挑战",
    menu_daily_done     = "✓ 今日已挑战",
    menu_endless        = "∞ 无尽模式",
    menu_endless_desc   = "30天后继续挑战",
    menu_stats          = "生涯统计",
    menu_version        = "v0.6.0",

    -- === 排行榜 ===
    leaderboard_title   = "🏆 星海排行榜",
    leaderboard_my_rank = "我的排名: #%d  最高分: %d",
    leaderboard_no_data = "完成一局游戏即可上榜",
    leaderboard_loading = "加载中...",
    leaderboard_hint    = "按 ESC 或 L 返回",
    leaderboard_rank    = "排名",
    leaderboard_player  = "玩家",
    leaderboard_score   = "分数",
    leaderboard_plays   = "场次",

    -- === 统计 ===
    stats_title         = "生涯统计",
    stats_total_games   = "总局数",
    stats_total_kills   = "总击杀",
    stats_total_score   = "总得分",
    stats_total_days    = "总存活天数",
    stats_best_score    = "最高单局分数",
    stats_best_combo    = "最长连击",
    stats_best_day      = "最长存活天",
    stats_boss_kills    = "Boss击杀数",
    stats_metal_total   = "采集金属总量",
    stats_energy_total  = "采集能源总量",

    -- === 事件 ===
    event_special       = "⚡ 特殊事件!",
    event_choice_hint   = "点击选项做出选择",

    -- === 资源拾取 ===
    pickup_metal        = "+%d 金属",
    pickup_energy       = "+%d 能量",
    pickup_blueprint    = "+%d 图纸",
    pickup_key          = "+%d 密钥",

    -- === 商人舰队 ===
    merchant_buy_weapon = "购买武器",
    merchant_buy_desc   = "消耗20金属 → 火力+30%持续15秒",
    merchant_sell_energy = "出售资源",
    merchant_sell_desc  = "消耗15能量 → 获得8图纸",
    merchant_no_metal   = "金属不足！需要20",
    merchant_no_energy  = "能量不足！需要15",

    -- === 任务 ===
    quest_chapter       = "章节%d",
    quest_completed     = "✓ 完成",
    quest_day_range     = "D%d-%d",

    -- === 玩家 ===
    default_player_name = "征途者",
    default_faction     = "玩家",

    -- === 阵营 ===
    faction_merchants   = "星际商人联盟",
    faction_warband     = "虚空战团",
    faction_scholars    = "远古学者会",

    -- === 操作提示 ===
    hint_move           = "WASD移动 | 鼠标瞄准 | 左键射击",
    hint_weapons        = "T科技树 | R中继站 | H劫持 | Q导弹 | V激光 | F盟友",
    hint_game           = "WASD移动 | 左键射击 | Space副武器 | Tab切换 | T科技树 | Q导弹 | V激光",
}

-- ============================================================================
-- 语言表注册（未来可扩展 en / ja 等）
-- ============================================================================
local langTables = { zh = zh }

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 获取当前语言的字符串（支持 string.format 参数）
---@param key string
---@vararg any
---@return string
function Strings.get(key, ...)
    local tbl = langTables[currentLang] or zh
    local s = tbl[key]
    if not s then return key end  -- 未找到返回 key 本身
    if select("#", ...) > 0 then
        return string.format(s, ...)
    end
    return s
end

--- 切换语言
---@param lang string "zh"|"en"|...
function Strings.setLang(lang)
    if langTables[lang] then
        currentLang = lang
    end
end

--- 获取当前语言
---@return string
function Strings.getLang()
    return currentLang
end

--- 注册新语言表
---@param lang string
---@param tbl table<string,string>
function Strings.register(lang, tbl)
    langTables[lang] = tbl
end

--- 获取教程数据列表（供 RenderFX 使用）
---@param sw number 屏幕宽
---@param sh number 屏幕高
---@return table[]
function Strings.getTutorials(sw, sh)
    return {
        { text = zh.tut1_text, sub = zh.tut1_sub, hx = sw / 2, hy = sh * 0.6 },
        { text = zh.tut2_text, sub = zh.tut2_sub, hx = sw / 2, hy = sh * 0.4 },
        { text = zh.tut3_text, sub = zh.tut3_sub, hx = sw / 2, hy = sh * 0.5 },
        { text = zh.tut4_text, sub = zh.tut4_sub, hx = sw - 100, hy = 60 },
        { text = zh.tut5_text, sub = zh.tut5_sub, hx = 80, hy = 40 },
        { text = zh.tut6_text, sub = zh.tut6_sub, hx = sw / 2, hy = sh * 0.3 },
        { text = zh.tut7_text, sub = zh.tut7_sub, hx = sw / 2, hy = sh * 0.4 },
        { text = zh.tut8_text, sub = zh.tut8_sub, hx = sw / 2, hy = sh * 0.3 },
    }
end

return Strings
