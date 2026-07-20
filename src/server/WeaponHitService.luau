--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local GameplayFeedbackService = require(script.Parent:WaitForChild("GameplayFeedbackService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))
local RunItemService = require(script.Parent:WaitForChild("RunItemService"))

local WeaponHitService = {}

function WeaponHitService.Apply(player: Player, monster: Instance, weaponId: string, baseDamage: number, flashColor: Color3?)
	if player == nil or monster == nil or not MonsterService.IsMonsterAlive(monster) then
		return false, 0, false
	end

	local targetPath = monster:GetFullName()
	local damage, isCritical = PerkService.CalculateOutgoingDamage(player, baseDamage, monster)
	local didDamage, damageDealt = MonsterService.DamageMonster(monster, damage, player, {
		FlashColor = flashColor,
	})
	local dealt = math.max(0, tonumber(damageDealt) or 0)

	if not didDamage then
		return false, 0, isCritical
	end

	if isCritical then
		GameplayFeedbackService.Queue(player, "Critical", dealt)
	end

	PerkService.ApplyLifeSteal(player, dealt, "Hit")
	RunAnalyticsService.RecordDamageDealt(player, dealt, weaponId)
	RunItemService.TryApplyOnWeaponHit(player, monster, weaponId)
	DebugLog.ThrottledInfo("Weapon", "weapon_hit_" .. weaponId, 0.5, "Arme touche un monstre", {
		Player = player.Name,
		WeaponId = weaponId,
		Damage = damage,
		DamageDealt = dealt,
		Target = targetPath,
	})

	return true, dealt, isCritical
end

return WeaponHitService
