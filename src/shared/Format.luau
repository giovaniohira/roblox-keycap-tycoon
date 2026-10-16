-- Notacao compacta: 1_000 → 1K, 1_000_000 → 1M, etc.
local Format = {}

local SUFFIXES = {
	{ 1e33, "Dc" },
	{ 1e30, "No" },
	{ 1e27, "Oc" },
	{ 1e24, "Sp" },
	{ 1e21, "Sx" },
	{ 1e18, "Qi" },
	{ 1e15, "Qa" },
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
}

function Format.money(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local neg = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = if n % 1 < 1e-9 then string.format("%.0f", n) else string.format("%.1f", n)
		return if neg then "-" .. s else s
	end
	for _, pair in SUFFIXES do
		local div, suf = pair[1], pair[2]
		if n >= div then
			local v = n / div
			local s = if v >= 100 then string.format("%.0f%s", v, suf)
				elseif v >= 10 then string.format("%.1f%s", v, suf)
				else string.format("%.2f%s", v, suf)
			return if neg then "-" .. s else s
		end
	end
	return if neg then "-" .. string.format("%.0f", n) else string.format("%.0f", n)
end

function Format.moneyPerSec(n: number): string
	return "$" .. Format.money(n) .. "/s"
end

function Format.cash(n: number): string
	return "$" .. Format.money(n)
end

return Format
