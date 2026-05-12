-- src/server/StowayServerV1.2/Core/InventoryState.luau
-- Pure data container for player inventory state
-- Includes per-player settings (defaults from Config, modifiable at runtime)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryState = {}
InventoryState.__index = InventoryState

local Settings = require(ReplicatedStorage.Shared.Settings)

--// Types
export type ItemInstance = {
	UUID: string,
	Id: string,
	Amount: number,
	Metadata: { [string]: any }?,
}

export type PlayerSettings = {
	Limit: number, -- Weight limit (0 = infinite)
	CanStack: boolean, -- Allow stacking
	MaxStackSize: number, -- Max items per stack
	MaxHotbarSlots: number, -- Number of hotbar slots
	Droppable: boolean, -- Allow dropping
	UiType: string, -- Interface version to load (default, admin, mod, developer, content, spec, etc)
}

export type InventoryStateType = {
	Player: Player,
	Items: { [string]: ItemInstance }, -- UUID -> Item
	ItemsByID: { [string]: { string } }, -- ItemId -> Array of UUIDs (for stacking lookup)
	Hotbar: { [number]: string? }, -- Slot -> UUID (Static: nil holes allowed)
	Storage: { string }, -- Array of UUIDs (Dynamic: packed, no holes)
	EquippedItemUUID: string?, -- UUID of currently equipped item
	Equipment: { -- Dedicated equipment slots
		Armor: {
			Head: string?, -- UUID
			Body: string?,
			Leggings: string?,
			Backpack: string?,
		},
		Weapons: {
			Primary: string?, -- UUID
			Secondary: string?,
		},
	},
	Weight: number, -- Total item count (sum of all stack amounts)
	Settings: PlayerSettings, -- Per-player settings (modifiable!)
}

--// Constructor
function InventoryState.new(player: Player): InventoryStateType
	local self = setmetatable({}, InventoryState)
	self.Player = player
	self.Items = {}
	self.ItemsByID = {}
	self.Hotbar = {}
	self.Storage = {}
	self.EquippedItemUUID = nil
	self.Equipment = {
		Armor = {
			Head = nil,
			Body = nil,
			Leggings = nil,
			Backpack = nil,
		},
		Weapons = {
			Primary = nil,
			Secondary = nil,
		},
	}
	self.Weight = 0
	self.died = false

	-- Per-player settings (defaults from Config)
	self.Settings = {
		Droppable = Settings.Gameplay.Droppable,
		Limit = Settings.Storage.Limit,
		CanStack = Settings.Storage.CanStack,
		MaxStackSize = Settings.Storage.MaxStackSize,
		MaxHotbarSlots = Settings.Hotbar.MaxSlots,
		UiType = "Default",
	}

	return self
end

--// Getters (No logic, just data access)
function InventoryState:GetItem(uuid: string): ItemInstance?
	return self.Items[uuid]
end

function InventoryState:GetHotbarUUID(slot: number): string?
	return self.Hotbar[slot]
end

function InventoryState:GetStorageUUID(index: number): string?
	return self.Storage[index]
end

function InventoryState:IsEquipped(uuid: string): boolean
	return self.EquippedItemUUID == uuid
end

return InventoryState
