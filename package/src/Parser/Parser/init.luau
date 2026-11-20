--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

local Parser = {}

type CommandNode = {
	type: "Command",
	name: string,
	args: {string}
}

type RedirectNode = {
	type: "Redirect",
	command: ASTNode,
	target: string
}

type PipelineNode = {
	type: "Pipeline",
	left: ASTNode,
	right: ASTNode
}

type LogicalNode = {
	type: "Logical",
	op: ";",
	left: ASTNode,
	right: ASTNode
}

export type ASTNode = CommandNode | RedirectNode | PipelineNode | LogicalNode

local function subArray(t: {string}, startIdx: number, endIdx: number): {string}
	local sub = {}
	for i = startIdx, endIdx do
		table.insert(sub, t[i])
	end
	return sub
end

local parseLogicalChain, parsePipelineChain, parseRedirectChain, parseCommand

function parseCommand(tokens: {string}, startIdx: number, endIdx: number): ASTNode?
	if startIdx > endIdx then return nil end
	return {
		type = "Command",
		name = tokens[startIdx],
		args = subArray(tokens, startIdx + 1, endIdx)
	} :: CommandNode
end

function parseRedirectChain(tokens: {string}, startIdx: number, endIdx: number): ASTNode?
	for i = endIdx, startIdx, -1 do
		if tokens[i] == ">" then
			local leftNode = parseRedirectChain(tokens, startIdx, i - 1)
			local target = tokens[i + 1] or ""
			return {
				type = "Redirect",
				command = leftNode,
				target = target
			} :: RedirectNode
		end
	end
	return parseCommand(tokens, startIdx, endIdx)
end

function parsePipelineChain(tokens: {string}, startIdx: number, endIdx: number): ASTNode?
	for i = endIdx, startIdx, -1 do
		if tokens[i] == "|" then
			local leftNode = parsePipelineChain(tokens, startIdx, i - 1)
			local rightNode = parseRedirectChain(tokens, i + 1, endIdx)
			return {
				type = "Pipeline",
				left = leftNode,
				right = rightNode
			} :: PipelineNode
		end
	end
	return parseRedirectChain(tokens, startIdx, endIdx)
end

function parseLogicalChain(tokens: {string}, startIdx: number, endIdx: number): ASTNode?
	for i = endIdx, startIdx, -1 do
		local tok = tokens[i]
		if tok == ";" or tok == "&&" or tok == "||" then
			local leftNode = parseLogicalChain(tokens, startIdx, i - 1)
			local rightNode = parsePipelineChain(tokens, i + 1, endIdx)
			return {
				type = "Logical",
				op = tok,
				left = leftNode,
				right = rightNode
			} :: LogicalNode
		end
	end
	return parsePipelineChain(tokens, startIdx, endIdx)
end

--[=[
	Parses a list of expanded tokens into an Abstract Syntax Tree (AST).
	Returns the root ASTNode of the command line.
]=]
function Parser.parse(tokens: {string}): ASTNode?
	if #tokens == 0 then return nil end
	return parseLogicalChain(tokens, 1, #tokens)
end

return Parser
