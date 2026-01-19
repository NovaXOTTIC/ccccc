local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Player = Players.LocalPlayer

if _G.VyzenLoaded then
    warn("Vyzen Hub is already running!")
    return
end
_G.VyzenLoaded = true

local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success then
    warn("Failed to load Rayfield. Trying backup...")
    Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()
end

local Window = Rayfield:CreateWindow({
   Name = "Vyzen Hub | Blade Ball",
   LoadingTitle = "Initializing Systems...",
   LoadingSubtitle = "Loading Vyzen Engine",
   ConfigurationSaving = { Enabled = true, FolderName = "VyzenHub", FileName = "BladeBallConfig" },
   Discord = {
      Enabled = true,
      Invite = "QB5q7yK",
      RememberJoins = true 
   },
   KeySystem = false
})

local LastClickTime = 0
local LastBallTarget = ""
local LastBallPosition = Vector3.new(0, 0, 0)
local CanClick = true
local ParryCount = 0
local ConnectionStore = {}
local IsAutoSpamming = false
local AutoSpamLoop = nil
local MobileGui = nil

local AbilityStates = {
    DeathSlash = false,
    Infinity = false,
    Phantom = false,
    Singularity = false
}

local Config = {
    AutoParry = true,
    ParryAccuracy = 95,
    AutoSpamSpeed = 0.01,
    AutoSpamMode = "Normal",
    BurstClicks = 2,
    BurstDelay = 0.005,
    WalkSpeed = 34,
    JumpPower = 50,
    InfiniteJump = false,
    Fly = false,
    FlySpeed = 50,
    Noclip = false,
    AntiRagdoll = true,
    AutoSpawn = true,
    
    DetectDeathSlash = true,
    DetectInfinity = true,
    DetectPhantom = true,
    DetectSingularity = true,
    
    BallDome = true,
    FOV = 70,
    Fullbright = false,
    SpeedDivisorMultiplier = 0.85
}

local Visuals = {
    Folder = Instance.new("Folder", Workspace),
    BallDome = nil,
    DomeDistanceLabel = nil
}
Visuals.Folder.Name = "VyzenVisuals"

local AutoParry = {}

AutoParry.GetBall = function()
    local bestBall = nil
    local shortestDist = math.huge
    
    local ballsFolder = Workspace:FindFirstChild("Balls")
    if not ballsFolder then return nil end

    for _, instance in pairs(ballsFolder:GetChildren()) do
        if instance:IsA("BasePart") then
            local isRealBall = instance:GetAttribute("realBall") == true
            local notVisual = instance:GetAttribute("visualBall") ~= true
            
            if not isRealBall and instance.Name == "Ball" then
                isRealBall = true
            end
            
            if isRealBall and notVisual then
                local char = Player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (hrp.Position - instance.Position).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        bestBall = instance
                    end
                end
            end
        end
    end
    
    if bestBall then 
        bestBall.CanCollide = false
    end
    return bestBall
end

-- FIXED: Better click function that works when tabbed out and doesn't click GUIs
local function Click()
    pcall(function()
        if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
        
        -- Use VirtualInputManager for more reliable clicks that work when tabbed out
        local vim = VirtualInputManager
        local camera = Workspace.CurrentCamera
        local viewportSize = camera.ViewportSize
        
        -- Click at center of screen (where the parry hitbox usually is)
        vim:SendMouseButtonEvent(viewportSize.X / 2, viewportSize.Y / 2, 0, true, game, 1)
        task.wait()
        vim:SendMouseButtonEvent(viewportSize.X / 2, viewportSize.Y / 2, 0, false, game, 1)
    end)
end

local function BurstClick()
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
    for i = 1, Config.BurstClicks do
        Click()
        if i < Config.BurstClicks then
            task.wait(Config.BurstDelay)
        end
    end
end

local function StartAutoSpam()
    if AutoSpamLoop then return end
    IsAutoSpamming = true
    
    AutoSpamLoop = task.spawn(function()
        while IsAutoSpamming and _G.VyzenLoaded do
            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                if Config.AutoSpamMode == "Burst" then
                    BurstClick()
                else
                    Click()
                end
            end
            if Config.AutoSpamSpeed > 0 then
                task.wait(Config.AutoSpamSpeed)
            else
                task.wait(0.001)
            end
        end
        AutoSpamLoop = nil
    end)
    
    Rayfield:Notify({
        Title = "Auto Spam ON",
        Content = "Press F or button to stop",
        Duration = 2
    })
    
    if MobileGui then
        local btn = MobileGui:FindFirstChild("SpamButton")
        if btn then
            btn.Text = "ON"
            btn.TextColor3 = Color3.fromRGB(60, 255, 60)
            local stroke = btn:FindFirstChild("UIStroke")
            if stroke then
                stroke.Color = Color3.fromRGB(60, 255, 60)
            end
        end
    end
end

local function StopAutoSpam()
    IsAutoSpamming = false
    if AutoSpamLoop then
        task.cancel(AutoSpamLoop)
        AutoSpamLoop = nil
    end
    
    Rayfield:Notify({
        Title = "Auto Spam OFF",
        Content = "Press F or button to start",
        Duration = 2
    })
    
    if MobileGui then
        local btn = MobileGui:FindFirstChild("SpamButton")
        if btn then
            btn.Text = "OFF"
            btn.TextColor3 = Color3.fromRGB(255, 60, 60)
            local stroke = btn:FindFirstChild("UIStroke")
            if stroke then
                stroke.Color = Color3.fromRGB(255, 60, 60)
            end
        end
    end
end

local function CreateMobileGui()
    local CoreGui = game:GetService("CoreGui")
    
    if _G.VyzenButtonLoaded and _G.CleanupVyzenButton then
        _G.CleanupVyzenButton()
    end
    _G.VyzenButtonLoaded = true
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "VyzenSpamButton"
    ScreenGui.DisplayOrder = 1000
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = false
    if gethui then
        ScreenGui.Parent = gethui()
    else
        ScreenGui.Parent = CoreGui
    end
    
    local Button = Instance.new("TextButton")
    Button.Name = "SpamButton"
    Button.Size = UDim2.new(0, 80, 0, 80)
    Button.Position = UDim2.new(1, -100, 0.5, -40)
    Button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Button.BackgroundTransparency = 0.3
    Button.Text = "OFF"
    Button.TextColor3 = Color3.fromRGB(255, 60, 60)
    Button.TextScaled = true
    Button.Font = Enum.Font.GothamBold
    Button.AutoButtonColor = false
    Button.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(1, 0)
    UICorner.Parent = Button
    
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(255, 60, 60)
    UIStroke.Thickness = 3
    UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    UIStroke.Parent = Button
    
    local dragging = false
    local dragInput, mousePos, framePos
    local clickStartTime = 0
    local isDragging = false
    
    Button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            clickStartTime = tick()
            isDragging = false
            dragging = true
            mousePos = input.Position
            framePos = Button.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    
                    local clickDuration = tick() - clickStartTime
                    if clickDuration < 0.2 and not isDragging then
                        if IsAutoSpamming then
                            StopAutoSpam()
                        else
                            StartAutoSpam()
                        end
                    end
                end
            end)
        end
    end)
    
    Button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            if delta.Magnitude > 5 then
                isDragging = true
            end
            Button.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end
    end)
    
    MobileGui = ScreenGui
    
    _G.CleanupVyzenButton = function()
        _G.VyzenButtonLoaded = false
        if ScreenGui then ScreenGui:Destroy() end
    end
end

local function CreateVisuals()
    if Visuals.Folder then
        Visuals.Folder:ClearAllChildren()
    end
    
    pcall(function()
        local dome = Instance.new("Part")
        dome.Name = "BallDome"
        dome.Shape = Enum.PartType.Ball
        dome.Material = Enum.Material.ForceField
        dome.Transparency = 0.7
        dome.Color = Color3.fromRGB(100, 200, 255)
        dome.CanCollide = false
        dome.Anchored = true
        dome.Size = Vector3.new(50, 50, 50)
        dome.CastShadow = false
        dome.Parent = Visuals.Folder
        Visuals.BallDome = dome
        
        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = "DistanceLabel"
        billboardGui.AlwaysOnTop = true
        billboardGui.Size = UDim2.new(0, 200, 0, 80)
        billboardGui.StudsOffset = Vector3.new(0, 0, 0)
        billboardGui.Parent = dome
        
        local textLabel = Instance.new("TextLabel")
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 16
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextStrokeTransparency = 0.5
        textLabel.Text = "Distance: --"
        textLabel.TextWrapped = true
        textLabel.Parent = billboardGui
        
        Visuals.DomeDistanceLabel = textLabel
    end)
end

local function UpdateVisuals(ball, hrp, parryRadius, distance, ballSpeed)
    if not Config.BallDome or not Visuals.BallDome then return end
    
    local dome = Visuals.BallDome
    
    if not hrp or not hrp.Parent then
        dome.Transparency = 1
        if Visuals.DomeDistanceLabel then
            Visuals.DomeDistanceLabel.Text = "No Player"
        end
        return
    end
    
    if ball and distance and ball.Parent then
        dome.Transparency = 0.7
        dome.CFrame = hrp.CFrame
        
        local target = ball:GetAttribute("target")
        local isTargeted = (target == Player.Name)
        
        if isTargeted then
            if distance <= parryRadius then
                dome.Color = Color3.fromRGB(50, 255, 50)
                dome.Transparency = 0.5
            elseif distance <= parryRadius * 2 then
                dome.Color = Color3.fromRGB(255, 255, 50)
            else
                dome.Color = Color3.fromRGB(255, 100, 50)
            end
        else
            dome.Color = Color3.fromRGB(100, 200, 255)
        end
        
        if Visuals.DomeDistanceLabel then
            local distText = string.format("%.1f studs", distance)
            local statusText = ""
            
            if isTargeted then
                if distance <= parryRadius then
                    statusText = "\nHIT NOW!"
                    Visuals.DomeDistanceLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
                else
                    statusText = "\nWait..."
                    Visuals.DomeDistanceLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
                end
            else
                statusText = "\nSafe"
                Visuals.DomeDistanceLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
            end
            
            Visuals.DomeDistanceLabel.Text = distText .. statusText
        end
    else
        dome.CFrame = hrp.CFrame
        dome.Transparency = 0.9
        if Visuals.DomeDistanceLabel then
            Visuals.DomeDistanceLabel.Text = "No Ball"
        end
    end
end

local function AutoSpawnPlayer()
    if not Config.AutoSpawn then return end
    
    task.spawn(function()
        local success, err = pcall(function()
            local spawnRemote = ReplicatedStorage:WaitForChild("Remotes", 5)
            if spawnRemote then
                local spawnFunc = spawnRemote:FindFirstChild("Spawn") or spawnRemote:FindFirstChild("SpawnPlayer")
                if spawnFunc then
                    spawnFunc:FireServer()
                end
            end
        end)
        if not success then
            warn("Auto spawn failed:", err)
        end
    end)
end

local Combat = Window:CreateTab("Combat", 4483362458)

Combat:CreateSection("Auto Parry")

Combat:CreateToggle({
   Name = "Enable Auto Parry",
   CurrentValue = true,
   Flag = "AutoParry",
   Callback = function(v) 
      Config.AutoParry = v 
   end,
})

Combat:CreateSlider({
   Name = "Parry Accuracy",
   Range = {1, 100},
   Increment = 1,
   CurrentValue = 95,
   Flag = "ParryAccuracy",
   Callback = function(v)
      Config.SpeedDivisorMultiplier = 0.7 + ((v - 1) / 99) * 0.35
   end,
})

Combat:CreateSection("Auto Spam")

Combat:CreateParagraph({
   Title = "Controls",
   Content = "Press F or mobile button. Set to 0 for max speed!"
})

Combat:CreateDropdown({
   Name = "Mode",
   Options = {"Normal", "Burst"},
   CurrentOption = "Normal",
   Flag = "SpamMode",
   Callback = function(v)
      Config.AutoSpamMode = v
   end,
})

Combat:CreateSlider({
   Name = "Speed (seconds)",
   Range = {0, 0.5},
   Increment = 0.001,
   CurrentValue = 0.01,
   Flag = "AutoSpamSpeed",
   Callback = function(v) Config.AutoSpamSpeed = v end,
})

Combat:CreateSlider({
   Name = "Burst Clicks",
   Range = {1, 5},
   Increment = 1,
   CurrentValue = 2,
   Flag = "BurstClicks",
   Callback = function(v) Config.BurstClicks = v end,
})

local AutoSpamLabel = Combat:CreateLabel("Auto Spam: OFF")

Combat:CreateSection("Detections")

Combat:CreateToggle({Name = "Death Slash", CurrentValue = true, Flag = "DetectDeathSlash", Callback = function(v) Config.DetectDeathSlash = v end})
Combat:CreateToggle({Name = "Infinity", CurrentValue = true, Flag = "DetectInfinity", Callback = function(v) Config.DetectInfinity = v end})
Combat:CreateToggle({Name = "Phantom", CurrentValue = true, Flag = "DetectPhantom", Callback = function(v) Config.DetectPhantom = v end})
Combat:CreateToggle({Name = "Singularity", CurrentValue = true, Flag = "DetectSingularity", Callback = function(v) Config.DetectSingularity = v end})

local ParryLabel = Combat:CreateLabel("Parries: 0")

Combat:CreateButton({
   Name = "Reset Counter",
   Callback = function()
      ParryCount = 0
      ParryLabel:Set("Parries: 0")
   end,
})

local Movement = Window:CreateTab("Movement", 4483362458)

Movement:CreateSection("Auto Spawn")

Movement:CreateToggle({
   Name = "Auto Spawn (34 WS)",
   CurrentValue = true,
   Flag = "AutoSpawn",
   Callback = function(v) 
      Config.AutoSpawn = v 
      if v then
         Config.WalkSpeed = 34
      end
   end,
})

Movement:CreateButton({
   Name = "Spawn Now",
   Callback = function()
      AutoSpawnPlayer()
      task.wait(0.5)
      if Player.Character then
         local hum = Player.Character:FindFirstChild("Humanoid")
         if hum then
            hum.WalkSpeed = 34
         end
      end
   end,
})

Movement:CreateSection("Movement Settings")

Movement:CreateSlider({Name = "Walk Speed", Range = {16, 150}, Increment = 1, CurrentValue = 34, Flag = "WalkSpeed", Callback = function(v) Config.WalkSpeed = v end})
Movement:CreateSlider({Name = "Jump Power", Range = {50, 200}, Increment = 5, CurrentValue = 50, Flag = "JumpPower", Callback = function(v) Config.JumpPower = v end})
Movement:CreateToggle({Name = "Infinite Jump", CurrentValue = false, Flag = "InfiniteJump", Callback = function(v) Config.InfiniteJump = v end})
Movement:CreateToggle({Name = "Anti-Ragdoll", CurrentValue = true, Flag = "AntiRagdoll", Callback = function(v) Config.AntiRagdoll = v end})

local function EnableFly()
    if not Config.Fly then return end
    local char = Player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, obj in pairs(hrp:GetChildren()) do
        if obj:IsA("BodyGyro") or obj:IsA("BodyVelocity") then obj:Destroy() end
    end

    local bg = Instance.new("BodyGyro", hrp)
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.P = 9e9
    bg.D = 500

    local bv = Instance.new("BodyVelocity", hrp)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)

    local flyLoop
    flyLoop = RunService.Heartbeat:Connect(function()
        if not Config.Fly or not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then 
            if bg then bg:Destroy() end
            if bv then bv:Destroy() end
            if flyLoop then flyLoop:Disconnect() end
            return 
        end
        
        local cam = Workspace.CurrentCamera
        bg.CFrame = cam.CFrame
        
        local move = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + (cam.CFrame.LookVector * Config.FlySpeed) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - (cam.CFrame.LookVector * Config.FlySpeed) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - (cam.CFrame.RightVector * Config.FlySpeed) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + (cam.CFrame.RightVector * Config.FlySpeed) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, Config.FlySpeed, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, Config.FlySpeed, 0) end
        
        bv.Velocity = move
    end)
    table.insert(ConnectionStore, flyLoop)
end

Movement:CreateToggle({
   Name = "Fly",
   CurrentValue = false,
   Flag = "Fly",
   Callback = function(v)
      Config.Fly = v
      if v then EnableFly() else
         pcall(function()
            for _, v in pairs(Player.Character.HumanoidRootPart:GetChildren()) do
               if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then v:Destroy() end
            end
         end)
      end
   end,
})

Movement:CreateSlider({Name = "Fly Speed", Range = {10, 200}, Increment = 5, CurrentValue = 50, Flag = "FlySpeed", Callback = function(v) Config.FlySpeed = v end})
Movement:CreateToggle({Name = "Noclip", CurrentValue = false, Flag = "Noclip", Callback = function(v) Config.Noclip = v end})

local VisualsTab = Window:CreateTab("Visuals", 4483362458)

VisualsTab:CreateToggle({Name = "Ball Dome", CurrentValue = true, Flag = "BallDome", Callback = function(v) Config.BallDome = v end})

VisualsTab:CreateSlider({
   Name = "FOV",
   Range = {70, 120},
   Increment = 1,
   CurrentValue = 70,
   Flag = "FOV",
   Callback = function(v)
      Config.FOV = v
      if Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView = v end
   end,
})

VisualsTab:CreateToggle({
   Name = "Fullbright",
   CurrentValue = false,
   Flag = "Fullbright",
   Callback = function(v)
      Config.Fullbright = v
      if v then
         Lighting.Brightness = 2
         Lighting.ClockTime = 14
         Lighting.FogEnd = 100000
      else
         Lighting.Brightness = 1
         Lighting.ClockTime = 12
      end
   end,
})

CreateVisuals()
CreateMobileGui()

local function WaitForGameLoad()
    if not Player.Character then Player.CharacterAdded:Wait() end
    local char = Player.Character
    char:WaitForChild("HumanoidRootPart", 10)
    char:WaitForChild("Humanoid", 10)
    task.wait(0.5)
end

WaitForGameLoad()

local function SafeRemoteConnect(remoteName, callback)
    task.spawn(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
        if not remotes then return end
        local remote = remotes:FindFirstChild(remoteName)
        if remote then
            local conn = remote.OnClientEvent:Connect(callback)
            table.insert(ConnectionStore, conn)
        end
    end)
end

SafeRemoteConnect("DeathBall", function(value) AbilityStates.DeathSlash = value end)
SafeRemoteConnect("InfinityBall", function(a, b) AbilityStates.Infinity = b end)
SafeRemoteConnect("Phantom", function(a, b) AbilityStates.Phantom = (b and b.Name == Player.Name) end)

-- FIXED: Use RenderStepped instead of Heartbeat for better performance when tabbed out
local PhysicsLoop = RunService.RenderStepped:Connect(function()
    pcall(function()
        local char = Player.Character
        if not char then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then 
            UpdateVisuals(nil, nil, 0, nil, nil)
            return 
        end
        
        hum.WalkSpeed = Config.WalkSpeed
        hum.JumpPower = Config.JumpPower
        
        if Config.AntiRagdoll then
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end

        if Config.Noclip then
            for _, part in pairs(char:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end

        if not Config.AutoParry then 
            UpdateVisuals(nil, hrp, 0, nil, nil)
            return 
        end
        
        local ball = AutoParry.GetBall()
        if not ball or not ball.Parent then 
            UpdateVisuals(nil, hrp, 0, nil, nil)
            return 
        end

        local ballTarget = ball:GetAttribute("target")
        if not ballTarget or ballTarget == "" then
            UpdateVisuals(ball, hrp, 0, nil, nil)
            return
        end
        
        local isTarget = (ballTarget == Player.Name)
        
        local ballVelocity = Vector3.new(0, 0, 0)
        local zoomies = ball:FindFirstChild('zoomies')
        
        if zoomies and zoomies:FindFirstChild("VectorVelocity") then
            ballVelocity = zoomies.VectorVelocity
        elseif zoomies and zoomies:IsA("BodyVelocity") then
            ballVelocity = zoomies.Velocity
        else
            ballVelocity = ball.AssemblyLinearVelocity or Vector3.zero
        end
        
        local ballSpeed = ballVelocity.Magnitude
        
        if ballSpeed < 5 then
            UpdateVisuals(ball, hrp, 0, nil, nil)
            return
        end
        
        local ballToPlayer = (hrp.Position - ball.Position)
        local distance = ballToPlayer.Magnitude
        local Direction = ballToPlayer.Unit
        local Ball_Direction = ballVelocity.Unit
        local Dot = Direction:Dot(Ball_Direction)

        if Config.DetectSingularity and hrp:FindFirstChild('SingularityCape') then 
            UpdateVisuals(ball, hrp, 0, distance, ballSpeed)
            return 
        end
        if Config.DetectDeathSlash and AbilityStates.DeathSlash then 
            UpdateVisuals(ball, hrp, 0, distance, ballSpeed)
            return 
        end
        if Config.DetectInfinity and AbilityStates.Infinity then 
            UpdateVisuals(ball, hrp, 0, distance, ballSpeed)
            return 
        end
        if Config.DetectPhantom and AbilityStates.Phantom then 
            UpdateVisuals(ball, hrp, 0, distance, ballSpeed)
            return 
        end

        local targetChanged = (ballTarget ~= LastBallTarget)
        if targetChanged then
            CanClick = true
        end
        
        local clickTime = tick()
        if clickTime - LastClickTime < 0.15 then
            CanClick = false
        elseif clickTime - LastClickTime > 0.4 then
            CanClick = true
        end

        LastBallTarget = ballTarget
        LastBallPosition = ball.Position

        if isTarget and CanClick then
            if distance > 150 then
                UpdateVisuals(ball, hrp, 0, distance, ballSpeed)
                return
            end
            
            local parryAccuracy = math.max(ballSpeed / (2.5 * Config.SpeedDivisorMultiplier), 15)
            
            UpdateVisuals(ball, hrp, parryAccuracy, distance, ballSpeed)
            
            if Dot > 0 and distance <= parryAccuracy then
                Click()
                ParryCount = ParryCount + 1
                LastClickTime = clickTime
                CanClick = false
            end
        else
            UpdateVisuals(ball, hrp, 0, distance, ballSpeed)
        end
    end)
end)
table.insert(ConnectionStore, PhysicsLoop)

local RespawnHook = Player.CharacterAdded:Connect(function(newChar)
    CanClick = true
    LastClickTime = 0
    LastBallTarget = ""
    LastBallPosition = Vector3.new(0, 0, 0)
    
    if IsAutoSpamming then StopAutoSpam() end
    
    newChar:WaitForChild("HumanoidRootPart", 10)
    newChar:WaitForChild("Humanoid", 10)
    task.wait(0.5)
    
    if Visuals.Folder then
        Visuals.Folder:ClearAllChildren()
        CreateVisuals()
    end
    
    local hum = newChar:FindFirstChild("Humanoid")
    if hum and Config.AutoSpawn then
        hum.WalkSpeed = 34
        AutoSpawnPlayer()
    end
    
    if Config.Fly then task.wait(0.5) EnableFly() end
end)
table.insert(ConnectionStore, RespawnHook)

local JumpHook = UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump and Player.Character and Player.Character:FindFirstChild("Humanoid") then
        Player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
table.insert(ConnectionStore, JumpHook)

local AutoSpamHook = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        if IsAutoSpamming then StopAutoSpam() else StartAutoSpam() end
    end
end)
table.insert(ConnectionStore, AutoSpamHook)

Window.OnUnload = function()
    _G.VyzenLoaded = false
    StopAutoSpam()
    
    for _, conn in pairs(ConnectionStore) do
        if conn and typeof(conn) == "RBXScriptConnection" then 
            pcall(function() conn:Disconnect() end)
        end
    end
    
    if Visuals.Folder then pcall(function() Visuals.Folder:Destroy() end) end
    if _G.CleanupVyzenButton then _G.CleanupVyzenButton() end
end

task.spawn(function()
    while _G.VyzenLoaded and task.wait(1) do
        pcall(function()
            ParryLabel:Set("Parries: " .. ParryCount)
            local spamStatus = IsAutoSpamming and "ON" or "OFF"
            AutoSpamLabel:Set("Auto Spam: " .. spamStatus)
        end)
    end
end)

if Config.AutoSpawn then
    task.wait(1)
    AutoSpawnPlayer()
    if Player.Character then
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum then
            hum.WalkSpeed = 34
        end
    end
end

Rayfield:Notify({
    Title = "Vyzen Hub Loaded", 
    Content = "Optimized & ready! Fixed auto-click & tab-out bugs.", 
    Duration = 4
})

print("Vyzen Hub: Loaded successfully - Fixed version")
