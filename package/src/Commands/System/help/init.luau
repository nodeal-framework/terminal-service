local Help = {}

Help.Name = "help"
Help.Permission = "Any"
Help.Aliases = { "man", "?" }
Help.Description = "Lists all commands grouped by category or shows detailed usage for a specific command"
Help.Args = {
	{ Name = "Command", Type = "command", Description = "Command name to get details", Optional = true }
}

function Help.Run(context, commandName: string?)
	local TerminalService = context.Terminal
	if not commandName then
		local byCategory = {}
		for _, cmd in TerminalService:GetCommands() do
			local cat = cmd.Category or "Other"
			if not byCategory[cat] then byCategory[cat] = {} end
			table.insert(byCategory[cat], cmd)
		end

		local list = { "Available Commands:" }
		local sortedCats = {}
		for cat in byCategory do table.insert(sortedCats, cat) end
		table.sort(sortedCats)

		for _, cat in sortedCats do
			table.insert(list, "")
			table.insert(list, `  [{cat}]`)
			local sorted = {}
			for _, c in byCategory[cat] do table.insert(sorted, c) end
			table.sort(sorted, function(a, b) return a.Name < b.Name end)
			for _, c in sorted do
				local aliasText = (#c.Aliases > 0) and ` (aliases: {table.concat(c.Aliases, ", ")})` or ""
				table.insert(list, `    {c.Name}{aliasText} - {c.Description}`)
			end
		end

		table.insert(list, "")
		table.insert(list, "Tip: Use '` <player>' to redirect stdout to a player's terminal.")
		table.insert(list, "Tip: Pipe commands with '|', chain with ';', '&&', '||'.")
		return table.concat(list, "\n")
	end

	local cmd = TerminalService:GetCommand(commandName)
	if not cmd then
		return `Command '{commandName}' not found.`
	end

	local detail = {
		`Command: {cmd.Name}`,
		`Category: {cmd.Category or "Other"}`,
		`Description: {cmd.Description}`
	}

	if #cmd.Aliases > 0 then
		table.insert(detail, `Aliases: {table.concat(cmd.Aliases, ", ")}`)
	end

	if cmd.Permission and cmd.Permission ~= "Any" then
		table.insert(detail, `Permission: {cmd.Permission}`)
	end

	if #cmd.Args > 0 then
		table.insert(detail, "Arguments:")
		for _, argSpec in cmd.Args do
			local reqText = argSpec.Optional and "[Optional]" or "[Required]"
			local defaultText = argSpec.Default ~= nil and ` (Default: {tostring(argSpec.Default)})` or ""
			table.insert(detail, `  * {argSpec.Name} ({argSpec.Type}) {reqText}{defaultText} - {argSpec.Description or ""}`)
		end
	else
		table.insert(detail, "Arguments: None")
	end

	return table.concat(detail, "\n")
end

return Help
