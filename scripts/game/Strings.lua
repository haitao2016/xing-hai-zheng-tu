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

    -- === 浮动文本 ===
    float_self_destruct = "💥自爆!",
    float_reveal        = "现形!",
    float_summon        = "召唤!",
    float_rage          = "狂暴!",
    float_split         = "分裂!",
    float_shield_up     = "+20护盾",
    float_regen         = "回复中!",
    float_firepower     = "火力全开!",

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

    -- === 科技树分类 ===
    tech_cat_weapon     = "武器",
    tech_cat_shield     = "护盾",
    tech_cat_engine     = "引擎",
    tech_cat_core       = "核心",
    tech_cat_auth       = "权限",

    -- === 玩家 ===
    default_player_name = "征途者",
    default_faction     = "玩家",
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
