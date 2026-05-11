return {
	
	OnSlotClick = function(slotType, index, uuid)
		-- Your custom click logic
		print("Clicked " .. slotType .. " #" .. index)
	end,

	OnDragStart = function(type, index)
		-- Play sound
		print("drag started")
	end,
	
	OnSlotHover = function(btn:GuiButton, slotType, slotIndex)
		local uistroke: UIStroke = btn:FindFirstChild("UIStroke")
		uistroke.Enabled = true
		local TS = game:GetService("TweenService")
		local tInfo = TweenInfo.new(0.125, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		
		TS:Create(uistroke, tInfo, {Thickness = 5}):Play()
		task.wait(0.125)
		TS:Create(uistroke, tInfo, {Thickness = 0}):Play()
		task.wait(0.125)
		uistroke.Enabled = false
	end,
		
	OnDragEnd = function(type, index)
		-- Play sound
		print("drag ended")
	end,
	
	OnEquip = function(type, index)
		-- Play sound
		print("equipped")
	end,
	
	OnUnequip = function(type, index)
		-- Play sound
		print("unequipped")
	end,
	
	OnItemAdd = function(type, index)
		-- Play sound
		print("Item Added")
	end,
	
	OnItemRemove = function(type, index)
		-- Play sound
		print("Item Removed")
	end,
	
	OnSwap = function(type, index)
		-- Play sound
		print("OnSwap")
	end,
	
	OnSelect = function(frame, slotType, slotIndex)
		local highlight = Instance.new("UIStroke")
		highlight.Name = "SelectionHighlight"
		highlight.Color = Color3.fromRGB(255, 255, 0)
		highlight.Thickness = 4
		highlight.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		highlight.Parent = frame
	end,

	OnDeselect = function(frame, slotType, slotIndex)
		local highlight = frame:FindFirstChild("SelectionHighlight")
		if highlight then highlight:Destroy() end
	end,
}
