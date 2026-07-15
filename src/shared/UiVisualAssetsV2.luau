--!strict

-- Registre des assets importes pour l'interface MegaRoblox V2.
-- Les cadres extensibles doivent etre affiches avec ScaleType.Slice et leur SliceCenter.

export type VisualAsset = {
	Id: string,
	SliceCenter: Rect?,
}

local UiVisualAssetsV2 = {}

UiVisualAssetsV2.Assets: { [string]: VisualAsset } = {
	PanelBase = {
		Id = "rbxassetid://128263580426710",
		SliceCenter = Rect.new(34, 34, 222, 222),
	},
	PanelBlue = {
		Id = "rbxassetid://126156514123431",
		SliceCenter = Rect.new(34, 34, 222, 222),
	},
	PanelGold = {
		Id = "rbxassetid://128287308621862",
		SliceCenter = Rect.new(34, 34, 222, 222),
	},
	PanelGreen = {
		Id = "rbxassetid://94538246856743",
		SliceCenter = Rect.new(34, 34, 222, 222),
	},
	ModalPanel = {
		Id = "rbxassetid://89640726438140",
		SliceCenter = Rect.new(38, 78, 282, 222),
	},
	Tooltip = {
		Id = "rbxassetid://132233815663421",
		SliceCenter = Rect.new(28, 28, 272, 112),
	},
	Notification = {
		Id = "rbxassetid://86622302436804",
		SliceCenter = Rect.new(32, 24, 328, 86),
	},
	HudTopBar = {
		Id = "rbxassetid://89320870141836",
		SliceCenter = Rect.new(48, 28, 592, 68),
	},
	HudBottomBar = {
		Id = "rbxassetid://138259406727242",
		SliceCenter = Rect.new(48, 34, 592, 106),
	},
	ButtonPrimaryNormal = {
		Id = "rbxassetid://123950428226818",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonPrimaryHover = {
		Id = "rbxassetid://107570778232488",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonPrimaryPressed = {
		Id = "rbxassetid://132232414844103",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonPrimaryDisabled = {
		Id = "rbxassetid://76573490130480",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonSecondaryNormal = {
		Id = "rbxassetid://131380304586121",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonSecondaryHover = {
		Id = "rbxassetid://117591280137002",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonSecondaryPressed = {
		Id = "rbxassetid://74914980202928",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonSecondaryDisabled = {
		Id = "rbxassetid://85093319237242",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonConfirmNormal = {
		Id = "rbxassetid://124224246511878",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonConfirmHover = {
		Id = "rbxassetid://110621251574151",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonConfirmPressed = {
		Id = "rbxassetid://116138548782024",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonConfirmDisabled = {
		Id = "rbxassetid://72410862616272",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonDangerNormal = {
		Id = "rbxassetid://137464224018679",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonDangerHover = {
		Id = "rbxassetid://118735599064853",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonDangerPressed = {
		Id = "rbxassetid://127741022950268",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonDangerDisabled = {
		Id = "rbxassetid://138965159173131",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonDarkNormal = {
		Id = "rbxassetid://119248414668979",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonDarkHover = {
		Id = "rbxassetid://117218813654658",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonDarkPressed = {
		Id = "rbxassetid://103342708200400",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	ButtonDarkDisabled = {
		Id = "rbxassetid://135197076505588",
		SliceCenter = Rect.new(28, 24, 292, 72),
	},
	TabInactive = {
		Id = "rbxassetid://111092712378077",
		SliceCenter = Rect.new(24, 20, 236, 56),
	},
	TabActive = {
		Id = "rbxassetid://98276925229019",
		SliceCenter = Rect.new(24, 20, 236, 56),
	},
	TabActiveBlue = {
		Id = "rbxassetid://97231852121416",
		SliceCenter = Rect.new(24, 20, 236, 56),
	},
	SlotEmpty = {
		Id = "rbxassetid://133728619092740",
		SliceCenter = Rect.new(28, 28, 100, 100),
	},
	SlotCommon = {
		Id = "rbxassetid://122534822520253",
		SliceCenter = Rect.new(28, 28, 100, 100),
	},
	SlotRare = {
		Id = "rbxassetid://103621622931474",
		SliceCenter = Rect.new(28, 28, 100, 100),
	},
	SlotEpic = {
		Id = "rbxassetid://99790524864854",
		SliceCenter = Rect.new(28, 28, 100, 100),
	},
	SlotLegendary = {
		Id = "rbxassetid://78405584012011",
		SliceCenter = Rect.new(28, 28, 100, 100),
	},
	SlotSelected = {
		Id = "rbxassetid://81559102835116",
		SliceCenter = Rect.new(28, 28, 100, 100),
	},
	BarTrack = {
		Id = "rbxassetid://97592261427606",
		SliceCenter = Rect.new(28, 20, 484, 44),
	},
	BarFillHealth = {
		Id = "rbxassetid://77217876440772",
		SliceCenter = Rect.new(28, 20, 484, 44),
	},
	BarFillShield = {
		Id = "rbxassetid://128301822436656",
		SliceCenter = Rect.new(28, 20, 484, 44),
	},
	BarFillXp = {
		Id = "rbxassetid://137216599621399",
		SliceCenter = Rect.new(28, 20, 484, 44),
	},
	BarFillGold = {
		Id = "rbxassetid://74411331938170",
		SliceCenter = Rect.new(28, 20, 484, 44),
	},
	BarFillDanger = {
		Id = "rbxassetid://125546774319749",
		SliceCenter = Rect.new(28, 20, 484, 44),
	},
	DividerArcane = {
		Id = "rbxassetid://133654189846875",
	},
	CornerArcane = {
		Id = "rbxassetid://108208723003991",
	},
	DiamondBadge = {
		Id = "rbxassetid://110959766708222",
	},
	RibbonCommon = {
		Id = "rbxassetid://118924561817482",
		SliceCenter = Rect.new(18, 14, 202, 42),
	},
	RibbonRare = {
		Id = "rbxassetid://135961017713308",
		SliceCenter = Rect.new(18, 14, 202, 42),
	},
	RibbonEpic = {
		Id = "rbxassetid://79203041665483",
		SliceCenter = Rect.new(18, 14, 202, 42),
	},
	RibbonLegendary = {
		Id = "rbxassetid://97229987160836",
		SliceCenter = Rect.new(18, 14, 202, 42),
	},
	IconHealth = {
		Id = "rbxassetid://82523622579105",
	},
	IconShield = {
		Id = "rbxassetid://76636561795841",
	},
	IconKills = {
		Id = "rbxassetid://107173043896966",
	},
	IconGold = {
		Id = "rbxassetid://77977713386395",
	},
	IconArcaneGem = {
		Id = "rbxassetid://79327771247121",
	},
	IconTimer = {
		Id = "rbxassetid://72591268429151",
	},
	IconPause = {
		Id = "rbxassetid://124342329229178",
	},
	IconPlay = {
		Id = "rbxassetid://81661835582003",
	},
	IconWeapon = {
		Id = "rbxassetid://74562872961810",
	},
	IconPerks = {
		Id = "rbxassetid://91001725555853",
	},
	IconShop = {
		Id = "rbxassetid://130939873513742",
	},
	IconQuests = {
		Id = "rbxassetid://99878352990547",
	},
	IconUnlocks = {
		Id = "rbxassetid://84032879548224",
	},
	IconLock = {
		Id = "rbxassetid://128956060190078",
	},
	IconHousing = {
		Id = "rbxassetid://78624865416113",
	},
	IconChest = {
		Id = "rbxassetid://123393983330246",
	},
	IconFireball = {
		Id = "rbxassetid://118952275406596",
	},
	IconMagnet = {
		Id = "rbxassetid://74283113282534",
	},
	IconPoison = {
		Id = "rbxassetid://102446768451899",
	},
	IconTrophy = {
		Id = "rbxassetid://91915362318785",
	},
	IconReroll = {
		Id = "rbxassetid://129475596503364",
	},
	IconSettings = {
		Id = "rbxassetid://72413435958211",
	},
}

function UiVisualAssetsV2.Get(key: string): VisualAsset
	local asset = UiVisualAssetsV2.Assets[key]

	assert(asset ~= nil, ("Asset visuel V2 introuvable : %s"):format(key))
	return asset
end

return UiVisualAssetsV2

