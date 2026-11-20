return {
	Name = "blur",
	Permission = "Admin",
	Description = "Adds an Admin BlurEffect to Lighting for ambiance",
	Args = {
		{ Name = "Size", Type = "number", Description = "Blur size (0-56)", Default = 20 }
	},
	Run = function(context, size: number)
		local Lighting = game:GetService("Lighting")
		local existing = Lighting:FindFirstChild("AdminBlur")
		if existing then existing:Destroy() end
		local blur = Instance.new("BlurEffect")
		blur.Name = "AdminBlur"
		blur.Size = size
		blur.Parent = Lighting
		return `Blur effect applied (size {size})`
	end
}
