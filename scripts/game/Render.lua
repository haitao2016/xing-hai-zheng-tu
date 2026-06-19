-- ============================================================================
-- 星海征途 - 渲染编排器 (Orchestrator)
-- 委托给子模块: RenderWorld / RenderFX / RenderUI
-- ============================================================================

local RenderWorld = require("game.RenderWorld")
local RenderFX   = require("game.RenderFX")
local RenderUI   = require("game.RenderUI")

local Render = {}

-- ============================================================================
-- World 渲染 (14 functions)
-- ============================================================================
Render.drawStars       = RenderWorld.drawStars
Render.drawWorldRings  = RenderWorld.drawWorldRings
Render.drawPlayer      = RenderWorld.drawPlayer
Render.drawEnemies     = RenderWorld.drawEnemies
Render.drawBullets     = RenderWorld.drawBullets
Render.drawAsteroids   = RenderWorld.drawAsteroids
Render.drawPickups     = RenderWorld.drawPickups
Render.drawRelicDrops  = RenderWorld.drawRelicDrops
Render.drawRelays      = RenderWorld.drawRelays
Render.drawPowerups    = RenderWorld.drawPowerups
Render.drawAllies      = RenderWorld.drawAllies
Render.drawLaser       = RenderWorld.drawLaser
Render.drawMissiles    = RenderWorld.drawMissiles
Render.drawHazards     = RenderWorld.drawHazards
Render.drawBoomerangs  = RenderWorld.drawBoomerangs
Render.drawMines       = RenderWorld.drawMines

-- ============================================================================
-- FX 特效 (10 functions)
-- ============================================================================
Render.drawParticles         = RenderFX.drawParticles
Render.drawFloatingTexts     = RenderFX.drawFloatingTexts
Render.drawToasts            = RenderFX.drawToasts
Render.drawEventOverlay      = RenderFX.drawEventOverlay
Render.drawWaveWarning       = RenderFX.drawWaveWarning
Render.drawBossEffects       = RenderFX.drawBossEffects
Render.drawCollectAnims      = RenderFX.drawCollectAnims
Render.drawTutorial          = RenderFX.drawTutorial
Render.drawAchievementPopups = RenderFX.drawAchievementPopups
Render.drawSlowmoOverlay     = RenderFX.drawSlowmoOverlay
Render.drawTimeSlowFX        = RenderFX.drawTimeSlowFX
Render.drawDamageFlash       = RenderFX.drawDamageFlash

-- ============================================================================
-- UI 界面 (13 functions)
-- ============================================================================
Render.drawHUD              = RenderUI.drawHUD
Render.drawQuestPanel       = RenderUI.drawQuestPanel
Render.drawMinimap          = RenderUI.drawMinimap
Render.drawMenu             = RenderUI.drawMenu
Render.drawTechTree         = RenderUI.drawTechTree
Render.drawGameOver         = RenderUI.drawGameOver
Render.drawActivePowerups   = RenderUI.drawActivePowerups
Render.drawLeaderboard      = RenderUI.drawLeaderboard
Render.drawEventChoice      = RenderUI.drawEventChoice
Render.drawAllyModeIndicator = RenderUI.drawAllyModeIndicator
Render.drawCombo            = RenderUI.drawCombo
Render.drawRelicSlots       = RenderUI.drawRelicSlots
Render.drawStats            = RenderUI.drawStats
Render.drawModManager       = RenderUI.drawModManager
Render.drawDifficultySelect = RenderUI.drawDifficultySelect
Render.drawCampaignSelect   = RenderUI.drawCampaignSelect
Render.drawComboBanner      = RenderUI.drawComboBanner
Render.drawScreenFlash      = RenderUI.drawScreenFlash
Render.drawTouchControls    = RenderUI.drawTouchControls
Render.hitTestTouchControl  = RenderUI.hitTestTouchControl
Render.isTouchDevice        = RenderUI.isTouchDevice

return Render
