--!strict

-- Load the WindUI Library from GitHub using the user's provided working example method.
-- This method uses the releases/latest/download link.
local WindUI_Loaded, WindUI_Result = pcall(function()
    -- The WindUI loading link and format from the user's working example
    local code = game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua")
    if not code or #code == 0 then
        error("WindUI main.lua content is empty or could not be retrieved.")
    end
    -- Execute the loaded code directly
    return loadstring(code)() 
end)

local WindUI = nil
if WindUI_Loaded then
    WindUI = WindUI_Result
    print("WindUI Library successfully loaded. Type:", typeof(WindUI))
else
    warn("CRITICAL ERROR: An issue occurred while loading the WindUI Library! Please check your internet connection and the GitHub link. Error:", WindUI_Result)
    return -- Stop the script if WindUI cannot be loaded
end

if not WindUI then
    warn("Error: WindUI object is nil. GUI will not be created. Script stopped.")
    return
end

-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Backpack = LocalPlayer:WaitForChild("Backpack")
local HttpService = game:GetService("HttpService") -- Required for JSONEncode
local RunService = game:GetService("RunService") -- For Heartbeat loop

-- Global Variables
local localPlayerFarmId = "Not Found"
local currentShecklesAmount = "Loading..."
local EkilexekSeed = {} -- Seeds to auto plant
local plantingEnabled = false -- Is auto planting enabled?

local EkilexekBuySeed = {} -- Seeds to auto buy
local autoBuyEnabled = false -- Is auto buying enabled?

local autoHarvestEnabled = false -- Is auto harvesting enabled?
local HarvestIgnores = { -- Blacklist: Items in this list will NOT be harvested if selected
	Normal = false,
	Gold = false,
	Rainbow = false
}
-- EkilexekHarvest removed as per user request (no specific harvestable items selection)

-- Farm positions (farmNumber => position)
local farmPositions = {
    [4] = Vector3.new(-70.54048156738281, 0.13552704453468323, 87.05094146728516),
    [2] = Vector3.new(68.38848876953125, 0.13552704453468323, 83.08100128173828),
    [3] = Vector3.new(-139.2397918701172, 0.13552704453468323, -112.45325469970703),
    [1] = Vector3.new(-1.9766778945922852, 0.13552704453468323, -113.26812744140625),
    [5] = Vector3.new(-274.8962707519531, 0.13552704453468323, -106.14342498779297),
}

-- Original player properties (saved for noclip toggle)
local originalWalkSpeed = 16 -- Default Roblox walk speed
local originalJumpPower = 50 -- Default Roblox jump power
local originalCanCollide = true -- Default HumanoidRootPart CanCollide
local originalPlatformStand = false -- Default Humanoid PlatformStand state
local originalSit = false -- Default Humanoid Sit state

-- Noclip toggle function
local function toggleNoclip(enable)
    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")

    if HumanoidRootPart and Humanoid then
        if enable then
            -- Save current values
            originalCanCollide = HumanoidRootPart.CanCollide
            originalWalkSpeed = Humanoid.WalkSpeed
            originalJumpPower = Humanoid.JumpPower
            originalPlatformStand = Humanoid.PlatformStand
            originalSit = Humanoid.Sit

            -- Apply noclip settings
            HumanoidRootPart.CanCollide = false
            Humanoid.WalkSpeed = 0 -- Prevent self-movement
            Humanoid.JumpPower = 0 -- Disable jumping
            Humanoid.PlatformStand = true -- Prevent falling
            Humanoid.Sit = true -- Make character "sit" to aid CFrame manipulation
            print("Noclip ON.")
        else
            -- Restore original values
            HumanoidRootPart.CanCollide = originalCanCollide
            Humanoid.WalkSpeed = originalWalkSpeed
            Humanoid.JumpPower = originalJumpPower
            Humanoid.PlatformStand = originalPlatformStand -- Crucial: Reset PlatformStand
            Humanoid.Sit = originalSit -- Explicitly set to original state
            print("Noclip OFF.")
        end
    end
end

-- Find own farm (owner == player.name)
local function getOwnFarm()
    local farmFolder = workspace:FindFirstChild("Farm")
    if not farmFolder then
        warn("Error: workspace.Farm not found.")
        return nil
    end
    for _, farm in ipairs(farmFolder:GetChildren()) do
        local imp = farm:FindFirstChild("Important")
        local data = imp and imp:FindFirstChild("Data")
        local owner = data and data:FindFirstChild("Owner")
        if owner and owner.Value == LocalPlayer.Name then
            print("Own farm found: " .. farm.Name)
            return farm
        end
    end
    warn("Error: Your farm not found.")
    return nil
end

-- Check if selected seed is in hand
local function hasSeedInHand(seedName)
    local tool = Character:FindFirstChildOfClass("Tool")
    return tool and tool.Name:lower():find(seedName:lower() .. " seed")
end

-- Equip seed tool from backpack
local function equipSeedTool(seedName)
    for _, tool in ipairs(Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find(seedName:lower() .. " seed") then
            local humanoid = Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(tool)
                print("Seed equipped: "..tool.Name)
                return true
            end
        end
    end
    warn("Error: "..seedName.." Seed tool not found.")
    return false
end

-- Plant_RE event to plant seed
local function plantSeed(position, seedName)
    local ge = ReplicatedStorage:FindFirstChild("GameEvents")
    local plantRE = ge and ge:FindFirstChild("Plant_RE")
    if not plantRE or typeof(plantRE.FireServer) ~= "function" then
        warn("Error: Plant_RE event not found.")
        return
    end
    plantRE:FireServer(position, seedName)
    print("Planted: " .. seedName .. " @ " .. tostring(position))
end

-- Auto Planting main function
local function autoPlant()
    while plantingEnabled do
        local farm = getOwnFarm()
        if farm and #EkilexekSeed > 0 then
            local data = farm.Important and farm.Important:FindFirstChild("Data")
            local farmNumber = data and data:FindFirstChild("Farm_Number") and data.Farm_Number.Value
            local pos = farmPositions[farmNumber]
            if pos then
                for _, seed in ipairs(EkilexekSeed) do
                    if not hasSeedInHand(seed) then
                        if not equipSeedTool(seed) then 
                            warn("Warning: " .. seed .. " tool not found or could not be equipped, skipping.")
                            continue -- Skip this seed and move to the next
                        end
                        task.wait(0.3)
                    end
                    plantSeed(pos, seed)
                    task.wait(0.2)
                end
            else
                warn("Warning: No position for Farm_Number " .. tostring(farmNumber))
            end
        else
            warn("Warning: Farm not found or no seeds selected for planting.")
        end
        task.wait(0.5) -- Adjusted wait time for less lag
    end
end

-- Auto Buy Seed function
local function buySeed(seedName)
    local ge = ReplicatedStorage:FindFirstChild("GameEvents")
    local buySeedStockRE = ge and ge:FindFirstChild("BuySeedStock")
    if not buySeedStockRE or typeof(buySeedStockRE.FireServer) ~= "function" then
        warn("Error: BuySeedStock event not found.")
        return
    end
    buySeedStockRE:FireServer(seedName)
    print("Seed purchased: " .. seedName)
end

-- Auto Buy main loop
local function autoBuyLoop()
    while autoBuyEnabled do
        if #EkilexekBuySeed > 0 then
            for _, seed in ipairs(EkilexekBuySeed) do
                buySeed(seed)
                task.wait(1) -- Short wait between purchases
            end
        else
            warn("Warning: No seeds selected for auto buying.")
        end
        task.wait(5) -- Repeat purchase cycle every 5 seconds
    end
end

-- Harvest functions from autofarm.lua.txt
local function HarvestPlant(Plant: Model)
	local Prompt = Plant:FindFirstChild("ProximityPrompt", true)

	--// Check if it can be harvested
	if not Prompt then
        warn("Error: ProximityPrompt not found in plant '" .. Plant.Name .. "'.")
        return
    end
    if not Prompt.Enabled then
        print("Info: ProximityPrompt for plant '" .. Plant.Name .. "' is not enabled.")
        return
    end
    print("Triggering ProximityPrompt for: " .. Plant.Name)
	fireproximityprompt(Prompt)
end

local function CanHarvest(Plant): boolean
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	if not Prompt then return false end
    if not Prompt.Enabled then return false end

    return true
end

-- This function is no longer needed as the dropdown is removed
-- local function GetAllUniquePlantVariants()
--     local uniqueVariants = {}
--     local seen = {}

--     local function collectVariantsRecursive(parent)
--         for _, plant in ipairs(parent:GetChildren()) do
--             local variant = plant:FindFirstChild("Variant")
--             if variant and variant:IsA("StringValue") then
--                 local variantName = variant.Value
--                 if not seen[variantName] then
--                     table.insert(uniqueVariants, variantName)
--                     seen[variantName] = true
--                 end
--             end
--             local fruits = plant:FindFirstChild("Fruits")
--             if fruits then
--                 collectVariantsRecursive(fruits)
--             end
--         end
--     end

--     local ownFarm = getOwnFarm()
--     if ownFarm then
--         local plantsPhysical = ownFarm.Important:FindFirstChild("Plants_Physical")
--         if plantsPhysical then
--             collectVariantsRecursive(plantsPhysical)
--         end
--     end
--     return uniqueVariants
-- end

local function CollectHarvestable(Parent, Plants, IgnoreDistance: boolean?)
	local Character = LocalPlayer.Character
	local PlayerPosition = Character:GetPivot().Position

    for _, Plant in next, Parent:GetChildren() do
        --// Fruits (nested plants)
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then
			CollectHarvestable(Fruits, Plants, IgnoreDistance)
		end

		--// Check if the plant's variant is in the ignore list (blacklist)
		local Variant = Plant:FindFirstChild("Variant")
		if Variant and HarvestIgnores[Variant.Value] then 
            continue -- Skip if in ignore list
        end

        -- EkilexekHarvest (whitelist) filtering logic removed as per user request
        -- All non-ignored plants will be collected

        --// Collect
        if CanHarvest(Plant) then
            table.insert(Plants, Plant)
        end
	end
    return Plants
end

local PlantsPhysical = nil -- To be defined globally

local function GetHarvestablePlants(IgnoreDistance: boolean?)
    local Plants = {}
    if PlantsPhysical then
        CollectHarvestable(PlantsPhysical, Plants, IgnoreDistance)
    else
        warn("Error: PlantsPhysical folder not defined.")
    end
    return Plants
end

-- Reference for the Total Plant Count display (removed as per user request)
-- local totalPlantCountDisplay = nil

-- Auto Harvest main function
local function autoHarvest()
    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not HumanoidRootPart then
        warn("Error: HumanoidRootPart not found.")
        return
    end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then
        warn("Error: Humanoid not found.")
        return
    end

    -- Enable Noclip
    toggleNoclip(true)

    while autoHarvestEnabled do
        local ownFarm = getOwnFarm()
        if ownFarm then
            PlantsPhysical = ownFarm.Important:FindFirstChild("Plants_Physical") -- Get current folder each loop
            if PlantsPhysical then
                local allHarvestablePlants = GetHarvestablePlants()
                
                -- Total Plant Count display update logic removed as per user request
                -- if totalPlantCountDisplay then
                --     totalPlantCountDisplay.Desc = tostring(#allHarvestablePlants)
                -- end

                if #allHarvestablePlants > 0 then
                    -- Select a random plant
                    local randomIndex = math.random(1, #allHarvestablePlants)
                    local targetPlant = allHarvestablePlants[randomIndex]

                    -- Set target position slightly above the plant
                    -- This helps trigger the ProximityPrompt
                    -- Teleport directly to the plant's position, slightly above it
                    local targetPosition = targetPlant:GetPivot().Position + Vector3.new(0, 1.5, 0) -- Increased offset for better reach
                    
                    print("Teleporting to a random plant: " .. targetPlant.Name .. " @ " .. tostring(targetPosition))
                    
                    -- Teleport the character
                    HumanoidRootPart.CFrame = CFrame.new(targetPosition) * CFrame.Angles(HumanoidRootPart.CFrame:ToOrientation())
                    
                    -- Wait for the game to register the new position and activate the prompt
                    task.wait(0.1) -- Faster wait time for teleportation

                    -- Perform harvest
                    HarvestPlant(targetPlant)
                    print("Harvested: " .. targetPlant.Name)
                    task.wait(0.2) -- Wait after harvest before finding next plant
                else
                    print("Warning: No harvestable plants found or not grown yet. Stopping auto harvest.")
                    autoHarvestEnabled = false -- Stop the loop when nothing to harvest
                    toggleNoclip(false) -- Revert character state
                    -- if totalPlantCountDisplay then -- Removed as per user request
                    --     totalPlantCountDisplay.Desc = "0"
                    -- end
                end
            else
                warn("Warning: Plants_Physical folder not found. Waiting 1 second.")
                task.wait(1)
            end
        else
            warn("Warning: Your farm not found. Waiting 1 second.")
            task.wait(1)
        end
    end

    -- Ensure Noclip is disabled when the loop ends naturally
    toggleNoclip(false)
    -- if totalPlantCountDisplay then -- Removed as per user request
    --     totalPlantCountDisplay.Desc = "0" -- Reset count when auto harvest stops
    -- end
end


-- Gradient function (from Example.lua (2).txt, for UI)
function gradient(text, startColor, endColor)
    local result = ""
    local length = #text

    for i = 1, length do
        local t = (i - 1) / math.max(length - 1, 1)
        local r = math.floor((startColor.R + (endColor.R - startColor.R) * t) * 255)
        local g = math.floor((startColor.G + (endColor.G - startColor.G) * t) * 255)
        local b = math.floor((startColor.B + (endColor.B - startColor.B) * t) * 255) 

        local char = text:sub(i, i)
        result = result .. "<font color=\"rgb(" .. r ..", " .. g .. ", " .. b .. ")\">" .. char .. "</font>"
    end

    return result
end

local Confirmed = false

-- Popup (from Example.lua, optional)
WindUI:Popup({
    Title = "Welcome! Popup Example",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Content = "This is an Example UI for the " .. gradient("WindUI", Color3.fromHex("#00FF87"), Color3.fromHex("#60EFFF")) .. " Lib",
    Buttons = {
        {
            Title = "Cancel",
            Callback = function() end,
            Variant = "Secondary",
        },
        {
            Title = "Continue",
            Icon = "arrow-right",
            Callback = function() Confirmed = true end,
            Variant = "Primary",
        }
    }
})

repeat task.wait() until Confirmed

-- Create the WindUI window (from Example.lua)
local Window = WindUI:CreateWindow({
    Title = "Game Info and Settings", -- Title updated
    Icon = "monitor", -- Icon updated
    IconThemed = true,
    Author = "Your Script", -- Author updated
    Folder = "GameGUI", -- Folder updated
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, -- Added transparency
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
    User = {
        Enabled = true,
        Callback = function() print("User icon clicked") end,
        Anonymous = true
    },
    SideBarWidth = 200,
    ScrollBarEnabled = true,
    KeySystem = { -- <- keysystem enabled
        Key = { "1234", "5678" },
        Note = "Enter a key to use the UI. Example Keys: '1234' or '5678'",
        URL = "https://github.com/Footagesus/WindUI",
        SaveKey = true,
    },
})

-- Debugging: Ensure the window was created
if not Window then
    warn("Error: WindUI window could not be created! Script stopped.")
    return
end
print("WindUI window successfully created. Type:", typeof(Window))

-- Create tabs and sections
local Tabs = {}

do
    -- Main sections (Sections are added to the Window)
    Tabs.MainSection = Window:Section({ Title = "Main Sections", Opened = true })
    Tabs.AutoSection = Window:Section({ Title = "Automated Actions", Opened = true }) -- New automated actions section

    -- Information tab
    Tabs.Info = Tabs.MainSection:Tab({ Title = "Information", Icon = "info" })
    -- Player Settings tab
    Tabs.PlayerSettings = Tabs.MainSection:Tab({ Title = "Player Settings", Icon = "user" })
    -- Stock tab
    Tabs.Stock = Tabs.MainSection:Tab({ Title = "Stock", Icon = "package" })
    
    -- Auto Planting tab (Moved to Automated Actions section)
    Tabs.AutoPlanting = Tabs.AutoSection:Tab({ Title = "Auto Planting", Icon = "leaf" })
    -- Auto Buy tab (New)
    Tabs.AutoBuy = Tabs.AutoSection:Tab({ Title = "Auto Buy", Icon = "shopping-cart" })
    
    -- Auto Harvest tab (New)
    Tabs.AutoHarvest = Tabs.AutoSection:Tab({ Title = "Auto Harvest", Icon = "pickaxe" }) -- Auto Harvest is now a Tab
    
    -- Debug tab (New)
    Tabs.Debug = Tabs.MainSection:Tab({ Title = "Debug", Icon = "bug" }) -- New Debug tab
    
    -- Debugging: Ensure tabs and sections were created
    if not Tabs.Info or not Tabs.PlayerSettings or not Tabs.Stock or not Tabs.AutoPlanting or not Tabs.AutoBuy or not Tabs.AutoHarvest or not Tabs.Debug then
        warn("Error: Required tabs/sections could not be created! Script stopped.")
        return
    end
    print("Required tabs and sections successfully created.")
end

-- Information Tab Content
local shecklesParagraph = nil
local yourFarmIdParagraph = nil
local serverFarmIdsParagraph = nil

-- Stock Tab Content
local seedStockParagraph = nil
local gearStockParagraph = nil
local cosmeticStockParagraph = nil
local stockTimersParagraph = nil

-- Debug Tab Content
local debugFarmIdParagraph = nil
local debugShecklesParagraph = nil

do
    local InfoTab = Tabs.Info
    local StockTab = Tabs.Stock
    local DebugTab = Tabs.Debug -- Reference to the new Debug tab

    local function updateAllDisplays()
        local LocalPlayer = game:GetService("Players").LocalPlayer
        local shecklesValue = "Loading..."
        local yourFarmIdContent = "Loading..."
        local serverFarmIdsContent = "Loading..."
        local seedStockContent = "Loading..."
        local gearStockContent = "Loading..."
        local cosmeticStockContent = "Loading..."
        local stockTimersContent = "Loading..."

        if not LocalPlayer then
            warn("Error: LocalPlayer not found! Cannot update info.")
            shecklesValue = "Error: LocalPlayer not found."
            yourFarmIdContent = "Error: LocalPlayer not found."
            serverFarmIdsContent = "Error: LocalPlayer not found."
            seedStockContent = "Error: LocalPlayer not found."
            gearStockContent = "Error: LocalPlayer not found."
            cosmeticStockContent = "Error: LocalPlayer not found."
            stockTimersContent = "Error: LocalPlayer not found."
        else
            -- Get Sheckles value
            local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
            if leaderstats then
                local sheckles = leaderstats:FindFirstChild("Sheckles")
                if sheckles and (sheckles:IsA("IntValue") or sheckles:IsA("NumberValue")) then
                    shecklesValue = tostring(sheckles.Value)
                    currentShecklesAmount = shecklesValue -- Update global variable
                else
                    shecklesValue = "Not Found/Invalid Type"
                    currentShecklesAmount = shecklesValue -- Update global variable
                end
            else
                shecklesValue = "leaderstats not found."
                currentShecklesAmount = shecklesValue -- Update global variable
            end

            local localPlayerName = LocalPlayer.Name
            local farm = workspace:FindFirstChild("Farm")

            if not farm then
                yourFarmIdContent = "Error: 'Farm' object not found."
                serverFarmIdsContent = "Error: 'Farm' object not found."
                warn("Warning: 'Farm' object not found in Workspace.")
            else
                local children = farm:GetChildren()
                localPlayerFarmId = "Not Found" -- Reset for each update
                localPlayerFarmName = "Not Found"
                local allServerFarms = {}

                if #children == 0 then
                    serverFarmIdsContent = "No items found in Farm."
                else
                    for _, child in ipairs(children) do
                        local important = child:FindFirstChild("Important")
                        if important then
                            local data = important:FindFirstChild("Data")
                            if data then
                                local owner = data:FindFirstChild("Owner")
                                local farmNumber = data:FindFirstChild("Farm_Number")

                                local ownerValue = "Unused by anyone"
                                if owner and (owner:IsA("StringValue") or owner:IsA("IntValue") or owner:IsA("NumberValue")) then
                                    local actualOwnerValue = tostring(owner.Value)
                                    if actualOwnerValue ~= "" then
                                        ownerValue = actualOwnerValue
                                    end
                                end

                                local farmNumberValue = "Not Found"
                                if farmNumber and (farmNumber:IsA("IntValue") or farmNumber:IsA("NumberValue") or farmNumber:IsA("StringValue")) then
                                    farmNumberValue = tostring(farmNumber.Value)
                                end

                                if ownerValue == localPlayerName then
                                    localPlayerFarmId = farmNumberValue -- Update player's farm ID
                                    localPlayerFarmName = child.Name
                                end
                                table.insert(allServerFarms, child.Name .. " (Owner: " .. ownerValue .. ", ID: " .. farmNumberValue .. ")")
                            else
                                table.insert(allServerFarms, child.Name .. " (Data folder not found)")
                            end
                        else
                            table.insert(allServerFarms, child.Name .. " (Important folder not found)")
                        end
                    end
                    serverFarmIdsContent = table.concat(allServerFarms, "\n")
                end
                yourFarmIdContent = "Username: " .. localPlayerName .. "\nFarm ID: " .. localPlayerFarmId
            end

            -- Get Seed Stock information and filter
            local seedShopFrame = LocalPlayer.PlayerGui:FindFirstChild("Seed_Shop")
            if seedShopFrame and seedShopFrame:FindFirstChild("Frame") and seedShopFrame.Frame:FindFirstChild("ScrollingFrame") then
                local scrollingFrame = seedShopFrame.Frame.ScrollingFrame
                local seeds = {}
                for _, itemFrame in ipairs(scrollingFrame:GetChildren()) do
                    if itemFrame:IsA("Frame") and not itemFrame.Name:find("_Padding") then
                        local mainFrame = itemFrame:FindFirstChild("Main_Frame")
                        if mainFrame then
                            local stockText = mainFrame:FindFirstChild("Stock_Text")
                            if stockText and stockText:IsA("TextLabel") then
                                local textValue = stockText.Text:lower():gsub("%s+", "")
                                if textValue ~= "0" and textValue ~= "nil" and textValue ~= "x0" and textValue ~= "x0stock" and textValue ~= "" then
                                    table.insert(seeds, itemFrame.Name .. " (" .. stockText.Text .. ")")
                                    end
                            end
                        end
                    end
                end
                if #seeds > 0 then
                    seedStockContent = table.concat(seeds, "\n")
                else
                    seedStockContent = "No active items in seed stock."
                end
            else
                seedStockContent = "Seed_Shop UI not found or structure is different."
            end

            -- Get Gear Stock information and filter
            local gearShopFrame = LocalPlayer.PlayerGui:FindFirstChild("Gear_Shop")
            if gearShopFrame and gearShopFrame:FindFirstChild("Frame") and gearShopFrame.Frame:FindFirstChild("ScrollingFrame") then
                local scrollingFrame = gearShopFrame.Frame.ScrollingFrame
                local gears = {}
                for _, itemFrame in ipairs(scrollingFrame:GetChildren()) do
                    if itemFrame:IsA("Frame") and not itemFrame.Name:find("_Padding") then
                        local mainFrame = itemFrame:FindFirstChild("Main_Frame")
                        if mainFrame then
                            local stockText = mainFrame:FindFirstChild("Stock_Text")
                            if stockText and stockText:IsA("TextLabel") then
                                local textValue = stockText.Text:lower():gsub("%s+", "")
                                if textValue ~= "0" and textValue ~= "nil" and textValue ~= "x0" and textValue ~= "x0stock" and textValue ~= "" then
                                    table.insert(gears, itemFrame.Name .. " (" .. stockText.Text .. ")")
                                end
                            end
                        end
                    end
                end
                if #gears > 0 then
                    gearStockContent = table.concat(gears, "\n")
                else
                    gearStockContent = "No active items in gear stock."
                end
            else
                gearStockContent = "Gear_Shop UI not found or structure is different."
            end

            -- Get Cosmetic Stock information and filter
            local cosmeticShopUI = LocalPlayer.PlayerGui:FindFirstChild("CosmeticShop_UI")
            if cosmeticShopUI and cosmeticShopUI:FindFirstChild("CosmeticShop") and
               cosmeticShopUI.CosmeticShop:FindFirstChild("Main") and
               cosmeticShopUI.CosmeticShop.Main:FindFirstChild("Holder") and
               cosmeticShopUI.CosmeticShop.Main.Holder:FindFirstChild("Shop") and
               cosmeticShopUI.CosmeticShop.Main.Holder.Shop:FindFirstChild("ContentFrame") and
               cosmeticShopUI.CosmeticShop.Main.Holder.Shop.ContentFrame:FindFirstChild("BottomSegment") then
                
                local contentFrame = cosmeticShopUI.CosmeticShop.Main.Holder.Shop.ContentFrame.BottomSegment
                local cosmetics = {}
                for _, itemFrame in ipairs(contentFrame:GetChildren()) do
                    if itemFrame:IsA("Frame") and not itemFrame.Name:find("_Padding") then
                        local main = itemFrame:FindFirstChild("Main")
                        if main then
                            local stock = main:FindFirstChild("Stock")
                            if stock then
                                local stockText = stock:FindFirstChild("STOCK_TEXT")
                                if stockText and stockText:IsA("TextLabel") then
                                    local textValue = stockText.Text:lower():gsub("%s+", "")
                                    if textValue ~= "0" and textValue ~= "nil" and textValue ~= "x0" and textValue ~= "x0stock" and textValue ~= "" then
                                        table.insert(cosmetics, itemFrame.Name .. " (" .. stockText.Text .. ")")
                                    end
                                end
                            end
                        end
                    end
                end
                if #cosmetics > 0 then
                    cosmeticStockContent = table.concat(cosmetics, "\n")
                else
                    cosmeticStockContent = "No active items in cosmetic stock."
                end
            else
                cosmeticStockContent = "CosmeticShop_UI not found or structure is different."
            end

            -- Get Stock Refresh Timers
            local timers = {}
            local seedShopTimer = LocalPlayer.PlayerGui:FindFirstChild("Seed_Shop")
            if seedShopTimer and seedShopTimer:FindFirstChild("Frame") and seedShopTimer.Frame:FindFirstChild("Frame") and seedShopTimer.Frame.Frame:FindFirstChild("Timer") then
                local timerText = seedShopTimer.Frame.Frame.Timer
                if timerText:IsA("TextLabel") then
                    table.insert(timers, "Seed Shop: " .. timerText.Text)
                end
            end

            local petShopUI = LocalPlayer.PlayerGui:FindFirstChild("PetShop_UI")
            if petShopUI and petShopUI:FindFirstChild("Frame") and petShopUI.Frame:FindFirstChild("Frame") and petShopUI.Frame.Frame:FindFirstChild("Timer") then
                local timerText = petShopUI.Frame.Frame.Timer
                if timerText:IsA("TextLabel") then
                    table.insert(timers, "Pet Shop: " .. timerText.Text)
                end
            end

            local gearShopTimer = LocalPlayer.PlayerGui:FindFirstChild("Gear_Shop")
            if gearShopTimer and gearShopTimer:FindFirstChild("Frame") and gearShopTimer.Frame:FindFirstChild("Frame") and gearShopTimer.Frame.Frame:FindFirstChild("Timer") then
                local timerText = gearShopTimer.Frame.Frame.Timer
                if timerText:IsA("TextLabel") then
                    table.insert(timers, "Gear Shop: " .. timerText.Text)
                end
            end

            if #timers > 0 then
                stockTimersContent = table.concat(timers, "\n")
            else
                stockTimersContent = "Timers not found."
            end
        end

        -- Destroy previous paragraphs (if they exist)
        if shecklesParagraph then shecklesParagraph:Destroy() end
        if yourFarmIdParagraph then yourFarmIdParagraph:Destroy() end
        if serverFarmIdsParagraph then serverFarmIdsParagraph:Destroy() end
        if seedStockParagraph then seedStockParagraph:Destroy() end
        if gearStockParagraph then gearStockParagraph:Destroy() end
        if cosmeticStockParagraph then cosmeticStockParagraph:Destroy() end
        if stockTimersParagraph then stockTimersParagraph:Destroy() end

        -- Create new paragraphs (add directly to InfoTab and StockTab)
        shecklesParagraph = InfoTab:Paragraph({
            Title = "Sheckle Amount:",
            Desc = shecklesValue
        })

        yourFarmIdParagraph = InfoTab:Paragraph({
            Title = "Your Farm ID:",
            Desc = yourFarmIdContent
        })

        serverFarmIdsParagraph = InfoTab:Paragraph({
            Title = "Server Farm IDs:",
            Desc = serverFarmIdsContent
        })

        -- Create stock paragraphs
        seedStockParagraph = StockTab:Paragraph({
            Title = "Seed Stock:",
            Desc = seedStockContent
        })

        gearStockParagraph = StockTab:Paragraph({
            Title = "Gear Stock:",
            Desc = gearStockContent
        })
        
        cosmeticStockParagraph = StockTab:Paragraph({
            Title = "Cosmetic Stock:",
            Desc = cosmeticStockContent
        })

        stockTimersParagraph = StockTab:Paragraph({
            Title = "Stock Refresh Timers:",
            Desc = stockTimersContent
        })

        if not shecklesParagraph or not yourFarmIdParagraph or not serverFarmIdsParagraph or not seedStockParagraph or not gearStockParagraph or not cosmeticStockParagraph or not stockTimersParagraph then
            warn("Error: New info or stock paragraphs could not be created!")
        end
    end

    -- Load initial data when GUI is loaded
    updateAllDisplays()

    -- Loop to automatically update data (less frequent for performance)
    task.spawn(function()
        while true do
            task.wait(1) -- Update every 1 second (less frequent to reduce lag)
            updateAllDisplays()
        end
    end)

    -- Debug tab content (only once for static info)
    DebugTab:Paragraph({
        Title = "Initial Farm ID:",
        Desc = localPlayerFarmId ~= "Not Found" and localPlayerFarmId or "Farm ID not found on startup."
    })
    DebugTab:Paragraph({
        Title = "Initial Sheckles:",
        Desc = currentShecklesAmount ~= "Loading..." and currentShecklesAmount or "Sheckles amount not loaded on startup."
    })
    DebugTab:Paragraph({
        Title = "Script Status:",
        Desc = "Script loaded and GUI initialized."
    })
end

-- Player Settings Tab Content
local walkSpeedInputRef = nil
local jumpPowerInputRef = nil

do
    local PlayerSettingsTab = Tabs.PlayerSettings -- Hold this variable for convenience

    -- Walk Speed Input (Text Box)
    walkSpeedInputRef = PlayerSettingsTab:Input({
        Title = "Walk Speed",
        Desc = "Sets the player's walk speed.",
        Value = "16",
        Placeholder = "Enter Walk Speed",
        Numeric = true,
        Finished = false,
        Callback = function(Value)
            print("Walk Speed Input value: " .. Value)
        end
    })

    -- Jump Power Input (Text Box)
    jumpPowerInputRef = PlayerSettingsTab:Input({
        Title = "Jump Power",
        Desc = "Sets the player's jump power.",
        Value = "50",
        Placeholder = "Enter Jump Power",
        Numeric = true,
        Finished = false,
        Callback = function(Value)
            print("Jump Power Input value: " .. Value)
        end
    })

    -- Loop to continuously update WalkSpeed and JumpPower
    task.spawn(function()
        while true do
            task.wait(0.05)
            local LocalPlayer = game:GetService("Players").LocalPlayer
            if LocalPlayer and LocalPlayer.Character then
                local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if Humanoid then
                    Humanoid.WalkSpeed = tonumber(walkSpeedInputRef.Value) or 16
                    Humanoid.JumpPower = tonumber(jumpPowerInputRef.Value) or 50
                end
            end
            if not Window.Enabled then break end
        end
    end)
end

-- Auto Planting Tab Content
do
    local AutoPlantingTab = Tabs.AutoPlanting

    AutoPlantingTab:Paragraph({Title = "Selected Location", Desc = "Auto-selects location based on farm number."})
    
    local seedDropdown = AutoPlantingTab:Dropdown({
        Title = "Select Seed",
        Desc = "Select seeds to auto plant.",
        Values = {"Carrot", "Strawberry", "Blueberry", "Orange Tulip", "Tomato", "Corn", "Daffodil", "Watermelon", "Pumpkin", "Apple", "Bamboo","Coconut","Cactus","Dragon Fruit","Mango","Grape","Mushroom","Pepper","Cacao","Beanstalk","Ember Lily","Sugar Apple","Burning Bud","Giant Pinecone","Elder Strawbery"},
        Value = {}, -- No selection initially
        Multi = true, -- Allow multiple selection
        AllowNone = true, -- Allow no selection
        Callback = function(Options)
            -- Check if Callback is triggered correctly and Options value
            print("Auto Planting Dropdown Callback triggered! Selected Options: " .. HttpService:JSONEncode(Options))
            EkilexekSeed = Options
            print("Auto planting seeds updated: " .. table.concat(Options, ", "))
        end
    })
    
    -- Check if Dropdown was created successfully
    if seedDropdown then
        print("Auto Planting Seed Dropdown successfully created.")
    else
        warn("Error: Auto Planting Seed Dropdown could not be created.")
    end

    AutoPlantingTab:Toggle({
        Title = "Auto Planting",
        Desc = "Toggles auto planting on/off.",
        CurrentValue = false,
        Callback = function(Value)
            plantingEnabled = Value
            if Value then
                task.spawn(autoPlant)
                print("Auto planting started.")
            else
                print("Auto planting stopped.")
            end
        end
    })
end

-- Auto Buy Tab Content
do
    local AutoBuyTab = Tabs.AutoBuy

    AutoBuyTab:Paragraph({Title = "Seed Purchase", Desc = "Automatically purchases selected seeds."})

    local buySeedDropdown = AutoBuyTab:Dropdown({
        Title = "Select Seeds to Buy",
        Desc = "Select seeds to auto purchase.",
        Values = {"Carrot", "Strawberry", "Blueberry", "Orange Tulip", "Tomato", "Corn", "Daffodil", "Watermelon", "Pumpkin", "Apple", "Bamboo","Coconut","Cactus","Dragon Fruit","Mango","Grape","Mushroom","Pepper","Cacao","Beanstalk","Ember Lily","Sugar Apple","Burning Bud","Giant Pinecone","Elder Strawbery"},
        Value = {}, -- No selection initially
        Multi = true, -- Allow multiple selection
        AllowNone = true, -- Allow no selection
        Callback = function(Options)
            print("Auto Buy Dropdown Callback triggered! Selected Options: " .. HttpService:JSONEncode(Options))
            EkilexekBuySeed = Options
            print("Auto buying seeds updated: " .. table.concat(Options, ", "))
        end
    })

    if buySeedDropdown then
        print("Auto Buy Seed Dropdown successfully created.")
    else
        warn("Error: Auto Buy Seed Dropdown could not be created.")
    end

    AutoBuyTab:Toggle({
        Title = "Auto Buy",
        Desc = "Toggles auto seed purchasing on/off.",
        CurrentValue = false,
        Callback = function(Value)
            autoBuyEnabled = Value
            if Value then
                task.spawn(autoBuyLoop)
                print("Auto buying started.")
            else
                print("Auto buying stopped.")
            end
        end
    })
end

-- Auto Harvest Content (Now a Tab)
do
    local AutoHarvestTab = Tabs.AutoSection:Tab({ Title = "Auto Harvest", Icon = "pickaxe" }) 

    AutoHarvestTab:Paragraph({Desc = "Automatically harvests ripe plants on your farm."})

    -- Total Plant Count display and its logic removed as per user request
    -- totalPlantCountDisplay = AutoHarvestTab:Paragraph({
    --     Title = "Total Harvestable Plants:",
    --     Desc = "0" -- Initial value
    -- })

    -- Dropdown for selecting harvestable items removed as per user request
    -- local harvestableDropdown = AutoHarvestTab:Dropdown({
    --     Title = "Alınacak Bitkiler",
    --     Desc = "Otomatik hasat edilecek bitki türlerini seçin.",
    --     GetItems = GetAllUniquePlantVariants,
    --     Value = {},
    --     Multi = true,
    --     AllowNone = true,
    --     Callback = function(Options)
    --         print("Alınacak Bitkiler Dropdown Callback tetiklendi! Seçilen Seçenekler: " .. HttpService:JSONEncode(Options))
    --         EkilexekHarvest = Options
    --         print("Otomatik hasat edilecek bitkiler güncellendi: " .. table.concat(Options, ", "))
    --     end
    -- })

    AutoHarvestTab:Toggle({
        Title = "Auto Harvest",
        Desc = "Toggles auto harvesting on/off.",
        CurrentValue = false,
        Callback = function(Value)
            autoHarvestEnabled = Value
            if Value then
                task.spawn(autoHarvest)
                -- Enable Noclip here
                toggleNoclip(true) 
                print("Auto harvest started.")
            else
                -- Disable Noclip here
                toggleNoclip(false) 
                print("Auto harvest stopped.")
                -- if totalPlantCountDisplay then -- Removed as per user request
                --     totalPlantCountDisplay.Desc = "0"
                -- end
            end
        end
    })

    AutoHarvestTab:Divider()
    AutoHarvestTab:Paragraph({Title = "Ignores:"})
    
    -- Create checkboxes for HarvestIgnores
    local function CreateCheckboxes(Parent, Dict: table)
        for Key, Value in pairs(Dict) do
            Parent:Toggle({
                Title = Key, -- Used Title instead of Label
                Type = "Checkbox",
                Value = Value,
                Callback = function(_, newValue)
                    Dict[Key] = newValue
                    print("Harvest ignore setting updated: " .. Key .. " = " .. tostring(newValue))
                end
            })
        end
    end
    CreateCheckboxes(AutoHarvestTab, HarvestIgnores)
end

-- When GUI is closed, clean up
Window:OnClose(function()
    print("UI closed.")
    -- Disable Noclip when script closes
    toggleNoclip(false) 
    -- if totalPlantCountDisplay then -- Removed as per user request
    --     totalPlantCountDisplay.Desc = "0"
    -- end
end)

-- Select the "Information" tab at startup
Window:SelectTab(1) -- "Information" tab is the first created tab, so index 1.

-- Show WindUI notification only if WindUI loaded successfully
if WindUI then
    -- Send notification after GUI is fully loaded and initial data is updated
    task.wait(1) -- Short wait for GUI to fully form
    print(string.format("Script Started! Total Sheckles: %s\nYour Farm ID: %s", currentShecklesAmount, localPlayerFarmId))
end
