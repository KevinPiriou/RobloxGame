-- Collecteur volontairement petit et inactif hors campagne P0.

local PerformanceTelemetryService = {}

local isCapturing = false
local captureId = nil
local startedAt = nil
local samplesByMetric = {}
local countersByMetric = {}

local function getOrCreateSamples(metricName)
	local samples = samplesByMetric[metricName]

	if samples == nil then
		samples = {}
		samplesByMetric[metricName] = samples
	end

	return samples
end

local function percentile(sortedSamples, percentileValue)
	if #sortedSamples == 0 then
		return nil
	end

	local index = math.clamp(math.ceil(#sortedSamples * percentileValue), 1, #sortedSamples)
	return sortedSamples[index]
end

local function summarizeSamples(samples)
	if #samples == 0 then
		return nil
	end

	local sortedSamples = table.clone(samples)
	table.sort(sortedSamples)
	local total = 0

	for _, value in ipairs(sortedSamples) do
		total += value
	end

	return {
		Count = #sortedSamples,
		Min = sortedSamples[1],
		Average = total / #sortedSamples,
		Max = sortedSamples[#sortedSamples],
		P50 = percentile(sortedSamples, 0.5),
		P95 = percentile(sortedSamples, 0.95),
		P99 = percentile(sortedSamples, 0.99),
	}
end

function PerformanceTelemetryService.IsCapturing()
	return isCapturing
end

function PerformanceTelemetryService.Begin(nextCaptureId)
	isCapturing = true
	captureId = nextCaptureId
	startedAt = os.clock()
	samplesByMetric = {}
	countersByMetric = {}
end

function PerformanceTelemetryService.Reset()
	if not isCapturing then
		return
	end

	startedAt = os.clock()
	samplesByMetric = {}
	countersByMetric = {}
end

function PerformanceTelemetryService.Record(metricName, value, maximumSamples)
	if not isCapturing or typeof(metricName) ~= "string" or typeof(value) ~= "number" then
		return
	end

	if value ~= value or value == math.huge or value == -math.huge then
		return
	end

	local samples = getOrCreateSamples(metricName)

	if #samples < (maximumSamples or 7200) then
		table.insert(samples, value)
	end
end

function PerformanceTelemetryService.Increment(metricName, amount)
	if not isCapturing or typeof(metricName) ~= "string" then
		return
	end

	countersByMetric[metricName] = (countersByMetric[metricName] or 0) + (amount or 1)
end

function PerformanceTelemetryService.Finish()
	if not isCapturing then
		return nil
	end

	local metrics = {}

	for metricName, samples in pairs(samplesByMetric) do
		metrics[metricName] = summarizeSamples(samples)
	end

	local result = {
		CaptureId = captureId,
		DurationSeconds = if startedAt ~= nil then os.clock() - startedAt else 0,
		Metrics = metrics,
		Counters = table.clone(countersByMetric),
	}

	isCapturing = false
	captureId = nil
	startedAt = nil
	samplesByMetric = {}
	countersByMetric = {}

	return result
end

return PerformanceTelemetryService
