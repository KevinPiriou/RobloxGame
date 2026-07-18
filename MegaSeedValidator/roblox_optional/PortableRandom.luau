--!strict
-- RNG portable identique à seed_validator.py.
-- Son adoption change la géométrie produite par les anciennes seeds.
local PortableRandom = {}
PortableRandom.__index = PortableRandom
local UINT32_MOD = 4294967296
local UINT32_MAX = 4294967295
local ZERO_SEED_FALLBACK = 0x6D2B79F5
export type PortableRandom = {
    _state: number,
    NextNumber: (self: PortableRandom, minimum: number?, maximum: number?) -> number,
    NextInteger: (self: PortableRandom, minimum: number, maximum: number) -> number,
    _nextUInt32: (self: PortableRandom) -> number,
}
local function normalize(value: number): number
    local n = math.floor(value) % UINT32_MOD
    if n < 0 then n += UINT32_MOD end
    return n
end
function PortableRandom.new(seed: number): PortableRandom
    local state = normalize(seed)
    if state == 0 then state = ZERO_SEED_FALLBACK end
    return setmetatable({_state = state}, PortableRandom) :: any
end
function PortableRandom:_nextUInt32(): number
    local x = self._state
    x = bit32.bxor(x, bit32.lshift(x, 13))
    x = bit32.bxor(x, bit32.rshift(x, 17))
    x = bit32.bxor(x, bit32.lshift(x, 5))
    x = normalize(x)
    self._state = x
    return x
end
function PortableRandom:NextNumber(minimum: number?, maximum: number?): number
    local a = minimum or 0
    local b = maximum or 1
    return a + ((b - a) * (self:_nextUInt32() / UINT32_MAX))
end
function PortableRandom:NextInteger(minimum: number, maximum: number): number
    assert(maximum >= minimum, "maximum doit etre >= minimum")
    local span = maximum - minimum + 1
    local limit = math.floor(UINT32_MOD / span) * span
    while true do
        local value = self:_nextUInt32()
        if value < limit then return minimum + (value % span) end
    end
end
return PortableRandom
