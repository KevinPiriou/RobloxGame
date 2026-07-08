local CombatStateService = {}

local pauseReasons = {}
local pauseStartedAt = nil
local totalPausedDuration = 0

local function getReasonCount()
	local count = 0

	for _ in pairs(pauseReasons) do
		count += 1
	end

	return count
end

function CombatStateService.Pause(reason)
	if pauseReasons[reason] then
		return
	end

	pauseReasons[reason] = true

	if getReasonCount() == 1 then
		pauseStartedAt = os.clock()
	end
end

function CombatStateService.Resume(reason)
	if not pauseReasons[reason] then
		return
	end

	pauseReasons[reason] = nil

	if getReasonCount() == 0 and pauseStartedAt ~= nil then
		totalPausedDuration += os.clock() - pauseStartedAt
		pauseStartedAt = nil
	end
end

function CombatStateService.IsPaused()
	return getReasonCount() > 0
end

function CombatStateService.GetTime()
	local pausedNow = 0

	if pauseStartedAt ~= nil then
		pausedNow = os.clock() - pauseStartedAt
	end

	return os.clock() - totalPausedDuration - pausedNow
end

return CombatStateService
