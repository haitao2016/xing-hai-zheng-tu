-- ============================================================================
-- 星海征途 - 精灵贴图加载与绘制模块
-- 用 nvgCreateImage 加载所有游戏素材，提供绘制辅助函数
-- ============================================================================

local Sprites = {}

-- 图片句柄存储
Sprites.images = {}

-- 是否已初始化
Sprites.loaded = false

-- ============================================================================
-- 初始化：加载所有精灵图片（在 Start() 中调用一次）
-- ============================================================================
function Sprites.init(vg)
    if Sprites.loaded then return end

    local assets = {
        -- 飞船
        player_ship   = "image/player_ship.png",
        enemy_scout   = "image/enemy_scout.png",
        enemy_fighter = "image/enemy_fighter.png",
        enemy_cruiser = "image/enemy_cruiser.png",
        enemy_bomber  = "image/enemy_bomber.png",
        boss_ship     = "image/boss_ship.png",
        ally_ship     = "image/ally_ship.png",

        -- 道具
        powerup_shield  = "image/powerup_shield.png",
        powerup_rapid   = "image/powerup_rapid.png",
        powerup_spread  = "image/powerup_spread.png",
        powerup_missile = "image/powerup_missile.png",

        -- 拾取物
        pickup_scrap     = "image/pickup_scrap.png",
        pickup_energy    = "image/pickup_energy.png",
        pickup_blueprint = "image/pickup_blueprint.png",
        pickup_key       = "image/pickup_key.png",

        -- 环境
        space_bg      = "image/space_bg.png",
        asteroid_1    = "image/asteroid_1.png",
        asteroid_2    = "image/asteroid_2.png",
        relay_station = "image/relay_station.png",

        -- 武器
        missile = "image/missile.png",
    }

    for name, path in pairs(assets) do
        local handle = nvgCreateImage(vg, path, 0)
        if handle >= 0 then
            Sprites.images[name] = handle
        else
            print("[Sprites] WARNING: Failed to load " .. path)
        end
    end

    Sprites.loaded = true
    print("[Sprites] Loaded " .. #(Sprites.getNames()) .. " sprites")
end

-- 获取已加载图片名称列表
function Sprites.getNames()
    local names = {}
    for k, _ in pairs(Sprites.images) do
        names[#names + 1] = k
    end
    return names
end

-- ============================================================================
-- 绘制精灵：居中、支持旋转和缩放
-- vg: NanoVG context
-- name: 图片名称（对应 Sprites.images 中的 key）
-- x, y: 屏幕中心坐标
-- w, h: 绘制宽高
-- angle: 旋转角度（弧度），默认 0
-- alpha: 透明度 0-1，默认 1
-- ============================================================================
function Sprites.draw(vg, name, x, y, w, h, angle, alpha)
    local img = Sprites.images[name]
    if not img then return end

    angle = angle or 0
    alpha = alpha or 1.0

    nvgSave(vg)
    nvgTranslate(vg, x, y)
    if angle ~= 0 then
        nvgRotate(vg, angle)
    end

    nvgBeginPath(vg)
    nvgRect(vg, -w / 2, -h / 2, w, h)
    local paint = nvgImagePattern(vg, -w / 2, -h / 2, w, h, 0, img, alpha)
    nvgFillPaint(vg, paint)
    nvgFill(vg)

    nvgRestore(vg)
end

-- ============================================================================
-- 绘制精灵（带染色）：居中、支持旋转和 NVGcolor 叠色
-- ============================================================================
function Sprites.drawTinted(vg, name, x, y, w, h, angle, color)
    local img = Sprites.images[name]
    if not img then return end

    angle = angle or 0
    color = color or nvgRGBA(255, 255, 255, 255)

    nvgSave(vg)
    nvgTranslate(vg, x, y)
    if angle ~= 0 then
        nvgRotate(vg, angle)
    end

    nvgBeginPath(vg)
    nvgRect(vg, -w / 2, -h / 2, w, h)
    local paint = nvgImagePatternTinted(vg, -w / 2, -h / 2, w, h, 0, img, color)
    nvgFillPaint(vg, paint)
    nvgFill(vg)

    nvgRestore(vg)
end

-- ============================================================================
-- 绘制精灵（不旋转、不居中，用于背景平铺等）
-- ============================================================================
function Sprites.drawRect(vg, name, x, y, w, h, alpha)
    local img = Sprites.images[name]
    if not img then return end

    alpha = alpha or 1.0
    nvgBeginPath(vg)
    nvgRect(vg, x, y, w, h)
    local paint = nvgImagePattern(vg, x, y, w, h, 0, img, alpha)
    nvgFillPaint(vg, paint)
    nvgFill(vg)
end

-- ============================================================================
-- 敌人类型 → 精灵名称映射
-- ============================================================================
Sprites.enemyTypeMap = {
    drone       = "enemy_scout",
    aberration  = "enemy_cruiser",
    guard       = "enemy_fighter",
    kamikaze    = "enemy_bomber",
    flanker     = "enemy_scout",
    healer      = "enemy_fighter",
    cloaker     = "enemy_cruiser",
    summoner    = "enemy_fighter",
    splitter    = "enemy_bomber",
}

-- 拾取物类型 → 精灵名称映射
Sprites.pickupTypeMap = {
    metal       = "pickup_scrap",
    energy      = "pickup_energy",
    blueprint   = "pickup_blueprint",
    ancient_key = "pickup_key",
}

-- 强化道具类型 → 精灵名称映射（对应 Data.POWERUP_TYPES 的 key）
Sprites.powerupTypeMap = {
    speed_boost = "powerup_rapid",
    fire_rate   = "powerup_spread",
    invincible  = "powerup_shield",
    magnet      = "powerup_missile",
}

return Sprites
