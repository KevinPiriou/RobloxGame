--!strict

-- Referentiel de texte partage. Le francais reste la source produit ; l'anglais
-- est livre explicitement et les autres langues peuvent etre completees par Roblox.

local I18n = {}

export type Entry = {
	Key: string,
	Source: string,
	Values: {[string]: string},
}

local entries: {Entry} = {
	{ Key = "action.ban", Source = "BANNIR", Values = { fr = "BANNIR", ["en-us"] = "BAN" } },
	{ Key = "action.choose_weapon", Source = "CHOISIR L'ARME", Values = { fr = "CHOISIR L'ARME", ["en-us"] = "CHOOSE A WEAPON" } },
	{ Key = "action.continue", Source = "CONTINUER", Values = { fr = "CONTINUER", ["en-us"] = "CONTINUE" } },
	{ Key = "action.pass", Source = "PASSER", Values = { fr = "PASSER", ["en-us"] = "PASS" } },
	{ Key = "action.refresh", Source = "RAFRAICHIR", Values = { fr = "RAFRAICHIR", ["en-us"] = "REFRESH" } },
	{ Key = "action.pass_credits", Source = "PASSER ({current}/{max})", Values = { fr = "PASSER ({current}/{max})", ["en-us"] = "PASS ({current}/{max})" } },
	{ Key = "action.ban_credits", Source = "BANNIR ({current}/{max})", Values = { fr = "BANNIR ({current}/{max})", ["en-us"] = "BAN ({current}/{max})" } },
	{ Key = "character.albert.description", Source = "Savant fou dont les instruments attirent les collectibles.", Values = { fr = "Savant fou dont les instruments attirent les collectibles.", ["en-us"] = "A mad scientist whose instruments attract collectibles." } },
	{ Key = "character.albert.passive", Source = "Magnetisme scientifique", Values = { fr = "Magnetisme scientifique", ["en-us"] = "Scientific magnetism" } },
	{ Key = "character.lorelei.name", Source = "Lorelei", Values = { fr = "Lorelei", ["en-us"] = "Lorelei" } },
	{ Key = "character.lorelei.description", Source = "Succube qui lie son essence a celle de ses proies pour leur derober la vie.", Values = { fr = "Succube qui lie son essence a celle de ses proies pour leur derober la vie.", ["en-us"] = "A succubus who binds her essence to her prey to steal their life." } },
	{ Key = "character.lorelei.passive", Source = "Moisson du Voile", Values = { fr = "Moisson du Voile", ["en-us"] = "Veil Harvest" } },
	{ Key = "character.medivh.description", Source = "Mage malicieux qui amplifie les salves de projectiles.", Values = { fr = "Mage malicieux qui amplifie les salves de projectiles.", ["en-us"] = "A mischievous mage who amplifies projectile volleys." } },
	{ Key = "character.medivh.passive", Source = "Volee arcanique", Values = { fr = "Volee arcanique", ["en-us"] = "Arcane volley" } },
	{ Key = "character.shinobi.name", Source = "Shinobi", Values = { fr = "Shinobi", ["en-us"] = "Shinobi" } },
	{ Key = "character.shinobi.description", Source = "Ninja precis qui accelere sa cadence a chaque niveau.", Values = { fr = "Ninja precis qui accelere sa cadence a chaque niveau.", ["en-us"] = "A precise ninja who accelerates their attack speed every level." } },
	{ Key = "character.shinobi.passive", Source = "Entrainement de l'ombre", Values = { fr = "Entrainement de l'ombre", ["en-us"] = "Shadow training" } },
	{ Key = "character.rusal_gale.name", Source = "Ru's al Gale", Values = { fr = "Ru's al Gale", ["en-us"] = "Ru's al Gale" } },
	{ Key = "character.rusal_gale.description", Source = "Necromancien qui rallie les morts sous une lanterne spectrale.", Values = { fr = "Necromancien qui rallie les morts sous une lanterne spectrale.", ["en-us"] = "A necromancer who rallies the dead beneath a spectral lantern." } },
	{ Key = "character.rusal_gale.passive", Source = "Instinct funeraire", Values = { fr = "Instinct funeraire", ["en-us"] = "Funeral instinct" } },
	{ Key = "character.rufus.name", Source = "Rufus", Values = { fr = "Rufus", ["en-us"] = "Rufus" } },
	{ Key = "character.rufus.description", Source = "Chevalier de l'Alliance qui tient la ligne au corps a corps.", Values = { fr = "Chevalier de l'Alliance qui tient la ligne au corps a corps.", ["en-us"] = "An Alliance knight who holds the line in close combat." } },
	{ Key = "character.rufus.passive", Source = "Bastion de Valorcrest", Values = { fr = "Bastion de Valorcrest", ["en-us"] = "Valorcrest bulwark" } },
	{ Key = "character.wukong.name", Source = "Wukong", Values = { fr = "Wukong", ["en-us"] = "Wukong" } },
	{ Key = "character.wukong.description", Source = "Singe guerrier du soleil dont le baton frappe plus fort a mesure qu'il gagne en vitesse.", Values = { fr = "Singe guerrier du soleil dont le baton frappe plus fort a mesure qu'il gagne en vitesse.", ["en-us"] = "Sun warrior monkey whose staff hits harder as he gains movement speed." } },
	{ Key = "character.wukong.passive", Source = "Pas des nuages", Values = { fr = "Pas des nuages", ["en-us"] = "Cloudstep" } },
	{ Key = "chapter.1.name", Source = "Chapitre 1", Values = { fr = "Chapitre 1", ["en-us"] = "Chapter 1" } },
	{ Key = "chapter.2.name", Source = "Chapitre 2", Values = { fr = "Chapitre 2", ["en-us"] = "Chapter 2" } },
	{ Key = "chapter.3.name", Source = "Chapitre 3", Values = { fr = "Chapitre 3", ["en-us"] = "Chapter 3" } },
	{ Key = "rarity.common", Source = "COMMUN", Values = { fr = "COMMUN", ["en-us"] = "COMMON" } },
	{ Key = "rarity.epic", Source = "EPIQUE", Values = { fr = "EPIQUE", ["en-us"] = "EPIC" } },
	{ Key = "rarity.legendary", Source = "LEGENDAIRE", Values = { fr = "LEGENDAIRE", ["en-us"] = "LEGENDARY" } },
	{ Key = "rarity.rare", Source = "RARE", Values = { fr = "RARE", ["en-us"] = "RARE" } },
	{ Key = "ui.character.passive", Source = "PASSIF", Values = { fr = "PASSIF", ["en-us"] = "PASSIVE" } },
	{ Key = "ui.character.preview", Source = "APERCU", Values = { fr = "APERCU", ["en-us"] = "PREVIEW" } },
	{ Key = "ui.chapter.available", Source = "DISPONIBLE", Values = { fr = "DISPONIBLE", ["en-us"] = "AVAILABLE" } },
	{ Key = "ui.chapter.completed", Source = "TERMINE", Values = { fr = "TERMINE", ["en-us"] = "COMPLETED" } },
	{ Key = "ui.chapter.locked", Source = "VERROUILLE", Values = { fr = "VERROUILLE", ["en-us"] = "LOCKED" } },
	{ Key = "ui.coming_soon", Source = "A VENIR", Values = { fr = "A VENIR", ["en-us"] = "COMING SOON" } },
	{ Key = "ui.level.one", Source = "NIVEAU 1", Values = { fr = "NIVEAU 1", ["en-us"] = "LEVEL 1" } },
	{ Key = "ui.map.test", Source = "MAP TEST", Values = { fr = "MAP TEST", ["en-us"] = "TEST MAP" } },
	{ Key = "ui.run.characters_unavailable", Source = "Personnages indisponibles. Reessaie dans un instant.", Values = { fr = "Personnages indisponibles. Reessaie dans un instant.", ["en-us"] = "Characters are unavailable. Please try again shortly." } },
	{ Key = "ui.run.generating", Source = "Generation de la run...", Values = { fr = "Generation de la run...", ["en-us"] = "Generating run..." } },
	{ Key = "ui.run.loading", Source = "CHARGEMENT...", Values = { fr = "CHARGEMENT...", ["en-us"] = "LOADING..." } },
	{ Key = "ui.run.choose_level", Source = "CHOISIR LE NIVEAU", Values = { fr = "CHOISIR LE NIVEAU", ["en-us"] = "CHOOSE A LEVEL" } },
	{ Key = "ui.run.start", Source = "LANCER LA RUN", Values = { fr = "LANCER LA RUN", ["en-us"] = "START RUN" } },
	{ Key = "ui.run.launch_failed", Source = "Lancement impossible : {reason}", Values = { fr = "Lancement impossible : {reason}", ["en-us"] = "Unable to start: {reason}" } },
	{ Key = "ui.run.launch", Source = "LANCER UNE RUN", Values = { fr = "LANCER UNE RUN", ["en-us"] = "START A RUN" } },
	{ Key = "ui.run.progression_unavailable", Source = "Progression indisponible. Reessaie dans un instant.", Values = { fr = "Progression indisponible. Reessaie dans un instant.", ["en-us"] = "Progression is unavailable. Please try again shortly." } },
	{ Key = "ui.run.ready", Source = "Run prete", Values = { fr = "Run prete", ["en-us"] = "Run ready" } },
	{ Key = "ui.weapon_choice.evolution", Source = "EVOLUTION  NIV. {current} > {next}", Values = { fr = "EVOLUTION  NIV. {current} > {next}", ["en-us"] = "EVOLUTION  LVL {current} > {next}" } },
	{ Key = "ui.weapon_choice.new", Source = "NOUVELLE ARME", Values = { fr = "NOUVELLE ARME", ["en-us"] = "NEW WEAPON" } },
	{ Key = "ui.weapon_choice.subtitle", Source = "Choisis une arme ou renforce ton arsenal", Values = { fr = "Choisis une arme ou renforce ton arsenal", ["en-us"] = "Choose a weapon or reinforce your arsenal" } },
	{ Key = "ui.weapon_choice.title", Source = "CHOIX D'ARME", Values = { fr = "CHOIX D'ARME", ["en-us"] = "WEAPON CHOICE" } },
	{ Key = "weapon.fireball.name", Source = "Boule de feu", Values = { fr = "Boule de feu", ["en-us"] = "Fireball" } },
	{ Key = "weapon.leyden_needle.name", Source = "Aiguille de Leyde", Values = { fr = "Aiguille de Leyde", ["en-us"] = "Leyden Needle" } },
	{ Key = "weapon.shuriken.name", Source = "Shuriken", Values = { fr = "Shuriken", ["en-us"] = "Shuriken" } },
	{ Key = "weapon.soul_lantern.name", Source = "Lanterne des ames", Values = { fr = "Lanterne des ames", ["en-us"] = "Soul Lantern" } },
	{ Key = "weapon.soulthorn_drain.name", Source = "Epine d'ame", Values = { fr = "Epine d'ame", ["en-us"] = "Soulthorn" } },
	{ Key = "weapon.valorcrest_blade.name", Source = "Lame de Valorcrest", Values = { fr = "Lame de Valorcrest", ["en-us"] = "Valorcrest Blade" } },
	{ Key = "weapon.sunward_staff.name", Source = "Baton du Roi Singe", Values = { fr = "Baton du Roi Singe", ["en-us"] = "Sunward Staff" } },
	{ Key = "weapon.evolution.damage", Source = "Degats de l'arme", Values = { fr = "Degats de l'arme", ["en-us"] = "Weapon damage" } },
	{ Key = "weapon.evolution.projectile_count", Source = "Projectile supplementaire", Values = { fr = "Projectile supplementaire", ["en-us"] = "Additional projectile" } },
	{ Key = "weapon.evolution.bounce_count", Source = "Rebond supplementaire", Values = { fr = "Rebond supplementaire", ["en-us"] = "Additional bounce" } },
	{ Key = "weapon.evolution.zone_radius", Source = "Rayon de la zone", Values = { fr = "Rayon de la zone", ["en-us"] = "Zone radius" } },
	{ Key = "weapon.evolution.minion_count", Source = "Serviteur supplementaire", Values = { fr = "Serviteur supplementaire", ["en-us"] = "Additional servant" } },
	{ Key = "weapon.evolution.minion_duration", Source = "Duree d'invocation", Values = { fr = "Duree d'invocation", ["en-us"] = "Summon duration" } },
	{ Key = "weapon.effect.damage", Source = "+{amount} degats de l'arme", Values = { fr = "+{amount} degats de l'arme", ["en-us"] = "+{amount} weapon damage" } },
	{ Key = "weapon.effect.projectile_count", Source = "+{amount} projectile", Values = { fr = "+{amount} projectile", ["en-us"] = "+{amount} projectile" } },
	{ Key = "weapon.effect.projectile_count_plural", Source = "+{amount} projectiles", Values = { fr = "+{amount} projectiles", ["en-us"] = "+{amount} projectiles" } },
	{ Key = "weapon.effect.bounce_count", Source = "+{amount} rebond", Values = { fr = "+{amount} rebond", ["en-us"] = "+{amount} bounce" } },
	{ Key = "weapon.effect.bounce_count_plural", Source = "+{amount} rebonds", Values = { fr = "+{amount} rebonds", ["en-us"] = "+{amount} bounces" } },
	{ Key = "weapon.effect.zone_radius", Source = "+{amount} studs de rayon", Values = { fr = "+{amount} studs de rayon", ["en-us"] = "+{amount} studs of radius" } },
}

local byKey: {[string]: Entry} = {}
for _, entry in ipairs(entries) do
	byKey[entry.Key] = entry
end

function I18n.NormalizeLocale(localeId: string?): string
	local normalized = string.lower(tostring(localeId or "fr"))
	if string.sub(normalized, 1, 2) == "fr" then
		return "fr"
	end
	if string.sub(normalized, 1, 2) == "en" then
		return "en-us"
	end
	return normalized
end

function I18n.GetEntries(): {Entry}
	return entries
end

function I18n.Format(key: string, localeId: string?, parameters: {[string]: unknown}?): string
	local entry = byKey[key]
	if entry == nil then
		return key
	end

	local locale = I18n.NormalizeLocale(localeId)
	local text = entry.Values[locale] or entry.Values.fr or entry.Source
	if parameters == nil then
		return text
	end

	return string.gsub(text, "{([%w_]+)}", function(parameterName)
		local value = parameters[parameterName]
		return if value == nil then "{" .. parameterName .. "}" else tostring(value)
	end)
end

return I18n
