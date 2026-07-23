--!strict

-- Initialise la table locale avant les adaptateurs UI afin que les composants
-- dynamiques et les textes AutoLocalize utilisent le meme referentiel.
local I18nClient = require(script.Parent:WaitForChild("I18nClient"))

I18nClient.Start()
