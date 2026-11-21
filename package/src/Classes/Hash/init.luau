--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

--[=[
	MD5, SHA-1 and SHA-256 for the *sum commands. Pure Luau, no filesystem.
]=]

local MOD = 4294967296
local band = bit32.band
local bor = bit32.bor
local bxor = bit32.bxor
local bnot = bit32.bnot
local lrotate = bit32.lrotate
local rrotate = bit32.rrotate

local Hash = {}

--[=[
	Serialises a 32-bit word in little-endian order.

	@param value The value to convert.
	@return The resulting text.
]=]
local function wordLE(value: number): string
	value = value % MOD
	return string.char(
		value % 256,
		math.floor(value / 256) % 256,
		math.floor(value / 65536) % 256,
		math.floor(value / 16777216) % 256
	)
end

--[=[
	Serialises a 32-bit word in big-endian order.

	@param value The value to convert.
	@return The resulting text.
]=]
local function wordBE(value: number): string
	return string.char(
		math.floor(value / 16777216) % 256,
		math.floor(value / 65536) % 256,
		math.floor(value / 256) % 256,
		value % 256
	)
end

--[=[
	Reads a little-endian 32-bit word.

	@param text The text to inspect.
	@param position The position to inspect.
	@return The resulting number.
]=]
local function readLE(text: string, position: number): number
	local a, b, c, d = string.byte(text, position, position + 3)
	return (a or 0) + (b or 0) * 256 + (c or 0) * 65536 + (d or 0) * 16777216
end

--[=[
	Reads a big-endian 32-bit word.

	@param text The text to inspect.
	@param position The position to inspect.
	@return The resulting number.
]=]
local function readBE(text: string, position: number): number
	local a, b, c, d = string.byte(text, position, position + 3)
	return (a or 0) * 16777216 + (b or 0) * 65536 + (c or 0) * 256 + (d or 0)
end

--[=[
	Formats a 32-bit word as big-endian hexadecimal.

	@param value The value to convert.
	@return The resulting text.
]=]
local function hex32(value: number): string
	return string.format("%08x", value % MOD)
end

--[=[
	Formats a 32-bit word as little-endian hexadecimal.

	@param value The value to convert.
	@return The resulting text.
]=]
local function hex32LE(value: number): string
	value = value % MOD
	return string.format(
		"%02x%02x%02x%02x",
		value % 256,
		math.floor(value / 256) % 256,
		math.floor(value / 65536) % 256,
		math.floor(value / 16777216) % 256
	)
end

--// MD5 //--

local MD5_SHIFT = {
	7,
	12,
	17,
	22,
	7,
	12,
	17,
	22,
	7,
	12,
	17,
	22,
	7,
	12,
	17,
	22,
	5,
	9,
	14,
	20,
	5,
	9,
	14,
	20,
	5,
	9,
	14,
	20,
	5,
	9,
	14,
	20,
	4,
	11,
	16,
	23,
	4,
	11,
	16,
	23,
	4,
	11,
	16,
	23,
	4,
	11,
	16,
	23,
	6,
	10,
	15,
	21,
	6,
	10,
	15,
	21,
	6,
	10,
	15,
	21,
	6,
	10,
	15,
	21,
}

local MD5_K = {}
for i = 1, 64 do
	MD5_K[i] = math.floor(math.abs(math.sin(i)) * MOD) % MOD
end

--[=[
	Computes the MD5 digest of a string.

	@param input The input to process.
	@return The resulting text.
]=]
function Hash.md5(input: string): string
	local message = input
	local bitLength = #message * 8

	message ..= string.char(0x80)
	while #message % 64 ~= 56 do
		message ..= string.char(0)
	end
	message ..= wordLE(bitLength % MOD)
	message ..= wordLE(math.floor(bitLength / MOD) % MOD)

	local a0, b0, c0, d0 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476

	for offset = 1, #message, 64 do
		local m = {}
		for j = 0, 15 do
			m[j] = readLE(message, offset + j * 4)
		end

		local a, b, c, d = a0, b0, c0, d0

		for i = 0, 63 do
			local f, g
			if i < 16 then
				f = bor(band(b, c), band(bnot(b), d))
				g = i
			elseif i < 32 then
				f = bor(band(d, b), band(bnot(d), c))
				g = (5 * i + 1) % 16
			elseif i < 48 then
				f = bxor(bxor(b, c), d)
				g = (3 * i + 5) % 16
			else
				f = bxor(c, bor(b, bnot(d)))
				g = (7 * i) % 16
			end

			f = (f + a + MD5_K[i + 1] + m[g]) % MOD
			a = d
			d = c
			c = b
			b = (b + lrotate(f, MD5_SHIFT[i + 1])) % MOD
		end

		a0 = (a0 + a) % MOD
		b0 = (b0 + b) % MOD
		c0 = (c0 + c) % MOD
		d0 = (d0 + d) % MOD
	end

	return hex32LE(a0) .. hex32LE(b0) .. hex32LE(c0) .. hex32LE(d0)
end

--// SHA-1 //--

--[=[
	Expands one SHA-1 block into its message schedule.

	@param block The statement block to parse.
	@return The resulting list.
]=]
local function sha1Schedule(block: string): { number }
	local w = {}
	for i = 0, 15 do
		w[i] = readBE(block, i * 4 + 1)
	end
	for i = 16, 79 do
		w[i] = lrotate(bxor(bxor(w[i - 3], w[i - 8]), bxor(w[i - 14], w[i - 16])), 1)
	end
	return w
end

--[=[
	Computes the SHA-1 digest of a string.

	@param input The input to process.
	@return The resulting text.
]=]
function Hash.sha1(input: string): string
	local message = input
	local bitLength = #message * 8

	message ..= string.char(0x80)
	while #message % 64 ~= 56 do
		message ..= string.char(0)
	end
	message ..= wordBE(math.floor(bitLength / MOD) % MOD)
	message ..= wordBE(bitLength % MOD)

	local h0, h1, h2, h3, h4 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0

	for offset = 1, #message, 64 do
		local block = string.sub(message, offset, offset + 63)
		local w = sha1Schedule(block)

		local a, b, c, d, e = h0, h1, h2, h3, h4

		for i = 0, 79 do
			local f, k
			if i < 20 then
				f = bor(band(b, c), band(bnot(b), d))
				k = 0x5a827999
			elseif i < 40 then
				f = bxor(bxor(b, c), d)
				k = 0x6ed9eba1
			elseif i < 60 then
				f = bor(bor(band(b, c), band(b, d)), band(c, d))
				k = 0x8f1bbcdc
			else
				f = bxor(bxor(b, c), d)
				k = 0xca62c1d6
			end

			local temp = (lrotate(a, 5) + f + e + k + w[i]) % MOD
			e = d
			d = c
			c = lrotate(b, 30)
			b = a
			a = temp
		end

		h0 = (h0 + a) % MOD
		h1 = (h1 + b) % MOD
		h2 = (h2 + c) % MOD
		h3 = (h3 + d) % MOD
		h4 = (h4 + e) % MOD
	end

	return hex32(h0) .. hex32(h1) .. hex32(h2) .. hex32(h3) .. hex32(h4)
end

--// SHA-256 //--

local SHA256_K = {
	0x428a2f98,
	0x71374491,
	0xb5c0fbcf,
	0xe9b5dba5,
	0x3956c25b,
	0x59f111f1,
	0x923f82a4,
	0xab1c5ed5,
	0xd807aa98,
	0x12835b01,
	0x243185be,
	0x550c7dc3,
	0x72be5d74,
	0x80deb1fe,
	0x9bdc06a7,
	0xc19bf174,
	0xe49b69c1,
	0xefbe4786,
	0x0fc19dc6,
	0x240ca1cc,
	0x2de92c6f,
	0x4a7484aa,
	0x5cb0a9dc,
	0x76f988da,
	0x983e5152,
	0xa831c66d,
	0xb00327c8,
	0xbf597fc7,
	0xc6e00bf3,
	0xd5a79147,
	0x06ca6351,
	0x14292967,
	0x27b70a85,
	0x2e1b2138,
	0x4d2c6dfc,
	0x53380d13,
	0x650a7354,
	0x766a0abb,
	0x81c2c92e,
	0x92722c85,
	0xa2bfe8a1,
	0xa81a664b,
	0xc24b8b70,
	0xc76c51a3,
	0xd192e819,
	0xd6990624,
	0xf40e3585,
	0x106aa070,
	0x19a4c116,
	0x1e376c08,
	0x2748774c,
	0x34b0bcb5,
	0x391c0cb3,
	0x4ed8aa4a,
	0x5b9cca4f,
	0x682e6ff3,
	0x748f82ee,
	0x78a5636f,
	0x84c87814,
	0x8cc70208,
	0x90befffa,
	0xa4506ceb,
	0xbef9a3f7,
	0xc67178f2,
}

--[=[
	Computes the SHA-256 digest of a string.

	@param input The input to process.
	@return The resulting text.
]=]
function Hash.sha256(input: string): string
	local message = input
	local bitLength = #message * 8

	message ..= string.char(0x80)
	while #message % 64 ~= 56 do
		message ..= string.char(0)
	end
	message ..= wordBE(math.floor(bitLength / MOD) % MOD)
	message ..= wordBE(bitLength % MOD)

	local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
	local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

	for offset = 1, #message, 64 do
		local block = string.sub(message, offset, offset + 63)
		local w = {}

		for i = 0, 15 do
			w[i] = readBE(block, i * 4 + 1)
		end
		for i = 16, 63 do
			local s0 =
				bxor(bxor(rrotate(w[i - 15], 7), rrotate(w[i - 15], 18)), math.floor(w[i - 15] / 8))
			local s1 = bxor(
				bxor(rrotate(w[i - 2], 17), rrotate(w[i - 2], 19)),
				math.floor(w[i - 2] / 1024)
			)
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % MOD
		end

		local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7

		for i = 0, 63 do
			local s1 = bxor(bxor(rrotate(e, 6), rrotate(e, 11)), rrotate(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local temp1 = (h + s1 + ch + SHA256_K[i + 1] + w[i]) % MOD
			local s0 = bxor(bxor(rrotate(a, 2), rrotate(a, 13)), rrotate(a, 22))
			local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
			local temp2 = (s0 + maj) % MOD

			h = g
			g = f
			f = e
			e = (d + temp1) % MOD
			d = c
			c = b
			b = a
			a = (temp1 + temp2) % MOD
		end

		h0 = (h0 + a) % MOD
		h1 = (h1 + b) % MOD
		h2 = (h2 + c) % MOD
		h3 = (h3 + d) % MOD
		h4 = (h4 + e) % MOD
		h5 = (h5 + f) % MOD
		h6 = (h6 + g) % MOD
		h7 = (h7 + h) % MOD
	end

	return hex32(h0)
		.. hex32(h1)
		.. hex32(h2)
		.. hex32(h3)
		.. hex32(h4)
		.. hex32(h5)
		.. hex32(h6)
		.. hex32(h7)
end

return Hash
