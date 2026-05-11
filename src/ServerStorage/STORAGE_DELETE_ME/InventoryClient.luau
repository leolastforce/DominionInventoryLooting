--!nocheck
-- Services
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")
local TS = game:GetService("TweenService")

-- Libraries
local Janitor = require(RS.Modules.ManualLibraries.Janitor)
local Signal = require(RS.Modules.ManualLibraries.Signal)
local Types = require(RS.Modules.ManualLibraries.Types)

-- Player variables
local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- Gui variables
local guiHud = playerGui:WaitForChild("HUD")
local guiMenu = playerGui:WaitForChild("Menu")
local guiSystem = playerGui:WaitForChild("System")

export type HotbarSlotButton = TextButton & { ItemCount: TextLabel, Image: ImageLabel }
export type InventoryItemButton = TextButton & { ItemCount: TextLabel, Image: ImageLabel, Equipped: Frame }

local hotbarF = guiHud:WaitForChild("Hotbar")
local invF = guiMenu:WaitForChild("Inventory"):WaitForChild("Inventory")
invF.Visible = false
local errorT = guiSystem:WaitForChild("Error")
errorT.Visible = false

local infoF = invF:WaitForChild("ItemInfo")
infoF.Visible = false
local itemNameT = infoF:WaitForChild("ItemName")
local itemDescT = infoF:WaitForChild("ItemDesc")
local itemImageF = infoF:WaitForChild("Image")
local equipB = infoF:WaitForChild("Equip")
local dropB = infoF:WaitForChild("Drop")
local instructT = infoF:WaitForChild("Instructions")
instructT.Visible = false

local itemsSF = invF:WaitForChild("ItemsScroll")
local itemSample = itemsSF:WaitForChild("UIGridLayout"):WaitForChild("Sample") :: InventoryItemButton
itemSample.Visible = false

local EquipmentF = invF:WaitForChild("Equipment")
local armorF = EquipmentF:WaitForChild("Armor")
local weaponF = EquipmentF:WaitForChild("Weapons")

local attributeF = infoF:WaitForChild("AttributeInfo")
local itemTypeT = attributeF:WaitForChild("ItemType"):WaitForChild("ItemTypeLabel")
local sellPriceT = attributeF:WaitForChild("SellPrice"):WaitForChild("SellValueLabel")
local RarityT = attributeF:WaitForChild("Rarity"):WaitForChild("RarityLabel")
local RarityF = attributeF:WaitForChild("Rarity")

UIStrokeRarity = RarityF:WaitForChild("UIStroke")

local hotbarSlots: { HotbarSlotButton } = {
	hotbarF.Slot1 :: HotbarSlotButton,
	hotbarF.Slot2 :: HotbarSlotButton,
	hotbarF.Slot3 :: HotbarSlotButton,
	hotbarF.Slot4 :: HotbarSlotButton,
	hotbarF.Slot5 :: HotbarSlotButton,
	hotbarF.Slot6 :: HotbarSlotButton,
	hotbarF.Slot7 :: HotbarSlotButton,
	hotbarF.Slot8 :: HotbarSlotButton,
}
local keysToSlots: { [Enum.KeyCode]: HotbarSlotButton } = {
	[Enum.KeyCode.One] = hotbarF.Slot1 :: HotbarSlotButton,
	[Enum.KeyCode.Two] = hotbarF.Slot2 :: HotbarSlotButton,
	[Enum.KeyCode.Three] = hotbarF.Slot3 :: HotbarSlotButton,
	[Enum.KeyCode.Four] = hotbarF.Slot4 :: HotbarSlotButton,
	[Enum.KeyCode.Five] = hotbarF.Slot5 :: HotbarSlotButton,
	[Enum.KeyCode.Six] = hotbarF.Slot6 :: HotbarSlotButton,
	[Enum.KeyCode.Seven] = hotbarF.Slot7 :: HotbarSlotButton,
	[Enum.KeyCode.Eight] = hotbarF.Slot8 :: HotbarSlotButton,
}
local armorSlots = {
	Head = armorF.Head,
	Body = armorF.Body,
	Leggings = armorF.Leggings,
	Backpack = armorF.Backpack,
}
local weaponSlots = {
	PrimaryGun = weaponF.PrimaryGun,
	SecondaryGun = weaponF.SecondaryGun,
}

-- Store armor slot connections to avoid duplicate event listeners
local armorSlotConnections = {}

-- Module
local InventoryClient = {}
InventoryClient.OpenPosition = invF.Position
InventoryClient.ClosePosition = invF.Position + UDim2.fromScale(0, 1)
InventoryClient.OpenCloseDb = false
InventoryClient.IsOpen = false

InventoryClient.ErrorDb = false
InventoryClient.ErrorPosition = errorT.Position
InventoryClient.ErrorTime = 2

InventoryClient.InvData = nil
InventoryClient.SelectedStackId = nil
InventoryClient.UpdatingDb = false

InventoryClient.EquipInstructText = instructT.Text
InventoryClient.HeldSlotNum = nil

-- Drag and drop variables
InventoryClient.IsDragging = false
InventoryClient.DragItem = nil

-- Starting
function InventoryClient.Start()
	-- Disabling default backpack
	SG:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	SG:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

	-- Updating inventory
	InventoryClient.UpdateInventoryData()
	InventoryClient.UpdateDisplay()
	InventoryClient.UpdateHeldItem()

	-- Connecting signals
	Signal.ListenRemote("InventoryClient:Update", function(newInvData: Types.Inventory)
		InventoryClient.InvData = newInvData
		InventoryClient.UpdateDisplay()
		InventoryClient.UpdateHeldItem()
	end)
	Signal.ListenRemote("InventoryClient:ErrorMessage", InventoryClient.ErrorMessage)

	-- Open/close
	UIS.InputBegan:Connect(InventoryClient.OnInputBegan)
	UIS.InputChanged:Connect(InventoryClient.OnInputChanged)

	-- Connecting buttons
	equipB.MouseButton1Click:Connect(InventoryClient.OnEquipButton)
	dropB.MouseButton1Click:Connect(InventoryClient.OnDropButton)

	-- Connecting slot buttons
	for i, slotF: TextButton in hotbarSlots do
		slotF.MouseButton1Click:Connect(function()
			InventoryClient.ToggleHold(i)
		end)
	end
end

--Remove me
function InventoryClient.PrintFunction() end

-- Input began
function InventoryClient.OnInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	-- Open / close
	if input.KeyCode == Enum.KeyCode.Tab then
		InventoryClient.SetWindowOpen(not InventoryClient.IsOpen)
	end

	-- Holster weapon (H key)
	if input.KeyCode == Enum.KeyCode.H then
		InventoryClient.ToggleHolster()
	end

	-- Equipping slots
	for key: Enum.KeyCode, slotF: HotbarSlotButton in keysToSlots do
		if input.KeyCode == key then
			local slotIndex: number? = table.find(hotbarSlots, slotF)
			InventoryClient.ToggleHold(slotIndex)
			break
		end
	end
end

-- Input changed (for mouse wheel)
function InventoryClient.OnInputChanged(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseWheel then
		InventoryClient.CycleWeapons(input.Position.Z > 0)
	end
end

-- Opening and closing
function InventoryClient.SetWindowOpen(toSet: boolean)
	if InventoryClient.OpenCloseDb then
		return
	end
	InventoryClient.OpenCloseDb = true

	-- Checking toSet
	if toSet == true then
		invF.Position = InventoryClient.ClosePosition
		invF.Visible = true
		invF:TweenPosition(InventoryClient.OpenPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0)
		task.wait(0.1)
		InventoryClient.IsOpen = true
	else
		invF:TweenPosition(InventoryClient.ClosePosition, Enum.EasingDirection.In, Enum.EasingStyle.Quart, 0)
		task.wait(0.1)
		invF.Visible = false
		InventoryClient.IsOpen = false
	end

	InventoryClient.OpenCloseDb = false
end

-- Equip button
function InventoryClient.OnEquipButton()
	--Equipping And Unequipping Sound
	local ArmorEquipSound = script.ArmorEquip
	local ArmorUnequipSound = script.ArmorUnequip

	-- Finding stack data
	local stackData = InventoryClient.FindStackDataFromId(InventoryClient.SelectedStackId)

	-- Checking button mode
	if equipB.Text == "Equip" and stackData ~= nil then
		-- Instructions
		local tempJanitor = Janitor.new()
		instructT.Visible = true
		tempJanitor:GiveChore(function()
			instructT.Visible = false
		end)
		equipB.Text = "Equipping.."
		tempJanitor:GiveChore(function()
			equipB.Text = "Equip"
		end)

		-- Checking item type
		if stackData.ItemType == "Armor" then
			tempJanitor:Clean()

			-- Equipping to armor slot
			local success = Signal.InvokeServer("InventoryServer:EquipArmor", stackData.StackId)
			ArmorEquipSound:Play()

			if not success then
				InventoryClient.ErrorMessage("Something went wrong while equipping armor!")
				return
			end
		elseif stackData.ItemType == "Weapon" then
			tempJanitor:Clean()

			-- Equipping to weapon slot
			local success = Signal.InvokeServer("InventoryServer:EquipWeapon", stackData.StackId)

			if not success then
				InventoryClient.ErrorMessage("Something went wrong while equipping weapon!")
				return
			end
		else
			-- Variables
			local chosenSlot: HotbarSlotButton? = nil
			local slotNum: number? = nil

			-- Keyboard inputs
			tempJanitor:GiveChore(UIS.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
				if gameProcessedEvent then
					return
				end
				if input.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end

				-- Selecting slot
				for key: Enum.KeyCode, slotF: HotbarSlotButton in keysToSlots do
					if input.KeyCode == key then
						chosenSlot = slotF
						tempJanitor:Clean()
						return
					end
				end
				-- Canceling
				instructT.Text = "Error: Not a valid key"
				tempJanitor:GiveChore(function()
					instructT.Text = InventoryClient.EquipInstructText
				end)
				task.wait(2)
				tempJanitor:Clean()
			end))

			-- Button presses
			for i, slotF: HotbarSlotButton in hotbarSlots do
				tempJanitor:GiveChore(slotF.MouseButton1Click:Connect(function()
					chosenSlot = slotF
					slotNum = i
					tempJanitor:Clean()
				end))
			end

			-- Waiting for selection
			while chosenSlot == nil do
				task.wait()
			end

			if slotNum == nil and chosenSlot ~= nil then
				slotNum = table.find(hotbarSlots, chosenSlot)
			end

			if slotNum == nil then
				InventoryClient.ErrorMessage("Unable to find selected hotbar slot.")
				return
			end

			-- Equipping
			Signal.FireServer("InventoryServer:EquipToHotbar", slotNum, stackData.StackId)
		end
	elseif equipB.Text == "Unequip" and stackData ~= nil then
		if stackData.ItemType == "Armor" then
			Signal.FireServer("InventoryServer:UnequipArmor", InventoryClient.SelectedStackId)
			ArmorUnequipSound:Play()
		elseif stackData.ItemType == "Weapon" then
			Signal.FireServer("InventoryServer:UnequipWeapon", InventoryClient.SelectedStackId)
		else
			Signal.FireServer("InventoryServer:UnequipFromHotbar", InventoryClient.SelectedStackId)
		end
	end
end

-- Drop button
function InventoryClient.OnDropButton()
	if InventoryClient.SelectedStackId == nil then
		return
	end

	-- Dropping item
	local success: boolean = Signal.InvokeServer("InventoryServer:DropItem", InventoryClient.SelectedStackId)
	if success == nil then
		InventoryClient.ErrorMessage("Something went wrong!")
	elseif success == false then
		InventoryClient.ErrorMessage("You can't drop that item!")
	end
end

-- Setting equip/unequip button
function InventoryClient.SetEquipButton(toSet: boolean)
	if toSet == true then
		equipB.Text = "Equip"
		equipB.BackgroundColor3 = equipB:GetAttribute("EquipColor") :: Color3
	else
		equipB.Text = "Unequip"
		equipB.BackgroundColor3 = equipB:GetAttribute("UnequipColor") :: Color3
	end
end

-- Toggling held item
function InventoryClient.ToggleHold(slotNum: number?)
	if slotNum == nil then
		return
	end
	if InventoryClient.HeldSlotNum == slotNum then
		Signal.FireServer("InventoryServer:UnholdItems")
	else
		Signal.FireServer("InventoryServer:HoldItem", slotNum)
	end
end

-- Update held item
function InventoryClient.UpdateHeldItem()
	-- Character variables
	local char: Model? = player.Character
	if not char then
		return
	end
	local tool: Tool? = char:FindFirstChildOfClass("Tool")

	-- If there's a tool
	if tool then
		-- Finding slot number
		local slotNum: number? = nil
		for i = 1, #hotbarSlots do
			local stackId: number? = InventoryClient.InvData.Hotbar["Slot" .. i]
			local stackData: Types.StackData? = if stackId ~= nil
				then InventoryClient.FindStackDataFromId(stackId)
				else nil
			if stackData ~= nil and table.find(stackData.Items, tool) then
				slotNum = i
				break
			end
		end

		-- Updating
		if slotNum ~= nil then
			InventoryClient.HeldSlotNum = slotNum
			local slotF: HotbarSlotButton = hotbarSlots[slotNum]
			for i, otherSlotF: HotbarSlotButton in hotbarSlots do
				if (otherSlotF :: TextButton) == (slotF :: TextButton) then
					otherSlotF.BackgroundColor3 = otherSlotF:GetAttribute("SelectedColor") :: Color3
				else
					otherSlotF.BackgroundColor3 = otherSlotF:GetAttribute("NormalColor") :: Color3
				end
			end
		else
			InventoryClient.HeldSlotNum = nil
			Signal.FireServer("InventoryServer:UnholdItems")
		end
	else
		-- Setting all slots back to normal
		for i, slotF: HotbarSlotButton in hotbarSlots do
			slotF.BackgroundColor3 = slotF:GetAttribute("NormalColor") :: Color3
		end
		InventoryClient.HeldSlotNum = nil
	end
end

-- Checking if an item is currently equipped
function InventoryClient.CheckItemEquipped(stackData: Types.StackData): boolean
	if stackData.ItemType == "Armor" then
		for armorType: string, stackId: number in InventoryClient.InvData.Armor do
			if stackId == stackData.StackId then
				return true
			end
		end
		return false
	elseif stackData.ItemType == "Weapon" then
		for weaponType: string, stackId: number in InventoryClient.InvData.Weapons do
			if stackId == stackData.StackId then
				return true
			end
		end
		return false
	else
		for slotKey: string, stackId: number in InventoryClient.InvData.Hotbar do
			if stackId == stackData.StackId then
				return true
			end
		end
		return false
	end
end

-- Updating inventory data
function InventoryClient.UpdateInventoryData()
	InventoryClient.InvData = Signal.InvokeServer("InventoryServer:GetInventoryData")
end

-- Updating display
function InventoryClient.UpdateDisplay()
	while InventoryClient.UpdatingDb do
		task.wait()
	end
	InventoryClient.UpdatingDb = true

	-- Clearing items
	for i, itemF: Frame in itemsSF:GetChildren() do
		if itemF.ClassName == "TextButton" and itemF ~= itemSample then
			itemF:Destroy()
		end
	end

	-- Creating item frames
	local inv: Types.Inventory = InventoryClient.InvData
	for i, stackData: Types.StackData in inv.Inventory do
		-- Cloning
		local itemF = itemSample:Clone()
		itemF.Name = "Stack-" .. stackData.StackId
		itemF.Image.Image = stackData.Image
		itemF.ItemCount.Text = #stackData.Items .. "x"
		itemF.Equipped.Visible = InventoryClient.CheckItemEquipped(stackData)
		itemF.Parent = itemSample.Parent
		itemF.Visible = true

		if #stackData.Items == 1 then
			itemF.ItemCount.Visible = false
		end

		-- Drag and drop
		local dragConn
		itemF.MouseButton1Down:Connect(function()
			InventoryClient.StartDrag(itemF, stackData)
		end)

		-- Right click to select for info
		itemF.MouseButton2Click:Connect(function()
			if InventoryClient.SelectedStackId == stackData.StackId then
				InventoryClient.SelectItem()
			else
				InventoryClient.SelectItem(stackData)
			end
		end)
	end

	-- Updating hotbar
	for slotNum = 1, #hotbarSlots do
		-- Getting slot information
		local slotF: HotbarSlotButton = hotbarSlots[slotNum]
		local stackId: number? = InventoryClient.InvData.Hotbar["Slot" .. slotNum]

		-- Updating display of hotbar slot
		if stackId == nil then
			slotF.ItemCount.Visible = false
			slotF.Image.Image = ""
		else
			-- Finding stack data
			local foundStack: Types.StackData? = InventoryClient.FindStackDataFromId(stackId)

			-- Updating information
			if foundStack ~= nil then
				slotF.ItemCount.Text = #foundStack.Items .. "x"
				slotF.Image.Image = foundStack.Image
				if #foundStack.Items == 1 then
					slotF.ItemCount.Visible = false
				else
					slotF.ItemCount.Visible = true
				end
			else
				slotF.ItemCount.Visible = false
				slotF.Image.Image = ""
			end
		end
	end

	-- Updating armor
	for armorType, slotF in armorSlots do
		if armorSlotConnections[armorType] then
			armorSlotConnections[armorType]:Disconnect()
			armorSlotConnections[armorType] = nil
		end
	end

	for armorType, slotF in armorSlots do
		-- Finding slot data
		local stackId: number? = InventoryClient.InvData.Armor[armorType]
		local stackData: Types.StackData? = InventoryClient.FindStackDataFromId(stackId)

		-- Updating display
		if stackData == nil then
			slotF.Image.Image = ""
		else
			slotF.Image.Image = stackData.Image
		end

		--Unequipping Armor when clicked
		armorSlotConnections[armorType] = slotF.MouseButton1Click:Connect(function()
			Signal.FireServer("InventoryServer:UnequipArmor", stackId)
		end)
	end

	-- Updating weapons
	local weaponSlotConnections = {}
	for weaponType, slotF in weaponSlots do
		-- Finding slot data
		local stackId: number? = InventoryClient.InvData.Weapons[weaponType]
		local stackData: Types.StackData? = InventoryClient.FindStackDataFromId(stackId)

		-- Updating display
		if stackData == nil then
			slotF.Image.Image = ""
		else
			slotF.Image.Image = stackData.Image
		end

		-- Unequipping weapon when clicked
		if weaponSlotConnections[weaponType] then
			weaponSlotConnections[weaponType]:Disconnect()
		end
		weaponSlotConnections[weaponType] = slotF.MouseButton1Click:Connect(function()
			Signal.FireServer("InventoryServer:UnequipWeapon", stackId)
		end)
	end

	-- Reselecting item
	local selectedStack: Types.StackData? = InventoryClient.FindStackDataFromId(InventoryClient.SelectedStackId)
	InventoryClient.SelectItem(selectedStack)
	InventoryClient.UpdatingDb = false
end

-- Selecting items
function InventoryClient.SelectItem(stackData: Types.StackData?)
	-- Setting selected item
	InventoryClient.SelectedStackId = if stackData ~= nil then stackData.StackId else nil

	-- Finding item frame
	local itemF: InventoryItemButton? = if stackData ~= nil
		then itemsSF:FindFirstChild("Stack-" .. stackData.StackId)
		else nil

	-- Setting frame colors
	for i, otherItemF: InventoryItemButton in itemsSF:GetChildren() do
		if otherItemF.ClassName == "TextButton" and otherItemF ~= itemSample then
			if itemF ~= nil and (otherItemF :: TextButton) == (itemF :: TextButton) then
				otherItemF.BackgroundColor3 = otherItemF:GetAttribute("SelectedColor") :: Color3
			else
				otherItemF.BackgroundColor3 = otherItemF:GetAttribute("NormalColor") :: Color3
			end
		end
	end

	-- Updating information
	if stackData ~= nil then
		local tool = stackData.Items[1]

		-- Setting stack information
		infoF.Visible = true
		itemNameT.Text = stackData.Name
		itemDescT.Text = stackData.Description
		itemImageF.Image = stackData.Image
		itemTypeT.Text = stackData.ItemType

		--Setting attribute information
		sellPriceT.Text = tool:GetAttribute("SellPrice")
		RarityT.Text = tool:GetAttribute("Rarity")

		--Setting armor stats
		local itemType = stackData.ItemType
		if itemType == "Armor" then
			print("ItemType = Armor!") --Stats Display, also add weapon logic
		end

		-- Setting equip button
		local isEquipped = InventoryClient.CheckItemEquipped(stackData)
		InventoryClient.SetEquipButton(not isEquipped)
	else
		infoF.Visible = false
		InventoryClient.SetEquipButton(true)
	end
end

-- Error mesasge
function InventoryClient.ErrorMessage(message: string)
	print(1)
	if InventoryClient.ErrorDb then
		return
	end
	print(2)
	local errorJanitor = Janitor.new()
	InventoryClient.ErrorDb = true
	errorJanitor:GiveChore(function()
		InventoryClient.ErrorDb = false
	end)
	print(3)

	-- Setting up message
	errorT.Text = message
	errorT.Position = InventoryClient.ErrorPosition + UDim2.fromScale(0, -0.5)
	errorT.Visible = true
	errorJanitor:GiveChore(function()
		errorT.Visible = false
	end)

	-- Tweening out
	local tweenOut = TS:Create(
		errorT,
		TweenInfo.new(InventoryClient.ErrorTime / 4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Position = InventoryClient.ErrorPosition,
		}
	)
	errorJanitor:GiveChore(tweenOut)
	tweenOut:Play()
	tweenOut.Completed:Wait()

	-- Waiting error time
	task.wait(InventoryClient.ErrorTime / 2)

	-- Tweening to be invisible
	local tweenAway = TS:Create(
		errorT,
		TweenInfo.new(InventoryClient.ErrorTime / 4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	errorJanitor:GiveChore(tweenAway)
	errorJanitor:GiveChore(function()
		errorT.TextTransparency = 0
		errorT.TextStrokeTransparency = 0
	end)
	tweenAway:Play()
	tweenAway.Completed:Wait()

	-- Cleaning up
	errorJanitor:Clean()
end

-- Finding stack data from id
function InventoryClient.FindStackDataFromId(stackId: number?): Types.StackData?
	if stackId == nil then
		return nil
	end
	for i, stackData: Types.StackData in InventoryClient.InvData.Inventory do
		if stackData.StackId == stackId then
			return stackData
		end
	end
	return nil
end

-- Toggle holster
function InventoryClient.ToggleHolster()
	local char = player.Character
	if not char then
		return
	end

	local tool = char:FindFirstChildOfClass("Tool")
	if tool then
		-- Unequip current tool
		Signal.FireServer("InventoryServer:UnholdItems")
	else
		-- Equip primary weapon if available
		local primaryStackId = InventoryClient.InvData.Weapons.PrimaryGun
		if primaryStackId then
			local stackData = InventoryClient.FindStackDataFromId(primaryStackId)
			if stackData then
				-- Find which hotbar slot this weapon is in
				for slotName, stackId in InventoryClient.InvData.Hotbar do
					if stackId == primaryStackId then
						local slotNum = tonumber(string.sub(slotName, 5))
						InventoryClient.ToggleHold(slotNum)
						return
					end
				end
			end
		end
	end
end

-- Cycle weapons with mouse wheel
function InventoryClient.CycleWeapons(up: boolean)
	local currentHeld = InventoryClient.HeldSlotNum
	if not currentHeld then
		-- If nothing held, start with primary
		local primaryStackId = InventoryClient.InvData.Weapons.PrimaryGun
		if primaryStackId then
			for slotName, stackId in InventoryClient.InvData.Hotbar do
				if stackId == primaryStackId then
					local slotNum = tonumber(string.sub(slotName, 5))
					InventoryClient.ToggleHold(slotNum)
					return
				end
			end
		end
		return
	end

	-- Find current weapon type
	local currentStackId = InventoryClient.InvData.Hotbar["Slot" .. currentHeld]
	if not currentStackId then
		return
	end

	local currentStackData = InventoryClient.FindStackDataFromId(currentStackId)
	if not currentStackData or currentStackData.ItemType ~= "Weapon" then
		return
	end

	-- Cycle to next weapon
	local weaponOrder = { "PrimaryGun", "SecondaryGun" }
	local currentWeaponType
	for weaponType, stackId in InventoryClient.InvData.Weapons do
		if stackId == currentStackId then
			currentWeaponType = weaponType
			break
		end
	end

	if not currentWeaponType then
		return
	end

	local currentIndex = table.find(weaponOrder, currentWeaponType)
	if not currentIndex then
		return
	end

	local nextIndex
	if up then
		nextIndex = currentIndex % #weaponOrder + 1
	else
		nextIndex = (currentIndex - 2) % #weaponOrder + 1
	end

	local nextWeaponType = weaponOrder[nextIndex]
	local nextStackId = InventoryClient.InvData.Weapons[nextWeaponType]

	if nextStackId then
		for slotName, stackId in InventoryClient.InvData.Hotbar do
			if stackId == nextStackId then
				local slotNum = tonumber(string.sub(slotName, 5))
				InventoryClient.ToggleHold(slotNum)
				return
			end
		end
	end
end

-- Drag and drop functions
function InventoryClient.StartDrag(itemF: InventoryItemButton, stackData: Types.StackData)
	if InventoryClient.IsDragging then
		return
	end

	InventoryClient.IsDragging = true
	InventoryClient.DragItem = itemF

	-- Create drag image
	local dragImage = itemF.Image:Clone()
	dragImage.Parent = guiHud
	dragImage.Size = UDim2.fromScale(0.05, 0.05)
	dragImage.ZIndex = 100
	InventoryClient.DragImage = dragImage

	-- Connect mouse movement
	local conn = UIS.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local mousePos = UIS:GetMouseLocation()
			dragImage.Position = UDim2.fromOffset(mousePos.X - 25, mousePos.Y - 25) -- Center the 50x50 image on cursor
		end
	end)

	-- Wait for mouse release
	local releaseConn
	releaseConn = UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			InventoryClient.EndDrag(stackData)
			conn:Disconnect()
			releaseConn:Disconnect()
		end
	end)
end

function InventoryClient.EndDrag(stackData: Types.StackData)
	if not InventoryClient.IsDragging then
		return
	end

	InventoryClient.IsDragging = false

	if InventoryClient.DragImage then
		InventoryClient.DragImage:Destroy()
		InventoryClient.DragImage = nil
	end

	-- Check if dropped on a slot
	local mousePos = UIS:GetMouseLocation()

	-- Check hotbar slots
	for i, slotF in hotbarSlots do
		local slotPos = slotF.AbsolutePosition
		local slotSize = slotF.AbsoluteSize

		if
			mousePos.X >= slotPos.X
			and mousePos.X <= slotPos.X + slotSize.X
			and mousePos.Y >= slotPos.Y
			and mousePos.Y <= slotPos.Y + slotSize.Y
		then
			-- Drop on hotbar slot
			Signal.FireServer("InventoryServer:EquipToHotbar", i, stackData.StackId)
			return
		end
	end

	-- Check armor slots
	for armorType, slotF in armorSlots do
		local slotPos = slotF.AbsolutePosition
		local slotSize = slotF.AbsoluteSize

		if
			mousePos.X >= slotPos.X
			and mousePos.X <= slotPos.X + slotSize.X
			and mousePos.Y >= slotPos.Y
			and mousePos.Y <= slotPos.Y + slotSize.Y
		then
			-- Drop on armor slot
			if stackData.ItemType == "Armor" then
				local success = Signal.InvokeServer("InventoryServer:EquipArmor", stackData.StackId)
				if not success then
					InventoryClient.ErrorMessage("Something went wrong while equipping armor!")
				end
			end
			return
		end
	end

	-- Check weapon slots
	for weaponType, slotF in weaponSlots do
		local slotPos = slotF.AbsolutePosition
		local slotSize = slotF.AbsoluteSize

		if
			mousePos.X >= slotPos.X
			and mousePos.X <= slotPos.X + slotSize.X
			and mousePos.Y >= slotPos.Y
			and mousePos.Y <= slotPos.Y + slotSize.Y
		then
			-- Drop on weapon slot
			if stackData.ItemType == "Weapon" then
				local success = Signal.InvokeServer("InventoryServer:EquipWeapon", stackData.StackId)
				if not success then
					InventoryClient.ErrorMessage("Something went wrong while equipping weapon!")
				end
			end
			return
		end
	end
end

-- Returning
return InventoryClient
