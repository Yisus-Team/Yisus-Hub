local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Palette = {
    Background   = Color3.fromRGB(13, 15, 22),
    Inline       = Color3.fromRGB(10, 12, 18),
    Surface      = Color3.fromRGB(20, 24, 34),
    Element      = Color3.fromRGB(29, 35, 49),
    Hover        = Color3.fromRGB(41, 49, 69),
    Border       = Color3.fromRGB(53, 63, 86),
    SubBorder    = Color3.fromRGB(36, 43, 59),
    TopHighlight = Color3.fromRGB(75, 89, 119),
    Text         = Color3.fromRGB(241, 244, 252),
    Dim          = Color3.fromRGB(151, 163, 188),
    Accent       = Color3.fromRGB(116, 139, 255),
    AccentHi     = Color3.fromRGB(155, 172, 255),
    AccentLo     = Color3.fromRGB(77, 94, 190),
    Success      = Color3.fromRGB(112, 222, 162),
    Risky        = Color3.fromRGB(235, 110, 120),
}

local ChangelogColors = {
    Added   = "#78DC82",
    Removed = "#DC6464",
    Fixed   = "#DCC864",
}

local DefaultLogo = "rbxassetid://6942501524"
local FontUrl     = "https://github.com/SzNeo8083/SzNeo8083.github.io/raw/refs/heads/main/fonts/verdanab.ttf"
local WebsiteUrl  = "https://yisus-hub.vercel.app/"
local DiscordUrl  = "https://discord.gg/r3kUPsk99A"

local RegularFont = Font.fromEnum(Enum.Font.Arial)
local BoldFont    = Font.fromEnum(Enum.Font.ArialBold)

do
    if writefile and isfile and getcustomasset then
        local assetsFolder = "yisus_assets"
        if makefolder and isfolder and not isfolder(assetsFolder) then
            pcall(makefolder, assetsFolder)
        end
        local fontPath = assetsFolder .. "/verdanab.ttf"
        if not isfile(fontPath) then
            local fetched, data = pcall(function() return game:HttpGet(FontUrl) end)
            if fetched and type(data) == "string" and #data > 0 then
                pcall(writefile, fontPath, data)
            end
        end
        if isfile(fontPath) then
            local resolved, asset = pcall(getcustomasset, fontPath)
            if resolved and asset then
                local loaded, loadedFont = pcall(Font.new, asset)
                if loaded and loadedFont then
                    RegularFont = loadedFont
                    BoldFont    = loadedFont
                end
            end
        end
    end
end

local function createInstance(class, props)
    local instance = Instance.new(class)
    for key, value in pairs(props or {}) do
        instance[key] = value
    end
    return instance
end

local function applyBorderStroke(parent, color, thickness)
    return createInstance("UIStroke", {
        Parent          = parent,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        LineJoinMode    = Enum.LineJoinMode.Miter,
        Color           = color or Palette.Border,
        Thickness       = thickness or 1,
    })
end

local function addCorner(parent, radius)
    return createInstance("UICorner", {
        Parent        = parent,
        CornerRadius  = UDim.new(0, radius or 8),
    })
end

local function copyToClipboard(value)
    local clipboard = setclipboard or toclipboard or toClipboard
    return type(clipboard) == "function" and pcall(clipboard, value)
end

local function addTopHighlight(parent, inset, color)
    return createInstance("Frame", {
        Parent           = parent,
        BackgroundColor3 = color or Palette.TopHighlight,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, inset or 0, 0, inset or 0),
        Size             = UDim2.new(1, -(inset or 0) * 2, 0, 1),
    })
end

local function addBottomShade(parent, inset, color)
    return createInstance("Frame", {
        Parent           = parent,
        BackgroundColor3 = color or Palette.Inline,
        BorderSizePixel  = 0,
        AnchorPoint      = Vector2.new(0, 1),
        Position         = UDim2.new(0, inset or 0, 1, -(inset or 0)),
        Size             = UDim2.new(1, -(inset or 0) * 2, 0, 1),
    })
end

local function playTween(instance, info, props)
    local tweenObject = TweenService:Create(instance, info, props)
    tweenObject:Play()
    return tweenObject
end

local Tweens = {
    Drop      = TweenInfo.new(0.85, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
    Pop       = TweenInfo.new(0.55, Enum.EasingStyle.Back,   Enum.EasingDirection.Out),
    Slide     = TweenInfo.new(0.5,  Enum.EasingStyle.Back,   Enum.EasingDirection.Out),
    Item      = TweenInfo.new(0.32, Enum.EasingStyle.Back,   Enum.EasingDirection.Out),
    Button    = TweenInfo.new(0.42, Enum.EasingStyle.Back,   Enum.EasingDirection.Out),
    ShutDrop  = TweenInfo.new(0.4,  Enum.EasingStyle.Back,   Enum.EasingDirection.In),
    ShutSlide = TweenInfo.new(0.3,  Enum.EasingStyle.Back,   Enum.EasingDirection.In),
    ShutItem  = TweenInfo.new(0.18, Enum.EasingStyle.Back,   Enum.EasingDirection.In),
    FadeOut   = TweenInfo.new(0.14, Enum.EasingStyle.Quad,   Enum.EasingDirection.In),
    FadeIn    = TweenInfo.new(0.28, Enum.EasingStyle.Quint,  Enum.EasingDirection.Out),
    Fast      = TweenInfo.new(0.15, Enum.EasingStyle.Quad,   Enum.EasingDirection.Out),
}

local Layout = {
    OuterWidth     = 640,
    OuterHeight    = 450,
    SidePanelWidth = 190,
    Padding        = 7,
    TitleBarHeight = 38,
}

local Loader = {}
Loader.__index = Loader

function Loader.new(options)
    options = options or {}
    local self = setmetatable({}, Loader)
    self.Name        = options.Name or "YisusHub"
    self.Logo        = options.Logo or DefaultLogo
    self.Games       = {}
    self.Current     = nil
    self._entries    = {}
    self._isClosing  = false
    self._isOpened   = false

    local screenGui = createInstance("ScreenGui", {
        Name             = "YisusHubLoader_" .. HttpService:GenerateGUID(false),
        IgnoreGuiInset   = true,
        ResetOnSpawn     = false,
        ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
        DisplayOrder     = 9999,
    })
    pcall(function()
        screenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if not screenGui.Parent then
        pcall(function()
            screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end)
    end
    self.ScreenGui = screenGui

    local mainFrame = createInstance("Frame", {
        Parent               = screenGui,
        AnchorPoint          = Vector2.new(0.5, 0.5),
        Position             = UDim2.new(0.5, 0, 0.5, 0),
        Size                 = UDim2.fromOffset(Layout.OuterWidth, Layout.OuterHeight),
        BackgroundColor3     = Palette.Background,
        BorderSizePixel      = 0,
        Visible              = false,
        ClipsDescendants     = true,
    })
    applyBorderStroke(mainFrame, Palette.Border, 1)
    addCorner(mainFrame, 12)
    addTopHighlight(mainFrame, 1)
    self.Frame         = mainFrame
    self._homePosition = UDim2.new(0.5, 0, 0.5, 0)
    self._baseScale    = 1
    local camera = workspace.CurrentCamera
    if UserInputService.TouchEnabled and camera then
        local viewport = camera.ViewportSize
        self._baseScale = math.max(0.25, math.min(
            1,
            (viewport.X - 24) / Layout.OuterWidth,
            (viewport.Y - 24) / Layout.OuterHeight
        ))
    end
    self._scaler = createInstance("UIScale", { Parent = mainFrame, Scale = self._baseScale })

    local titleBar = createInstance("Frame", {
        Parent           = mainFrame,
        BackgroundColor3 = Palette.Element,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 0, Layout.TitleBarHeight),
        Active           = true,
    })
    self._titleBar = titleBar

    createInstance("Frame", {
        Parent           = titleBar,
        BackgroundColor3 = Palette.Border,
        BorderSizePixel  = 0,
        AnchorPoint      = Vector2.new(0, 1),
        Position         = UDim2.new(0, 0, 1, 0),
        Size             = UDim2.new(1, 0, 0, 1),
    })

    createInstance("Frame", {
        Parent           = titleBar,
        BackgroundColor3 = Palette.Accent,
        BorderSizePixel  = 0,
        Size             = UDim2.new(0, 3, 1, 0),
    })

    local hasLogo = self.Logo and self.Logo ~= "" and self.Logo ~= "rbxassetid://0"
    local titleOffset = 12
    if hasLogo then
        local logoImage = createInstance("ImageLabel", {
            Parent               = titleBar,
            Image                = self.Logo,
            BackgroundTransparency = 1,
            AnchorPoint          = Vector2.new(0, 0.5),
            Position             = UDim2.new(0, 8, 0.5, 0),
            Size                 = UDim2.new(0, 22, 0, 22),
        })
        self._logoScale   = createInstance("UIScale", { Parent = logoImage, Scale = 1 })
        titleOffset       = 38
    end

    self._title = createInstance("TextLabel", {
        Parent               = titleBar,
        FontFace             = BoldFont,
        TextSize             = 14,
        Text                 = self.Name,
        TextColor3           = Palette.Text,
        BackgroundTransparency = 1,
        AnchorPoint          = Vector2.new(0, 0.5),
        Position             = UDim2.new(0, titleOffset, 0.5, 0),
        Size                 = UDim2.new(1, -titleOffset - 48, 1, 0),
        TextXAlignment       = Enum.TextXAlignment.Left,
    })

    local closeButton = createInstance("TextButton", {
        Parent               = titleBar,
        FontFace             = BoldFont,
        TextSize             = 12,
        AutoButtonColor      = false,
        Text                 = "x",
        TextColor3           = Palette.Dim,
        BackgroundColor3     = Palette.Surface,
        BorderSizePixel      = 0,
        AnchorPoint          = Vector2.new(1, 0.5),
        Position             = UDim2.new(1, -8, 0.5, 0),
        Size                 = UDim2.new(0, 24, 0, 24),
    })
    applyBorderStroke(closeButton, Palette.Border, 1)
    addCorner(closeButton, 6)
    closeButton.MouseEnter:Connect(function()
        playTween(closeButton, Tweens.Fast, { BackgroundColor3 = Palette.Risky, TextColor3 = Palette.Text })
    end)
    closeButton.MouseLeave:Connect(function()
        playTween(closeButton, Tweens.Fast, { BackgroundColor3 = Palette.Surface, TextColor3 = Palette.Dim })
    end)
    closeButton.MouseButton1Down:Connect(function()
        self:Exit()
    end)

    local innerContainer = createInstance("Frame", {
        Parent               = mainFrame,
        BackgroundColor3     = Palette.Inline,
        BorderSizePixel      = 0,
        Position             = UDim2.fromOffset(Layout.Padding, Layout.TitleBarHeight + Layout.Padding),
        Size                 = UDim2.new(1, -Layout.Padding * 2, 1, -Layout.TitleBarHeight - Layout.Padding * 2),
        ClipsDescendants     = true,
    })
    applyBorderStroke(innerContainer, Palette.SubBorder, 1)
    addCorner(innerContainer, 9)
    self._inner = innerContainer

    local function buildPanel(headerText, x, width)
        local panel = createInstance("Frame", {
            Parent               = innerContainer,
            BackgroundColor3     = Palette.Surface,
            BorderSizePixel      = 0,
            Position             = UDim2.fromOffset(x, Layout.Padding),
            Size                 = UDim2.new(0, width, 1, -Layout.Padding * 2),
            ClipsDescendants     = true,
        })
        applyBorderStroke(panel, Palette.Border, 1)
        addCorner(panel, 9)

        local header = createInstance("Frame", {
            Parent               = panel,
            BackgroundColor3     = Palette.Element,
            BorderSizePixel      = 0,
            Position             = UDim2.fromOffset(1, 1),
            Size                 = UDim2.new(1, -2, 0, 28),
        })
        addCorner(header, 7)
        addTopHighlight(header, 1)

        createInstance("Frame", {
            Parent               = panel,
            BackgroundColor3     = Palette.Border,
            BorderSizePixel      = 0,
            Position             = UDim2.new(0, 10, 0, 32),
            Size                 = UDim2.new(1, -20, 0, 1),
        })

        createInstance("TextLabel", {
            Parent               = header,
            FontFace             = BoldFont,
            TextSize             = 11,
            Text                 = headerText,
            TextColor3           = Palette.Text,
            BackgroundTransparency = 1,
            Position             = UDim2.new(0, 10, 0, 0),
            Size                 = UDim2.new(1, -20, 1, 0),
            TextXAlignment       = Enum.TextXAlignment.Left,
        })

        return panel
    end

    local leftPanel = buildPanel("INFORMATION", Layout.Padding, Layout.SidePanelWidth)
    self._leftPanel         = leftPanel
    self._leftPanelHome     = leftPanel.Position

    createInstance("TextLabel", {
        Parent                 = leftPanel,
        FontFace               = BoldFont,
        TextSize               = 10,
        Text                   = "OFFICIAL LINKS",
        TextColor3             = Palette.Dim,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 10, 0, 40),
        Size                   = UDim2.new(1, -20, 0, 14),
        TextXAlignment         = Enum.TextXAlignment.Left,
    })

    local function addLinkButton(title, initial, url, y)
        local button = createInstance("TextButton", {
            Parent               = leftPanel,
            AutoButtonColor      = false,
            Text                 = "",
            BackgroundColor3     = Palette.Element,
            BorderSizePixel      = 0,
            Position             = UDim2.new(0, 9, 0, y),
            Size                 = UDim2.new(1, -18, 0, 37),
        })
        applyBorderStroke(button, Palette.Border, 1)
        addCorner(button, 7)

        local icon = createInstance("Frame", {
            Parent           = button,
            BackgroundColor3 = Palette.Accent,
            BorderSizePixel  = 0,
            Position         = UDim2.new(0, 7, 0.5, -11),
            Size             = UDim2.new(0, 22, 0, 22),
        })
        addCorner(icon, 6)
        createInstance("TextLabel", {
            Parent                 = icon,
            FontFace               = BoldFont,
            TextSize               = 12,
            Text                   = initial,
            TextColor3             = Palette.Text,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, 0, 1, 0),
        })

        createInstance("TextLabel", {
            Parent                 = button,
            FontFace               = BoldFont,
            TextSize               = 12,
            Text                   = title,
            TextColor3             = Palette.Text,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0, 37, 0, 0),
            Size                   = UDim2.new(1, -93, 1, 0),
            TextXAlignment         = Enum.TextXAlignment.Left,
        })
        local actionLabel = createInstance("TextLabel", {
            Parent                 = button,
            FontFace               = BoldFont,
            TextSize               = 9,
            Text                   = "Copy Link",
            TextColor3             = Palette.AccentHi,
            BackgroundTransparency = 1,
            AnchorPoint            = Vector2.new(1, 0.5),
            Position               = UDim2.new(1, -8, 0.5, 0),
            Size                   = UDim2.new(0, 70, 0, 18),
            TextXAlignment         = Enum.TextXAlignment.Right,
        })
        local statusToken = 0
        button.Activated:Connect(function()
            statusToken = statusToken + 1
            local currentToken = statusToken
            local copied = copyToClipboard(url)
            actionLabel.Text = copied and "Copied" or "UNAVAILABLE"
            actionLabel.TextColor3 = copied and Palette.Success or Palette.Risky
            if copied then
                task.delay(2, function()
                    if actionLabel.Parent and statusToken == currentToken then
                        actionLabel.Text = "Copy Link"
                        actionLabel.TextColor3 = Palette.AccentHi
                    end
                end)
            end
        end)
    end

    addLinkButton("Website", "W", WebsiteUrl, 58)
    addLinkButton("Discord", "D", DiscordUrl, 101)

    createInstance("Frame", {
        Parent           = leftPanel,
        BackgroundColor3 = Palette.SubBorder,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 10, 0, 148),
        Size             = UDim2.new(1, -20, 0, 1),
    })
    createInstance("TextLabel", {
        Parent                 = leftPanel,
        FontFace               = BoldFont,
        TextSize               = 11,
        Text                   = "GAMES",
        TextColor3             = Palette.Text,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 10, 0, 158),
        Size                   = UDim2.new(1, -20, 0, 16),
        TextXAlignment         = Enum.TextXAlignment.Left,
    })

    local gameList = createInstance("ScrollingFrame", {
        Parent               = leftPanel,
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        Position             = UDim2.new(0, 8, 0, 182),
        Size                 = UDim2.new(1, -16, 1, -190),
        ScrollBarThickness   = 2,
        ScrollBarImageColor3 = Palette.Accent,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        Active               = false,
        ClipsDescendants     = true,
    })
    self._gameList = gameList
    createInstance("UIListLayout", {
        Parent     = gameList,
        Padding    = UDim.new(0, 1),
        SortOrder  = Enum.SortOrder.LayoutOrder,
    })

    local rightPanelX     = Layout.Padding + Layout.SidePanelWidth + Layout.Padding
    local innerWidth      = Layout.OuterWidth - Layout.Padding * 2
    local rightPanelWidth = innerWidth - rightPanelX - Layout.Padding
    local rightPanel      = buildPanel("GAME OVERVIEW", rightPanelX, rightPanelWidth)
    self._rightPanel      = rightPanel
    self._rightPanelHome  = rightPanel.Position

    local previewImage = createInstance("ImageLabel", {
        Parent               = rightPanel,
        Image                = "",
        BackgroundColor3     = Palette.Background,
        BorderSizePixel      = 0,
        Position             = UDim2.new(0, 10, 0, 40),
        Size                 = UDim2.new(1, -20, 0, 142),
        ScaleType            = Enum.ScaleType.Crop,
    })
    applyBorderStroke(previewImage, Palette.Border, 1)
    addCorner(previewImage, 8)
    self._previewImage       = previewImage
    self._previewImageScale  = createInstance("UIScale", { Parent = previewImage, Scale = 1 })

    self._nameLabel = createInstance("TextLabel", {
        Parent               = rightPanel,
        FontFace             = BoldFont,
        TextSize             = 21,
        Text                 = "—",
        TextColor3           = Palette.Text,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 10, 0, 195),
        Size                 = UDim2.new(1, -20, 0, 26),
        TextXAlignment       = Enum.TextXAlignment.Left,
        TextTruncate         = Enum.TextTruncate.AtEnd,
    })

    self._authorLabel = createInstance("TextLabel", {
        Parent               = rightPanel,
        FontFace             = RegularFont,
        TextSize             = 13,
        Text                 = "—",
        TextColor3           = Palette.Dim,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 10, 0, 225),
        Size                 = UDim2.new(1, -20, 0, 18),
        TextXAlignment       = Enum.TextXAlignment.Left,
    })

    self._descriptionLabel = createInstance("TextLabel", {
        Parent               = rightPanel,
        FontFace             = RegularFont,
        TextSize             = 13,
        Text                 = "select a game on the left.",
        TextColor3           = Palette.Dim,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 10, 0, 258),
        Size                 = UDim2.new(1, -20, 1, -318),
        TextXAlignment       = Enum.TextXAlignment.Left,
        TextYAlignment       = Enum.TextYAlignment.Top,
        TextWrapped          = true,
    })

    self._changelogScroll = createInstance("ScrollingFrame", {
        Parent               = rightPanel,
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        Position             = UDim2.new(0, 10, 0, 258),
        Size                 = UDim2.new(1, -20, 1, -318),
        ScrollBarThickness   = 2,
        ScrollBarImageColor3 = Palette.Accent,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        Active               = false,
        Visible              = false,
        ClipsDescendants     = true,
    })
    createInstance("UIListLayout", {
        Parent     = self._changelogScroll,
        Padding    = UDim.new(0, 2),
        SortOrder  = Enum.SortOrder.LayoutOrder,
    })

    local loadButton = createInstance("TextButton", {
        Parent               = rightPanel,
        AutoButtonColor      = false,
        Text                 = "",
        BackgroundColor3     = Palette.Accent,
        BorderSizePixel      = 0,
        AnchorPoint          = Vector2.new(1, 1),
        Position             = UDim2.new(1, -10, 1, -10),
        Size                 = UDim2.new(0, 124, 0, 36),
        ClipsDescendants     = true,
    })
    local loadButtonStroke = applyBorderStroke(loadButton, Palette.AccentHi, 1)
    addCorner(loadButton, 7)
    addTopHighlight(loadButton, 0, Palette.AccentHi)
    addBottomShade(loadButton, 0, Palette.AccentLo)

    local loadIndicator = createInstance("Frame", {
        Parent               = loadButton,
        BackgroundColor3     = Palette.Text,
        BorderSizePixel      = 0,
        AnchorPoint          = Vector2.new(0, 0.5),
        Position             = UDim2.new(0, 11, 0.5, 0),
        Size                 = UDim2.new(0, 5, 0, 5),
    })

    local loadLabel = createInstance("TextLabel", {
        Parent               = loadButton,
        FontFace             = BoldFont,
        TextSize             = 13,
        Text                 = "LOAD GAME",
        TextColor3           = Palette.Text,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 24, 0, 0),
        Size                 = UDim2.new(1, -30, 1, 0),
        TextXAlignment       = Enum.TextXAlignment.Left,
    })

    loadButton.MouseEnter:Connect(function()
        playTween(loadButton,       Tweens.Fast, { BackgroundColor3 = Palette.AccentHi })
        playTween(loadButtonStroke, Tweens.Fast, { Color = Palette.Text })
        playTween(loadIndicator,    Tweens.Fast, { Size = UDim2.new(0, 6, 0, 6) })
    end)
    loadButton.MouseLeave:Connect(function()
        playTween(loadButton,       Tweens.Fast, { BackgroundColor3 = Palette.Accent })
        playTween(loadButtonStroke, Tweens.Fast, { Color = Palette.AccentHi })
        playTween(loadIndicator,    Tweens.Fast, { Size = UDim2.new(0, 4, 0, 4) })
    end)
    loadButton.MouseButton1Down:Connect(function()
        if not self.Current or self._isClosing then return end
        local selectedGame = self.Current
        loadLabel.Text = "loading..."
        self:Exit()
        task.delay(0.75, function()
            pcall(selectedGame.Callback, selectedGame)
        end)
    end)
    self._loadButton      = loadButton
    self._loadButtonScale = createInstance("UIScale", { Parent = loadButton, Scale = 1 })

    self:_enableDragging(mainFrame)

    task.defer(function()
        self:_playEntranceAnimation()
    end)

    return self
end

function Loader:_playEntranceAnimation()
    if not self.Frame or not self.Frame.Parent then return end

    self._scaler.Scale            = self._baseScale * 0.55
    self.Frame.Position           = UDim2.new(0.5, 0, 0.5, -150)
    self.Frame.Visible            = true
    self._leftPanel.Position      = UDim2.fromOffset(-Layout.SidePanelWidth - 30, Layout.Padding)
    self._rightPanel.Position     = UDim2.fromOffset(Layout.OuterWidth, Layout.Padding)
    self._previewImageScale.Scale = 0
    self._loadButtonScale.Scale   = 0
    if self._logoScale then
        self._logoScale.Scale = 0
    end
    for _, entry in ipairs(self._entries) do
        if entry.Scale then
            entry.Scale.Scale = 0
        end
    end

    playTween(self._scaler, Tweens.Pop,  { Scale = self._baseScale })
    playTween(self.Frame,   Tweens.Drop, { Position = self._homePosition })

    task.delay(0.12, function()
        if self._isClosing then return end
        playTween(self._leftPanel, Tweens.Slide, { Position = self._leftPanelHome })
    end)
    task.delay(0.18, function()
        if self._isClosing then return end
        playTween(self._rightPanel, Tweens.Slide, { Position = self._rightPanelHome })
    end)
    task.delay(0.28, function()
        if self._isClosing then return end
        playTween(self._previewImageScale, Tweens.Pop, { Scale = 1 })
        if self._logoScale then
            playTween(self._logoScale, Tweens.Pop, { Scale = 1 })
        end
    end)
    task.delay(0.36, function()
        if self._isClosing then return end
        for index, entry in ipairs(self._entries) do
            if entry.Scale then
                task.delay((index - 1) * 0.045, function()
                    if entry.Scale and not self._isClosing then
                        playTween(entry.Scale, Tweens.Item, { Scale = 1 })
                    end
                end)
            end
        end
    end)
    task.delay(0.5, function()
        if self._isClosing then return end
        playTween(self._loadButtonScale, Tweens.Button, { Scale = 1 })
    end)

    task.delay(0.95, function()
        self._isOpened = true
    end)
end

function Loader:_enableDragging(gui)
    local dragHandle = self._titleBar or gui
    local isDragging, dragStart, initialPosition

    dragHandle.InputBegan:Connect(function(input)
        if self._isClosing then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            isDragging      = true
            dragStart       = input.Position
            initialPosition = gui.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not isDragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta       = input.Position - dragStart
            local newPosition = UDim2.new(
                initialPosition.X.Scale, initialPosition.X.Offset + delta.X,
                initialPosition.Y.Scale, initialPosition.Y.Offset + delta.Y
            )
            gui.Position       = newPosition
            self._homePosition = newPosition
        end
    end)
end

function Loader:_hasChangelogEntries(changelog)
    if type(changelog) ~= "table" then return false end
    for _, key in ipairs({ "Added", "Removed", "Fixed" }) do
        if type(changelog[key]) == "table" and #changelog[key] > 0 then
            return true
        end
    end
    return false
end

function Loader:_renderChangelog(changelog)
    for _, child in ipairs(self._changelogScroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    if not changelog then return end

    local layoutOrder = 0
    local function appendEntry(prefix, hexColor, text)
        layoutOrder = layoutOrder + 1
        createInstance("TextLabel", {
            Parent               = self._changelogScroll,
            FontFace             = RegularFont,
            TextSize             = 12,
            RichText             = true,
            Text                 = string.format('<font color="%s"><b>%s</b></font>  %s', hexColor, prefix, text),
            TextColor3           = Palette.Text,
            BackgroundTransparency = 1,
            Size                 = UDim2.new(1, -6, 0, 0),
            AutomaticSize        = Enum.AutomaticSize.Y,
            TextXAlignment       = Enum.TextXAlignment.Left,
            TextYAlignment       = Enum.TextYAlignment.Top,
            TextWrapped          = true,
            LayoutOrder          = layoutOrder,
        })
    end

    local categories = {
        { Key = "Added",   Prefix = "+", Hex = ChangelogColors.Added },
        { Key = "Removed", Prefix = "-", Hex = ChangelogColors.Removed },
        { Key = "Fixed",   Prefix = "~", Hex = ChangelogColors.Fixed },
    }
    for _, category in ipairs(categories) do
        local items = changelog[category.Key]
        if type(items) == "table" then
            for _, text in ipairs(items) do
                appendEntry(category.Prefix, category.Hex, text)
            end
        end
    end
end

function Loader:_renderGameDetails(gameRecord)
    self._previewImage.Image = gameRecord.Image or ""
    self._nameLabel.Text     = gameRecord.Name
    self._authorLabel.Text   = "by " .. (gameRecord.Author or "unknown")

    if self:_hasChangelogEntries(gameRecord.Changelog) then
        self._descriptionLabel.Visible = false
        self._changelogScroll.Visible  = true
        self:_renderChangelog(gameRecord.Changelog)
    else
        self._descriptionLabel.Visible = true
        self._changelogScroll.Visible  = false
        self._descriptionLabel.Text    = gameRecord.Description or ""
    end
end

function Loader:_selectGame(gameRecord)
    if self._activeSelection == gameRecord then return end
    self._activeSelection = gameRecord
    self.Current          = gameRecord

    for _, entry in ipairs(self._entries) do
        local isActive = entry.Game == gameRecord
        playTween(entry.Button, Tweens.Fast, { BackgroundColor3 = isActive and Palette.Hover or Palette.Element })
        playTween(entry.Label,  Tweens.Fast, { TextColor3 = isActive and Palette.Text or Palette.Dim })
        if entry.AccentBar then
            playTween(entry.AccentBar, Tweens.Fast, { BackgroundTransparency = isActive and 0 or 1 })
        end
    end

    if not self._isOpened then
        self:_renderGameDetails(gameRecord)
        return
    end

    playTween(self._previewImage, Tweens.FadeOut, { ImageTransparency = 1 })
    playTween(self._nameLabel,    Tweens.FadeOut, { TextTransparency = 1 })
    playTween(self._authorLabel,  Tweens.FadeOut, { TextTransparency = 1 })

    if self._descriptionLabel.Visible then
        playTween(self._descriptionLabel, Tweens.FadeOut, { TextTransparency = 1 })
    end
    if self._changelogScroll.Visible then
        for _, child in ipairs(self._changelogScroll:GetChildren()) do
            if child:IsA("TextLabel") then
                playTween(child, Tweens.FadeOut, { TextTransparency = 1 })
            end
        end
    end

    task.delay(Tweens.FadeOut.Time, function()
        if self._activeSelection ~= gameRecord or self._isClosing then return end
        self:_renderGameDetails(gameRecord)

        playTween(self._previewImage, Tweens.FadeIn, { ImageTransparency = 0 })
        playTween(self._nameLabel,    Tweens.FadeIn, { TextTransparency = 0 })
        playTween(self._authorLabel,  Tweens.FadeIn, { TextTransparency = 0 })

        if self._descriptionLabel.Visible then
            self._descriptionLabel.TextTransparency = 1
            playTween(self._descriptionLabel, Tweens.FadeIn, { TextTransparency = 0 })
        end
        if self._changelogScroll.Visible then
            local labelIndex = 0
            for _, child in ipairs(self._changelogScroll:GetChildren()) do
                if child:IsA("TextLabel") then
                    labelIndex = labelIndex + 1
                    child.TextTransparency = 1
                    local staggeredInfo = TweenInfo.new(
                        0.3,
                        Enum.EasingStyle.Quint,
                        Enum.EasingDirection.Out,
                        0,
                        false,
                        (labelIndex - 1) * 0.03
                    )
                    playTween(child, staggeredInfo, { TextTransparency = 0 })
                end
            end
        end
    end)
end

function Loader:AddGame(options)
    options = options or {}
    local gameRecord = {
        Name        = options.Name or "Game",
        Author      = options.Author or "unknown",
        Description = options.Description or "",
        Image       = options.Image or "",
        Changelog   = options.Changelog,
        Callback    = options.Callback or function() end,
    }

    local gameButton = createInstance("TextButton", {
        Parent               = self._gameList,
        FontFace             = RegularFont,
        TextSize             = 12,
        AutoButtonColor      = false,
        Text                 = "",
        BackgroundColor3     = Palette.Element,
        BorderSizePixel      = 0,
        Size                 = UDim2.new(1, 0, 0, 34),
        LayoutOrder          = #self.Games + 1,
        ClipsDescendants     = true,
    })

    local accentBar = createInstance("Frame", {
        Parent               = gameButton,
        BackgroundColor3     = Palette.Accent,
        BorderSizePixel      = 0,
        Position             = UDim2.new(0, 0, 0, 0),
        Size                 = UDim2.new(0, 3, 1, 0),
        BackgroundTransparency = 1,
    })

    local gameLabel = createInstance("TextLabel", {
        Parent               = gameButton,
        FontFace             = RegularFont,
        TextSize             = 13,
        Text                 = gameRecord.Name,
        TextColor3           = Palette.Dim,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 8, 0, 0),
        Size                 = UDim2.new(1, -12, 1, 0),
        TextXAlignment       = Enum.TextXAlignment.Left,
    })

    local itemScale = createInstance("UIScale", {
        Parent = gameButton,
        Scale  = self._isOpened and 1 or 0,
    })

    gameButton.MouseEnter:Connect(function()
        if self.Current == gameRecord then return end
        playTween(gameButton, Tweens.Fast, { BackgroundColor3 = Palette.Hover })
        playTween(gameLabel,  Tweens.Fast, { TextColor3 = Palette.Text })
    end)
    gameButton.MouseLeave:Connect(function()
        if self.Current == gameRecord then return end
        playTween(gameButton, Tweens.Fast, { BackgroundColor3 = Palette.Element })
        playTween(gameLabel,  Tweens.Fast, { TextColor3 = Palette.Dim })
    end)
    gameButton.MouseButton1Down:Connect(function()
        self:_selectGame(gameRecord)
    end)

    table.insert(self._entries, {
        Button    = gameButton,
        Label     = gameLabel,
        AccentBar = accentBar,
        Scale     = itemScale,
        Game      = gameRecord,
    })
    table.insert(self.Games, gameRecord)

    if self._isOpened then
        itemScale.Scale = 0
        playTween(itemScale, Tweens.Item, { Scale = 1 })
    end

    if #self.Games == 1 then
        self:_selectGame(gameRecord)
    end
    return gameRecord
end

function Loader:Select(name)
    for _, gameRecord in ipairs(self.Games) do
        if gameRecord.Name == name then
            self:_selectGame(gameRecord)
            return gameRecord
        end
    end
end

function Loader:Exit()
    if not self.ScreenGui or self._isClosing then return end
    self._isClosing = true

    local entryCount = #self._entries
    for index, entry in ipairs(self._entries) do
        if entry.Scale then
            task.delay((entryCount - index) * 0.025, function()
                if entry.Scale then
                    playTween(entry.Scale, Tweens.ShutItem, { Scale = 0 })
                end
            end)
        end
    end

    task.delay(0.1, function()
        playTween(self._previewImageScale, Tweens.ShutItem, { Scale = 0 })
        playTween(self._loadButtonScale,   Tweens.ShutItem, { Scale = 0 })
        if self._logoScale then
            playTween(self._logoScale, Tweens.ShutItem, { Scale = 0 })
        end
    end)

    task.delay(0.16, function()
        playTween(self._leftPanel,  Tweens.ShutSlide, { Position = UDim2.fromOffset(-Layout.SidePanelWidth - 30, Layout.Padding) })
        playTween(self._rightPanel, Tweens.ShutSlide, { Position = UDim2.fromOffset(Layout.OuterWidth, Layout.Padding) })
    end)

    task.delay(0.28, function()
        playTween(self._scaler, Tweens.ShutDrop, { Scale = self._baseScale * 0.55 })
        playTween(self.Frame,   Tweens.ShutDrop, {
            Position = UDim2.new(
                self._homePosition.X.Scale, self._homePosition.X.Offset,
                self._homePosition.Y.Scale, self._homePosition.Y.Offset + 150
            ),
        })
    end)

    task.delay(0.72, function()
        if self.ScreenGui then
            self.ScreenGui:Destroy()
            self.ScreenGui = nil
        end
    end)
end

local YisusHubLoader = Loader.new({ Name = "YisusHub | loader" })

YisusHubLoader:AddGame({
    Name      = "Duels",
    Author    = "YisusHub",
    Image     = "rbxthumb://type=GameThumbnail&id=131117978948830&w=768&h=432",
    Changelog = {
        Added   = { "Added" },
        Removed = { "Removed" },
        Fixed   = { "Fixed" },
    },
    Callback = function()
        loadstring(game:HttpGet("https://yisus-hub.vercel.app/api/script/dmvs"))()
    end,
})

return Loader
