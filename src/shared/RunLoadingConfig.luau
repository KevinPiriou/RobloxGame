return {
	RemoteName = "Run_LoadingState",
	AttributeName = "IsRunLoading",
	GuiName = "RunLoadingGui",
	ReleaseDelay = 0.18,
	Stages = {
		Preparing = {
			Progress = 0.05,
			Message = "Preparation de la run",
		},
		Map = {
			Progress = 0.16,
			Message = "Generation du niveau",
		},
		Terrain = {
			Progress = 0.34,
			Message = "Modelage du relief",
		},
		Decorations = {
			Progress = 0.48,
			Message = "Mise en place des decors",
		},
		Portal = {
			Progress = 0.58,
			Message = "Stabilisation du portail",
		},
		Shrines = {
			Progress = 0.7,
			Message = "Activation des autels",
		},
		Chests = {
			Progress = 0.8,
			Message = "Dispersion des coffres",
		},
		Totems = {
			Progress = 0.9,
			Message = "Ancrage des totems",
		},
		Jars = {
			Progress = 0.97,
			Message = "Ajout des ressources",
		},
		Ready = {
			Progress = 1,
			Message = "Run prete",
		},
	},
	BatchSizes = {
		Portal = 1,
		Shrines = 3,
		Chests = 5,
		Totems = 2,
		Jars = 5,
	},
}
