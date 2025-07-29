

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local LocalPlayer       = Players.LocalPlayer
local Backpack          = LocalPlayer:WaitForChild("Backpack")
local Character         = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Seçilenler
local EkilexekSeed = {}
local selectedSeeds = {}
local selectedGears = {}
local selectedEggs = {}
local plantingEnabled = false
local plantingPosition = nil
local plantingPart = nil
local boughtSeedsLog = {} -- ["Sugar Apple"] = 3, vs.

-- Farm konumları (farmNumber => pozisyon)
local farmPositions = {
    [4] = Vector3.new(-70.54048156738281, 0.13552704453468323, 87.05094146728516),
    [2] = Vector3.new(68.38848876953125, 0.13552704453468323, 83.08100128173828),
    [3] = Vector3.new(-139.2397918701172, 0.13552704453468323, -112.45325469970703),
    [1] = Vector3.new(-1.9766778945922852, 0.13552704453468323, -113.26812744140625),
    [5] = Vector3.new(-274.8962707519531, 0.13552704453468323, -106.14342498779297),
}

local function tw(tm)
    
    task.wait(tm)
    
end

local function Not(msg)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Notification = ReplicatedStorage.GameEvents.Notification
firesignal(Notification.OnClientEvent, 
    msg
)

end



local SellRemote = game:WaitForChild("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("Sell_Inventory")

local SelRemote =
-- Remote'e boş argüman gönder, hata vermezse argüman istemiyordur
game:WaitForChild("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("Sell_Item")



-- Bildirim fonksiyonu
local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 4,
        })
    end)
end

-- Kendi farm'ını bul (owner == player.name)
local function getOwnFarm()
    local farmFolder = workspace:FindFirstChild("Farm")
    if not farmFolder then
        notify("Hata", "workspace.Farm bulunamadı")
        return nil
    end
    for _, farm in ipairs(farmFolder:GetChildren()) do
        local imp = farm:FindFirstChild("Important")
        local data = imp and imp:FindFirstChild("Data")
        local owner = data and data:FindFirstChild("Owner")
        if owner and owner.Value == LocalPlayer.Name then
            return farm
        end
    end
    notify("Hata", "Sana ait farm bulunamadı")
    return nil
end

-- Elimizde seçilen seed var mı?
local function hasSeedInHand(seedName)
    local tool = Character:FindFirstChildOfClass("Tool")
    return tool and tool.Name:lower():find(seedName:lower() .. " seed")
end

-- Seed tool'u backpack'ten eline al
local function equipSeedTool(seedName)
    for _, tool in ipairs(Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find(seedName:lower() .. " seed") then
            local humanoid = Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(tool)
                notify("Tohum Alındı", "Eline alındı: "..tool.Name)
                return true
            end
        end
    end
    notify("Hata", seedName.." Seed tool bulunamadı")
    return false
end

-- Plant_RE event'i ile ekim yap
local function plantSeed(position, seedName)
    local ge = ReplicatedStorage:FindFirstChild("GameEvents")
    local plantRE = ge and ge:FindFirstChild("Plant_RE")
    if not plantRE or typeof(plantRE.FireServer) ~= "function" then
        notify("Hata", "Plant_RE event bulunamadı")
        return
    end
    plantRE:FireServer(position, seedName)
end

-- Otomatik Tohum Alma
local function autoBuySeeds()
    while true do
        for _, seed in ipairs(selectedSeeds) do
            pcall(function()
                ReplicatedStorage.GameEvents.BuySeedStock:FireServer(seed)
                boughtSeedsLog[seed] = (boughtSeedsLog[seed] or 0) + 1
            end)
            task.wait(0.15)
        end
        task.wait(0.5)
    end
end


-- Otomatik Ekipman Alma
local function autoBuyGears()
    while true do
        for _, gear in ipairs(selectedGears) do
            pcall(function()
                ReplicatedStorage.GameEvents.BuyGearStock:FireServer(gear)
            end)
            task.wait(0.15)
        end
        task.wait(0.5)
    end
end

-- Otomatik Yumurta Alma
local function autoBuyEggs()
    while true do
        for _, egg in ipairs(selectedEggs) do
            pcall(function()
                ReplicatedStorage.GameEvents.BuyEggStock:FireServer(egg)
            end)
            task.wait(0.15)
        end
        task.wait(0.5)
    end
end

-- Otomatik Ekim
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
                        if not equipSeedTool(seed) then break end
                        task.wait(0.3)
                    end
                    plantSeed(pos, seed)
                    task.wait(0.2)
                end
            else
                notify("Uyarı", "Farm_Number " .. tostring(farmNumber) .. " için konum yok")
            end
        else
            notify("Uyarı", "Farm bulunamadı veya tohum seçilmedi")
        end
        task.wait(0.5)
    end
end




-- GUI oluşturma

local Window = Rayfield:CreateWindow({
   Name = "Emocii Hub [GaG]",
   Icon = 0, -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
   LoadingTitle = "Emocii Hub [GaG]",
   LoadingSubtitle = "by Emocii",
   ShowText = "Emocii", -- for mobile users to unhide rayfield, change if you'd like
   Theme = "Default", -- Check https://docs.sirius.menu/rayfield/configuration/themes

   ToggleUIKeybind = "K", -- The keybind to toggle the UI visibility (string like "K" or Enum.KeyCode)

   DisableRayfieldPrompts = true,
   DisableBuildWarnings = false, -- Prevents Rayfield from warning when the script has a version mismatch with the interface

   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil, -- Create a custom folder for your hub/game
      FileName = "Emocii Hub"
   },

   Discord = {
      Enabled = true, -- Prompt the user to join your Discord server if their executor supports it
      Invite = "noinvitelink", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ ABCD would be ABCD
      RememberJoins = true -- Set this to false to make them join the discord every time they load it up
   },

   KeySystem = false, -- Set this to true to use our key system
   KeySettings = {
      Title = "Untitled",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided", -- Use this to tell the user how to get a key
      FileName = "Key", -- It is recommended to use something unique as other scripts using Rayfield may overwrite your key file
      SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
      GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
      Key = {"Hello"} -- List of keys that will be accepted by the system, can be RAW file links (pastebin, github etc) or simple strings ("hello","key22")
   }
})



local RestockTab = Window:CreateTab("🕒 Restock", 4483362458)

-- 1. Paragraf: Timer bilgileri
local TimerParagraph = RestockTab:CreateParagraph({
    Title = "🕒 Mağaza Yenileme Zamanları",
    Content = "Yükleniyor..."
})

-- 2. Paragraf: Tohum Stok bilgileri
local StockParagraph = RestockTab:CreateParagraph({
    Title = "🌱 Tohum Stokları",
    Content = "Yükleniyor..."
})

-- 3. Paragraf: Gear Shop stok bilgileri
local GearStockParagraph = RestockTab:CreateParagraph({
    Title = "🛠️ Gear Shop Stokları",
    Content = "Yükleniyor..."
})

-- 4. Paragraf: Pet Shop stok bilgileri
local PetStockParagraph = RestockTab:CreateParagraph({
    Title = "🐾 Pet Shop Stokları",
    Content = "Yükleniyor..."
})

-- Fonksiyon: Bilgileri güncelle
local function updateRestockInfo()
    while true do
        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

        -- TIMER bilgilerini al
        local function getTimerText(framePath)
            local success, result = pcall(function()
                if framePath and framePath:IsA("TextLabel") then
                    return framePath.Text
                else
                    return "Bulunamadı"
                end
            end)
            return result or "Hata"
        end

        -- Tüm timer değerlerini oku
        local seedTimer = getTimerText(playerGui:FindFirstChild("Seed_Shop") and playerGui.Seed_Shop.Frame.Frame:FindFirstChild("Timer"))
        local petTimer  = getTimerText(playerGui:FindFirstChild("PetShop_UI") and playerGui.PetShop_UI.Frame.Frame:FindFirstChild("Timer"))
        local gearTimer = getTimerText(playerGui:FindFirstChild("Gear_Shop") and playerGui.Gear_Shop.Frame.Frame:FindFirstChild("Timer"))

        -- Paragraf 1: Timer Bilgileri
        TimerParagraph:Set({
            Title = "⏳ Mağaza Yenilenme Süreleri",
            Content = string.format("🌱 Seed Shop: %s\n🐾 Pet Shop: %s\n⚙️ Gear Shop: %s", seedTimer, petTimer, gearTimer)
        })

        -- Paragraf 2: Seed Shop stokları
        local seedStockLines = {}
        local seedFrame = playerGui:FindFirstChild("Seed_Shop") and playerGui.Seed_Shop.Frame:FindFirstChild("ScrollingFrame")
        if seedFrame then
            for _, item in pairs(seedFrame:GetChildren()) do
                if item:IsA("Frame") and item:FindFirstChild("Main_Frame") and item.Main_Frame:FindFirstChild("Stock_Text") then
                    local stockText = item.Main_Frame.Stock_Text.Text
                    table.insert(seedStockLines, "🌾 " .. item.Name .. ": " .. stockText)
                end
            end
        else
            table.insert(seedStockLines, "📦 Seed Shop verisi alınamadı.")
        end

        StockParagraph:Set({
            Title = "🌱 Seed Shop Stokları",
            Content = table.concat(seedStockLines, "\n")
        })

        -- Paragraf 3: Gear Shop stokları
        local gearStockLines = {}
        local gearFrame = playerGui:FindFirstChild("Gear_Shop") and playerGui.Gear_Shop.Frame:FindFirstChild("ScrollingFrame")
        if gearFrame then
            for _, item in pairs(gearFrame:GetChildren()) do
                if item:IsA("Frame") and item:FindFirstChild("Main_Frame") and item.Main_Frame:FindFirstChild("Stock_Text") then
                    local stockText = item.Main_Frame.Stock_Text.Text
                    table.insert(gearStockLines, "🔧 " .. item.Name .. ": " .. stockText)
                end
            end
        else
            table.insert(gearStockLines, "📦 Gear Shop verisi alınamadı.")
        end

        GearStockParagraph:Set({
            Title = "🛠️ Gear Shop Stokları",
            Content = table.concat(gearStockLines, "\n")
        })

        -- Paragraf 4: Pet Shop stokları (özellikle Bug Egg dahil)
        local petStockLines = {}
        local petFrame = playerGui:FindFirstChild("PetShop_UI") and playerGui.PetShop_UI.Frame:FindFirstChild("ScrollingFrame")
        if petFrame then
            for _, item in pairs(petFrame:GetChildren()) do
                if item:IsA("Frame") and item:FindFirstChild("Main_Frame") and item.Main_Frame:FindFirstChild("Stock_Text") then
                    local stockText = item.Main_Frame.Stock_Text.Text
                    table.insert(petStockLines, "🐣 " .. item.Name .. ": " .. stockText)
                end
            end
        else
            table.insert(petStockLines, "📦 Pet Shop verisi alınamadı.")
        end

        PetStockParagraph:Set({
            Title = "🐾 Pet Shop Stokları",
            Content = table.concat(petStockLines, "\n")
        })

        task.wait(1)
    end
end

task.spawn(updateRestockInfo)

local FarmTab = Window:CreateTab("Idk why i add", 4483362458)

FarmTab:CreateButton({
    Name = "Sell İnv",
    Callback = function()
        local player = game.Players.LocalPlayer
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char:WaitForChild("HumanoidRootPart")
        -- 🔒 Eski konumu kaydet
        local originalPos = hrp.Position
        -- 🌀 Yeni konuma ışınla
        hrp.CFrame = CFrame.new(87, 3, 0)
        -- 🔁 Küçük gecikme (teleport tamamlanması için)
        task.wait(0.1)
        -- 🚀 Remote çalıştır (boş argümanlı)
        pcall(function()
            SellRemote:FireServer()
        end)
        -- 🔙 Geri dön
        task.wait(0.4)
        hrp.CFrame = CFrame.new(originalPos)
    end,
})

FarmTab:CreateButton({
    Name = "Sell Single(Need Hold)",
    Callback = function()
        local player = game.Players.LocalPlayer
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char:WaitForChild("HumanoidRootPart")
        -- 🔒 Eski konumu kaydet
        local originalPos = hrp.Position
        -- 🌀 Yeni konuma ışınla
        hrp.CFrame = CFrame.new(87, 3, 0)
        -- 🔁 Küçük gecikme (teleport tamamlanması için)
        task.wait(0.1)
        -- 🚀 Remote çalıştır (boş argümanlı)
        pcall(function()
            SelRemote:FireServer()
        end)
        -- 🔙 Geri dön
        task.wait(0.4)
        hrp.CFrame = CFrame.new(originalPos)
    end,
})


-- Tohumlar tab
local SeedTab = Window:CreateTab("🌱 Seeds", 4483362458)
SeedTab:CreateDropdown({
	Name = "Tohum Seç",
	Options = {"Carrot", "Strawberry", "Blueberry", "Orange Tulip", "Tomato", "Corn", "Daffodil", "Watermelon", "Pumpkin", "Apple", "Bamboo","Coconut","Cactus","Dragon Fruit","Mango","Grape","Mushroom","Pepper","Cacao","Beanstalk","Ember Lily","Sugar Apple","Burning Bud","Giant Pinecone","Elder Strawbery"},
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "SeedDropdown",
	Callback = function(Options)
		selectedSeeds = Options
	end
})

local SeedToggle = SeedTab:CreateToggle({
	Name = "Otomatik Tohum Al",
	CurrentValue = false,
	Flag = "AutoSeed",
	Callback = function(Value)
		if Value then
			task.spawn(autoBuySeeds)
		end
	end,
})

-- Ekipman tab
local GearTab = Window:CreateTab("🛠️ Gear", 4483362458)
GearTab:CreateDropdown({
	Name = "Ekipman Seç",
	Options = {"Watering Can","Trowel","Recall Wrench","Basic Sprinkler","Advanced Sprinkler","Medium Treat","Medium Toy","Godly Sprinkler","Magnifying Glass","Master Sprinkler","Cleaning Spray","Favorite Tool","Harvest Tool","Friendship Pot","Level Up Lollipop"},
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "GearDropdown",
	Callback = function(Options)
		selectedGears = Options
	end
})

local GearToggle = GearTab:CreateToggle({
	Name = "Otomatik Ekipman Al",
	CurrentValue = false,
	Flag = "AutoGear",
	Callback = function(Value)
		if Value then
			task.spawn(autoBuyGears)
		end
	end,
})

-- Yumurtalar tab
local EggTab = Window:CreateTab("🥚 Eggs", 4483362458)
EggTab:CreateDropdown({
	Name = "Yumurta Seç",
	Options = {"Chicken Egg", "Duck Egg"},
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "EggDropdown",
	Callback = function(Options)
		selectedEggs = Options
	end
})

local EggToggle = EggTab:CreateToggle({
	Name = "Otomatik Yumurta Al",
	CurrentValue = false,
	Flag = "AutoEgg",
	Callback = function(Value)
		if Value then
			task.spawn(autoBuyEggs)
		end
	end,
})

-- Ekim tab
local PlantTab = Window:CreateTab("🧪 Planting", 4483362458)
PlantTab:CreateParagraph({Title = "Seçili Konum", Content = "FarmNumber'a göre otomatik konum seçilir."})
PlantTab:CreateDropdown({
	Name = "Tohum Seç",
	Options = {"Carrot", "Strawberry", "Blueberry", "Orange Tulip", "Tomato", "Corn", "Daffodil", "Watermelon", "Pumpkin", "Apple", "Bamboo","Coconut","Cactus","Dragon Fruit","Mango","Grape","Mushroom","Pepper","Cacao","Beanstalk","Ember Lily","Sugar Apple","Burning Bud","Giant Pinecone","Elder Strawbery"},
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "SeedDropdown",
	Callback = function(Options)
		EkilexekSeed = Options
	end
})


PlantTab:CreateToggle({
	Name = "Otomatik Ekim",
	CurrentValue = false,
	Flag = "AutoPlanting",
	Callback = function(Value)
		plantingEnabled = Value
		if Value then
			task.spawn(autoPlant)
		end
	end
})



local CreTab = Window:CreateTab("Help", 4483362458)

local Paragraph = CreTab:CreateParagraph({Title = "Credits", Content = "Owner:Emocii \ngui:Rayfield"})

local Button = CreTab:CreateButton({
   Name = "Copy Gui source",
   Callback = function()
    setclipboard("https://docs.sirius.menu/rayfield")
    toclipboard("https://docs.sirius.menu/rayfield")
       -- The function that takes place when the button is pressed
   end,
})
local Button = CreTab:CreateButton({
   Name = "Copy Owner Dc name ",
   Callback = function()
    setclipboard("bhak._")
    toclipboard("bhak._")
       -- The function that takes place when the button is pressed
   end,
})
local Button = CreTab:CreateButton({
   Name = "copy script",
   Callback = function()
    setclipboard("Dickhead")
    toclipboard("Dickhead")
       -- The function that takes place when the button is pressed
   end,
})

local Label = CreTab:CreateLabel("///////////////////////////////////////////////////////////////////////////////////////////////////////////////", 4483362458, false) -- Title, Icon, Color, IgnoreTheme



local Mutations = {
    {
        name = "Friendbound", x = 70,
        info = {
            "Obtained through Friendship Pots (More pots = higher mutation chance).",
            "Obtained by having 5 friends (connections) in a server.",
            "Pink in color.",
            "Emits pink hearts and stars."
        }
    },
    {
        name = "Sundried", x = 85,
        info = {
            "During a Heatwave or Solar Flare event.",
            "Can redirect with a Tanning Mirror.",
            "Dark brown tint applied"
        }
    },
    {
        name = "Aurora", x = 90,
        info = {
            "Have a chance of applying during Aurora Borealis.",
            "Have a chance to appear during night.",
            "Shifts between blues and purples.",
            "Releases faint smoke.",
            "Purplish, Whitish glow"
        }
    },
    {
        name = "Shocked", x = 100,
        info = {
            "Struck by lightning during Thunderstorm or Jandel Storm",
            "Using the Mutation Spray Shocked",
            "Neon glow"
        }
    },
    {
        name = "Celestial", x = 120,
        info = {
            "During Meteor Shower",
            "Reflective",
            "Sparkling yellow and purple"
        }
    },
    {
        name = "Dawnbound", x = 150,
        info = {
            "During Sun God Event",
            "4 players must hold Sunflowers in front of the Sun God",
            "Also applied by pets with the Ascended mutation",
            "Glowing, electrified look"
        }
    },
    {
        name = "Burnt", x = 4,
        info = {
            "Can be applied by the Cooked Owl pet.",
            "Can be applied by the Mutation Spray Burnt.",
            "Can be applied by the Extinction Weather.",
            "Unharvested: Black in color, Sparking",
            "Harvested: Black in color, Emits ash particles"
        }
    },
    {
        name = "Static", x = 8,
        info = {
            "Obtained from raiju pet after devouring a shocked fruit",
            "Emits yellow electricity particles"
        }
    },
    {
        name = "Amber", x = 10,
        info = {
            "Using Amber Mutation Spray.",
            "Small chance to be applied by the Raptor pet when a fruit is harvested.",
            "Coated in semi-transparent orange overlay, emits orange cloud particles."
        }
    },
    {
        name = "Cooked", x = 10,
        info = {
            "Small chance to be applied by the Cooked Owl pet.",
            "Orange in color.",
            "Emits white steam and red swirls."
        }
    },
    {
        name = "Chakra", x = 15,
        info = {
            "Can be applied by the Kitsune pet when stolen.",
            "Red electric particles around the crop with the red star particle in the handle."
        }
    },
    {
        name = "CorruptChakra", x = 15,
        info = {
            "20.29% chance every 20 minutes from the Corrupted Kitsune",
            "Blue lightning sparks around the plant with blue stars in the middle"
        }
    },
    {
        name = "Tranquil", x = 20,
        info = {
            "Obtained by the Tranquil weather event.",
            "Obtained also by the Tanchozuru when it meditates every 10 minutes.",
            "Obtained also by pets with the Tranquil mutation",
            "Has a white, circular rippling effect.",
            "Words like \"信\", \"命\", \"夢\", and \"氣\" appear."
        }
    },
    {
        name = "OldAmber", x = 20,
        info = {
            "After 24 hours, the Amber mutation will age into OldAmber.",
            "Cannot coexist with any of the other Amber mutation stages.",
            "More orange than its yellow predecessor."
        }
    },
    {
        name = "Corrupt", x = 20,
        info = {
            "Can be applied by the pet that have Corrupted Mutation.",
            "Emits falling red and black particles",
            "Red lightning"
        }
    },
    {
        name = "Zombified", x = 25,
        info = {
            "Can be applied by the Chicken Zombie pet.",
            "Emits a green fog.",
            "Dripping with green liquid."
        }
    },
    {
        name = "HarmonizedChakra", x = 35,
        info = {
            "Requires chakra and corrupted chakra",
            "Magenta rays and lightning streak out of the fruit with stars on the handle.",
            "A faint magenta halo around the crop."
        }
    },
    {
        name = "AncientAmber", x = 50,
        info = {
            "After 2 days, OldAmber will age into AncientAmber.",
            "Orange Particles."
        }
    },
    {
        name = "FoxfireChakra", x = 90,
        info = {
            "Very rare chance to be applied when a fruit is duplicated by the Kitsune pet.",
            "Intense red electric particles around the crop.",
            "Imbues the crop with red flames."
        }
    },
    {
        name = "CorruptFoxfireChakra", x = 90,
        info = {
            "Extremely Rare mutation from the Corrupted Kitsune",
            "Blue lightning sparks around the plant with blue stars in the middle",
            "Imbues the crop with blue flames"
        }
    },
    {
        name = "Paradisal", x = 100,
        info = {
            "Occurs when a plant is both Verdant and Sundried, replaces both mutations.",
            "Lime Green in color",
            "Emits sun ray-like particles."
        }
    },
    {
        name = "Disco", x = 125,
        info = {
            "During a Disco event. (Can be spawned by admins)",
            "Can be applied by the Disco Bee pet and Mutation Disco Spray."
        }
    },
    {
        name = "Heavenly", x = 5,
        info = {
            "During a Jandel float event (Can only be spawned by Admin).",
            "Emits Glow, shining fire from the base."
        }
    },
    {
        name = "Voidtouched", x = 135,
        info = {
            "During a Black Hole event (Can only be spawned by admins).",
            "Emits black hole particles"
        }
    },
    {
        name = "Meteoric", x = 125,
        info = {
            "During a Meteor event (Can only be spawned by admins).",
            "Having golden-yellow particles around the crop."
        }
    },
    {
        name = "Galactic", x = 120,
        info = {
            "During a Space Travel event (Can only be spawned by admins).",
            "Turns the crop a light purple, some parts of the fruit are glowing."
        }
    },
    {
        name = "Infected", x = 75,
        info = {
            "During a Jandel Zombie event.",
            "Emits small, hazy green particles",
            "Completely green in color"
        }
    },
    {
        name = "Jackpot", x = 77,
        info = {
            "Rare mutation from a Money Rain event (Can only be spawned by admins).",
            "Emits falling robux particles",
            "Emits shiny star particles"
        }
    },
    {
        name = "Blitzshock", x = 50,
        info = {
            "Obtained during an Admin weather event exclusive to the Celebrity Guest Event.",
            "Blue tint with neon shine.",
            "Has yellow and blue \"electric\" particles swirling around.",
            "Occasionally emits a blue cloud puff."
        }
    },
    {
        name = "Plasma", x = 5,
        info = {
            "During a Laser Storm.",
            "Neon.",
            "Pinkish purple in color."
        }
    },
    {
        name = "Touchdown", x = 125,
        info = {
            "Given during the Travis Kelce event",
            "Red and orange sparkles spray out of the bottom of the fruit."
        }
    },
    {
        name = "Alienlike", x = 100,
        info = {
            "During the Alien Invasion Event. (Can only be spawned by admins).",
            "Cyan in color",
            "Cyan particles emitted from the fruit",
            "Parts of fruit can be fully transparent/invisible, or be partially transparent."
        }
    },
    {
        name = "Radioactive", x = 80,
        info = {
            "During a Carrot Rocket event",
            "Neon green in color"
        }
    },
    {
        name = "Molten", x = 25,
        info = {
            "During a Volcano event.",
            "Neon.",
            "Orange, yellow and red in color."
        }
    },
    {
        name = "Fried", x = 8,
        info = {
            "During a Fried Chicken event.",
            "Small yellow particles fall from the crop."
        }
    },
    {
        name = "Subzero", x = 50,
        info = {} -- Bilgi eksik
    },
    {
        name = "Cosmic", x = 140,
        info = {
            "A mutation when a comet hits a fruit during the comet event (Can only be spawned by admins).",
            "Unknown (Unreleased)"
        }
    },
    {
        name = "Equinox", x = 165,
        info = {
            "Rare mutation from a Eclipse event (Can only be spawned by admins).",
            "Unknown (Unreleased)"
        }
    },
    {
        name = "Eclipsed", x = 15,
        info = {
            "During Solar Eclipse",
            "Unknown (Unreleased)"
        }
    },
    {
        name = "Wiltproof", x = 4,
        info = {
            "Obtainable in the Drought Weather.",
            "Unknown (Unreleased)"
        }
    },
    {
        name = "Enlightened", x = 35,
        info = {
            "Unknown (Unreleased)"
        }
    },
    {
        name = "Toxic",
        x = 12,
        info = {
            "During Acid Rain",
            "Unknown"
        }
    }
}

-- Mutations tablosu burada tamamlanmıştır.

-- Başta boş paragraf
local Paragraph = CreTab:CreateParagraph({
    Title = "Bilgi",
    Content = "Arama sonuçları burada görünecek."
})

-- Arama kutusu




local AramaKutusu = CreTab:CreateInput({
    Name = "Search Mutation",
    PlaceholderText = "Toxic, Gold, Rainbow, Fried...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local aranacak = string.lower(text)
        local sonuc = ""

        for _, bilgi in pairs(Mutations) do
            local isim = tostring(bilgi.name or "???")
            local carpim = tostring(bilgi.x or "?")
            local aciklama = ""

            if type(bilgi.info) == "table" then
                aciklama = table.concat(bilgi.info, "\n")
            else
                aciklama = tostring(bilgi.info or "-")
            end

            if string.find(string.lower(isim), aranacak) then
                sonuc = sonuc .. "🔸 " .. isim .. " (" .. carpim .. "x multi)\n" .. aciklama .. "\n\n"
            end
        end

        if sonuc == "" then
            sonuc = "❌ Eşleşme bulunamadı."
        end

        Paragraph:Set({
            Title = "Bilgi Sonuçları",
            Content = sonuc
        })
    end
})



local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)

-- Webhook girişi
local WebhookBox = SettingsTab:CreateInput({
   Name = "Webhook URL",
   PlaceholderText = "https://discord.com/api/webhooks/...",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
       getgenv().WebhookURL = Text
       notify("Ayarlandı", "Webhook kaydedildi.")
   end,
})

-- Delay ayarı
local delayValue = 1 -- varsayılan

local DelaySlider = SettingsTab:CreateSlider({
   Name = "Delay (saniye)",
   Range = {0.1, 5},
   Increment = 0.1,
   Suffix = "s",
   CurrentValue = delayValue,
   Flag = "DelayValue",
   Callback = function(Value)
       delayValue = Value
       notify("Delay Ayarlandı", "Delay: " .. tostring(Value) .. " sn")
   end,
})

local HttpService = game:GetService("HttpService")

local function sendWebhook(title, description)
    local url = getgenv().WebhookURL
    if not url or url == "" then return end

    local data = {
        ["content"] = "",
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = description,
            ["color"] = tonumber(0x00ff00),
            ["footer"] = {["text"] = "Emocii Hub"}
        }}
    }

    local encoded = HttpService:JSONEncode(data)

    local requestFunc = (syn and syn.request) or (http and http.request) or (request) or (fluxus and fluxus.request) or (http_request)

    if requestFunc then
        requestFunc({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = encoded
        })
    else
        warn("Executor desteklemiyor.")
        notify("Hata", "Executor webhook desteklemiyor.")
    end
end


SettingsTab:CreateButton({
   Name = "Bilgileri Webhook'a Gönder",
   Callback = function()
       local player = game:GetService("Players").LocalPlayer
       local ls = player:FindFirstChild("leaderstats")
       local sheckles = ls and ls:FindFirstChild("Sheckles") and ls.Sheckles.Value or "?"
       local biome = player:FindFirstChild("Current_Biome") and player.Current_Biome.Value or "?"

       -- Alınan tohumları formatla
       local seedLines = {}
       for seed, count in pairs(boughtSeedsLog) do
           table.insert(seedLines, tostring(count) .. "x " .. seed)
       end
       local boughtSeedsText = (#seedLines > 0) and table.concat(seedLines, "\n") or "Hiç alınmadı"

       local msg = "**Delay:** " .. tostring(delayValue) .. " saniye\n" ..
                   "**Sheckles:** " .. tostring(sheckles) .. "\n" ..
                   "**Biome:** " .. tostring(biome) .. "\n\n" ..
                   "**Alınan Tohumlar:**\n" .. boughtSeedsText

       sendWebhook("Kullanıcı Bilgisi", msg)
       notify("Gönderildi", "Webhook'a bilgi gönderildi.")
   end,
})



tw(30)
Not("Owner of the hub is Emocii")
tw(1)
Not("Owner of the hub is Emocii")
tw(1)
Not("Owner of the hub is Emocii")
tw(1)
Not("Owner of the hub is Emocii")
tw(1)
Not("Owner of the hub is Emocii")





