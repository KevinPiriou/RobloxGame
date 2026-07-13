local DebugConfig = require(script.Parent:WaitForChild("DebugConfig"))

local DebugLog = {}

local lastLogAtByKey = {}

local function isCategoryEnabled(category)
	if not DebugConfig.ConsoleEnabled then
		return false
	end

	local categories = DebugConfig.Categories or {}
	local categoryValue = categories[category]

	if categoryValue == nil then
		return DebugConfig.DefaultCategoryEnabled == true
	end

	return categoryValue == true
end

local function serializeValue(value, depth)
	depth = depth or 0

	if depth >= 2 then
		return "..."
	end

	local valueType = typeof(value)

	if valueType == "Instance" then
		return value:GetFullName()
	elseif valueType == "Vector3" then
		return ("(%.1f, %.1f, %.1f)"):format(value.X, value.Y, value.Z)
	elseif valueType == "CFrame" then
		return serializeValue(value.Position, depth + 1)
	elseif valueType == "Color3" then
		return ("rgb(%.2f, %.2f, %.2f)"):format(value.R, value.G, value.B)
	elseif valueType ~= "table" then
		return tostring(value)
	end

	local parts = {}
	local count = 0

	for key, childValue in pairs(value) do
		count += 1

		if count > 14 then
			table.insert(parts, "...")
			break
		end

		table.insert(parts, tostring(key) .. "=" .. serializeValue(childValue, depth + 1))
	end

	table.sort(parts)

	return "{" .. table.concat(parts, ", ") .. "}"
end

local function createLine(level, category, message, context)
	local line = ("[MegaRoblox][%s][%s] %s"):format(level, category, message)

	if context ~= nil then
		line ..= " | " .. serializeValue(context)
	end

	return line
end

local function shouldLog(category, throttleKey, throttleSeconds)
	if not isCategoryEnabled(category) then
		return false
	end

	if throttleKey == nil or throttleSeconds == nil or throttleSeconds <= 0 then
		return true
	end

	local scopedKey = category .. ":" .. throttleKey
	local now = os.clock()
	local lastLogAt = lastLogAtByKey[scopedKey]

	if lastLogAt ~= nil and now - lastLogAt < throttleSeconds then
		return false
	end

	lastLogAtByKey[scopedKey] = now

	return true
end

function DebugLog.Info(category, message, context)
	if not shouldLog(category) then
		return
	end

	print(createLine("INFO", category, message, context))
end

function DebugLog.Warn(category, message, context)
	if not shouldLog(category) then
		return
	end

	warn(createLine("WARN", category, message, context))
end

function DebugLog.ThrottledInfo(category, throttleKey, throttleSeconds, message, context)
	if not shouldLog(category, throttleKey, throttleSeconds) then
		return
	end

	print(createLine("INFO", category, message, context))
end

function DebugLog.ThrottledWarn(category, throttleKey, throttleSeconds, message, context)
	if not shouldLog(category, throttleKey, throttleSeconds) then
		return
	end

	warn(createLine("WARN", category, message, context))
end

function DebugLog.GetState()
	local categories = {}

	for category, isEnabled in pairs(DebugConfig.Categories or {}) do
		categories[category] = isEnabled == true
	end

	return {
		ConsoleEnabled = DebugConfig.ConsoleEnabled == true,
		Categories = categories,
	}
end

function DebugLog.ApplyState(state)
	if typeof(state) ~= "table" then
		return
	end

	if typeof(state.ConsoleEnabled) == "boolean" then
		DebugConfig.ConsoleEnabled = state.ConsoleEnabled
	end

	if typeof(state.Categories) ~= "table" then
		return
	end

	for category, isEnabled in pairs(state.Categories) do
		if typeof(category) == "string" and category ~= "" and typeof(isEnabled) == "boolean" then
			DebugConfig.Categories[category] = isEnabled
		end
	end
end

function DebugLog.SetConsoleEnabled(isEnabled)
	DebugConfig.ConsoleEnabled = isEnabled == true
end

function DebugLog.SetCategoryEnabled(category, isEnabled)
	if typeof(category) ~= "string" or category == "" then
		return false
	end

	DebugConfig.Categories[category] = isEnabled == true
	return true
end

return DebugLog
