local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local ALLOWED_GAME_ID = 87029994390208

if game.PlaceId ~= ALLOWED_GAME_ID then
    warn("wrong game Twin.")
    return
end

local playerGui = player:WaitForChild("PlayerGui")
local zombieFolder = workspace:WaitForChild("RAB_ZombieApocalypse")

local enabled = false
local autoJumpEnabled = false
local unloaded = false
local minimized = false
local currentZombie = nil
local connections = {}
local jumpThreadToken = 0

local oldGui = playerGui:FindFirstChild("ZombieTPGui")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ZombieTPGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(250, 155)
frame.Position = UDim2.new(0, 20, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -65, 0, 30)
title.Position = UDim2.fromOffset(8, 0)
title.BackgroundTransparency = 1
title.Text = "Zombie Teleporter"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local function makeButton(text, position, size, color)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.Parent = frame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 5)
    buttonCorner.Parent = button

    return button
end

local minimize = makeButton(
    "-", UDim2.new(1, -55, 0, 2),
    UDim2.fromOffset(25, 25), Color3.fromRGB(55, 55, 65)
)

local close = makeButton(
    "X", UDim2.new(1, -28, 0, 2),
    UDim2.fromOffset(25, 25), Color3.fromRGB(170, 45, 45)
)

local toggle = makeButton(
    "Teleport: OFF", UDim2.fromOffset(8, 37),
    UDim2.new(1, -16, 0, 32), Color3.fromRGB(150, 45, 45)
)

local jumpToggle = makeButton(
    "Auto Jump: OFF", UDim2.fromOffset(8, 76),
    UDim2.new(1, -16, 0, 32), Color3.fromRGB(150, 45, 45)
)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 20)
status.Position = UDim2.fromOffset(8, 117)
status.BackgroundTransparency = 1
status.Text = "Status: Disabled"
status.TextColor3 = Color3.fromRGB(210, 210, 210)
status.TextSize = 12
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local dragging = false
local dragStart, startPos

table.insert(connections, title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end))

table.insert(connections, UserInputService.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end))

table.insert(connections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

local function getRoot()
    local character = player.Character
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

local function isAliveZombie(model)
    if not model or not model:IsA("Model") then return false end
    if not model:IsDescendantOf(zombieFolder) then return false end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")

    return humanoid ~= nil
        and root ~= nil
        and humanoid.Health > 0
end

local function nearestZombie()
    local root = getRoot()
    if not root then return nil end

    local best, bestDistance = nil, math.huge

    for _, model in ipairs(zombieFolder:GetChildren()) do
        if isAliveZombie(model) then
            local zombieRoot = model:FindFirstChild("HumanoidRootPart")
            local distance = (root.Position - zombieRoot.Position).Magnitude

            if distance < bestDistance then
                best = model
                bestDistance = distance
            end
        end
    end

    return best
end

local function updateTeleportButton()
    toggle.Text = enabled and "Teleport: ON" or "Teleport: OFF"
    toggle.BackgroundColor3 = enabled
        and Color3.fromRGB(40, 145, 75)
        or Color3.fromRGB(150, 45, 45)
end

local function updateJumpButton()
    jumpToggle.Text = autoJumpEnabled and "Auto Jump: ON" or "Auto Jump: OFF"
    jumpToggle.BackgroundColor3 = autoJumpEnabled
        and Color3.fromRGB(40, 145, 75)
        or Color3.fromRGB(150, 45, 45)
end

table.insert(connections, toggle.MouseButton1Click:Connect(function()
    enabled = not enabled
    currentZombie = nil
    updateTeleportButton()
    status.Text = enabled and "Status: Finding zombies" or "Status: Disabled"
end))

table.insert(connections, jumpToggle.MouseButton1Click:Connect(function()
    autoJumpEnabled = not autoJumpEnabled
    jumpThreadToken += 1

    local myToken = jumpThreadToken
    updateJumpButton()

    if autoJumpEnabled then
        task.spawn(function()
            while autoJumpEnabled and not unloaded
                and myToken == jumpThreadToken do

                task.wait(120)

                if not autoJumpEnabled or unloaded
                    or myToken ~= jumpThreadToken then
                    break
                end

                pcall(function()
                    local virtualInput = game:GetService("VirtualInputManager")

                    virtualInput:SendKeyEvent(
                        true,
                        Enum.KeyCode.Space,
                        false,
                        game
                    )

                    task.wait(0.1)

                    virtualInput:SendKeyEvent(
                        false,
                        Enum.KeyCode.Space,
                        false,
                        game
                    )
                end)
            end
        end)
    end
end))

table.insert(connections, minimize.MouseButton1Click:Connect(function()
    minimized = not minimized

    toggle.Visible = not minimized
    jumpToggle.Visible = not minimized
    status.Visible = not minimized

    frame.Size = minimized
        and UDim2.fromOffset(250, 30)
        or UDim2.fromOffset(250, 155)

    minimize.Text = minimized and "+" or "-"
end))

table.insert(connections, close.MouseButton1Click:Connect(function()
    unloaded = true
    enabled = false
    autoJumpEnabled = false
    jumpThreadToken += 1

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    gui:Destroy()
end))

table.insert(connections, RunService.Heartbeat:Connect(function()
    if unloaded or not enabled then return end

    local root = getRoot()
    local character = player.Character
    local humanoid = character
        and character:FindFirstChildOfClass("Humanoid")

    if not root or not humanoid or humanoid.Health <= 0 then
        status.Text = "Status: Waiting for character"
        return
    end

    if not isAliveZombie(currentZombie) then
        currentZombie = nearestZombie()
    end

    if not currentZombie then
        status.Text = "Status: No living zombies"
        return
    end

    local zombieRoot = currentZombie:FindFirstChild("HumanoidRootPart")

    if zombieRoot then
        root.CFrame = zombieRoot.CFrame * CFrame.new(0, 0, -2)
        status.Text = "Target: " .. currentZombie.Name
    end
end))
