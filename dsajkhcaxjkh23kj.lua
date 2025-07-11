-- Dịch vụ và module
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local DataService = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DataService"))
local PetRegistry = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("PetRegistry"))
local InventoryService = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("InventoryService"))
local RemoteCollect = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes")).Crops.Collect
local GetFarm = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GetFarm"))
local QuestController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("QuestsController"))
local ActivePetsService = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PetServices"):WaitForChild("ActivePetsService"))
local eggService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetEggService")
local buyEggRemote = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("BuyPetEgg")
local sellRemote = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Sell_Inventory")
local plantRemote = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Plant_RE")
local buySeedRemote = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("BuySeedStock")
local Remove_Item = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Remove_Item")
local DinoMachineEvent = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE")
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local LoadScreenEvent = GameEvents:WaitForChild("LoadScreenEvent")
local FinishLoading = GameEvents:WaitForChild("Finish_Loading")
local SellPetEvent = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("SellPet_RE")
local player = Players.LocalPlayer

-- State để quản lý trạng thái trồng cây hoặc bán
local isPlanting = false
local isSelling = false
local lastSellTime = 0

local function isBlacklisted(petName)
	for _, blacklisted in ipairs(getgenv().Config["Sell Mode"]["Blacklist To Sell Pet"]) do
		if string.find(petName, blacklisted) then
			return true
		end
	end
	return false
end

-- Tìm và bán 1 pet không nằm trong blacklist
local function sellOnePet()
	local petSold = false
	local inventory = player.Backpack:GetChildren()

	for _, item in ipairs(inventory) do
		if item:IsA("Tool") and item:GetAttribute("PET_UUID") then
			local name = item.Name
			if not isBlacklisted(name) then
                item.Parent = player.Character
                task.wait(0.2)
				SellPetEvent:FireServer(item)
				print("Đã bán pet:", name)
				petSold = true
				break
			end
		end
	end

	return petSold
end

local function sellPetIfNeeded()
    local sellConfig = getgenv().Config and getgenv().Config["Sell Mode"]
    if not (sellConfig and sellConfig["Enable"]) then return end

    local inventory = LocalPlayer.Backpack:GetChildren()
    local petCount = 0

    for _, item in ipairs(inventory) do
        if item:IsA("Tool") and item:GetAttribute("PET_UUID") then
            petCount += 1
        end
    end

    print("🐾 Pet hiện tại:", petCount .. "/60")

    local limit = tonumber(sellConfig["Sell Pet With Full Inventory"])
    if petCount >= 60 and limit and limit > 0 then
        for i = 1, limit do
            local success = sellOnePet()
            if not success then
                print("❌ Không còn pet hợp lệ để bán.")
                break
            end
            task.wait(0.2)
        end
    end
end

local function autoFinishLoading()
    LoadScreenEvent:FireServer(LocalPlayer)
    wait(5)
    FinishLoading:FireServer()
end

-- Lock FPS
local function lockFPS()
    local cfg = getgenv().Config and getgenv().Config["Lock FPS"]
    if not cfg or not cfg.Enable then return end

    local fps = tonumber(cfg["FPS Need Lock"]) or 5

    if setfpscap then
        setfpscap(fps)
        print("Đã đặt FPS cap là:", fps)
    else
        warn("Error To Lock FPS CAP")
    end
end

-- BoostFPS
local function boostFPS()
    if not getgenv().Config["Boost FPS"] then return end

    -- Cài đặt nâng cao
    local Settings = {
        Graphics = true,
        Lighting = true,
        Texture = true,
        Terrain = true,
        Effects = true
    }

    local sethiddenproperty = sethiddenproperty or set_hidden_property or set_hidden_prop
    local Lighting = game:GetService("Lighting")
    local Terrain = workspace.Terrain

    -- Render Settings
    if settings then
        local RenderSettings = settings():GetService("RenderSettings")
        local UserGameSettings = UserSettings():GetService("UserGameSettings")

        if Settings.Graphics then
            RenderSettings.EagerBulkExecution = false
            RenderSettings.QualityLevel = Enum.QualityLevel.Level01
            RenderSettings.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
            UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
            workspace.InterpolationThrottling = Enum.InterpolationThrottlingMode.Enabled
        end
    end

    -- Lighting
    if Settings.Lighting then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e9
        Lighting.Brightness = 0

        if sethiddenproperty then
            pcall(sethiddenproperty, Lighting, "Technology", Enum.Technology.Compatibility)
        end
    end

    -- Texture
    if Settings.Texture then
        workspace.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled

        if sethiddenproperty then
            pcall(sethiddenproperty, workspace, "MeshPartHeads", Enum.MeshPartHeads.Disabled)
        end
    end

    -- Terrain
    if Settings.Terrain then
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
        Terrain.WaterTransparency = 0

        if sethiddenproperty then
            pcall(sethiddenproperty, Terrain, "Decoration", false)
        end
    end

    -- Tắt các hiệu ứng gây lag
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("Sky") and Settings.Texture then
            obj.StarCount = 0
            obj.CelestialBodiesShown = false
        elseif obj:IsA("BasePart") and Settings.Texture then
            obj.Material = Enum.Material.SmoothPlastic
        elseif obj:IsA("BasePart") and Settings.Lighting then
            obj.CastShadow = false
        elseif obj:IsA("Atmosphere") and Settings.Lighting then
            obj.Density = 0
            obj.Offset = 0
            obj.Glare = 0
            obj.Haze = 0
        elseif obj:IsA("SurfaceAppearance") and Settings.Texture then
            obj:Destroy()
        elseif (obj:IsA("Decal") or obj:IsA("Texture")) and obj.Parent.Name:lower() ~= "head" and Settings.Texture then
            obj.Transparency = 1
        elseif (obj:IsA("ParticleEmitter") or obj:IsA("Sparkles") or obj:IsA("Smoke") or obj:IsA("Trail") or obj:IsA("Fire")) and Settings.Effects then
            obj.Enabled = false
        elseif (obj:IsA("ColorCorrectionEffect") or obj:IsA("DepthOfFieldEffect") or obj:IsA("SunRaysEffect") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect")) and Settings.Lighting then
            obj.Enabled = false
        elseif obj:IsA("Sound") then
            obj.Volume = 0
            obj:Stop()
        end
    end

    print("🚀 Boost FPS nâng cao đã được bật thành công!")
end

-- Black Screen 
local function updateScreenAppearance()
    if not getgenv().Config["Black Screen"] then
        local screenGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("ScreenEffectGui")
        if screenGui then
            screenGui:Destroy()
            print("🟥 Đã xóa hiệu ứng màn hình")
        end
        return
    end

    local function CleanPetName(rawName)
        return rawName:match("^(.-)%s*%[") or rawName
    end

    local petList = {
        "Queen Bee", "Red Fox", "Dragonfly", "Raccoon", "Disco Bee", "Butterfly",
        "Mimic Octopus", "Meerkat", "Sand Snake", "Fennec Fox", "Bunny",
        "Hyacinth Macaw", "Hamster", "Golden Lab", "T-Rex"
    }

    local trackedPets = {}
    for _, name in ipairs(petList) do
        trackedPets[name] = true
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        warn("⚠️ Không tìm thấy PlayerGui")
        return
    end

    local screenGui = playerGui:FindFirstChild("ScreenEffectGui")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "ScreenEffectGui"
        screenGui.Parent = playerGui
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screenGui.IgnoreGuiInset = true
    end

    local frame = screenGui:FindFirstChild("BackgroundFrame")
    if not frame then
        frame = Instance.new("Frame")
        frame.Name = "BackgroundFrame"
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.Position = UDim2.new(0, 0, 0, 0)
        frame.BackgroundTransparency = 0
        frame.BorderSizePixel = 10
        frame.BorderColor3 = Color3.fromRGB(255, 255, 0)
        frame.ZIndex = 1000
        frame.Parent = screenGui
    end

    local hasTrackedPet = false
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local cleanName = CleanPetName(tool.Name)
            if trackedPets[cleanName] then
                hasTrackedPet = true
                break
            end
        end
    end

    if hasTrackedPet then
        frame.BackgroundColor3 = Color3.fromRGB(128, 0, 128) -- Màu tím
        print("🟣 Màn hình đổi tím: phát hiện pet hiếm")
    else
        frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Màu đen
        print("⚫ Màn hình đen: không có pet hiếm")
    end
end

-- Luồng kiểm tra liên tục
task.spawn(function()
    while true do
        updateScreenAppearance()
        task.wait(1)
    end
end)

-- Hàm tìm farm của người chơi
local function findPlayerFarm()
    for _, farm in pairs(Workspace.Farm:GetChildren()) do
        local data = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Data")
        if data and data:FindFirstChild("Owner") and data.Owner.Value == LocalPlayer.Name then
            return farm
        end
    end
    warn("⚠️ Không tìm thấy farm của người chơi")
    return nil
end

-- Hàm lấy số Sheckles
local function getSheckles()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local sheckles = leaderstats and leaderstats:FindFirstChild("Sheckles")
    return sheckles and sheckles.Value or 0
end

-- Hàm loại bỏ [1.80 KG] khỏi tên
local function CleanPetName(rawName)
    return rawName:match("^(.-)%s*%[") or rawName
end

-- Hàm gửi webhook
local function sendPetWebhook(petType)
    local config = getgenv().Config
    if not config or not config.Webhook or not config.Webhook.Enable then return end
    local urls = config.Webhook.Url or {}
    local username = LocalPlayer.Name
    local sheckles = getSheckles()

    local httpRequest = syn and syn.request or http_request or request
    if not httpRequest then
        warn("❌ Không tìm thấy hàm gửi HTTP request.")
        return
    end

    for _, url in ipairs(urls) do
        local data = {
            content = "@everyone",
            embeds = {{
                title = "Sigma Hub Kaitun | Grow Of Garden",
                description = "A new pet has been obtained in the your garden!",
                color = 0x800080,
                fields = {
                    { name = "Username", value = "```" .. username .. "```", inline = false },
                    { name = "Money", value = "```" .. tostring(sheckles) .. "```", inline = false },
                    { name = "Pet", value = "```" .. petType .. "```", inline = false }
                }
            }}
        }
        local success, err = pcall(function()
            httpRequest({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(data)
            })
        end)
        if success then
            print("📤 Đã gửi webhook cho pet:", petType)
        else
            warn("❌ Gửi webhook thất bại:", err)
        end
    end
end

-- Hàm kiểm tra pet đang trang bị
local function printEquippedPets()
    local PetUtilities = require(ReplicatedStorage.Modules.PetServices.PetUtilities)
    local data = DataService:GetData()
    if not data or not data.PetsData then
        warn("⚠️ Không thể lấy dữ liệu PetsData.")
        return 0
    end

    local equippedPets = data.PetsData.EquippedPets or {}
    local maxSlots = data.PetsData.MutableStats and data.PetsData.MutableStats.MaxEquippedPets or 3

    print("📦 Pet đang trang bị: " .. #equippedPets .. "/" .. maxSlots)
    local sortedPets = PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
    for _, pet in pairs(sortedPets) do
        if equippedPets[pet.UUID] then
            local petName = pet.PetData.Name or "Unnamed"
            local petType = pet.PetType or "Unknown"
            local petLevel = pet.PetData.Level or 0
            print(string.format("🐾 %s | Type: %s | Level: %s", petName, petType, petLevel))
        end
    end
    return #equippedPets, maxSlots
end

-- Equip Pets
local function equipPets()
    if not getgenv().Config["Equip Pets"] or not getgenv().Config["Equip Pets"].Enable then
        print("⚠️ Tính năng Equip Pets đang tắt.")
        return
    end

    local equippedCount, maxSlots = printEquippedPets()
    if equippedCount >= maxSlots then
        print("✅ Đã trang bị đủ " .. equippedCount .. "/" .. maxSlots .. " pet. Bỏ qua equip.")
        return
    end

    local petsToEquip = getgenv().Config["Equip Pets"]["List Pet Need Equip"] or {}
    local farm = findPlayerFarm()
    if not farm then return end
    local centerPoint = farm:FindFirstChild("Center_Point")
    if not centerPoint then
        warn("❌ Không tìm thấy Center_Point trong farm")
        return
    end

    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local cleanName = CleanPetName(tool.Name)
            for _, wantedPet in ipairs(petsToEquip) do
                if cleanName == wantedPet then
                    print("✅ Tìm thấy pet phù hợp: " .. tool.Name)
                    LocalPlayer.Character.Humanoid:EquipTool(tool)
                    local uuid = tool:GetAttribute("PET_UUID")
                    if not uuid then
                        warn("❌ Không tìm thấy PET_UUID trong pet: " .. tool.Name)
                        return
                    end
                    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                    local hrp = character:WaitForChild("HumanoidRootPart")
                    hrp.CFrame = centerPoint.CFrame
                    local args = { [1] = "EquipPet", [2] = uuid, [3] = centerPoint.CFrame }
                    ReplicatedStorage.GameEvents.PetsService:FireServer(unpack(args))
                    print("🚀 Đã gửi yêu cầu EquipPet với UUID: " .. uuid)
                    return
                end
            end
        end
    end
    print("⚠️ Không tìm thấy pet phù hợp để equip.")
end

-- Craft Dino Egg
local function craftDinoEgg()
    local craftConfig = getgenv().Config["Craft"] and getgenv().Config["Craft"]["Craft Dino Egg"]
    if not craftConfig or not craftConfig["Enable"] then
        warn("⚠️ Tính năng Craft Dino Egg chưa được bật.")
        return
    end

    print("📦 Danh sách pet trong Backpack:")
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            print("- " .. tool.Name)
        end
    end

    local blacklistMap = {}
    for _, petName in ipairs(craftConfig["Pet Blacklist To Craft"] or {}) do
        blacklistMap[petName] = true
    end

    local validPetNames = {}
    for petName, _ in pairs(PetRegistry.PetList) do
        validPetNames[petName] = true
        print("🐾 Pet trong PetRegistry:", petName)
    end

    local function extractPetName(fullName)
        return fullName:match("^[^%[]+"):gsub("%s+$", "")
    end

    local function isValidPet(tool)
        if not tool:IsA("Tool") or tool.Name:lower():find("shovel") then return false end
        local baseName = extractPetName(tool.Name)
        if not validPetNames[baseName] then
            print("🚫 Pet không có trong PetRegistry:", baseName)
            return false
        end
        if blacklistMap[baseName] then
            print("🚫 Pet trong blacklist:", baseName)
            return false
        end
        print("✅ Pet hợp lệ:", baseName)
        return true
    end

    local function CraftPet()
        local backpack = LocalPlayer:WaitForChild("Backpack")
        for _, tool in ipairs(backpack:GetChildren()) do
            if isValidPet(tool) then
                LocalPlayer.Character.Humanoid:EquipTool(tool)
                print("⚙️ Đang craft bằng pet:", tool.Name)
                local args = { [1] = "MachineInteract" }
                DinoMachineEvent:FireServer(unpack(args))
                return true
            end
        end
        print("❌ Không còn pet hợp lệ để craft.")
        return false
    end

    local function ClaimReward()
        print("🎁 Nhận phần thưởng...")
        local args = { [1] = "ClaimReward" }
        DinoMachineEvent:FireServer(unpack(args))
    end

    task.spawn(function()
        while true do
            if not craftConfig["Enable"] then break end
            local data = DataService:GetData()
            print("📊 DataService:GetData():", data)
            local machine = data and data.DinoMachine
            if not machine then
                warn("⚠️ Không tìm thấy DinoMachine.")
                task.wait(5)
                continue
            end
            print("🔍 Trạng thái DinoMachine: IsRunning=", machine.IsRunning, "RewardReady=", machine.RewardReady)
            if machine.RewardReady then
                ClaimReward()
                task.wait(2)
            end
            if not machine.IsRunning then
                local crafted = CraftPet()
                if not crafted then
                    print("⏳ Không có pet hợp lệ, thử lại sau 5 giây...")
                    task.wait(5)
                else
                    task.wait(2)
                end
            else
                print("⏳ DinoMachine đang chạy, chờ...")
                task.wait(5)
            end
        end
    end)
end

-- Buy and Place Eggs
local function buyAndPlaceEggs()
    local buyEggConfig = getgenv().Config and getgenv().Config["Buy Egg"]
    if not buyEggConfig then
        warn("⚠️ Không có cấu hình Buy Egg.")
        return
    end
    local PetEggData = require(game:GetService("ReplicatedStorage").Data.PetEggData)
    local function getEggStockMap()
        local result = {}
        local data = DataService:GetData()
        if data and data.PetEggStock and data.PetEggStock.Stocks then
            for _, eggInfo in pairs(data.PetEggStock.Stocks) do
                result[eggInfo.EggName] = eggInfo.Stock or 0
            end
        end
        return result
    end

    local function gne(n)
        local f = Workspace.NPCS["Pet Stand"].EggLocations:GetChildren()
        local l, r = {}, {}
        for _, v in ipairs(f) do
            if v.Name:lower():find("egg") then table.insert(l, v.Name) end
        end
        n = n:lower()
        for i, name in ipairs(l) do
            if name:lower() == n then table.insert(r, i) end
        end
        return r
    end

    local function getPlacedEggCount(farm)
        if not farm then return 0 end
        local obj = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Objects_Physical")
        return obj and #obj:GetChildren() or 0
    end

    task.spawn(function()
        while true do
            local stockMap = getEggStockMap()
            local farm = findPlayerFarm()
            local mySheckles = game:GetService("Players").LocalPlayer:WaitForChild("leaderstats"):WaitForChild("Sheckles").Value

            for eggName, cfg in pairs(buyEggConfig) do
                local stock = stockMap[eggName] or 0
                local eggData = PetEggData[eggName]
                local price = eggData and eggData.Price or math.huge

                if cfg["Buy"] and stock > 0 then
                    if mySheckles < price then
                        warn("💸 Không đủ tiền mua trứng", eggName, "- Cần:", price, ", Có:", mySheckles)
                    else
                        print("🛒 Còn", stock, "trứng", eggName, "- Mua...")
                        local indexes = gne(eggName)
                        for _, idx in ipairs(indexes) do
                            buyEggRemote:FireServer(idx)
                            print("🥚 Đã mua trứng", eggName, "tại Index:", idx)
                            task.wait(0.3)
                        end

                        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            root.CFrame = CFrame.new(Vector3.new(-283.248, 3.000, 7.565))
                            print("🚶‍♂️ Teleport đến khu đặt trứng")
                            task.wait(0.5)
                        end
                    end
                elseif cfg["Buy"] and stock <= 0 then
                    print("❌ Trứng", eggName, "hết hàng.")
                end

                if cfg["Place"] and farm then
                    local plantLocation = farm.Important:FindFirstChild("Plant_Locations")
                    plantLocation = plantLocation and plantLocation:GetChildren()[2]
                    if not plantLocation then
                        warn("❌ Không tìm thấy Plant_Locations[2]")
                        continue
                    end
                    local placed = getPlacedEggCount(farm)
                    if placed >= 3 then
                        print("✅ Đã đủ 3/3 trứng", eggName)
                    else
                        local toolToUse = nil
                        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                            if tool:IsA("Tool") and tool.Name:find("Egg x") then
                                local toolEggName, _ = tool.Name:match("^(.-) x(%d+)$")
                                if toolEggName and toolEggName:lower() == eggName:lower() then
                                    toolToUse = tool
                                    break
                                end
                            end
                        end
                        if not toolToUse then
                            warn("⚠️ Không tìm thấy tool trứng", eggName)
                            continue
                        end

                        local offsets = {
                            Vector3.new(0, 0, -10),
                            Vector3.new(0, 0, -3),
                            Vector3.new(0, 0, 4),
                            Vector3.new(0, 0, 11)
                        }

                        local toPlace = 3 - placed
                        print("🌱 Cần đặt thêm", toPlace, "trứng", eggName)

                        for i = 1, toPlace do
                            local offset = offsets[i]
                            if not offset then break end
                            local pos = plantLocation.Position + offset
                            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if root then
                                root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                                task.wait(0.3)
                            end
                            pcall(function()
                                toolToUse.Parent = LocalPlayer.Character
                                task.wait(0.2)
                            end)
                            eggService:FireServer("CreateEgg", pos)
                            print("✅ Đã đặt trứng tại:", tostring(pos))
                            task.wait(0.5)
                            pcall(function()
                                toolToUse.Parent = LocalPlayer.Backpack
                            end)
                            placed = getPlacedEggCount(farm)
                            if placed >= 3 then
                                print("✅ Đã đủ 3/3 trứng", eggName)
                                break
                            end
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end

-- Hatch Pet
local function hatchPetLoop()
    task.spawn(function()
        while true do
            local farm = findPlayerFarm()
            if farm then
                local objects = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Objects_Physical")
                if objects and objects:FindFirstChild("PetEgg") then
                    local petEgg = objects:FindFirstChild("PetEgg")
                    local beforePets = {}
                    local currentData = DataService:GetData()
                    if currentData and currentData.PetsData then
                        local inventory = currentData.PetsData.PetInventory.Data
                        for uuid in pairs(inventory) do
                            beforePets[uuid] = true
                        end
                    end
                    local args = { "HatchPet", petEgg }
                    eggService:FireServer(unpack(args))
                    print("✅ Đã gửi yêu cầu ấp trứng:", petEgg.Name)
                    task.wait(2)
                    local afterPets = DataService:GetData().PetsData.PetInventory.Data
                    for uuid, pet in pairs(afterPets) do
                        if not beforePets[uuid] then
                            local petType = pet.PetType or "Unknown"
                            print("🎉 Pet vừa nở:", petType, "(UUID:", uuid, ")")
                            local sendList = getgenv().Config and getgenv().Config.PetSendWebhook or {}
                            for _, name in ipairs(sendList) do
                                if name == petType then
                                    sendPetWebhook(petType)
                                    break
                                end
                            end
                        end
                    end
                else
                    print("❌ Không tìm thấy PetEgg trong farm.")
                end
            else
                print("❌ Không tìm thấy farm của người chơi.")
            end
            task.wait(30)
        end
    end)
end

-- Destroy Trees
local function removeTrees()
    local config = getgenv().Config["Destroy Mode"]
    if not config or not config["Enable"] then
        print("⚠️ Destroy Mode đang tắt.")
        return
    end

    local shecklesValue = getSheckles()
    local moneyThreshold = config["Auto Destroy when have money"] or 1000000
    if shecklesValue < moneyThreshold then
        print("⚠️ Sheckles:", shecklesValue, "<", moneyThreshold, "→ Không xóa cây")
        return
    end

    local farm = findPlayerFarm()
    if not farm then return end

    print("✅ Đã tìm thấy farm của người chơi", LocalPlayer.Name)
    local treesToDestroy = config["Trees"]
    local candidates = {}

    for _, model in ipairs(farm:GetDescendants()) do
        if model:IsA("Model") and CollectionService:HasTag(model, "Growable") and table.find(treesToDestroy, model.Name) then
            if not model:GetAttribute("Favorited") then
                local hasFavoritedFruit = false
                local fruits = model:FindFirstChild("Fruits")
                if fruits then
                    for _, fruit in ipairs(fruits:GetChildren()) do
                        if fruit:GetAttribute("Favorited") then
                            hasFavoritedFruit = true
                            break
                        end
                    end
                end
                if not hasFavoritedFruit then
                    table.insert(candidates, model)
                end
            end
        end
    end

    if #candidates == 0 then
        print("✅ Không có cây nào hợp lệ để xóa.")
        return
    end

    local shovelTool = LocalPlayer.Backpack:FindFirstChild("Shovel [Destroy Plants]")
    if shovelTool and LocalPlayer.Character then
        pcall(function()
            shovelTool.Parent = LocalPlayer.Character
            print("🛠️ Đã cầm Shovel [Destroy Plants]")
            task.wait(0.2)
        end)
    else
        warn("⚠️ Không tìm thấy Shovel [Destroy Plants] trong Backpack")
        return
    end

    for _, model in ipairs(candidates) do
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if rootPart and model.PrimaryPart then
            rootPart.CFrame = model.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
            print("🚶‍♂️ Đã teleport tới cây:", model.Name)
            task.wait(0.3)
        elseif rootPart and model:FindFirstChild("Base") then
            rootPart.CFrame = model.Base.CFrame + Vector3.new(0, 3, 0)
            print("🚶‍♂️ Đã teleport tới cây (Base):", model.Name)
            task.wait(0.3)
        end
        Remove_Item:FireServer(model)
        print("❌ Đã xóa cây", model.Name)
        task.wait(0.2)
    end
end

-- Plant Seeds
local function plantSeeds()
    if isSelling then
        print("⏳ Đang bán, tạm dừng trồng cây...")
        return
    end
    isPlanting = true

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack or not plantRemote then
        warn("⚠️ Không tìm thấy Backpack hoặc Plant_RE")
        isPlanting = false
        return
    end

    local farm = findPlayerFarm()
    if not farm then
        isPlanting = false
        return
    end

    local centerPoint = farm:FindFirstChild("Center_Point")
    if centerPoint then
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(centerPoint.Position + Vector3.new(0, 3, 0))
            print("🚶‍♂️ Teleport đến khu trồng cây")
            task.wait(0.5)
        end
    end

    local plantLocations = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Plant_Locations")
    if not plantLocations then
        warn("⚠️ Không tìm thấy Plant_Locations")
        isPlanting = false
        return
    end

    local positionPart = plantLocations:GetChildren()[2]
    if not positionPart then
        warn("⚠️ Không tìm thấy vị trí trồng cây thứ 2")
        isPlanting = false
        return
    end

    local plantPosition = positionPart.CFrame.Position
    local hasPlanted = false
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:match("Seed %[X%d+%]") then
            local toolName = tool.Name
            local fullName = toolName:match("(.+) %[X%d+%]")
            local seedName = fullName and fullName:gsub(" Seed$", "")
            local initialCount = tonumber(toolName:match("%[X(%d+)%]"))

            if not seedName or not initialCount then continue end
            local successEquip = pcall(function()
                tool.Parent = LocalPlayer.Character
                task.wait(0.1)
            end)
            if not successEquip then continue end

            local plantedCount = 0
            while plantedCount < initialCount do
                plantRemote:FireServer(plantPosition, seedName)
                task.wait(0.5)
                toolName = tool.Name
                local updatedCount = tonumber(toolName:match("%[X(%d+)%]")) or 0
                if updatedCount < (initialCount - plantedCount) then
                    plantedCount = initialCount - updatedCount
                    print("✅ Đã trồng seed:", seedName)
                    hasPlanted = true
                else
                    warn("❌ Không thể trồng seed:", seedName)
                    break
                end
            end
            if tool and tool.Parent then
                pcall(function()
                    tool.Parent = backpack
                end)
            end
        end
    end
    if hasPlanted then
        print("🌱 Đã hoàn tất trồng cây")
    else
        print("⚠️ Không có seed để trồng")
    end
    isPlanting = false
end

local function buyAllSeeds()
    if isSelling then
        print("⏳ Đang bán, tạm dừng mua seed...")
        return
    end
    isPlanting = true

    local shecklesValue = getSheckles()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local shop = playerGui and playerGui:FindFirstChild("Seed_Shop")
    local frame = shop and shop:FindFirstChild("Frame")
    local scrollingFrame = frame and frame:FindFirstChild("ScrollingFrame")
    if not scrollingFrame or not buySeedRemote then
        warn("⚠️ Không tìm thấy Seed_Shop hoặc buySeedRemote, thử lại sau 5 giây...")
        task.wait(5)
        isPlanting = false
        return
    end

    local hasBought = false
    local affordableSeeds = {}

    -- Lấy danh sách seed, stock và giá từ Cost_Text, bỏ qua _Padding
    for _, seed in pairs(scrollingFrame:GetChildren()) do
        if not seed.Name:match("_Padding") then -- Chỉ lấy seed không chứa _Padding
            local mainFrame = seed:FindFirstChild("Main_Frame")
            local costText = mainFrame and mainFrame:FindFirstChild("Cost_Text")
            local stockText = mainFrame and mainFrame:FindFirstChild("Stock_Text")
            if costText and costText:IsA("TextLabel") and stockText and stockText:IsA("TextLabel") then
                local stockString = stockText.Text:match("X(%d+) Stock") or "0"
                local stockNumber = tonumber(stockString) or 0
                local costString = nil
                if costText.Text and costText.Text ~= "" then
                    costString = costText.Text:match("(%d+[%,]?%d*)¢") or costText.Text:match("(%d+[%,]?%d*)")
                else
                    warn("⚠️ CostText.Text rỗng hoặc không hợp lệ cho seed:", seed.Name)
                end
                local cost = math.huge -- Giá trị mặc định
                if costString and type(costString) == "string" then
                    local cleanedCost = costString:gsub("[^%d]", "") -- Loại bỏ tất cả ký tự không phải số
                    cost = tonumber(cleanedCost) or math.huge -- Chuyển thành số
                    print("📊 Debug - CostString:", costString, "CleanedCost:", cleanedCost, "Cost:", cost)
                else
                    warn("⚠️ CostString không hợp lệ cho seed:", seed.Name, "Giá mặc định:", cost)
                end
                if stockNumber > 0 and cost <= shecklesValue then
                    affordableSeeds[seed.Name] = { cost = cost, stock = stockNumber }
                    print("📊 Seed khả dụng:", seed.Name, "Giá:", cost, "Stock:", stockNumber)
                end
            else
                warn("⚠️ Không tìm thấy Cost_Text hoặc Stock_Text cho seed:", seed.Name)
            end
        end
    end

    if next(affordableSeeds) == nil then
        print("⚠️ Không tìm thấy seed nào khả dụng với Sheckles hiện tại:", shecklesValue)
        isPlanting = false
        return
    end

    -- Sắp xếp theo giá tăng dần để mua seed rẻ nhất trước
    local sortedSeeds = {}
    for seedName, info in pairs(affordableSeeds) do
        table.insert(sortedSeeds, { name = seedName, cost = info.cost, stock = info.stock })
    end
    table.sort(sortedSeeds, function(a, b) return a.cost < b.cost end)

    -- Mua seed có giá thấp hơn hoặc bằng shecklesValue
    for _, seedInfo in ipairs(sortedSeeds) do
        local seedName = seedInfo.name
        local cost = seedInfo.cost
        local stock = seedInfo.stock
        while stock > 0 and shecklesValue >= cost do
            buySeedRemote:FireServer(seedName)
            task.wait(0.5)
            shecklesValue = getSheckles() -- Cập nhật số tiền sau mỗi lần mua
            stock = stock - 1
            hasBought = true
            print("🛒 Đã mua seed:", seedName, "Giá:", cost, "Sheckles còn lại:", shecklesValue)
        end
    end

    if hasBought then
        print("🛒 Đã mua seed thành công")
    else
        print("⚠️ Không mua được seed (hết stock hoặc không đủ tiền)")
    end
    isPlanting = false
end

local function collectAll()
    local lastSellTime = 0
    if isPlanting then
        print("⏳ Đang trồng cây, tạm dừng thu hoạch và bán...")
        return
    end

    local currentTime = tick()
    if currentTime - lastSellTime < 35 and #CollectionService:GetTagged("CollectPrompt") == 0 then
        print("⏳ Chưa đủ 35 giây kể từ lần bán cuối hoặc không có cây để thu hoạch, bỏ qua...")
        return
    end

    isSelling = true
    local myFarm = GetFarm(LocalPlayer)
    if not myFarm then
        warn("⚠️ Không tìm thấy farm của người chơi")
        isSelling = false
        return
    end

    -- Thu hoạch cây
    local toSend = {}
    for _, prompt in ipairs(CollectionService:GetTagged("CollectPrompt")) do
        if prompt:IsDescendantOf(myFarm) and prompt:GetAttribute("Collected") ~= true and prompt.Enabled then
            prompt:SetAttribute("Collected", true)
            task.delay(1, function()
                if prompt then prompt:SetAttribute("Collected", nil) end
            end)
            local plantModel = prompt.Parent and prompt.Parent.Parent
            if plantModel then
                table.insert(toSend, plantModel)
            end
        end
    end
    if #toSend > 0 then
        RemoteCollect.send(toSend)
        print("🌾 Đã thu hoạch", #toSend, "cây")
    end

    -- Bán inventory nếu có thu hoạch hoặc đủ 35 giây
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and (#toSend > 0 or currentTime - lastSellTime >= 35) then
        hrp.CFrame = CFrame.new(86.585, 3.000, 0.427)
        print("🚶‍♂️ Teleport đến khu bán")
        task.wait(0.5)
        sellRemote:FireServer()
        print("💰 Đã bán inventory")
        lastSellTime = currentTime -- Cập nhật thời gian bán cuối cùng
    elseif #toSend == 0 then
        print("⚠️ Không có cây để thu hoạch, bỏ qua bán")
    end

    isSelling = false
end

local function manageFarmCycle()
    local config = getgenv().Config or {}
    local stopFarmConfig = config["Stop Farm"] or {}
    local stopFarmEnabled = stopFarmConfig["Enable"] or false
    local stopFarmThreshold = stopFarmConfig["Stop Farming When Money"] or math.huge

    local shecklesValue = getSheckles()
    if stopFarmEnabled and shecklesValue >= stopFarmThreshold then
        print("⏹️ Đã đạt giới hạn Sheckles:", shecklesValue, "Dừng mọi hoạt động farm!")
        return -- Dừng toàn bộ chu trình nếu đạt ngưỡng
    end

    local canBuySeeds = false
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local shop = playerGui and playerGui:FindFirstChild("Seed_Shop")
    if shop then
        local frame = shop:FindFirstChild("Frame")
        local scrollingFrame = frame and frame:FindFirstChild("ScrollingFrame")
        if scrollingFrame then
            for _, seed in pairs(scrollingFrame:GetChildren()) do
                if not seed.Name:match("_Padding") then -- Chỉ lấy seed không chứa _Padding
                    local mainFrame = seed:FindFirstChild("Main_Frame")
                    local costText = mainFrame and mainFrame:FindFirstChild("Cost_Text")
                    local stockText = mainFrame and mainFrame:FindFirstChild("Stock_Text")
                    if costText and costText:IsA("TextLabel") and stockText and stockText:IsA("TextLabel") then
                        local stockString = stockText.Text:match("X(%d+) Stock") or "0"
                        local stockNumber = tonumber(stockString) or 0
                        local costString = nil
                        if costText.Text and costText.Text ~= "" then
                            costString = costText.Text:match("(%d+[%,]?%d*)¢") or costText.Text:match("(%d+[%,]?%d*)")
                        else
                            warn("⚠️ CostText.Text rỗng hoặc không hợp lệ cho seed:", seed.Name)
                        end
                        local cost = math.huge
                        if costString and type(costString) == "string" then
                            local cleanedCost = costString:gsub("[^%d]", "") -- Loại bỏ tất cả ký tự không phải số
                            cost = tonumber(cleanedCost) or math.huge
                            print("📊 Debug - CostString:", costString, "CleanedCost:", cleanedCost, "Cost:", cost)
                        end
                        print("📊 Giá seed:", seed.Name, "Giá:", cost, "Stock:", stockNumber)
                        if stockNumber > 0 and shecklesValue >= cost then
                            canBuySeeds = true
                            break
                        end
                    end
                end
            end
        end
    end

    if canBuySeeds then
        print("🛒 Có thể mua seed, thực hiện mua...")
        buyAllSeeds()
        if not isSelling then
            plantSeeds()
        end
    else
        print("⚠️ Không đủ tiền hoặc hết stock seed, chuyển sang trồng/thu hoạch...")
        if not isSelling then
            plantSeeds()
        end
        local currentTime = tick()
        if not isPlanting and (currentTime - lastSellTime >= 35 or #CollectionService:GetTagged("CollectPrompt") > 0) then
            collectAll()
        end
    end
end

-- Main Loop
task.spawn(function()
    while true do
        print("🔄 Chạy vòng lặp chính...")
        local shecklesValue = getSheckles()
        print("💰 Sheckles:", shecklesValue)

        if shecklesValue <= 20 then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(86.59, 3.00, -27.00)
                print("🚶‍♂️ Teleport do Sheckles thấp")
            end
        end

        -- Thực hiện các chức năng khác
        sellPetIfNeeded()
        equipPets()
        craftDinoEgg()
        buyAndPlaceEggs()
        hatchPetLoop()
        removeTrees()

        -- Gọi hàm quản lý chu trình
        local config = getgenv().Config or {}
        local stopFarmConfig = config["Stop Farm"] or {}
        local stopFarmEnabled = stopFarmConfig["Enable"] or false
        local stopFarmThreshold = stopFarmConfig["Stop Farming When Money"] or math.huge

        if stopFarmEnabled and shecklesValue >= stopFarmThreshold then
            print("⏹️ Đã đạt giới hạn Sheckles:", shecklesValue, "Dừng mọi hoạt động farm!")
        else
            manageFarmCycle()
        end

        task.wait(10)
    end
end)
-- Checking Blackpack if has changed
LocalPlayer.Backpack.ChildAdded:Connect(function()
    updateScreenAppearance()
end)
LocalPlayer.Backpack.ChildRemoved:Connect(function()
    updateScreenAppearance()
end)

local function onSeedStockChanged()
    local config = getgenv().Config or {}
    local stopFarmConfig = config["Stop Farm"] or {}
    local stopFarmEnabled = stopFarmConfig["Enable"] or false
    local stopFarmThreshold = stopFarmConfig["Stop Farming When Money"] or math.huge

    local shecklesValue = getSheckles()
    print("🌱 SeedStock thay đổi → Sheckles:", shecklesValue)

    if stopFarmEnabled and shecklesValue >= stopFarmThreshold then
        print("⏹️ Đã đạt giới hạn Sheckles:", shecklesValue, "Dừng mua và trồng seed!")
        return -- Dừng hoàn toàn nếu đạt ngưỡng
    end

    if not isSelling then
        print("🌱 Tiến hành mua và trồng seed...")
        buyAllSeeds()
        plantSeeds()
    else
        print("⏳ Đang bán, tạm dừng mua và trồng seed...")
    end
end

local seedStockSignal = DataService:GetPathSignal("SeedStock")
if seedStockSignal then
    seedStockSignal:Connect(onSeedStockChanged)
end

local individualSeedStockSignal = DataService:GetPathSignal("SeedStock/@")
if individualSeedStockSignal then
    individualSeedStockSignal:Connect(onSeedStockChanged)
end
boostFPS()
lockFPS()
autoFinishLoading()
print("Welcome to Sigma Hub Kaitun Grow A Garden")
