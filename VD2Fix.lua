--[[
    Violence District: Ultimate Script V10 (Updated: Kategori Bahasa Indonesia)
    Aimbot dengan Pilihan Target (Kaki/Bahu/Tangan) - Tahan Q
    GUI Redesign + Input Lock Fix + Avatar Stealer (FIXED)
    MODIFIED: Removed Lighting Features (Fixed Panic Glitch)
    FINAL MOD: Added Panic Key (End) and "Lainnya" Category
    ADDED: Twist of Fate Bypass (Always Shoot) - ULTIMATE V3
]]

-- ========================
-- SERVICES
-- ========================
local UserInputService    = game:GetService("UserInputService")
local RunService          = game:GetService("RunService")
local Players             = game:GetService("Players")
local CoreGui             = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService        = game:GetService("TweenService")
local Lighting            = game:GetService("Lighting")
local HttpService         = game:GetService("HttpService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ========================
-- STATE / VARIABEL
-- ========================
local lungeEnabled      = false
local espEnabled        = false
local crosshairEnabled  = false
local fovEnabled        = false
local aimbotEnabled     = false
local skillcheckEnabled = false
local twistOfFateEnabled = false -- New Feature State
local silentAimTwistEnabled = false
local twistVisualLine = nil
local menuVisible       = true

local isMouseDown   = false
local toggleKey     = Enum.KeyCode.P
local hideMenuKey   = Enum.KeyCode.RightControl
local aimbotKey     = Enum.KeyCode.Q
local panicKey      = Enum.KeyCode.End -- Default Panic Key
local undoPanicKey  = Enum.KeyCode.Delete -- Default Undo Panic Key
local previousStates = {} -- Store states for Undo Panic
local lungeSpeed    = 30
local crosshairType = "Dot"
local targetFOV     = 100
local defaultFOV    = Camera.FieldOfView



-- NEW: Aimlock target category (Bahasa Indonesia)
local aimlockTargetType = "Kaki" -- Default: Kaki
local aimlockTargets    = {"Kepala", "Badan Kanan", "Tangan Kanan", "Kaki Kanan", "Bahu Kanan", "Kaki", "Bahu", "Tangan"}
local aimlockTargetIdx  = 1

local waitingForKey    = false
local waitingForAimKey = false

-- ========================
-- TWIST OF FATE BYPASS LOGIC (V3 ULTIMATE)
-- ========================
local function setupTwistOfFateBypass()
    local TwistRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Items"):WaitForChild("Twist of Fate"):WaitForChild("Fire")
    
    -- METODE 1: Intercept Remote Signal (Client -> Server)
    -- Karena server yang menentukan chance, kita tidak bisa mengubah FireServer,
    -- tapi kita bisa memastikan client selalu siap menerima "Shoot".

    -- METODE 2: Intercept OnClientEvent (Server -> Client) - PALING AMPUH
    -- Kita membajak fungsi Connect untuk menyisipkan filter kita sendiri.
    local oldConnect
    oldConnect = hookfunction(TwistRemote.OnClientEvent.Connect, function(self, callback)
        local newCallback = function(action, ...)
            if twistOfFateEnabled and action == "SelfDamage" then
                -- Jika server mengirim SelfDamage, kita bohongi client seolah server mengirim Shoot
                return callback("Shoot", ...)
            end
            return callback(action, ...)
        end
        return oldConnect(self, newCallback)
    end)

    -- METODE 3: Connection Manipulation (Untuk executor yang tidak support hookfunction penuh)
    task.spawn(function()
        while true do
            if twistOfFateEnabled and getconnections then
                for _, connection in pairs(getconnections(TwistRemote.OnClientEvent)) do
                    -- Kita coba blokir eksekusi jika argumennya adalah SelfDamage
                    -- Namun metode hookfunction di atas jauh lebih stabil.
                end
            end
            task.wait(5)
        end
    end)
    
    -- METODE 4: FireSignal Loopback
    -- Jika client menerima SelfDamage, kita kirim ulang sinyal Shoot secara lokal
    TwistRemote.OnClientEvent:Connect(function(action)
        if twistOfFateEnabled and action == "SelfDamage" then
            if firesignal then
                firesignal(TwistRemote.OnClientEvent, "Shoot")
            end
        end
    end)
end

-- Initialize bypass listener
pcall(setupTwistOfFateBypass)

-- ========================
-- AVATAR STEALER LOGIC
-- ========================
local function clearAppearance(character)
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("Accessory") or item:IsA("ShirtGraphic") or item:IsA("Hat") then
            item:Destroy()
        end
    end
    
    local head = character:FindFirstChild("Head")
    if head then
        local face = head:FindFirstChild("face")
        if face then
            face.Texture = "rbxasset://textures/face.png"
        end
    end
end

local function apply_description(humanoid, description)
    pcall(function()
        if humanoid.ApplyDescriptionClientServer then
            humanoid:ApplyDescriptionClientServer(description)
        else
            humanoid:ApplyDescription(description)
        end
    end)
end

local function stealAvatar(username, statusLabel)
    if statusLabel then statusLabel.Text = "Status: Mencari..." end
    local userId
    local success, err = pcall(function()
        userId = Players:GetUserIdFromNameAsync(username)
    end)

    if not success or not userId then
        if statusLabel then statusLabel.Text = "Status: User Tidak Ditemukan!" end
        return
    end

    if statusLabel then statusLabel.Text = "Status: Mengambil Data..." end
    local description
    local successDesc, errDesc = pcall(function()
        description = Players:GetHumanoidDescriptionFromUserId(userId)
    end)

    if not successDesc or not description then
        if statusLabel then statusLabel.Text = "Status: Error Data!" end
        return
    end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass('Humanoid')

    if not hum then
        if statusLabel then statusLabel.Text = "Status: Humanoid Hilang!" end
        return
    end

    if statusLabel then statusLabel.Text = "Status: Membersihkan..." end
    clearAppearance(char)

    if statusLabel then statusLabel.Text = "Status: Menerapkan..." end
    apply_description(hum, description)
    
    task.delay(0.5, function()
        if char:FindFirstChildOfClass("Shirt") == nil and description.Shirt ~= 0 then
            local s = Instance.new("Shirt", char)
            s.ShirtTemplate = "rbxassetid://" .. tostring(description.Shirt)
            local p = Instance.new("Pants", char)
            p.PantsTemplate = "rbxassetid://" .. tostring(description.Pants)
            
            local appearance = Players:GetCharacterAppearanceAsync(userId)
            for _, item in ipairs(appearance:GetChildren()) do
                if item:IsA("Accessory") then
                    item.Parent = char
                end
            end
            appearance:Destroy()
        end
        
        local head = char:FindFirstChild("Head")
        if head and head:FindFirstChild("face") and description.Face ~= 0 then
            head.face.Texture = "rbxassetid://" .. tostring(description.Face)
        end
    end)

    if statusLabel then statusLabel.Text = "Status: Berhasil!" end
end

-- ========================
-- INPUT LOCK: Cegah klik menembus GUI ke game
-- ========================
local function isMouseOverFrame(frame)
    if not frame.Visible then return false end
    local mouse = UserInputService:GetMouseLocation()
    local pos   = frame.AbsolutePosition
    local size  = frame.AbsoluteSize
    return mouse.X >= pos.X and mouse.X <= pos.X + size.X
       and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y
end

-- ========================
-- GUI SETUP
-- ========================
if CoreGui:FindFirstChild("VD_V10_GUI") then
    CoreGui:FindFirstChild("VD_V10_GUI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "VD_V10_GUI"
ScreenGui.Parent          = CoreGui
ScreenGui.ResetOnSpawn    = false
ScreenGui.DisplayOrder    = 999
ScreenGui.IgnoreGuiInset  = true

-- ========================
-- THEME COLORS
-- ========================
local C = {
    bg        = Color3.fromRGB(10,  12,  18),
    panel     = Color3.fromRGB(16,  18,  26),
    card      = Color3.fromRGB(20,  23,  34),
    border    = Color3.fromRGB(30,  34,  52),
    accent    = Color3.fromRGB(0,   200, 255),
    accentDim = Color3.fromRGB(0,   120, 160),
    red       = Color3.fromRGB(255, 60,  80),
    green     = Color3.fromRGB(0,   220, 140),
    text      = Color3.fromRGB(220, 225, 240),
    subtext   = Color3.fromRGB(120, 130, 160),
    off       = Color3.fromRGB(38,  42,  60),
    white     = Color3.fromRGB(255, 255, 255),
}

-- ========================
-- HELPER: UI Stroke
-- ========================
local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color      = color or C.border
    s.Thickness  = thickness or 1
    s.Parent     = parent
    return s
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function addGradient(parent, c0, c1, rotation)
    local g = Instance.new("UIGradient")
    g.Color    = ColorSequence.new(c0, c1)
    g.Rotation = rotation or 90
    g.Parent   = parent
    return g
end

-- ========================
-- MAIN FRAME (400x400)
-- ========================
local MainFrame = Instance.new("Frame")
MainFrame.Name              = "MainFrame"
MainFrame.Parent            = ScreenGui
MainFrame.BackgroundColor3  = C.bg
MainFrame.BorderSizePixel   = 0
MainFrame.Position          = UDim2.new(1, -410, 0, 10)
MainFrame.Size              = UDim2.new(0, 400, 0, 400)
MainFrame.Active            = true
MainFrame.Draggable         = true
addCorner(MainFrame, 12)
addStroke(MainFrame, C.border, 1.5)

addGradient(MainFrame,
    Color3.fromRGB(12, 14, 22),
    Color3.fromRGB(8, 10, 16),
    135)

local AccentLine = Instance.new("Frame")
AccentLine.Parent           = MainFrame
AccentLine.BackgroundColor3 = C.accent
AccentLine.Size             = UDim2.new(0.6, 0, 0, 2)
AccentLine.Position         = UDim2.new(0.2, 0, 0, 0)

-- ========================
-- SIDEBAR
-- ========================
local Sidebar = Instance.new("Frame")
Sidebar.Name              = "Sidebar"
Sidebar.Parent            = MainFrame
Sidebar.BackgroundColor3  = C.panel
Sidebar.BorderSizePixel   = 0
Sidebar.Size              = UDim2.new(0, 120, 1, 0)
addStroke(Sidebar, C.border, 1)

local Logo = Instance.new("TextLabel")
Logo.Parent             = Sidebar
Logo.BackgroundTransparency = 1
Logo.Position           = UDim2.new(0, 0, 0, 15)
Logo.Size               = UDim2.new(1, 0, 0, 30)
Logo.Font               = Enum.Font.GothamBlack
Logo.Text               = "VD V10"
Logo.TextColor3         = C.accent
Logo.TextSize           = 18

local TabContainer = Instance.new("Frame")
TabContainer.Parent             = Sidebar
TabContainer.BackgroundTransparency = 1
TabContainer.Position           = UDim2.new(0, 10, 0, 60)
TabContainer.Size               = UDim2.new(1, -20, 1, -70)

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.Parent = TabContainer
TabListLayout.Padding = UDim.new(0, 6)

-- ========================
-- CONTENT AREA
-- ========================
local ContentArea = Instance.new("Frame")
ContentArea.Name              = "ContentArea"
ContentArea.Parent            = MainFrame
ContentArea.BackgroundTransparency = 1
ContentArea.Position          = UDim2.new(0, 120, 0, 0)
ContentArea.Size              = UDim2.new(1, -120, 1, 0)

local function createTabFrame(name)
    local f = Instance.new("ScrollingFrame")
    f.Name                = name .. "Frame"
    f.Parent              = ContentArea
    f.BackgroundTransparency = 1
    f.BorderSizePixel     = 0
    f.Size                = UDim2.new(1, 0, 1, 0)
    f.ScrollBarThickness  = 2
    f.ScrollBarImageColor3 = C.accent
    f.Visible             = false
    f.CanvasSize          = UDim2.new(0, 0, 0, 600)
    
    local pad = Instance.new("UIPadding")
    pad.Parent = f
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 12)
    
    return f
end

local HomeFrame     = createTabFrame("Home")
local SurvivorFrame = createTabFrame("Survivor")
local MovementFrame = createTabFrame("Movement")
local VisualFrame   = createTabFrame("Visual")
local LainnyaFrame  = createTabFrame("Lainnya")

local tabs = {
    { name = "HOME",     frame = HomeFrame     },
    { name = "SURVIVOR", frame = SurvivorFrame },
    { name = "MOVEMENT", frame = MovementFrame },
    { name = "VISUAL",   frame = VisualFrame   },
    { name = "LAINNYA",  frame = LainnyaFrame  },
}

local function showTab(name)
    for _, t in pairs(tabs) do
        t.frame.Visible = (t.name == name)
    end
end

for _, t in pairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Parent             = TabContainer
    btn.BackgroundColor3   = C.card
    btn.Size               = UDim2.new(1, 0, 0, 32)
    btn.Font               = Enum.Font.GothamBold
    btn.Text               = t.name
    btn.TextColor3         = C.subtext
    btn.TextSize           = 11
    btn.AutoButtonColor    = false
    addCorner(btn, 6)
    addStroke(btn, C.border, 1)
    
    btn.MouseButton1Click:Connect(function()
        showTab(t.name)
        for _, other in pairs(TabContainer:GetChildren()) do
            if other:IsA("TextButton") then
                other.TextColor3 = C.subtext
                other.BackgroundColor3 = C.card
            end
        end
        btn.TextColor3 = C.white
        btn.BackgroundColor3 = C.accentDim
    end)
end

-- ========================
-- UI COMPONENTS
-- ========================
local function createCard(parent, yOffset, height)
    local card = Instance.new("Frame")
    card.Parent             = parent
    card.BackgroundColor3   = C.card
    card.BorderSizePixel    = 0
    card.Position           = UDim2.new(0, 0, 0, yOffset)
    card.Size               = UDim2.new(1, 0, 0, height)
    addCorner(card, 8)
    addStroke(card, C.border, 1)
    return card
end

local function createToggle(parent, icon, text, yOffset, default, callback)
    local card = createCard(parent, yOffset, 42)
    
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Parent             = card
    iconLbl.BackgroundTransparency = 1
    iconLbl.Position           = UDim2.new(0, 10, 0, 0)
    iconLbl.Size               = UDim2.new(0, 24, 1, 0)
    iconLbl.Font               = Enum.Font.GothamBold
    iconLbl.Text               = icon
    iconLbl.TextColor3         = C.accentDim
    iconLbl.TextSize           = 14
    
    local label = Instance.new("TextLabel")
    label.Parent             = card
    label.BackgroundTransparency = 1
    label.Position           = UDim2.new(0, 38, 0, 0)
    label.Size               = UDim2.new(0.5, 0, 1, 0)
    label.Font               = Enum.Font.Gotham
    label.Text               = text
    label.TextColor3         = C.text
    label.TextSize           = 13
    label.TextXAlignment     = Enum.TextXAlignment.Left
    
    local toggleBg = Instance.new("TextButton")
    toggleBg.Parent             = card
    toggleBg.BackgroundColor3   = default and C.accent or C.off
    toggleBg.Position           = UDim2.new(1, -44, 0.5, -10)
    toggleBg.Size               = UDim2.new(0, 34, 0, 20)
    toggleBg.Text               = ""
    toggleBg.AutoButtonColor    = false
    addCorner(toggleBg, 10)
    addStroke(toggleBg, C.border, 1)
    
    local dot = Instance.new("Frame")
    dot.Parent             = toggleBg
    dot.BackgroundColor3   = C.white
    dot.Position           = default and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8)
    dot.Size               = UDim2.new(0, 16, 0, 16)
    addCorner(dot, 8)

    local state = default
    toggleBg.MouseButton1Click:Connect(function()
        state = not state
        callback(state)
        TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = state and C.accent or C.off}):Play()
        TweenService:Create(dot, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8)}):Play()
    end)

    return function(v)
        state = v
        toggleBg.BackgroundColor3 = state and C.accent or C.off
        dot.Position = state and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8)
    end
end

local function createKeybindRow(parent, icon, text, currentKey, yOffset, callback)
    local card = createCard(parent, yOffset, 42)

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Parent             = card
    iconLbl.BackgroundTransparency = 1
    iconLbl.Position           = UDim2.new(0, 10, 0, 0)
    iconLbl.Size               = UDim2.new(0, 24, 1, 0)
    iconLbl.Font               = Enum.Font.GothamBold
    iconLbl.Text               = icon
    iconLbl.TextColor3         = C.accentDim
    iconLbl.TextSize           = 14

    local label = Instance.new("TextLabel")
    label.Parent             = card
    label.BackgroundTransparency = 1
    label.Position           = UDim2.new(0, 38, 0, 0)
    label.Size               = UDim2.new(0.45, 0, 1, 0)
    label.Font               = Enum.Font.Gotham
    label.Text               = text
    label.TextColor3         = C.text
    label.TextSize           = 13
    label.TextXAlignment     = Enum.TextXAlignment.Left

    local bindBtn = Instance.new("TextButton")
    bindBtn.Parent             = card
    bindBtn.BackgroundColor3   = C.off
    bindBtn.Position           = UDim2.new(1, -72, 0.5, -13)
    bindBtn.Size               = UDim2.new(0, 64, 0, 26)
    bindBtn.Font               = Enum.Font.GothamBold
    bindBtn.Text               = currentKey.Name
    bindBtn.TextColor3         = C.accent
    bindBtn.TextSize           = 11
    bindBtn.AutoButtonColor    = false
    addCorner(bindBtn, 6)
    addStroke(bindBtn, C.border, 1)

    bindBtn.MouseButton1Click:Connect(function()
        bindBtn.Text = "..."
        local connection
        connection = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode.Name
                bindBtn.Text = key
                callback(input.KeyCode)
                connection:Disconnect()
            end
        end)
    end)
end

local function createLabelInput(parent, icon, text, defaultVal, yOffset, callback)
    local card = createCard(parent, yOffset, 42)

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Parent             = card
    iconLbl.BackgroundTransparency = 1
    iconLbl.Position           = UDim2.new(0, 10, 0, 0)
    iconLbl.Size               = UDim2.new(0, 24, 1, 0)
    iconLbl.Font               = Enum.Font.GothamBold
    iconLbl.Text               = icon
    iconLbl.TextColor3         = C.accentDim
    iconLbl.TextSize           = 14

    local label = Instance.new("TextLabel")
    label.Parent             = card
    label.BackgroundTransparency = 1
    label.Position           = UDim2.new(0, 38, 0, 0)
    label.Size               = UDim2.new(0.45, 0, 1, 0)
    label.Font               = Enum.Font.Gotham
    label.Text               = text
    label.TextColor3         = C.text
    label.TextSize           = 13
    label.TextXAlignment     = Enum.TextXAlignment.Left

    local input = Instance.new("TextBox")
    input.Parent             = card
    input.BackgroundColor3   = C.off
    input.Position           = UDim2.new(1, -72, 0.5, -13)
    input.Size               = UDim2.new(0, 64, 0, 26)
    input.Font               = Enum.Font.GothamBold
    input.Text               = defaultVal
    input.TextColor3         = C.white
    input.TextSize           = 11
    addCorner(input, 6)
    addStroke(input, C.border, 1)

    input.FocusLost:Connect(function()
        callback(input.Text)
    end)

    return input
end

local function createSection(parent, text, yOffset)
    local lbl = Instance.new("TextLabel")
    lbl.Parent             = parent
    lbl.BackgroundTransparency = 1
    lbl.Position           = UDim2.new(0, 4, 0, yOffset)
    lbl.Size               = UDim2.new(1, -8, 0, 22)
    lbl.Font               = Enum.Font.GothamBold
    lbl.Text               = text
    lbl.TextColor3         = C.accent
    lbl.TextSize           = 11
    lbl.TextXAlignment     = Enum.TextXAlignment.Left

    local line = Instance.new("Frame")
    line.Parent             = lbl
    line.BackgroundColor3   = C.accent
    line.Size               = UDim2.new(1, 0, 0, 1)
    line.Position           = UDim2.new(0, 0, 1, -2)
    line.BorderSizePixel    = 0
    line.BackgroundTransparency = 0.6
end

-- ========================
-- HOME TAB
-- ========================
local BannerCard = createCard(HomeFrame, 5, 80)
BannerCard.BackgroundColor3 = C.panel
addGradient(BannerCard,
    Color3.fromRGB(0, 60, 80),
    Color3.fromRGB(12, 14, 22),
    135)

local BannerTitle = Instance.new("TextLabel")
BannerTitle.Parent             = BannerCard
BannerTitle.BackgroundTransparency = 1
BannerTitle.Position           = UDim2.new(0, 14, 0, 8)
BannerTitle.Size               = UDim2.new(1, -14, 0, 30)
BannerTitle.Font               = Enum.Font.GothamBlack
BannerTitle.Text               = "VIOLENCE DISTRICT"
BannerTitle.TextColor3         = C.accent
BannerTitle.TextSize           = 20
BannerTitle.TextXAlignment     = Enum.TextXAlignment.Left

local BannerSub = Instance.new("TextLabel")
BannerSub.Parent             = BannerCard
BannerSub.BackgroundTransparency = 1
BannerSub.Position           = UDim2.new(0, 14, 0, 36)
BannerSub.Size               = UDim2.new(1, -14, 0, 18)
BannerSub.Font               = Enum.Font.Gotham
BannerSub.Text               = "Script V10  ·  Semua fitur MATI saat mulai"
BannerSub.TextColor3         = C.subtext
BannerSub.TextSize           = 11
BannerSub.TextXAlignment     = Enum.TextXAlignment.Left

local BannerBadge = Instance.new("Frame")
BannerBadge.Parent           = BannerCard
BannerBadge.BackgroundColor3 = C.accent
BannerBadge.Position         = UDim2.new(1, -56, 0, 10)
BannerBadge.Size             = UDim2.new(0, 44, 0, 20)
addCorner(BannerBadge, 4)
local BadgeText = Instance.new("TextLabel")
BadgeText.Parent             = BannerBadge
BadgeText.BackgroundTransparency = 1
BadgeText.Size               = UDim2.new(1, 0, 1, 0)
BadgeText.Font               = Enum.Font.GothamBold
BadgeText.Text               = "V10"
BadgeText.TextColor3         = C.bg
BadgeText.TextSize           = 12

createSection(HomeFrame, "KEYBIND DEFAULT", 93)

local keybinds = {
    { key = "R-CTRL", desc = "Sembunyikan / Tampilkan Menu" },
    { key = "P",      desc = "Toggle Infinite Lunge"       },
    { key = "Q",      desc = "Tahan → Aimbot (Sesuai Target)" },
    { key = "END",    desc = "Panic Key (Matikan Semua)" },
}
for i, kb in ipairs(keybinds) do
    local kCard = createCard(HomeFrame, 118 + (i-1) * 48, 40)
    local kLabel = Instance.new("TextLabel")
    kLabel.Parent             = kCard
    kLabel.BackgroundTransparency = 1
    kLabel.Position           = UDim2.new(0, 10, 0, 0)
    kLabel.Size               = UDim2.new(0.6, 0, 1, 0)
    kLabel.Font               = Enum.Font.Gotham
    kLabel.Text               = kb.desc
    kLabel.TextColor3         = C.text
    kLabel.TextSize           = 11
    kLabel.TextXAlignment     = Enum.TextXAlignment.Left

    local kBadge = Instance.new("TextLabel")
    kBadge.Parent             = kCard
    kBadge.BackgroundColor3   = C.off
    kBadge.Position           = UDim2.new(1, -74, 0.5, -11)
    kBadge.Size               = UDim2.new(0, 64, 0, 22)
    kBadge.Font               = Enum.Font.GothamBold
    kBadge.Text               = kb.key
    kBadge.TextColor3         = C.accent
    kBadge.TextSize           = 10
    addCorner(kBadge, 4)
    addStroke(kBadge, C.border, 1)
end

local espInfoCard = createCard(HomeFrame, 315, 50)
local espInfoText = Instance.new("TextLabel")
espInfoText.Parent             = espInfoCard
espInfoText.BackgroundTransparency = 1
espInfoText.Position           = UDim2.new(0, 12, 0, 6)
espInfoText.Size               = UDim2.new(1, -16, 1, -12)
espInfoText.Font               = Enum.Font.Gotham
espInfoText.Text               = "Killer ESP  →  Warna MERAH\nSurvivor ESP  →  Warna HIJAU"
espInfoText.TextColor3         = C.subtext
espInfoText.TextSize           = 11
espInfoText.TextXAlignment     = Enum.TextXAlignment.Left
espInfoText.TextYAlignment     = Enum.TextYAlignment.Top

-- ========================
-- SURVIVOR TAB
-- ========================
createSection(SurvivorFrame, "AIMBOT", 5)
local updateAimbotUI = createToggle(SurvivorFrame, "⊕", "Aimbot Aktif (Tahan Q)", 30, false, function(v)
    aimbotEnabled = v
end)

local targetCard = createCard(SurvivorFrame, 78, 42)
local targetIcon = Instance.new("TextLabel")
targetIcon.Parent             = targetCard
targetIcon.BackgroundTransparency = 1
targetIcon.Position           = UDim2.new(0, 10, 0, 0)
targetIcon.Size               = UDim2.new(0, 24, 1, 0)
targetIcon.Font               = Enum.Font.GothamBold
targetIcon.Text               = "🎯"
targetIcon.TextColor3         = C.accentDim
targetIcon.TextSize           = 13

local targetLabel = Instance.new("TextLabel")
targetLabel.Parent             = targetCard
targetLabel.BackgroundTransparency = 1
targetLabel.Position           = UDim2.new(0, 38, 0, 0)
targetLabel.Size               = UDim2.new(0.45, 0, 1, 0)
targetLabel.Font               = Enum.Font.Gotham
targetLabel.Text               = "Target Aimbot:"
targetLabel.TextColor3         = C.text
targetLabel.TextSize           = 13
targetLabel.TextXAlignment     = Enum.TextXAlignment.Left

local TargetTypeBtn = Instance.new("TextButton")
TargetTypeBtn.Parent             = targetCard
TargetTypeBtn.BackgroundColor3   = C.accentDim
TargetTypeBtn.Position           = UDim2.new(1, -116, 0.5, -13)
TargetTypeBtn.Size               = UDim2.new(0, 108, 0, 26)
TargetTypeBtn.Font               = Enum.Font.GothamBold
TargetTypeBtn.Text               = aimlockTargetType
TargetTypeBtn.TextColor3         = C.white
TargetTypeBtn.TextSize           = 11
TargetTypeBtn.AutoButtonColor    = false
addCorner(TargetTypeBtn, 6)

TargetTypeBtn.MouseButton1Click:Connect(function()
    aimlockTargetIdx = aimlockTargetIdx % #aimlockTargets + 1
    aimlockTargetType = aimlockTargets[aimlockTargetIdx]
    TargetTypeBtn.Text = aimlockTargetType
end)

createKeybindRow(SurvivorFrame, "⌨", "Set Tombol Aimbot:", aimbotKey, 126, function(key)
    aimbotKey = key
end)

createSection(SurvivorFrame, "SKILLCHECK", 178)
local updateSkillcheckUI = createToggle(SurvivorFrame, "✓", "Skillcheck Sempurna", 203, false, function(v)
    skillcheckEnabled = v
end)

-- Twist of Fate Bypass UI
createSection(SurvivorFrame, "ITEMS", 251)
local updateTwistUI = createToggle(SurvivorFrame, "🎲", "Twist of Fate (Selalu Shoot)", 276, false, function(v)
    twistOfFateEnabled = v
end)

local updateSilentTwistUI = createToggle(SurvivorFrame, "🎯", "Silent Aim Twist of Fate", 324, false, function(v)
    silentAimTwistEnabled = v
end)

-- NEW: Target Category specifically for Silent Aim Twist of Fate
local silentTargetCard = createCard(SurvivorFrame, 372, 42)
local silentTargetIcon = Instance.new("TextLabel")
silentTargetIcon.Parent             = silentTargetCard
silentTargetIcon.BackgroundTransparency = 1
silentTargetIcon.Position           = UDim2.new(0, 10, 0, 0)
silentTargetIcon.Size               = UDim2.new(0, 24, 1, 0)
silentTargetIcon.Font               = Enum.Font.GothamBold
silentTargetIcon.Text               = "🎯"
silentTargetIcon.TextColor3         = C.accentDim
silentTargetIcon.TextSize           = 13

local silentTargetLabel = Instance.new("TextLabel")
silentTargetLabel.Parent             = silentTargetCard
silentTargetLabel.BackgroundTransparency = 1
silentTargetLabel.Position           = UDim2.new(0, 38, 0, 0)
silentTargetLabel.Size               = UDim2.new(0.45, 0, 1, 0)
silentTargetLabel.Font               = Enum.Font.Gotham
silentTargetLabel.Text               = "Target Silent Aim:"
silentTargetLabel.TextColor3         = C.text
silentTargetLabel.TextSize           = 13
silentTargetLabel.TextXAlignment     = Enum.TextXAlignment.Left

local SilentTargetBtn = Instance.new("TextButton")
SilentTargetBtn.Parent             = silentTargetCard
SilentTargetBtn.BackgroundColor3   = C.accentDim
SilentTargetBtn.Position           = UDim2.new(1, -116, 0.5, -13)
SilentTargetBtn.Size               = UDim2.new(0, 108, 0, 26)
SilentTargetBtn.Font               = Enum.Font.GothamBold
SilentTargetBtn.Text               = aimlockTargetType
SilentTargetBtn.TextColor3         = C.white
SilentTargetBtn.TextSize           = 11
SilentTargetBtn.AutoButtonColor    = false
addCorner(SilentTargetBtn, 6)

SilentTargetBtn.MouseButton1Click:Connect(function()
    aimlockTargetIdx = aimlockTargetIdx % #aimlockTargets + 1
    aimlockTargetType = aimlockTargets[aimlockTargetIdx]
    SilentTargetBtn.Text = aimlockTargetType
    TargetTypeBtn.Text = aimlockTargetType -- Sync with main aimbot target
end)

-- ========================
-- MOVEMENT
-- ========================
local updateLungeUI = createToggle(MovementFrame, "↯", "Lunge Tak Terbatas", 30, false, function(v)
    lungeEnabled = v
end)
createKeybindRow(MovementFrame, "⌨", "Set Tombol Lunge:", toggleKey, 78, function(key)
    toggleKey = key
end)
createLabelInput(MovementFrame, "⚡", "Kecepatan Lunge:", "30", 126, function(txt)
    lungeSpeed = tonumber(txt) or 30
end)

createSection(MovementFrame, "FOV", 178)
local updateFOVUI = createToggle(MovementFrame, "◎", "Pengubah FOV", 203, false, function(v)
    fovEnabled = v
end)
createLabelInput(MovementFrame, "👁", "Target FOV:", "100", 251, function(txt)
    targetFOV = tonumber(txt) or 100
end)

-- ========================
-- VISUAL TAB
-- ========================
createSection(VisualFrame, "ESP", 5)
local updateESPUI = createToggle(VisualFrame, "👁", "ESP Highlight Aktif", 30, false, function(v)
    espEnabled = v
end)

local updateCrosshairUI = createToggle(VisualFrame, "⌖", "Custom Crosshair", 78, false, function(v)
    crosshairEnabled = v
end)

local crossCard = createCard(VisualFrame, 126, 42)
local crossIcon = Instance.new("TextLabel")
crossIcon.Parent             = crossCard
crossIcon.BackgroundTransparency = 1
crossIcon.Position           = UDim2.new(0, 10, 0, 0)
crossIcon.Size               = UDim2.new(0, 24, 1, 0)
crossIcon.Font               = Enum.Font.GothamBold
crossIcon.Text               = "⚔"
crossIcon.TextColor3         = C.accentDim
crossIcon.TextSize           = 13

local crossLabel = Instance.new("TextLabel")
crossLabel.Parent             = crossCard
crossLabel.BackgroundTransparency = 1
crossLabel.Position           = UDim2.new(0, 38, 0, 0)
crossLabel.Size               = UDim2.new(0.45, 0, 1, 0)
crossLabel.Font               = Enum.Font.Gotham
crossLabel.Text               = "Tipe Crosshair:"
crossLabel.TextColor3         = C.text
crossLabel.TextSize           = 13
crossLabel.TextXAlignment     = Enum.TextXAlignment.Left

local CrossTypeBtn = Instance.new("TextButton")
CrossTypeBtn.Parent             = crossCard
CrossTypeBtn.BackgroundColor3   = C.accentDim
CrossTypeBtn.Position           = UDim2.new(1, -96, 0.5, -13)
CrossTypeBtn.Size               = UDim2.new(0, 88, 0, 26)
CrossTypeBtn.Font               = Enum.Font.GothamBold
CrossTypeBtn.Text               = crosshairType
CrossTypeBtn.TextColor3         = C.white
CrossTypeBtn.TextSize           = 11
CrossTypeBtn.AutoButtonColor    = false
addCorner(CrossTypeBtn, 6)

local crossTypes = {"Dot", "Cross", "Circle"}
local crossIdx   = 1
CrossTypeBtn.MouseButton1Click:Connect(function()
    crossIdx = crossIdx % #crossTypes + 1
    crosshairType = crossTypes[crossIdx]
    CrossTypeBtn.Text = crosshairType
end)

createSection(VisualFrame, "AVATAR STEALER", 178)
local stealCard = createCard(VisualFrame, 203, 120)

local stealInput = Instance.new("TextBox")
stealInput.Parent             = stealCard
stealInput.BackgroundColor3   = C.off
stealInput.Position           = UDim2.new(0, 10, 0, 10)
stealInput.Size               = UDim2.new(1, -20, 0, 30)
stealInput.Font               = Enum.Font.Gotham
stealInput.PlaceholderText    = "Masukkan Username Player..."
stealInput.Text               = ""
stealInput.TextColor3         = C.white
stealInput.TextSize           = 12
addCorner(stealInput, 6)
addStroke(stealInput, C.border, 1)

local stealStatus = Instance.new("TextLabel")
stealStatus.Parent             = stealCard
stealStatus.BackgroundTransparency = 1
stealStatus.Position           = UDim2.new(0, 10, 0, 45)
stealStatus.Size               = UDim2.new(1, -20, 0, 20)
stealStatus.Font               = Enum.Font.Gotham
stealStatus.Text               = "Status: Ready"
stealStatus.TextColor3         = C.subtext
stealStatus.TextSize           = 11
stealStatus.TextXAlignment     = Enum.TextXAlignment.Left

local stealBtn = Instance.new("TextButton")
stealBtn.Parent             = stealCard
stealBtn.BackgroundColor3   = C.accent
stealBtn.Position           = UDim2.new(0, 10, 0, 70)
stealBtn.Size               = UDim2.new(1, -20, 0, 35)
stealBtn.Font               = Enum.Font.GothamBold
stealBtn.Text               = "CURI AVATAR"
stealBtn.TextColor3         = C.bg
stealBtn.TextSize           = 12
addCorner(stealBtn, 6)

stealBtn.MouseButton1Click:Connect(function()
    if stealInput.Text ~= "" then
        stealAvatar(stealInput.Text, stealStatus)
    else
        stealStatus.Text = "Status: Username Kosong!"
    end
end)

-- ========================
-- LAINNYA TAB
-- ========================
createSection(LainnyaFrame, "PANIC KEY", 5)
createKeybindRow(LainnyaFrame, "⌨", "Set Panic Key:", panicKey, 30, function(key)
    panicKey = key
end)

createKeybindRow(LainnyaFrame, "⌨", "Set Undo Panic:", undoPanicKey, 78, function(key)
    undoPanicKey = key
end)

local panicInfoCard = createCard(LainnyaFrame, 126, 60)
local panicInfoText = Instance.new("TextLabel")
panicInfoText.Parent             = panicInfoCard
panicInfoText.BackgroundTransparency = 1
panicInfoText.Position           = UDim2.new(0, 12, 0, 6)
panicInfoText.Size               = UDim2.new(1, -16, 1, -12)
panicInfoText.Font               = Enum.Font.Gotham
panicInfoText.Text               = "Panic Key: Matikan SEMUA fitur instan.\nUndo Panic: Aktifkan kembali fitur yang tadinya aktif."
panicInfoText.TextColor3         = C.subtext
panicInfoText.TextSize           = 11
panicInfoText.TextXAlignment     = Enum.TextXAlignment.Left
panicInfoText.TextYAlignment     = Enum.TextYAlignment.Top
panicInfoText.TextWrapped        = true

createSection(LainnyaFrame, "CONFIGURATION", 192)
local configCard = createCard(LainnyaFrame, 217, 100)

local cfgStatus = Instance.new("TextLabel")
cfgStatus.Parent             = configCard
cfgStatus.BackgroundTransparency = 1
cfgStatus.Position           = UDim2.new(0, 10, 0, 10)
cfgStatus.Size               = UDim2.new(1, -20, 0, 20)
cfgStatus.Font               = Enum.Font.Gotham
cfgStatus.Text               = "Status: Ready"
cfgStatus.TextColor3         = C.subtext
cfgStatus.TextSize           = 11
cfgStatus.TextXAlignment     = Enum.TextXAlignment.Left

local saveBtn = Instance.new("TextButton")
saveBtn.Parent             = configCard
saveBtn.BackgroundColor3   = C.green
saveBtn.Position           = UDim2.new(0, 10, 0, 40)
saveBtn.Size               = UDim2.new(0.45, 0, 0, 35)
saveBtn.Font               = Enum.Font.GothamBold
saveBtn.Text               = "SAVE CONFIG"
saveBtn.TextColor3         = C.bg
saveBtn.TextSize           = 12
addCorner(saveBtn, 6)

local loadBtn = Instance.new("TextButton")
loadBtn.Parent             = configCard
loadBtn.BackgroundColor3   = C.accent
loadBtn.Position           = UDim2.new(0.5, 5, 0, 40)
loadBtn.Size               = UDim2.new(0.45, 0, 0, 35)
loadBtn.Font               = Enum.Font.GothamBold
loadBtn.Text               = "LOAD CONFIG"
loadBtn.TextColor3         = C.bg
loadBtn.TextSize           = 12
addCorner(loadBtn, 6)

-- Config Logic
local function saveConfig(status)
    local data = {
        lungeSpeed = lungeSpeed,
        crosshairType = crosshairType,
        targetFOV = targetFOV,
        aimlockTargetType = aimlockTargetType,
        toggleKey = toggleKey.Name,
        aimbotKey = aimbotKey.Name,
        panicKey = panicKey.Name,
        undoPanicKey = undoPanicKey.Name
    }
    local success, err = pcall(function()
        writefile("VD_V10_Config.json", HttpService:JSONEncode(data))
    end)
    if success then status.Text = "Status: Config Tersimpan!" else status.Text = "Status: Gagal Simpan!" end
end

local function loadConfig(status)
    if not isfile("VD_V10_Config.json") then status.Text = "Status: File Tidak Ada!"; return end
    local success, err = pcall(function()
        local data = HttpService:JSONDecode(readfile("VD_V10_Config.json"))
        lungeSpeed = data.lungeSpeed or 30
        crosshairType = data.crosshairType or "Dot"
        targetFOV = data.targetFOV or 100
        aimlockTargetType = data.aimlockTargetType or "Kaki"
        toggleKey = Enum.KeyCode[data.toggleKey] or Enum.KeyCode.P
        aimbotKey = Enum.KeyCode[data.aimbotKey] or Enum.KeyCode.Q
        panicKey = Enum.KeyCode[data.panicKey] or Enum.KeyCode.End
        undoPanicKey = Enum.KeyCode[data.undoPanicKey] or Enum.KeyCode.Delete
    end)
    if success then status.Text = "Status: Config Dimuat!" else status.Text = "Status: Gagal Muat!" end
end

saveBtn.MouseButton1Click:Connect(function()
    saveConfig(cfgStatus)
end)

loadBtn.MouseButton1Click:Connect(function()
    loadConfig(cfgStatus)
end)

-- ========================
-- CROSSHAIR ELEMENT
-- ========================
local CrosshairGUI = Instance.new("Frame")
CrosshairGUI.Parent           = ScreenGui
CrosshairGUI.Size             = UDim2.new(0, 4, 0, 4)
CrosshairGUI.Position         = UDim2.new(0.5, -2, 0.5, -2)
CrosshairGUI.BackgroundColor3 = Color3.fromRGB(255, 60, 80)
CrosshairGUI.BorderSizePixel  = 0
CrosshairGUI.Visible          = false
addCorner(CrosshairGUI, 2)

-- ========================
-- HELPER: KILLER CHECK
-- ========================
local function isKiller(player)
    return player.Team and (
        player.Team.Name == "Killer"  or
        player.Team.Name == "Slasher" or
        player.Team.Name == "Traitor"
    )
end

-- ========================
-- ESP LOGIC
-- ========================
local function applyESP(char, player)
    local highlight = char:FindFirstChild("ESPHighlight")
        or Instance.new("Highlight", char)
    highlight.Name                = "ESPHighlight"
    highlight.FillTransparency    = 0.92
    highlight.OutlineTransparency = 0.3
    highlight.Enabled             = espEnabled

    if isKiller(player) then
        highlight.FillColor    = Color3.fromRGB(255, 60, 80)
        highlight.OutlineColor = Color3.fromRGB(255, 60, 80)
    else
        highlight.FillColor    = Color3.fromRGB(0, 220, 140)
        highlight.OutlineColor = Color3.fromRGB(0, 220, 140)
    end
end

-- ========================
-- AIMBOT LOGIC
-- ========================
local function getAimbotTarget()
    local closestPart = nil
    local closestDist = math.huge
    local cx = Camera.ViewportSize.X / 2
    local cy = Camera.ViewportSize.Y / 2

    -- Helper to get the part that is visually on the right side of the screen
    local function getVisualRightPart(char, rightNames, leftNames)
        local rPart, lPart
        for _, name in ipairs(rightNames) do
            rPart = char:FindFirstChild(name)
            if rPart then break end
        end
        for _, name in ipairs(leftNames) do
            lPart = char:FindFirstChild(name)
            if lPart then break end
        end

        if rPart and lPart then
            local rPos, rOn = Camera:WorldToScreenPoint(rPart.Position)
            local lPos, lOn = Camera:WorldToScreenPoint(lPart.Position)
            if rOn and lOn then
                return (rPos.X > lPos.X) and rPart or lPart
            elseif rOn then return rPart
            elseif lOn then return lPart
            end
        end
        return rPart or lPart
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and isKiller(p) then
            local char = p.Character
            local targetPart = nil
            
            if aimlockTargetType == "Kepala" then
                targetPart = char:FindFirstChild("Head")
            elseif aimlockTargetType == "Badan Kanan" then
                targetPart = getVisualRightPart(char, {"RightUpperTorso", "Right Torso"}, {"LeftUpperTorso", "Left Torso"})
            elseif aimlockTargetType == "Tangan Kanan" then
                targetPart = getVisualRightPart(char, {"RightHand", "RightLowerArm", "RightUpperArm", "Right Arm"}, {"LeftHand", "LeftLowerArm", "LeftUpperArm", "Left Arm"})
            elseif aimlockTargetType == "Kaki Kanan" then
                targetPart = getVisualRightPart(char, {"RightFoot", "RightLowerLeg", "RightUpperLeg", "Right Leg"}, {"LeftFoot", "LeftLowerLeg", "LeftUpperLeg", "Left Leg"})
            elseif aimlockTargetType == "Bahu Kanan" then
                targetPart = getVisualRightPart(char, {"RightUpperArm", "Right Shoulder"}, {"LeftUpperArm", "Left Shoulder"})
            elseif aimlockTargetType == "Kaki" then
                targetPart = getVisualRightPart(char, {"RightFoot", "RightLowerLeg", "Right Leg"}, {"LeftFoot", "LeftLowerLeg", "Left Leg"})
            elseif aimlockTargetType == "Bahu" then
                targetPart = getVisualRightPart(char, {"RightUpperArm", "Right Shoulder"}, {"LeftUpperArm", "Left Shoulder"})
            elseif aimlockTargetType == "Tangan" then
                targetPart = getVisualRightPart(char, {"RightHand", "RightLowerArm", "Right Arm"}, {"LeftHand", "LeftLowerArm", "Left Arm"})
            end
            
            targetPart = targetPart or char:FindFirstChild("HumanoidRootPart")

            if targetPart then
                local screenPos, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
                if onScreen then
                    local dist = math.sqrt((screenPos.X - cx)^2 + (screenPos.Y - cy)^2)
                    if dist < closestDist then
                        closestDist = dist
                        closestPart = targetPart
                    end
                end
            end
        end
    end
    return closestPart
end

local function doAimbot()
    if not aimbotEnabled then return end
    if not UserInputService:IsKeyDown(aimbotKey) then return end
    local target = getAimbotTarget()
    if target then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
    end
end

-- ========================
-- PERFECT SKILLCHECK
-- ========================
local function doSkillcheck()
    if not skillcheckEnabled then return end
    local PG  = LocalPlayer:FindFirstChild("PlayerGui")
    local gui = PG and PG:FindFirstChild("SkillCheckPromptGui")
    local check = gui and gui:FindFirstChild("Check")

    if check and check.Visible then
        local line = check:FindFirstChild("Line")
        local goal = check:FindFirstChild("Goal")
        if line and goal then
            local lr = line.Rotation % 360
            local gr = goal.Rotation % 360
            local gs = (gr + 104) % 360
            local ge = (gr + 114) % 360
            local inGoal = (gs > ge)
                and (lr >= gs or lr <= ge)
                or  (lr >= gs and lr <= ge)
            if inGoal then
                VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Space, false, game)
                task.wait(0.01)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end
        end
    end
end

-- ========================
-- SILENT AIM TWIST OF FATE
-- ========================
local function drawVisualLine(startPos, endPos)
    if not twistVisualLine then
        twistVisualLine = Instance.new("Part")
        twistVisualLine.Name = "TwistVisualLine"
        twistVisualLine.Anchored = true
        twistVisualLine.CanCollide = false
        twistVisualLine.CanTouch = false
        twistVisualLine.CastShadow = false
        twistVisualLine.Material = Enum.Material.Neon
        twistVisualLine.Color = Color3.fromRGB(255, 0, 0)
        twistVisualLine.Transparency = 0.1 -- Sangat terang
        twistVisualLine.Parent = workspace
    end
    
    local distance = (startPos - endPos).Magnitude
    twistVisualLine.Size = Vector3.new(0.15, 0.15, distance) -- Lebih tebal
    twistVisualLine.CFrame = CFrame.new(startPos:Lerp(endPos, 0.5), endPos)
    twistVisualLine.Visible = true
end

local function doSilentAimTwist()
    if not silentAimTwistEnabled then 
        if twistVisualLine then twistVisualLine.Visible = false end
        return 
    end
    
    local isRightClick = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    if not isRightClick then
        if twistVisualLine then twistVisualLine.Visible = false end
        return
    end

    local target = getAimbotTarget()
    if not target then
        if twistVisualLine then twistVisualLine.Visible = false end
        return
    end

    local char = LocalPlayer.Character
    if not char then return end
    
    -- Improved gun detection
    local gun = nil
    local tof = char:FindFirstChild("Twist of Fate") or workspace:FindFirstChild(LocalPlayer.Name) and workspace[LocalPlayer.Name]:FindFirstChild("Twist of Fate")
    if tof then
        local ra = tof:FindFirstChild("Right Arm")
        if ra then
            gun = ra:FindFirstChild("gun")
        end
    end

    if gun then
        local startPos = gun.Position
        local endPos = target.Position
        drawVisualLine(startPos, endPos)
        
        if isMouseDown then
            local direction = (endPos - startPos).Unit
            local TwistRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Items") and ReplicatedStorage.Remotes.Items:FindFirstChild("Twist of Fate") and ReplicatedStorage.Remotes.Items["Twist of Fate"]:FindFirstChild("Fire")
            local VisualRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Items") and ReplicatedStorage.Remotes.Items:FindFirstChild("Twist of Fate") and ReplicatedStorage.Remotes.Items["Twist of Fate"]:FindFirstChild("VisualizeBullet")
            
            if TwistRemote then
                -- Fire directly at target position with precision
                TwistRemote:FireServer(gun, direction)
            end
            if VisualRemote then
                -- Visualize bullet following the red line (IDENTICAL TO VIDEO)
                task.spawn(function()
                    local bulletSpeed = 200
                    local travelTime = (endPos - startPos).Magnitude / bulletSpeed
                    local startTime = tick()
                    
                    while tick() - startTime < travelTime do
                        local alpha = (tick() - startTime) / travelTime
                        local currentPos = startPos:Lerp(endPos, alpha)
                        local nextPos = startPos:Lerp(endPos, math.min(alpha + 0.1, 1))
                        VisualRemote:FireServer(currentPos, nextPos, bulletSpeed, "default")
                        task.wait()
                    end
                    VisualRemote:FireServer(endPos, endPos, bulletSpeed, "default")
                end)
            end
        end
    else
        if twistVisualLine then twistVisualLine.Visible = false end
    end
end

-- ========================
-- PANIC LOGIC
-- ========================
local function doPanic()
    -- Save current states before disabling
    previousStates = {
        lunge      = lungeEnabled,
        esp        = espEnabled,
        crosshair  = crosshairEnabled,
        fov        = fovEnabled,
        aimbot     = aimbotEnabled,
        skillcheck = skillcheckEnabled,
        twistOfFate = twistOfFateEnabled,
        silentAimTwist = silentAimTwistEnabled,
        menuVisible = menuVisible,
        mouseIcon = UserInputService.MouseIconEnabled,
        mouseBehavior = UserInputService.MouseBehavior
    }

    -- Disable all features
    lungeEnabled = false
    espEnabled = false
    crosshairEnabled = false
    fovEnabled = false
    aimbotEnabled = false
    skillcheckEnabled = false
    twistOfFateEnabled = false
    silentAimTwistEnabled = false

    updateLungeUI(false)
    updateESPUI(false)
    updateCrosshairUI(false)
    updateFOVUI(false)
    updateAimbotUI(false)
    updateSkillcheckUI(false)
    updateTwistUI(false)
    updateSilentTwistUI(false)
    
    Camera.FieldOfView = defaultFOV
    
    -- Hide Menu (Panic Mode)
    menuVisible = false
    MainFrame.Visible = false
    UserInputService.MouseIconEnabled = false
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    
    print("PANIC KEY ACTIVATED: Active features saved and disabled.")
end

local function undoPanic()
    if previousStates.lunge == nil then return end -- Check if panic was ever used
    
    lungeEnabled      = previousStates.lunge
    espEnabled        = previousStates.esp
    crosshairEnabled  = previousStates.crosshair
    fovEnabled        = previousStates.fov
    aimbotEnabled     = previousStates.aimbot
    skillcheckEnabled = previousStates.skillcheck
    twistOfFateEnabled = previousStates.twistOfFate
    silentAimTwistEnabled = previousStates.silentAimTwist

    updateLungeUI(lungeEnabled)
    updateESPUI(espEnabled)
    updateCrosshairUI(crosshairEnabled)
    updateFOVUI(fovEnabled)
    updateAimbotUI(aimbotEnabled)
    updateSkillcheckUI(skillcheckEnabled)
    updateTwistUI(twistOfFateEnabled)
    updateSilentTwistUI(silentAimTwistEnabled)

    -- Restore Menu & Mouse State exactly as it was
    menuVisible = previousStates.menuVisible
    MainFrame.Visible = menuVisible
    UserInputService.MouseIconEnabled = previousStates.mouseIcon
    UserInputService.MouseBehavior = previousStates.mouseBehavior
    
    print("UNDO PANIC: Previous states restored.")
end

-- ========================
-- INPUT EVENTS
-- ========================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == hideMenuKey then
        menuVisible = not menuVisible
        MainFrame.Visible = menuVisible
        UserInputService.MouseIconEnabled = menuVisible
        if menuVisible then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
    elseif input.KeyCode == panicKey then
        doPanic()
    elseif input.KeyCode == undoPanicKey then
        undoPanic()
    elseif input.KeyCode == toggleKey then
        lungeEnabled = not lungeEnabled
        updateLungeUI(lungeEnabled)
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseDown = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseDown = false
    end
end)

-- ========================
-- MAIN LOOP
-- ========================
RunService.RenderStepped:Connect(function()
    local isAimingTwist = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    if lungeEnabled and isMouseDown and not isMouseOverFrame(MainFrame) and not isAimingTwist then
        pcall(function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp  = char.HumanoidRootPart
                local look = hrp.CFrame.LookVector
                hrp.Velocity = Vector3.new(look.X * lungeSpeed, hrp.Velocity.Y, look.Z * lungeSpeed)
            end
        end)
    end

    -- Aimbot & Skillcheck & Silent Aim
    pcall(doAimbot)
    pcall(doSkillcheck)
    pcall(doSilentAimTwist)

    -- FOV Logic
    if fovEnabled then
        Camera.FieldOfView = targetFOV
    else
        Camera.FieldOfView = defaultFOV
    end



    -- Crosshair Logic
    CrosshairGUI.Visible = crosshairEnabled
    if crosshairEnabled then
        if crosshairType == "Dot" then
            CrosshairGUI.Size     = UDim2.new(0, 6, 0, 6)
            CrosshairGUI.Position = UDim2.new(0.5, -3, 0.5, -3)
            addCorner(CrosshairGUI, 3)
        elseif crosshairType == "Cross" then
            CrosshairGUI.Size     = UDim2.new(0, 14, 0, 14)
            CrosshairGUI.Position = UDim2.new(0.5, -7, 0.5, -7)
        elseif crosshairType == "Circle" then
            CrosshairGUI.Size     = UDim2.new(0, 16, 0, 16)
            CrosshairGUI.Position = UDim2.new(0.5, -8, 0.5, -8)
            CrosshairGUI.BackgroundTransparency = 1
            addStroke(CrosshairGUI, C.red, 1.5)
        end
    end

    -- ESP Logic
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local highlight = p.Character:FindFirstChild("ESPHighlight")
            if highlight then
                highlight.Enabled             = espEnabled
                highlight.FillTransparency    = 0.92
                highlight.OutlineTransparency = 0.3
                highlight.FillColor    = isKiller(p) and Color3.fromRGB(255, 60, 80) or Color3.fromRGB(0, 220, 140)
                highlight.OutlineColor = isKiller(p) and Color3.fromRGB(255, 60, 80) or Color3.fromRGB(0, 220, 140)
            else
                applyESP(p.Character, p)
            end
        end
    end
end)

showTab("HOME")
