local RunItemConfig = {
	UpdateRemoteName = "RunItems_Update",
	ChestRewardIds = {
		"camembert",
		"energy_drink",
	},

	Definitions = {
		camembert = {
			Id = "camembert",
			Name = "Camembert",
			Description = "+5% chance d'empoisonner une cible",
			Icon = "rbxassetid://107647623254487",
			Accent = Color3.fromRGB(129, 228, 116),
			PoisonChancePerStack = 0.05,
			PoisonTickDamage = 4,
			PoisonTickInterval = 1,
			PoisonBaseDuration = 4,
			PoisonFlashColor = Color3.fromRGB(130, 255, 120),
		},
		energy_drink = {
			Id = "energy_drink",
			Name = "EnergyDrink",
			Description = "+5% vitesse de deplacement, attaque et projectile",
			Icon = "rbxassetid://123677384123688",
			Accent = Color3.fromRGB(82, 218, 255),
			MoveSpeedPercentPerStack = 0.05,
			AttackSpeedPercentPerStack = 0.05,
			ProjectileSpeedPercentPerStack = 0.05,
		},
	},
}

return RunItemConfig
