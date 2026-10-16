local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if RunService:IsServer() then
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local function remote(name: string): RemoteEvent
	if RunService:IsServer() then
		local r = folder:FindFirstChild(name)
		if r and r:IsA("RemoteEvent") then
			return r
		end
		local ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = folder
		return ev
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return {
	CashUpdated = remote("CashUpdated"),
	InventoryUpdated = remote("InventoryUpdated"),
	SelectInventory = remote("SelectInventory"),
	EquipBest = remote("EquipBest"),
	RequestRebirth = remote("RequestRebirth"),
	RebirthUpdated = remote("RebirthUpdated"),
	DevSummon = remote("DevSummon"),
	DevSummonEvent = remote("DevSummonEvent"),
	KeyClick = remote("KeyClick"),
	KeyPress = remote("KeyPress"),
}
