--!nocheck

-- Services
local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

-- Modules
local Types = require(RS.Modules.ManualLibraries.Types)
local Janitor = require(RS.Modules.ManualLibraries.Janitor)
local Signal = require(RS.Modules.ManualLibraries.Signal)

local DataModule = require(SS.Modules.Systems.DataModule)

-- Constants
local ARMOR_TAG = "%i-%s-EquippedArmor" -- player.UserId, armorType

-- Module
local InventoryServer = {}
InventoryServer.AllInventories = {}
InventoryServer.Janitors = {}
InventoryServer.HasLoaded = {}
InventoryServer.Respawning = {}
InventoryServer.ToolCanTouch = {}
InventoryServer.ToolCanCollide = {}

InventoryServer.MaxStackData = {
	Armor = 1,
	Weapon = 1,
	Special = 1,
	Consumable = 5,
	Resource = 99,
	Ability = 1,
}
InventoryServer.MaxStacks = 60

-- Start
function InventoryServer.Start()
	-- Player added
	for i, player: Player in Players:GetPlayers() do
		task.spawn(InventoryServer.OnPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(InventoryServer.OnPlayerAdded)

	-- Signal events
	Signal.ListenRemote("InventoryServer:GetInventoryData", InventoryServer.GetInventoryData)
	Signal.ListenRemote("InventoryServer:EquipToHotbar", InventoryServer.EquipToHotbar)
	Signal.ListenRemote("InventoryServer:UnequipFromHotbar", InventoryServer.UnequipFromHotbar)
	Signal.ListenRemote("InventoryServer:HoldItem", InventoryServer.HoldItem)
	Signal.ListenRemote("InventoryServer:UnholdItems", InventoryServer.UnholdItems)
	Signal.ListenRemote("InventoryServer:DropItem", InventoryServer.DropItem)
	Signal.ListenRemote("InventoryServer:EquipArmor", InventoryServer.EquipArmor)
	Signal.ListenRemote("InventoryServer:UnequipArmor", InventoryServer.UnequipArmor)
	Signal.ListenRemote("InventoryServer:EquipWeapon", InventoryServer.EquipWeapon)
	Signal.ListenRemote("InventoryServer:UnequipWeapon", InventoryServer.UnequipWeapon)

	-- Connecting post simulation
	RunService.PostSimulation:Connect(InventoryServer.OnPostSimulation)
end

-- Player added
function InventoryServer.OnPlayerAdded(player: Player)
	-- Waiting for starterpack
	for i, tool in StarterPack:GetChildren() do
		while not player.Backpack:FindFirstChild(tool.Name) do
			task.wait()
		end
	end

	-- Creating janitor object
	local janitor = Janitor.new()
	InventoryServer.Janitors[player] = janitor
	janitor:GiveChore(function()
		InventoryServer.Janitors[player] = nil
		InventoryServer.Respawning[player] = nil
	end)

	-- Waiting for character to load in the first time
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	InventoryServer.LoadData(player)

	-- Character added
	local function charAdded(char: Model)
		-- Registering items
		for i, tool in player.Backpack:GetChildren() do
			InventoryServer.RegisterItem(player, tool)
		end

		-- Connecting events
		char.ChildAdded:Connect(function(child: Instance)
			InventoryServer.RegisterItem(player, child)
		end)
		char.ChildRemoved:Connect(function(child: Instance)
			InventoryServer.UnregisterItem(player, child)
		end)

		player.Backpack.ChildAdded:Connect(function(child: Instance)
			InventoryServer.RegisterItem(player, child)
		end)
		player.Backpack.ChildRemoved:Connect(function(child: Instance)
			InventoryServer.UnregisterItem(player, child)
		end)

		-- On character death
		local hum: Humanoid = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			-- Unholding itesm and starting respawn
			InventoryServer.Respawning[player] = true
			InventoryServer.UnholdItems(player)

			-- Reparenting all items
			local allItems: { Tool } = player.Backpack:GetChildren()
			for i, item: Tool in allItems do
				item.Parent = script
			end

			-- Character respawning
			player.CharacterAdded:Wait()
			local backpack = player:WaitForChild("Backpack")

			-- Adding items back
			for i, item: Tool in allItems do
				item.Parent = backpack
			end

			InventoryServer.Respawning[player] = nil
		end)
	end

	-- Connecting character added
	task.spawn(charAdded, player.Character)
	janitor:GiveChore(player.CharacterAdded:Connect(charAdded))
end

-- Heartbeat loop
function InventoryServer.OnPostSimulation(dt: number)
	InventoryServer.UpdateDroppedItems()
end

-- Checking if inventory is full
function InventoryServer.CheckInventoryFull(player: Player, item: Tool)
	local inv = InventoryServer.AllInventories[player]
	if not inv then
		return true
	end -- Safety check

	if #inv.Inventory >= InventoryServer.MaxStacks then
		for i, stackData: Types.StackData in inv.Inventory do
			if stackData.Name == item.Name and #stackData.Items < InventoryServer.MaxStackData[stackData.ItemType] then
				return false
			end
		end
		return true
	end
	return false
end

-- Updating dropped items
function InventoryServer.UpdateDroppedItems()
	for i, tool: Tool in CS:GetTagged("ItemTool") do
		if not tool:IsDescendantOf(workspace) then
			continue
		end

		local handle = tool:FindFirstChild("Handle")
		if not handle then
			warn(`There was no handle found for tool {tool.Name}`)
			continue
		end
		local hum: Humanoid? = tool.Parent:FindFirstChild("Humanoid")
		local prompt: ProximityPrompt = handle:FindFirstChild("DroppedItemsPrompt")

		if hum then
			for i, part: BasePart in tool:GetDescendants() do
				if part:IsA("BasePart") then
					local prevValueTouch = InventoryServer.ToolCanTouch[part]
					if prevValueTouch ~= nil then
						part.CanTouch = prevValueTouch
						InventoryServer.ToolCanTouch[part] = nil
					end
					local prevValueCollide = InventoryServer.ToolCanCollide[part]
					if prevValueCollide ~= nil then
						part.CanCollide = prevValueCollide
						InventoryServer.ToolCanCollide[part] = nil
					end
				end
			end
			if prompt then
				prompt:Destroy()
			end
		else
			if not prompt then
				for i, part: BasePart in tool:GetDescendants() do
					if part:IsA("BasePart") then
						InventoryServer.ToolCanTouch[part] = part.CanTouch
						InventoryServer.ToolCanCollide[part] = part.CanCollide
						part.CanTouch = false
						part.CanCollide = true
					end
				end
				prompt = script.DroppedItemsPrompt:Clone()
				prompt.ObjectText = tool.Name
				prompt.Parent = handle

				prompt.Triggered:Connect(function(player: Player)
					if InventoryServer.CheckInventoryFull(player, tool) then
						warn(`{player.Name}'s inventory is full!`)
						Signal.FireClient(player, "InventoryClient:ErrorMessage", "Your inventory is full!")
						return
					end
					local backpack: Backpack = player:FindFirstChild("Backpack")
					if not backpack then
						return
					end
					tool.Parent = backpack
				end)
			end
		end
	end
end

-- Registering new items
function InventoryServer.RegisterItem(player: Player, tool: Tool)
	if tool.ClassName ~= "Tool" then
		return
	end
	if InventoryServer.Respawning[player] then
		return
	end

	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	if not inv then
		return
	end

	for i, stackData: Types.StackData in inv.Inventory do
		if table.find(stackData.Items, tool) then
			return
		end
	end

	local foundStack: Types.StackData = nil
	for i, stackData: Types.StackData in inv.Inventory do
		if stackData.Name == tool.Name and #stackData.Items < InventoryServer.MaxStackData[stackData.ItemType] then
			table.insert(stackData.Items, tool)
			foundStack = stackData
			break
		end
	end

	if not foundStack then
		if #inv.Inventory < InventoryServer.MaxStacks then
			local stack: Types.StackData = {
				Name = tool.Name,
				Description = tool.ToolTip,
				Image = tool.TextureId,
				ItemType = tool:GetAttribute("ItemType"),
				IsDroppable = tool:GetAttribute("IsDroppable"),
				Items = { tool },
				StackId = inv.NextStackId,
			}
			inv.NextStackId += 1
			table.insert(inv.Inventory, stack)

			if stack.ItemType == "Armor" then
				local armorType = stack.Items[1]:GetAttribute("ArmorType")
				if inv.Armor[armorType] == nil then
					InventoryServer.EquipArmor(player, stack.StackId)
				end
			else
				for slotNum: number = 1, 10 do
					if inv.Hotbar["Slot" .. slotNum] == nil then
						InventoryServer.EquipToHotbar(player, slotNum, stack.StackId)
						break
					end
				end
			end
		end
	end

	Signal.FireClient(player, "InventoryClient:Update", inv)
	InventoryServer.SaveData(player)
end

-- Unregistering items
function InventoryServer.UnregisterItem(player: Player, tool: Tool)
	if tool.ClassName ~= "Tool" then
		return
	end
	if tool.Parent == player.Backpack or (player.Character ~= nil and tool.Parent == player.Character) then
		return
	end
	if InventoryServer.Respawning[player] then
		return
	end

	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	if not inv then
		return
	end

	for i, stackData: Types.StackData in inv.Inventory do
		local found: number = table.find(stackData.Items, tool)
		if found then
			table.remove(stackData.Items, found)
			if #stackData.Items == 0 then
				local stackFound: number = table.find(inv.Inventory, stackData)
				if stackFound then
					table.remove(inv.Inventory, stackFound)
					InventoryServer.UnequipFromHotbar(player, stackData.StackId)
					InventoryServer.UnequipArmor(player, stackData.StackId)
				end
			end
		end
	end

	Signal.FireClient(player, "InventoryClient:Update", inv)
	InventoryServer.SaveData(player)
end

-- Equipping item to hotbar
function InventoryServer.EquipToHotbar(player: Player, equipTo: number, stackId: number)
	if InventoryServer.Respawning[player] then
		return
	end
	local inv: Types.Inventory = InventoryServer.AllInventories[player]

	InventoryServer.UnequipFromHotbar(player, stackId)

	local isValid: boolean = false
	for i, stackData: Types.StackData in inv.Inventory do
		if stackData.StackId == stackId and stackData.ItemType ~= "Armor" then
			isValid = true
		end
	end
	if isValid == false then
		return
	end

	inv.Hotbar["Slot" .. equipTo] = stackId
	Signal.FireClient(player, "InventoryClient:Update", inv)
	InventoryServer.SaveData(player)
end

-- Unequipping item from hotbar
function InventoryServer.UnequipFromHotbar(player: Player, stackId: number)
	if InventoryServer.Respawning[player] then
		return
	end
	local inv: Types.Inventory = InventoryServer.AllInventories[player]

	for slotKey: string, equippedId: number in inv.Hotbar do
		if equippedId == stackId then
			inv.Hotbar[slotKey] = nil
		end
	end
	Signal.FireClient(player, "InventoryClient:Update", inv)
	InventoryServer.SaveData(player)
end

-- Equipping armor
function InventoryServer.EquipArmor(player: Player, stackId: number): boolean?
	if InventoryServer.Respawning[player] then
		return
	end

	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	local stackData: Types.StackData = InventoryServer.FindStackDataFromId(player, stackId)
	if not stackData then
		return
	end
	if stackData.ItemType ~= "Armor" then
		return
	end

	local char = player.Character
	if not char then
		return
	end
	local armorType = stackData.Items[1]:GetAttribute("ArmorType")
	if not armorType then
		return
	end
	inv.Armor[armorType] = stackId

	InventoryServer.ClearArmor(player, armorType)

	local tag = ARMOR_TAG:format(player.UserId, armorType)
	local armorModel: Model = SS.ArmorModels:FindFirstChild(stackData.Name)

	if armorModel then
		local clone = armorModel:Clone()
		clone:AddTag(tag)
		clone.Parent = char
		for i, partModel: Model in clone:GetChildren() do
			local bodyPart: BasePart = char:FindFirstChild(partModel.Name)
			if bodyPart then
				local weld = Instance.new("Weld")
				weld.Parent = bodyPart
				weld.Part0 = bodyPart
				weld.Part1 = partModel.PrimaryPart
			else
				warn(`The armor model {clone.Name} has body part model {partModel.Name}, but no body part was found.`)
			end
		end
	end

	Signal.FireClient(player, "InventoryClient:Update", inv)
	InventoryServer.UpdateArmorStats(player)
	InventoryServer.SaveData(player)
	return true
end

-- Unequipping armor
function InventoryServer.UnequipArmor(player: Player, stackId: number)
	if InventoryServer.Respawning[player] then
		return
	end
	local inv: Types.Inventory = InventoryServer.AllInventories[player]

	for armorType, otherStackId in inv.Armor do
		if stackId == otherStackId then
			inv.Armor[armorType] = nil
			InventoryServer.ClearArmor(player, armorType)
		end
	end

	Signal.FireClient(player, "InventoryClient:Update", inv)
	InventoryServer.UpdateArmorStats(player)
	InventoryServer.SaveData(player)
end

-- Updating armor stats
function InventoryServer.UpdateArmorStats(player: Player)
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	local totalHealthBuff: number = 0

	for armorType: string, stackId: number in inv.Armor do
		if stackId == nil then
			continue
		end
		local stackData: Types.StackData = InventoryServer.FindStackDataFromId(player, stackId)
		if not stackData then
			continue
		end

		local healthBuff = stackData.Items[1]:GetAttribute("HealthBuff")
		if healthBuff ~= nil then
			totalHealthBuff += healthBuff
		end
	end

	local char = player.Character
	if not char then
		return
	end
	local hum = char:FindFirstChild("Humanoid")
	if not hum then
		return
	end

	local currentHealthPerc = hum.Health / hum.MaxHealth
	hum.MaxHealth = 100 + totalHealthBuff
	hum.Health = hum.MaxHealth * currentHealthPerc
end

-- Clearing armor models
function InventoryServer.ClearArmor(player: Player, armorType)
	local tag = ARMOR_TAG:format(player.UserId, armorType)
	for i, obj in CS:GetTagged(tag) do
		obj:Destroy()
	end
end

-- Equipping weapon
function InventoryServer.EquipWeapon(player: Player, stackId: number): boolean?
	if InventoryServer.Respawning[player] then
		return
	end

	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	local stackData: Types.StackData = InventoryServer.FindStackDataFromId(player, stackId)
	if not stackData then
		return
	end
	if stackData.ItemType ~= "Weapon" then
		return
	end

	local weaponType = stackData.Items[1]:GetAttribute("WeaponType")
	if not weaponType then
		return
	end

	-- Unequip any existing weapon in this slot
	if inv.Weapons[weaponType] then
		InventoryServer.UnequipWeapon(player, inv.Weapons[weaponType])
	end

	inv.Weapons[weaponType] = stackId

	-- Also equip to hotbar (find first available slot or replace existing)
	local hotbarSlot
	for i = 1, 8 do
		local slotName = "Slot" .. i
		local currentStackId = inv.Hotbar[slotName]
		if currentStackId == stackId then
			hotbarSlot = i
			break
		elseif not currentStackId then
			hotbarSlot = i
			break
		end
	end

	if hotbarSlot then
		inv.Hotbar["Slot" .. hotbarSlot] = stackId
	end

	Signal.FireClient(player, "InventoryClient:Update", inv)
	InventoryServer.SaveData(player)
	return true
end

-- Unequipping weapon
function InventoryServer.UnequipWeapon(player: Player, stackId: number)
	if InventoryServer.Respawning[player] then
		return
	end
	local inv: Types.Inventory = InventoryServer.AllInventories[player]

	for weaponType, otherStackId in inv.Weapons do
		if stackId == otherStackId then
			inv.Weapons[weaponType] = nil
			-- Also unequip from hotbar
			for slotKey, equippedId in inv.Hotbar do
				if equippedId == stackId then
					inv.Hotbar[slotKey] = nil
				end
			end
		end
	end

	Signal.FireClient(player, "InventoryClient:Update", inv)
	InventoryServer.SaveData(player)
end

-- Finding stack data from ID
function InventoryServer.FindStackDataFromId(player: Player, stackId: number)
	if stackId == nil then
		return
	end
	local inv = InventoryServer.AllInventories[player]
	if not inv then
		return
	end

	for i, stackData: Types.StackData in inv.Inventory do
		if stackData.StackId == stackId then
			return stackData
		end
	end
end

-- Dropping items
function InventoryServer.DropItem(player: Player, stackId: number): boolean?
	if InventoryServer.Respawning[player] then
		return
	end
	local stackData: Types.StackData = InventoryServer.FindStackDataFromId(player, stackId)
	if not stackData then
		return
	end
	if not stackData.IsDroppable then
		return false
	end

	local char: Model = player.Character
	if not char then
		return
	end
	local root: BasePart = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local toolToDrop = stackData.Items[1]
	toolToDrop:PivotTo(root.CFrame * CFrame.new(0, 0, -3))
	toolToDrop.Parent = workspace
	return true
end

-- Holding item
function InventoryServer.HoldItem(player: Player, slotNum: number)
	if InventoryServer.Respawning[player] then
		return
	end
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	local stackData: Types.StackData? = nil
	for slotKey: string, stackId: number in inv.Hotbar do
		if slotKey == "Slot" .. slotNum then
			stackData = InventoryServer.FindStackDataFromId(player, stackId)
			break
		end
	end

	InventoryServer.UnholdItems(player)
	if stackData ~= nil then
		local tool: Tool = stackData.Items[1]
		if not player.Character then
			return
		end
		tool.Parent = player.Character
		Signal.FireClient(player, "InventoryClient:Update", inv)
	end
end

-- Unholding items
function InventoryServer.UnholdItems(player: Player)
	if InventoryServer.Respawning[player] then
		return
	end
	local char: Model = player.Character
	if not char then
		return
	end
	local hum: Humanoid = char:FindFirstChild("Humanoid")
	if not hum then
		return
	end
	hum:UnequipTools()
	Signal.FireClient(player, "InventoryClient:Update", InventoryServer.AllInventories[player])
end

-- Getting inventory data
function InventoryServer.GetInventoryData(player: Player)
	while not InventoryServer.AllInventories[player] do
		task.wait()
	end
	return InventoryServer.AllInventories[player]
end

function InventoryServer.SaveData(player: Player)
	if InventoryServer.HasLoaded[player] ~= true then
		return
	end

	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	if not inv then
		return
	end

	-- Pack the live instances into a format safe for Datastores
	local modifiedInv = {
		Inventory = {},
		Hotbar = inv.Hotbar,
		Armor = inv.Armor,
		Weapons = inv.Weapons,
		NextStackId = inv.NextStackId,
	}

	for i, stackData in inv.Inventory do
		table.insert(modifiedInv.Inventory, {
			Name = stackData.Name,
			Count = #stackData.Items,
			StackId = stackData.StackId,
		})
	end
	DataModule.UpdateCategory(player, "Inventory", modifiedInv)
end

function InventoryServer.LoadData(player: Player)
	print("[INVENTORY] Waiting for ProfileService Session for: " .. player.Name)

	while not DataModule.GetSession(player) do
		task.wait(0.2)
	end

	print("[INVENTORY] Session found. Loading inventory data...")

	-- Pull the specific slot's inventory from DataModule
	local savedData = DataModule.GetCategory(player, "Inventory")

	-- Initialize the Active Inventory State
	local inv: Types.Inventory = {
		Inventory = {},
		Hotbar = savedData.Hotbar or {},
		Armor = savedData.Armor or {},
		Weapons = savedData.Weapons or {},
		NextStackId = savedData.NextStackId or 0,
	}

	local char: Model = player.Character or player.CharacterAdded:Wait()
	local backpack: Backpack = player:WaitForChild("Backpack")

	-- Reconstruct items from strings back to physical Tools
	if savedData.Inventory then
		for i, savedStack in savedData.Inventory do
			local sample: Tool = SS.AllItems:FindFirstChild(savedStack.Name)
			if not sample then
				warn("No item sample was found in ServerStorage.AllItems for " .. savedStack.Name)
				continue
			end

			local stack: Types.StackData = {
				Name = savedStack.Name,
				Description = sample.ToolTip,
				Image = sample.TextureId,
				ItemType = sample:GetAttribute("ItemType"),
				IsDroppable = sample:GetAttribute("IsDroppable"),
				Items = {},
				StackId = savedStack.StackId,
			}

			for i = 1, savedStack.Count do
				local clone = sample:Clone()
				clone.Parent = backpack
				table.insert(stack.Items, clone)
			end

			table.insert(inv.Inventory, stack)
		end
	end

	InventoryServer.AllInventories[player] = inv
	InventoryServer.HasLoaded[player] = true

	if InventoryServer.Janitors[player] then
		InventoryServer.Janitors[player]:GiveChore(function()
			InventoryServer.HasLoaded[player] = nil
		end)
	end

	-- Adding armor models
	for armorType, stackId in inv.Armor do
		InventoryServer.EquipArmor(player, stackId)
	end

	Signal.FireClient(player, "InventoryClient:Update", InventoryServer.AllInventories[player])
	print("[INVENTORY] Finished loading the data of " .. player.Name)
end

return InventoryServer
