-- ============================================================
--  Dark-SAE  |  Event + ESP Add-on
--  Loaded by the main script via loadstring(game:HttpGet(raw_url))
--  Expects _G.DarkSAE to be populated by the main script first:
--    _G.DarkSAE = {
--        Window  = Window,
--        h       = h,
--        notify  = function(t,c) ... end,
--        b4      = b4,
--        u4      = u4,
--        remotes = { carry = i, snapshot = R, strike = P },
--    }
-- ============================================================

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player            = Players.LocalPlayer

local api = _G.DarkSAE
if not api then
    warn("[Dark-SAE Addon] _G.DarkSAE not found. Load the main script first.")
    return
end

local Window   = api.Window
local h        = api.h
local notify   = api.notify or function(t, c) print(("[Dark-SAE] %s: %s"):format(tostring(t), tostring(c))) end
local b4       = api.b4
local u4       = api.u4
local REM      = api.remotes or {}
local RF_FieldEggCarry    = REM.carry
local RF_FieldEggSnapshot = REM.snapshot
local RE_GuardStrike      = REM.strike

if not Window then
    warn("[Dark-SAE Addon] Main window missing. Aborting.")
    return
end

-- Avoid double-loading
if _G.DarkSAE_AddonLoaded then
    warn("[Dark-SAE Addon] Already loaded. Skipping.")
    return
end
_G.DarkSAE_AddonLoaded = true

-- ------------------------------------------------------------
--  EVENT TAB
-- ------------------------------------------------------------
local EventTab = Window:AddTab("Event", "crown")

local EventSetup  = EventTab:AddGroupbox({ Side = "Left",  Name = "Event Setup",  IconName = "target" })
local EventEscape = EventTab:AddGroupbox({ Side = "Right", Name = "Escape Logic", IconName = "run" })

local eventState = {
    enabled        = false,
    evadeRadius    = 150,
    safeA          = "Angels",
    safeB          = "Demons",
    safeC          = "Cherry Blossom",
    currentSafe    = "A",
    godmodeOnEvade = true,
    busy           = false,
    targetPatterns = { "gorillaking", "gorilla king", "golden", "silver" },
}

local SAFE_COORDS = {
    Angels             = Vector3.new(6100, 70, -400),
    Demons             = Vector3.new(6100, 70,  400),
    ["Cherry Blossom"] = Vector3.new(4200, 70, -320),
}

local function isEventEgg(cat, uid, mut)
    local c = string.lower(tostring(cat or ""))
    local u = string.lower(tostring(uid or ""))
    local m = ""
    if type(mut) == "table" then
        for k, v in pairs(mut) do m = m .. " " .. tostring(k) .. " " .. tostring(v) end
    elseif mut then
        m = tostring(mut)
    end
    local combined = c .. " " .. u .. " " .. string.lower(m)
    for _, pat in ipairs(eventState.targetPatterns) do
        if string.find(combined, pat) then return true end
    end
    return false
end

local function isHoldingEventEgg()
    local char = player.Character
    if not char then return false end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") then
            local mut = c:GetAttribute("Mutations") or c:GetAttribute("Mutation")
            if isEventEgg(c.Name, c:GetAttribute("UID") or c:GetAttribute("EggUid") or c.Name, mut) then
                return true
            end
        end
    end
    return false
end

local function getEventEgg()
    local slots = Workspace:FindFirstChild("AreaEggSlotsClient")
    if not slots then return nil end
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position or Vector3.new(0, 0, 0)
    local best = nil
    for _, slot in ipairs(slots:GetChildren()) do
        local anchor = slot.PrimaryPart or slot:FindFirstChildWhichIsA("BasePart")
        if anchor then
            local cat = slot:GetAttribute("Category") or slot:GetAttribute("AssetCategory") or slot.Name
            local mut = slot:GetAttribute("Mutations") or slot:GetAttribute("Mutation")
            if isEventEgg(cat, slot.Name, mut) then
                local dist = (myPos - anchor.Position).Magnitude
                if not best or dist < best.dist then
                    best = { slot = slot, anchor = anchor, dist = dist, uid = slot.Name, cat = cat }
                end
            end
        end
    end
    return best
end

local function nearestEnemy()
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, 9999 end
    local nearest, nearestDist = nil, 9999
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local c = p.Character
            local hh = c and c:FindFirstChild("HumanoidRootPart")
            if hh then
                local d = (hrp.Position - hh.Position).Magnitude
                if d < nearestDist then nearestDist = d; nearest = p end
            end
        end
    end
    return nearest, nearestDist
end

local function stealEventEgg(target)
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local deadline = os.clock() + 6
    local lastCarry = 0
    while os.clock() < deadline do
        if not eventState.enabled then return false end
        local anchor = target.anchor
        if not anchor or not anchor.Parent then return false end
        hrp.CFrame = anchor.CFrame * CFrame.new(0, 2, 0)
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        if os.clock() - lastCarry > 0.2 then
            lastCarry = os.clock()
            if RF_FieldEggCarry then
                pcall(function()
                    if RF_FieldEggCarry:IsA("RemoteFunction") then
                        RF_FieldEggCarry:InvokeServer({ Uid = target.uid })
                    else
                        RF_FieldEggCarry:FireServer({ Uid = target.uid })
                    end
                end)
            end
            pcall(function()
                for _, d in ipairs(target.slot:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then
                        d.RequiresLineOfSight = false
                        d.HoldDuration = 0
                        if typeof(fireproximityprompt) == "function" then
                            fireproximityprompt(d, 0)
                            fireproximityprompt(d)
                        end
                    end
                end
            end)
        end
        if isHoldingEventEgg() then return true end
        task.wait(0.05)
    end
    return isHoldingEventEgg()
end

task.spawn(function()
    while true do
        if eventState.enabled and not eventState.busy then
            local char = player.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                if not isHoldingEventEgg() then
                    eventState.busy = true
                    local target = getEventEgg()
                    if target then
                        notify("Event", "Event egg found — stealing.")
                        local ok = stealEventEgg(target)
                        if ok then notify("Event", "Event egg secured.") end
                    end
                    eventState.busy = false
                else
                    local enemy, dist = nearestEnemy()
                    if enemy and dist < eventState.evadeRadius then
                        notify("Event", "Player nearby (" .. math.floor(dist) .. "m) — evading.")
                        if eventState.godmodeOnEvade and b4 then b4(true) end
                        local zones = { eventState.safeA, eventState.safeB, eventState.safeC }
                        local idx = (eventState.currentSafe == "A") and 2
                                 or (eventState.currentSafe == "B") and 3
                                 or 1
                        eventState.currentSafe = (idx == 1) and "A" or (idx == 2) and "B" or "C"
                        local zoneName = zones[idx]
                        local coords = SAFE_COORDS[zoneName] or SAFE_COORDS.Angels
                        hrp.CFrame = CFrame.new(coords + Vector3.new(math.random(-50, 50), 0, math.random(-50, 50)))
                        hrp.AssemblyLinearVelocity  = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                        notify("Event", "Warped to " .. zoneName)
                    else
                        local zoneName = (eventState.currentSafe == "A") and eventState.safeA
                                      or (eventState.currentSafe == "B") and eventState.safeB
                                      or eventState.safeC
                        local coords = SAFE_COORDS[zoneName] or SAFE_COORDS.Angels
                        if (hrp.Position - coords).Magnitude > 30 then
                            hrp.CFrame = CFrame.new(coords)
                            hrp.AssemblyLinearVelocity  = Vector3.zero
                            hrp.AssemblyAngularVelocity = Vector3.zero
                        end
                    end
                end
            end
        end
        task.wait(0.25)
    end
end)

EventSetup:AddToggle("EventEnabled", {
    Text    = "Enable Auto-Hold (Gorilla King / Golden / Silver)",
    Default = false,
    Tooltip = "Targets only Gorilla King, Golden, or Silver eggs. Runs to map edge and evades attackers.",
    Callback = function(v)
        eventState.enabled = v
        if v then notify("Event", "Auto-Hold armed. Waiting for event egg.")
        else notify("Event", "Auto-Hold disabled.") end
    end,
})

EventSetup:AddSlider("EvadeRadius", {
    Text     = "Evade When Player Within",
    Default  = 150,
    Min      = 50, Max = 600, Rounding = 25,
    Suffix   = " studs",
    Callback = function(v) eventState.evadeRadius = v end,
})

EventSetup:AddDropdown("SafeA", {
    Text    = "Safe Zone A",
    Values  = { "Angels", "Demons", "Cherry Blossom" },
    Default = "Angels",
    Callback = function(v) eventState.safeA = v end,
})

EventSetup:AddDropdown("SafeB", {
    Text    = "Safe Zone B",
    Values  = { "Angels", "Demons", "Cherry Blossom" },
    Default = "Demons",
    Callback = function(v) eventState.safeB = v end,
})

EventSetup:AddDropdown("SafeC", {
    Text    = "Safe Zone C",
    Values  = { "Angels", "Demons", "Cherry Blossom" },
    Default = "Cherry Blossom",
    Callback = function(v) eventState.safeC = v end,
})

EventEscape:AddToggle("GodmodeEvade", {
    Text    = "Force Godmode When Evading",
    Default = true,
    Callback = function(v) eventState.godmodeOnEvade = v end,
})

EventEscape:AddLabel("Targets: Gorilla King, Golden, Silver. Runs to end-of-map zones and alternates if players approach.", true)

-- ------------------------------------------------------------
--  ESP TAB
-- ------------------------------------------------------------
local ESPTab = Window:AddTab("ESP", "eye")

local ESPBoxL = ESPTab:AddGroupbox({ Side = "Left",  Name = "Display", IconName = "eye" })
local ESPBoxR = ESPTab:AddGroupbox({ Side = "Right", Name = "Style",   IconName = "palette" })

local espCfg = {
    enabled       = true,
    maxDistance   = 3000,
    showCategory  = true,
    showRarity    = true,
    showScale     = true,
    showDistance  = false,
    outlineOnly   = false,
    textSize      = 14,
    fillTransp    = 0.75,
    outlineTransp = 0,
}

local ESP_COLOR = {
    ["Divine"]    = Color3.fromRGB(244, 63, 94),
    ["Eternal"]   = Color3.fromRGB(217, 70, 239),
    ["Secret"]    = Color3.fromRGB(249, 115, 22),
    ["Cosmic"]    = Color3.fromRGB(6, 182, 212),
    ["Mythic"]    = Color3.fromRGB(139, 92, 246),
    ["Legendary"] = Color3.fromRGB(251, 191, 36),
    ["Epic"]      = Color3.fromRGB(168, 85, 247),
    ["Rare"]      = Color3.fromRGB(59, 130, 246),
    ["Uncommon"]  = Color3.fromRGB(34, 197, 94),
    ["Common"]    = Color3.fromRGB(148, 163, 184),
    ["Unknown"]   = Color3.fromRGB(230, 230, 230),
}

local espObjects = {}

local function espRarity(cat, attrRar, attrRank)
    local low = string.lower(tostring(attrRar or ""))
    for _, k in ipairs({"divine","eternal","secret","cosmic","mythic","legendary","epic","rare","uncommon","common"}) do
        if string.find(low, k) then return k:sub(1,1):upper() .. k:sub(2) end
    end
    local r = tonumber(attrRank) or 0
    if r >= 10 then return "Divine"    end
    if r >= 9  then return "Eternal"   end
    if r >= 8  then return "Secret"    end
    if r >= 7  then return "Cosmic"    end
    if r >= 6  then return "Mythic"    end
    if r >= 5  then return "Legendary" end
    if r >= 4  then return "Epic"      end
    if r >= 3  then return "Rare"      end
    if r >= 2  then return "Uncommon"  end
    if r >= 1  then return "Common"    end
    local c = string.lower(tostring(cat or ""))
    local kw = {
        {"Divine",    {"nightflame","unicornegg","kitsune","elmaja"}},
        {"Eternal",   {"gorillaking","gorilla king","lunardragon","onitiger","mosasaurus"}},
        {"Secret",    {"mutantshark","skeletonboss","cosmicdragon","trex","kraken"}},
        {"Cosmic",    {"saturnita","mantaris","rhinotaur","snowyowl","koiegg","triceratops","bronto"}},
        {"Mythic",    {"bladehide","redpanda","cosmicgorilla","ankylosaurus"}},
        {"Legendary", {"spideron","crustacia","salamander","cosmicgecko","pterodactyl"}},
        {"Epic",      {"crane","centapede","swordfish"}},
        {"Rare",      {"dodo","parrotfish"}},
    }
    for _, grp in ipairs(kw) do
        for _, k in ipairs(grp[2]) do
            if string.find(c, k) then return grp[1] end
        end
    end
    return "Common"
end

local function espSize(scale)
    scale = tonumber(scale) or 1
    if scale >= 1.5  then return string.format("XL %.2fx", scale) end
    if scale >= 1.2  then return string.format("L %.2fx",  scale) end
    if scale >= 1.05 then return string.format("M %.2fx",  scale) end
    return string.format("%.2fx", scale)
end

local function espDestroy(key)
    local e = espObjects[key]
    if not e then return end
    if e.highlight then pcall(function() e.highlight:Destroy() end) end
    if e.billboard then pcall(function() e.billboard:Destroy() end) end
    espObjects[key] = nil
end

local function espCreate(key, model, color)
    local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not anchor then return end

    local hl = Instance.new("Highlight")
    hl.Name                = "DarkSAE_ESP_Highlight"
    hl.FillColor           = color
    hl.FillTransparency    = espCfg.fillTransp
    hl.OutlineColor        = color
    hl.OutlineTransparency = espCfg.outlineTransp
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = model
    hl.Parent              = model

    local bill = Instance.new("BillboardGui")
    bill.Name           = "DarkSAE_ESP_Label"
    bill.Size           = UDim2.fromOffset(240, 60)
    bill.StudsOffset    = Vector3.new(0, 3.5, 0)
    bill.AlwaysOnTop    = true
    bill.LightInfluence = 0
    bill.Adornee        = anchor
    bill.Parent         = anchor

    local frame = Instance.new("Frame", bill)
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.fromScale(1, 1)

    local cat = Instance.new("TextLabel", frame)
    cat.Name = "Category"
    cat.BackgroundTransparency = 1
    cat.Size = UDim2.new(1, 0, 0, 18)
    cat.Font = Enum.Font.GothamBold
    cat.TextSize = espCfg.textSize
    cat.TextColor3 = color
    cat.TextStrokeTransparency = 0
    cat.TextStrokeColor3 = Color3.new(0, 0, 0)

    local rar = Instance.new("TextLabel", frame)
    rar.Name = "Rarity"
    rar.BackgroundTransparency = 1
    rar.Size = UDim2.new(1, 0, 0, 16)
    rar.Position = UDim2.new(0, 0, 0, 18)
    rar.Font = Enum.Font.Gotham
    rar.TextSize = espCfg.textSize - 2
    rar.TextColor3 = color
    rar.TextStrokeTransparency = 0
    rar.TextStrokeColor3 = Color3.new(0, 0, 0)

    local info = Instance.new("TextLabel", frame)
    info.Name = "Info"
    info.BackgroundTransparency = 1
    info.Size = UDim2.new(1, 0, 0, 14)
    info.Position = UDim2.new(0, 0, 0, 36)
    info.Font = Enum.Font.Gotham
    info.TextSize = espCfg.textSize - 4
    info.TextColor3 = Color3.fromRGB(225, 225, 225)
    info.TextStrokeTransparency = 0
    info.TextStrokeColor3 = Color3.new(0, 0, 0)

    espObjects[key] = { highlight = hl, billboard = bill, model = model, anchor = anchor }
end

task.spawn(function()
    while true do
        if espCfg.enabled then
            local slots = Workspace:FindFirstChild("AreaEggSlotsClient")
            local char = player.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local myPos = hrp and hrp.Position or Vector3.new(0, 0, 0)
            local alive = {}

            if slots then
                for _, slot in ipairs(slots:GetChildren()) do
                    local anchor = slot.PrimaryPart or slot:FindFirstChildWhichIsA("BasePart")
                    if anchor then
                        local dist = (myPos - anchor.Position).Magnitude
                        if dist <= espCfg.maxDistance then
                            local key = slot.Name
                            local cat = slot:GetAttribute("Category") or slot:GetAttribute("AssetCategory") or slot.Name
                            local rar = espRarity(cat, slot:GetAttribute("Rarity"), slot:GetAttribute("RarityRank"))
                            local color = ESP_COLOR[rar] or ESP_COLOR.Unknown
                            local scale = slot:GetAttribute("Scale") or slot:GetAttribute("AssetScale") or 1

                            alive[key] = true
                            if not espObjects[key] then espCreate(key, slot, color) end

                            local e = espObjects[key]
                            if e and e.highlight then
                                e.highlight.FillColor    = color
                                e.highlight.OutlineColor = color
                                e.highlight.Adornee      = slot
                            end

                            if e and e.billboard then
                                local frame = e.billboard:FindFirstChildWhichIsA("Frame")
                                if frame then
                                    local catLbl  = frame:FindFirstChild("Category")
                                    local rarLbl  = frame:FindFirstChild("Rarity")
                                    local infoLbl = frame:FindFirstChild("Info")
                                    if catLbl then
                                        catLbl.Visible = espCfg.showCategory and not espCfg.outlineOnly
                                        catLbl.Text = cat
                                    end
                                    if rarLbl then
                                        rarLbl.Visible = espCfg.showRarity and not espCfg.outlineOnly
                                        rarLbl.Text = rar
                                    end
                                    if infoLbl then
                                        local bits = {}
                                        if espCfg.showScale    then bits[#bits+1] = espSize(scale) end
                                        if espCfg.showDistance then bits[#bits+1] = string.format("%.0fm", dist) end
                                        infoLbl.Visible = (#bits > 0) and not espCfg.outlineOnly
                                        infoLbl.Text = table.concat(bits, " | ")
                                    end
                                end
                            end
                        end
                    end
                end
            end

            for k in pairs(espObjects) do
                if not alive[k] then espDestroy(k) end
            end
        else
            for k in pairs(espObjects) do espDestroy(k) end
        end
        task.wait(0.2)
    end
end)

ESPBoxL:AddToggle("EspEnabled", { Text = "Enable ESP", Default = true, Callback = function(v) espCfg.enabled = v end })
ESPBoxL:AddSlider("EspDist", { Text = "Max Distance", Default = 3000, Min = 100, Max = 15000, Rounding = 100, Suffix = " studs", Callback = function(v) espCfg.maxDistance = v end })
ESPBoxL:AddToggle("EspCat", { Text = "Show Egg Contents", Default = true, Callback = function(v) espCfg.showCategory = v end })
ESPBoxL:AddToggle("EspRar", { Text = "Show Rarity", Default = true, Callback = function(v) espCfg.showRarity = v end })
ESPBoxL:AddToggle("EspScale", { Text = "Show Size", Default = true, Callback = function(v) espCfg.showScale = v end })
ESPBoxL:AddToggle("EspOutlineOnly", { Text = "Outline Only", Default = false, Callback = function(v) espCfg.outlineOnly = v end })

ESPBoxR:AddSlider("EspFillT", { Text = "Fill Transparency", Default = 0.75, Min = 0, Max = 1, Rounding = 0.05, Callback = function(v) espCfg.fillTransp = v end })
ESPBoxR:AddSlider("EspOutT", { Text = "Outline Transparency", Default = 0, Min = 0, Max = 1, Rounding = 0.05, Callback = function(v) espCfg.outlineTransp = v end })
ESPBoxR:AddSlider("EspTextSize", { Text = "Text Size", Default = 14, Min = 8, Max = 28, Rounding = 1, Callback = function(v) espCfg.textSize = v end })

notify("Dark-SAE", "Event + ESP add-on loaded.")
