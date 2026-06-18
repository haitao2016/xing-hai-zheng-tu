-- ============================================================================
-- 星海征途 - 核心工具函数（所有子模块共享）
-- ============================================================================

local CoreUtils = {}

local TAU = math.pi * 2
CoreUtils.TAU = TAU

function CoreUtils.rand(a, b) return a + math.random() * (b - a) end
function CoreUtils.randInt(a, b) return math.floor(CoreUtils.rand(a, b + 1)) end
function CoreUtils.dist(ax, ay, bx, by) return math.sqrt((ax - bx)^2 + (ay - by)^2) end
function CoreUtils.lerp(a, b, t) return a + (b - a) * t end
function CoreUtils.clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function CoreUtils.angleToward(fromX, fromY, toX, toY) return math.atan(toY - fromY, toX - fromX) end

return CoreUtils
