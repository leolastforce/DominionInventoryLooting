-- src/server/StowayServerV1.2/Config/Settings.luau
-- Configuration for the Inventory System V1.2

local Settings = {}

--// Types
export type HotbarType = "Static" | "Dynamic"

--// Hotbar Settings
Settings.Hotbar = {
	Type = "Static" :: HotbarType, -- Static is fixed slots with holes, Dynamic is packed array (perplayer setting)
	MaxSlots = 8, -- Hotbar slots
}

--// Storage/Backpack Settings (Always Dynamic)
Settings.Storage = {
	Limit = 28, -- Total weight limit (Hotbar + Storage combined)
	CanStack = true, 
	Sorting = true, 
	MaxStackSize = 99, 
	BackpackEnabled = true, 
	SortOrder = "None" 
}

--// Stacking Rules
Settings.Stacking = {
	-- Fields that MUST match for items to stack
	RequiredFields = { "Rarity", "Type" }, -- (global setting)
	-- Rarities that can't stack
	Blacklist = { 
		["Legendary"] = true,
		["Mythic"] = true,
		["Special"] = true,
	},

	Rarity = false 
}

--// Gameplay Settings
Settings.Gameplay = { -- (global settings)
	Droppable = true,
	DropDistance = 10,
	MouseScroll = true,
}

Settings.DifferentUIs = {
	Default = {
		FolderName = "DominionGui",
		GuiName = "Inventory",
		HookPresetName = "DefaultHooks"
	},
}

return Settings
