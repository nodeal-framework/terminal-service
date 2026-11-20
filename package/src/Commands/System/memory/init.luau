return {
	Name = "memory",
	Aliases = { "mem" },
	Description = "Shows server memory usage (Luau managed heap)",
	Run = function(context)
		local ok, kbytes = pcall(gcinfo)
		if not ok then return "Memory info unavailable in this environment" end
		return string.format("Memory: %d KB (%.2f MB)", kbytes, kbytes / 1024)
	end
}
