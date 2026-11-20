return {
	Name = "size",
	Permission = "Admin",
	Description = "Scales a player's character (body depth/height/width + head). Requires R15 avatars",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Multiplier", Type = "number", Description = "Scale multiplier (positive)", Default = 1 }
	},
	Run = function(context, target, mult)
		local char = target.Character
		if not char then
			context:Error(`{target.Name} has no character`)
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then
			context:Error(`{target.Name} has no Humanoid`)
			return
		end
		if mult <= 0 then
			context:Error("Scale must be positive")
			return
		end
		local scaleFound = false
		for _, name in { "BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale" } do
			local num = hum:FindFirstChild(name)
			if num and num:IsA("NumberValue") then
				num.Value = mult
				scaleFound = true
			end
		end
		if not scaleFound then
			context:Error(`{target.Name} has no scale NumberValues (size requires R15 avatars)`)
			return
		end
		return `Scaled {target.Name} to {mult}x`
	end
}
