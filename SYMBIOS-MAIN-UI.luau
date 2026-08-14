--[[ =========================================================================
     SYMBIOS-MAIN-UI.luau  —  reusable monochrome "console" UI framework
     Drop-in skeleton for building a hub on ANY game. No game logic inside.

     QUICK START
       local UI = SymbiosUI.new({ title = "SYMBIOS", subtitle = "MY GAME" })
       local tab = UI:AddTab("MODULE", "rbxassetid://97834078379872")
       local sec = tab:AddSection("SECTION")
       sec:AddSwitch({ title = "DO THING", default = true, onChange = function(v) ... end })
       ...
     A full working DEMO (test content) is at the bottom of this file — delete
     it and build your own with the same API.
     ========================================================================= ]]
--!nonstrict

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
if not game:IsLoaded() then game.Loaded:Wait() end
if not Players.LocalPlayer then repeat task.wait() until Players.LocalPlayer end

--========================================================================
-- THEME + FONTS
--========================================================================
local C = {
    ground = Color3.fromHex("0a0a0b"), panel = Color3.fromHex("0f0f11"), raise = Color3.fromHex("17171a"),
    ink = Color3.fromHex("f2f2ef"), ink2 = Color3.fromHex("c7c7c2"), label = Color3.fromHex("9a9aa0"),
    dim = Color3.fromHex("74747a"), dim2 = Color3.fromHex("4c4c54"),
    line = Color3.fromHex("242429"), line2 = Color3.fromHex("38383f"),
}
local RM = "rbxasset://fonts/families/RobotoMono.json"
local W  = { reg = Enum.FontWeight.Medium, med = Enum.FontWeight.SemiBold, semi = Enum.FontWeight.Bold, bold = Enum.FontWeight.Heavy }
local function mono(w) return Font.new(RM, w or W.med) end

-- Download a PNG once (HttpGet -> writefile -> getcustomasset) and return a usable
-- rbxasset content string. For custom window icons / logos hosted on e.g. GitHub raw.
local function loadImage(url, fname)
    if not url or url == "" then return nil end
    local gca = getcustomasset or getsynasset
    if not (writefile and gca and isfile) then return nil end
    local ok, res = pcall(function()
        if not isfile(fname) then writefile(fname, game:HttpGet(url)) end
        return gca(fname)
    end)
    if ok and res then return res end
    return nil
end

--========================================================================
-- BUILDER HELPERS
--========================================================================
local function new(cls, props, kids)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do o[k] = v end
    for _, c in ipairs(kids or {}) do c.Parent = o end
    return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 2) }) end
local function stroke(col, th, tr) return new("UIStroke", { Color = col, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function pad(t, r, b, l) return new("UIPadding", { PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b), PaddingLeft = UDim.new(0, l) }) end
local function hlist(gap, align) return new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, gap or 0), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Left }) end
local function vlist(gap) return new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder }) end
local function flexFill() local f; pcall(function() f = new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) end); return f end
local function spacer(parent, order) local s = new("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 1), LayoutOrder = order or 500 }); local f = flexFill(); if f then f.Parent = s end; return s end
local function track(s) return (s:gsub(".", "%0 ")):gsub(" $", "") end
local function txt(parent, s, size, color, weight, order)
    return new("TextLabel", { Parent = parent, BackgroundTransparency = 1, FontFace = mono(weight or W.med), Text = s, TextSize = size, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, size + 4), LayoutOrder = order or 1 })
end

--========================================================================
-- ADJUSTABLE FONT WEIGHT (global; shifts every registered text object live)
--========================================================================
local WEIGHTS = { Enum.FontWeight.Thin, Enum.FontWeight.ExtraLight, Enum.FontWeight.Light, Enum.FontWeight.Regular, Enum.FontWeight.Medium, Enum.FontWeight.SemiBold, Enum.FontWeight.Bold, Enum.FontWeight.Heavy }
local wIndex = {}; for i, wt in ipairs(WEIGHTS) do wIndex[wt] = i end
local fontOffset = 0
local baseWeights, fauxStroke = {}, {}
local FAUX_STEP = 0.32
local function applyFontToObj(obj)
    local b = baseWeights[obj]; if not (b and obj.Parent) then return end
    local idx = (wIndex[b] or 4) + fontOffset
    pcall(function() obj.FontFace = Font.new(RM, WEIGHTS[math.clamp(idx, 1, #WEIGHTS)]) end)
    local over = math.max(0, idx - #WEIGHTS)
    local st = fauxStroke[obj]
    if over > 0 then
        if not st then
            st = Instance.new("UIStroke"); st.Color = obj.TextColor3; st.Thickness = 0; st.LineJoinMode = Enum.LineJoinMode.Round; st.Parent = obj
            obj:GetPropertyChangedSignal("TextColor3"):Connect(function() if st and st.Parent then st.Color = obj.TextColor3 end end)
            fauxStroke[obj] = st
        end
        st.Thickness = over * FAUX_STEP
    elseif st then st.Thickness = 0 end
end
local function registerText(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        local ok, ff = pcall(function() return obj.FontFace end)
        if ok and ff then baseWeights[obj] = ff.Weight; applyFontToObj(obj) end
    end
end
local function regTree(root) registerText(root); for _, d in ipairs(root:GetDescendants()) do registerText(d) end end
local function applyFontOffset() for obj in pairs(baseWeights) do applyFontToObj(obj) end end

--========================================================================
-- LOW-LEVEL COMPONENT BUILDERS  (parent, opts) -> handles
--========================================================================
local function buildSwitch(parent, initOn, onChange)
    local sw = new("Frame", { Parent = parent, BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 25) }, { corner(2), stroke(C.line2, 1, 0), hlist(0) })
    local st = { on = initOn }
    local offCell = new("TextButton", { Parent = sw, FontFace = mono(W.semi), Text = "OFF", TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0, TextColor3 = C.dim, BackgroundColor3 = C.raise, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 25), LayoutOrder = 1 }, { pad(5, 12, 5, 12) })
    new("Frame", { Parent = sw, BackgroundColor3 = C.line2, BorderSizePixel = 0, Size = UDim2.fromOffset(1, 25), LayoutOrder = 2 })
    local onCell = new("TextButton", { Parent = sw, FontFace = mono(W.semi), Text = "ON", TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0, TextColor3 = C.dim, BackgroundColor3 = C.ink, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 25), LayoutOrder = 3 }, { pad(5, 12, 5, 12) })
    local function render()
        onCell.BackgroundTransparency = st.on and 0 or 1; onCell.TextColor3 = st.on and C.ground or C.dim
        offCell.BackgroundTransparency = st.on and 1 or 0; offCell.TextColor3 = st.on and C.dim or C.ink2
    end
    local function set(v, fire) st.on = v; render(); if fire and onChange then onChange(v) end end
    offCell.MouseButton1Click:Connect(function() set(false, true) end)
    onCell.MouseButton1Click:Connect(function() set(true, true) end)
    render()
    return { set = function(v) set(v, false) end, get = function() return st.on end }, sw
end

--========================================================================
-- SECTION  (holds ordered components inside a titled block)
--========================================================================
local Section = {}
Section.__index = Section
function Section:_next() self._n = (self._n or 0) + 1; return self._n end

function Section:AddParagraph(text)
    local l = new("TextLabel", { Parent = self.inner, BackgroundTransparency = 1, FontFace = mono(W.med), Text = text, TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = self:_next() })
    regTree(l); return l
end

function Section:AddDropdown(o)
    local order = self:_next()
    local options, selectedSet = o.options or {}, o.selected or {}
    local wrap = new("Frame", { Parent = self.inner, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = order }, { vlist(7) })
    local lab = new("Frame", { Parent = wrap, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 0 }, { hlist(6) })
    txt(lab, o.label or "OPTIONS", 11, C.label, W.med, 1)
    spacer(lab, 2)
    local countLbl = txt(lab, o.note or "", 11, C.dim, W.med, 3); countLbl.TextXAlignment = Enum.TextXAlignment.Right
    local field = new("TextButton", { Parent = wrap, AutoButtonColor = false, Text = "", BackgroundColor3 = C.ground, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 37), LayoutOrder = 1 }, { corner(2), stroke(C.line2, 1, 0), pad(0, 10, 0, 11), hlist(8) })
    local summary = new("TextLabel", { Parent = field, BackgroundTransparency = 1, FontFace = mono(W.med), Text = "", TextSize = 12, TextColor3 = C.ink2, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -20, 1, 0), LayoutOrder = 1 })
    local chevron = new("TextLabel", { Parent = field, BackgroundTransparency = 1, FontFace = mono(W.med), Text = "▾", TextSize = 12, TextColor3 = C.dim, Size = UDim2.fromOffset(12, 37), LayoutOrder = 2 })
    local panel = new("Frame", { Parent = wrap, Visible = false, ClipsDescendants = true, BackgroundColor3 = C.ground, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 }, { corner(2), stroke(C.line2, 1, 0), pad(8, 8, 8, 8), vlist(7) })
    local searchBox
    if #options > 12 then
        local sbWrap = new("Frame", { Parent = panel, BackgroundColor3 = C.raise, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 0 }, { corner(2), stroke(C.line2, 1, 0), pad(0, 9, 0, 9) })
        searchBox = new("TextBox", { Parent = sbWrap, BackgroundTransparency = 1, FontFace = mono(W.med), Text = "", PlaceholderText = "search…", PlaceholderColor3 = C.dim2, TextColor3 = C.ink, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Size = UDim2.new(1, 0, 1, 0) })
    end
    local list = new("ScrollingFrame", { Parent = panel, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 60), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.line2, LayoutOrder = 1 }, { vlist(3) })
    local function refreshSummary()
        local sel = {}; for _, x in ipairs(options) do if selectedSet[x] then table.insert(sel, x) end end
        if #sel == 0 then summary.Text = "SELECT / ADD"; summary.TextColor3 = C.dim; countLbl.Text = o.note or ""
        else summary.Text = table.concat(sel, ", "); summary.TextColor3 = C.ink2; countLbl.Text = #sel .. " SELECTED" end
    end
    local function renderOptions(filter)
        for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        filter = (filter or ""):lower(); local count = 0
        for _, opt in ipairs(options) do
            if filter == "" or opt:lower():find(filter, 1, true) then
                count += 1; local sel = selectedSet[opt] == true
                local row = new("TextButton", { Parent = list, AutoButtonColor = false, Text = "", BackgroundColor3 = C.raise, BackgroundTransparency = sel and 0.4 or 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 27), LayoutOrder = count }, { corner(2), pad(0, 8, 0, 8), hlist(8) })
                new("Frame", { Parent = row, BackgroundColor3 = sel and C.ink or C.ground, BorderSizePixel = 0, Size = UDim2.fromOffset(11, 11), LayoutOrder = 1 }, { corner(2), stroke(sel and C.ink or C.line2, 1, 0) })
                registerText(new("TextLabel", { Parent = row, BackgroundTransparency = 1, FontFace = mono(sel and W.semi or W.med), Text = opt, TextSize = 12, TextColor3 = sel and C.ink or C.ink2, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -20, 1, 0), LayoutOrder = 2 }))
                row.MouseButton1Click:Connect(function()
                    if selectedSet[opt] then selectedSet[opt] = nil else selectedSet[opt] = true end
                    renderOptions(searchBox and searchBox.Text or ""); refreshSummary()
                    local arr = {}; for _, x in ipairs(options) do if selectedSet[x] then table.insert(arr, x) end end
                    if o.onChange then o.onChange(arr) end
                end)
            end
        end
        list.Size = UDim2.new(1, 0, 0, math.min(168, math.max(27, count * 30)))
    end
    local open = false
    local function setOpen(v)
        open = v; panel.Visible = v; chevron.Text = v and "▴" or "▾"
        if v then panel.AutomaticSize = Enum.AutomaticSize.Y; renderOptions(searchBox and searchBox.Text or "")
        else panel.AutomaticSize = Enum.AutomaticSize.None; panel.Size = UDim2.new(1, 0, 0, 0) end
    end
    field.MouseButton1Click:Connect(function() setOpen(not open) end)
    if searchBox then searchBox:GetPropertyChangedSignal("Text"):Connect(function() renderOptions(searchBox.Text) end) end
    refreshSummary(); regTree(wrap)
    return { refresh = refreshSummary }
end

function Section:AddSwitch(o)
    local sub = o.sub
    local row = new("Frame", { Parent = self.inner, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, sub and 46 or 36), LayoutOrder = self:_next() })
    new("Frame", { Parent = row, BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0) })
    new("TextLabel", { Parent = row, BackgroundTransparency = 1, FontFace = mono(W.med), Text = o.title or "TOGGLE", TextSize = 12, TextColor3 = C.ink2, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 0, 0, sub and 9 or 0), Size = UDim2.new(1, -90, 0, sub and 16 or 35) })
    if sub then new("TextLabel", { Parent = row, BackgroundTransparency = 1, FontFace = mono(W.med), Text = sub, TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 0, 0, 27), Size = UDim2.new(1, -90, 0, 14) }) end
    local api, sw = buildSwitch(row, o.default or false, o.onChange)
    sw.AnchorPoint = Vector2.new(1, 0.5); sw.Position = UDim2.new(1, 0, 0.5, 0)
    regTree(row); return api
end

function Section:AddSlider(o)
    local minV, maxV, suffix, intMode = o.min or 0, o.max or 100, o.suffix or "", o.int
    local function fmt(v) if intMode then return string.format("%d%s", math.floor(v + 0.5), suffix) else return string.format("%.2f%s", v, suffix) end end
    local val = o.default or minV
    local wrap = new("Frame", { Parent = self.inner, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = self:_next() })
    new("TextLabel", { Parent = wrap, BackgroundTransparency = 1, FontFace = mono(W.med), Text = o.label or "VALUE", TextSize = 11, TextColor3 = C.label, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, 0, 0, 15) })
    local valLbl = new("TextLabel", { Parent = wrap, BackgroundTransparency = 1, FontFace = mono(W.semi), Text = fmt(val), TextSize = 12, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.4, 0, 0, 15), Position = UDim2.new(0.6, 0, 0, 0) })
    local track_ = new("Frame", { Parent = wrap, BackgroundColor3 = C.line2, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 0, 27) })
    local fill = new("Frame", { Parent = track_, BackgroundColor3 = C.ink, BorderSizePixel = 0, Size = UDim2.new((val-minV)/(maxV-minV), 0, 1, 0) })
    local handle = new("Frame", { Parent = track_, BackgroundColor3 = C.ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(11, 11), Position = UDim2.new((val-minV)/(maxV-minV), 0, 0.5, 0) })
    local tk = new("Frame", { Parent = wrap, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 0, 36) }, { hlist(0) })
    for _, v in ipairs({ minV, (minV+maxV)/2, maxV }) do
        local c = new("TextLabel", { Parent = tk, BackgroundTransparency = 1, FontFace = mono(W.med), Text = tostring(v), TextSize = 10, TextColor3 = C.dim2, Size = UDim2.new(1/3, 0, 1, 0) })
        c.TextXAlignment = (v == minV and Enum.TextXAlignment.Left) or (v == maxV and Enum.TextXAlignment.Right) or Enum.TextXAlignment.Center
    end
    local dragging = false
    local function setFromX(px, fire)
        local rel = math.clamp((px - track_.AbsolutePosition.X) / track_.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0); handle.Position = UDim2.new(rel, 0, 0.5, 0)
        local v = minV + rel * (maxV - minV); valLbl.Text = fmt(v)
        if fire and o.onChange then o.onChange(intMode and math.floor(v + 0.5) or v) end
    end
    local hit = new("TextButton", { Parent = wrap, BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 17) })
    hit.MouseButton1Down:Connect(function() dragging = true; setFromX(UIS:GetMouseLocation().X, true) end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
    UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then setFromX(i.Position.X, true) end end)
    regTree(wrap)
end

function Section:AddInput(o)
    local box = new("TextBox", { Parent = self.inner, BackgroundColor3 = C.ground, BorderSizePixel = 0, FontFace = mono(W.med), Text = o.default or "", PlaceholderText = o.placeholder or "", PlaceholderColor3 = C.dim2, TextColor3 = C.ink, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ClipsDescendants = true, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = self:_next() }, { corner(2), stroke(C.line2, 1, 0), pad(0, 10, 0, 10) })
    box.FocusLost:Connect(function() if o.onCommit then o.onCommit(box.Text) end end)
    regTree(box); return box
end

function Section:AddButton(o)
    local b = new("TextButton", { Parent = self.inner, AutoButtonColor = false, FontFace = mono(W.semi), Text = o.text or "BUTTON", TextSize = 12, TextColor3 = C.ink, BackgroundColor3 = C.raise, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = self:_next() }, { corner(2), stroke(C.line2, 1, 0) })
    b.MouseEnter:Connect(function() b.BackgroundColor3 = C.line end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = C.raise end)
    b.MouseButton1Click:Connect(function() if o.onClick then o.onClick() end end)
    regTree(b); return b
end

function Section:AddReadout(initText)
    local read = new("Frame", { Parent = self.inner, BackgroundColor3 = C.ground, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = self:_next() }, { corner(2), stroke(C.line, 1, 0), pad(0, 11, 0, 11), hlist(0) })
    local lbl = new("TextLabel", { Parent = read, BackgroundTransparency = 1, FontFace = mono(W.med), Text = "> " .. (initText or ""), TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -12, 1, 0) })
    local cursor = new("Frame", { Parent = read, BackgroundColor3 = C.ink, BorderSizePixel = 0, Size = UDim2.fromOffset(7, 13), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0) })
    task.spawn(function() while cursor.Parent do cursor.BackgroundTransparency = cursor.BackgroundTransparency == 0 and 1 or 0; task.wait(0.55) end end)
    regTree(read); return function(t) lbl.Text = "> " .. t end
end

function Section:AddEnable(o)
    local box = new("Frame", { Parent = self.inner, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = self:_next() }, { corner(2), stroke(C.ink, 1, 0), pad(0, 15, 0, 15) })
    new("TextLabel", { Parent = box, BackgroundTransparency = 1, FontFace = mono(W.bold), Text = o.title or "ENABLE", TextSize = 13, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, -80, 0, 16) })
    new("TextLabel", { Parent = box, BackgroundTransparency = 1, FontFace = mono(W.med), Text = o.sub or "", TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 0, 0, 31), Size = UDim2.new(1, -80, 0, 14) })
    local api, sw = buildSwitch(box, o.default or false, o.onChange)
    sw.AnchorPoint = Vector2.new(1, 0.5); sw.Position = UDim2.new(1, 0, 0.5, 0)
    regTree(box); return api
end

function Section:AddKeybind(o)
    local sub = o.sub
    local row = new("Frame", { Parent = self.inner, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, sub and 46 or 36), LayoutOrder = self:_next() })
    new("Frame", { Parent = row, BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0) })
    new("TextLabel", { Parent = row, BackgroundTransparency = 1, FontFace = mono(W.med), Text = o.title or "KEYBIND", TextSize = 12, TextColor3 = C.ink2, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 0, 0, sub and 9 or 0), Size = UDim2.new(1, -140, 0, sub and 16 or 35) })
    if sub then new("TextLabel", { Parent = row, BackgroundTransparency = 1, FontFace = mono(W.med), Text = sub, TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 0, 0, 27), Size = UDim2.new(1, -140, 0, 14) }) end
    local cur = o.default or Enum.KeyCode.RightShift
    local btn = new("TextButton", { Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), AutoButtonColor = false, FontFace = mono(W.semi), Text = cur.Name, TextSize = 11, TextColor3 = C.ink2, BackgroundColor3 = C.raise, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 25) }, { corner(2), stroke(C.line2, 1, 0), pad(5, 12, 5, 12) })
    local ui = self.ui
    btn.MouseButton1Click:Connect(function() ui._rebinding = true; btn.Text = "PRESS A KEY…"; btn.TextColor3 = C.ink end)
    UIS.InputBegan:Connect(function(input)
        if not ui._rebinding or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode ~= Enum.KeyCode.Escape then cur = input.KeyCode; if o.onChange then o.onChange(cur) end end
        btn.Text = cur.Name; btn.TextColor3 = C.ink2
        task.defer(function() ui._rebinding = false end)
    end)
    regTree(row); return btn
end

--========================================================================
-- TAB
--========================================================================
local Tab = {}
Tab.__index = Tab
function Tab:AddSection(title, meta)
    local order = (self._n or 0) + 1; self._n = order
    local s = new("Frame", { Parent = self.frame, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = order })
    new("Frame", { Parent = s, BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0) })
    local inner = new("Frame", { Parent = s, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) }, { pad(18, 0, 18, 0), vlist(14) })
    local head = new("Frame", { Parent = inner, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 0 }, { hlist(10) })
    txt(head, title, 12, C.ink, W.semi, 1)
    local rule = new("Frame", { Parent = head, BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(0, 10, 0, 1), LayoutOrder = 2 }); local f = flexFill(); if f then f.Parent = rule end
    if meta then local m = txt(head, meta, 11, C.dim, W.med, 3); m.TextXAlignment = Enum.TextXAlignment.Right end
    regTree(s)
    return setmetatable({ inner = inner, ui = self.ui, _n = 0 }, Section)
end

--========================================================================
-- MAIN WINDOW
--========================================================================
local SymbiosUI = {}
SymbiosUI.__index = SymbiosUI
SymbiosUI.loadImage = loadImage  -- static: download a PNG from a URL for icons/logos

function SymbiosUI.new(opts)
    opts = opts or {}
    local self = setmetatable({ tabs = {}, navRefs = {}, _rebinding = false, toggleKey = opts.toggleKey or Enum.KeyCode.RightShift }, SymbiosUI)

    local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
    if not parentGui then parentGui = Players.LocalPlayer:WaitForChild("PlayerGui") end
    local gname = opts.name or "SYMBIOS_UI"
    if parentGui:FindFirstChild(gname) then parentGui[gname]:Destroy() end
    local screen = new("ScreenGui", { Name = gname, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 9999, Parent = parentGui })
    self.screen = screen

    -- Wait for a valid viewport (early/autoexec runs report a transient/fallback
    -- size → fixed window ends up oversized on the real screen). Then a UIScale fits it.
    repeat task.wait() until workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y > 100
    local camera = workspace.CurrentCamera
    local WW, WH = 650, 474  -- fixed design size; UIScale below fits it to any screen
    local Win = new("Frame", { Name = "Win", Parent = screen, BackgroundColor3 = C.panel, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(WW, WH) }, { corner(3), stroke(C.line2, 1, 0) })
    self.win = Win
    local uiScale = new("UIScale", { Parent = Win })
    -- Responsive: shrink the whole window to fit; recompute on resize/rotate.
    local baseScale = 1
    self._recomputeScale = function()
        local vp = camera.ViewportSize
        baseScale = math.min(1, (vp.X - 24) / WW, (vp.Y - 24) / WH)
        if uiScale.Scale > 0.01 then uiScale.Scale = baseScale end
    end
    self._recomputeScale(); uiScale.Scale = baseScale
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(self._recomputeScale)

    -- corner brackets (targeting-frame motif; opts.brackets = false to disable)
    if opts.brackets ~= false then
        local function bracket(ax, ay)
            local b = new("Frame", { Parent = Win, BackgroundTransparency = 1, AnchorPoint = Vector2.new(ax, ay), Position = UDim2.new(ax, ax == 0 and -1 or 1, ay, ay == 0 and -1 or 1), Size = UDim2.fromOffset(13, 13) })
            new("Frame", { Parent = b, BackgroundColor3 = C.ink, BorderSizePixel = 0, Size = UDim2.fromOffset(13, 2), AnchorPoint = Vector2.new(ax, ay), Position = UDim2.fromScale(ax, ay) })
            new("Frame", { Parent = b, BackgroundColor3 = C.ink, BorderSizePixel = 0, Size = UDim2.fromOffset(2, 13), AnchorPoint = Vector2.new(ax, ay), Position = UDim2.fromScale(ax, ay) })
        end
        bracket(0, 0); bracket(1, 0); bracket(0, 1); bracket(1, 1)
    end

    -- notifications
    local notifHost = new("Frame", { Parent = screen, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(260, 400) }, { new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }) })
    self._notifHost = notifHost

    -- floating icon shown while minimized (opts.icon = assetId/content string, OR opts.iconUrl = raw PNG url)
    local iconContent = opts.icon or (opts.iconUrl and loadImage(opts.iconUrl, gname .. "_icon.png"))
    local fab = new("ImageButton", { Name = "Fab", Parent = screen, Visible = false, AutoButtonColor = false, BackgroundColor3 = C.panel, BorderSizePixel = 0, Image = iconContent or "", ScaleType = Enum.ScaleType.Fit, Position = UDim2.new(0, 24, 0.5, -24), Size = UDim2.fromOffset(48, 48) }, { corner(8), stroke(C.line2, 1, 0), pad(3, 3, 3, 3) })
    if not iconContent then new("TextLabel", { Parent = fab, BackgroundTransparency = 1, FontFace = mono(W.bold), Text = (opts.title or "S"):sub(1, 1), TextSize = 26, TextColor3 = C.ink, Size = UDim2.new(1, 0, 1, 0) }) end
    self._fab = fab
    function self.Restore()
        fab.Visible = false; uiScale.Scale = 0; Win.Visible = true
        Tween:Create(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = baseScale }):Play()
    end
    function self.Minimize()
        local tw = Tween:Create(uiScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
        tw:Play(); tw.Completed:Once(function() Win.Visible = false; fab.Visible = true end)
    end
    do -- fab drag + tap-to-restore
        local dg, mv, ds, sp
        fab.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dg = true; mv = false; ds = i.Position; sp = fab.Position end end)
        UIS.InputChanged:Connect(function(i) if dg and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local d = i.Position - ds; if d.Magnitude > 6 then mv = true end; fab.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end end)
        UIS.InputEnded:Connect(function(i) if dg and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then dg = false; if not mv then self.Restore() end end end)
    end

    -- close handling: opts.onClose (default = hide), opts.confirmClose (bool or {title,body,confirm})
    function self.Close()
        local function doClose() if opts.onClose then opts.onClose() else screen.Enabled = false end end
        if not opts.confirmClose then doClose(); return end
        if Win:FindFirstChild("__Confirm") then return end
        local cc = type(opts.confirmClose) == "table" and opts.confirmClose or {}
        local ov = new("Frame", { Name = "__Confirm", Parent = Win, BackgroundColor3 = C.ground, BackgroundTransparency = 0.4, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ZIndex = 60 }, { corner(3) })
        local card = new("Frame", { Parent = ov, BackgroundColor3 = C.panel, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(312, 0), AutomaticSize = Enum.AutomaticSize.Y }, { corner(3), stroke(C.line2, 1, 0), pad(20, 22, 18, 22), vlist(9) })
        new("TextLabel", { Parent = card, BackgroundTransparency = 1, FontFace = mono(W.bold), Text = cc.title or "CLOSE?", TextSize = 16, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 })
        new("TextLabel", { Parent = card, BackgroundTransparency = 1, FontFace = mono(W.med), Text = cc.body or "Are you sure?", TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 })
        local row = new("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 3 }, { hlist(10) })
        local cancel = new("TextButton", { Parent = row, AutoButtonColor = false, FontFace = mono(W.semi), Text = "CANCEL", TextSize = 12, TextColor3 = C.ink, BackgroundColor3 = C.raise, BorderSizePixel = 0, Size = UDim2.new(0.5, -5, 1, 0), LayoutOrder = 1 }, { corner(2), stroke(C.line2, 1, 0) })
        local confirm = new("TextButton", { Parent = row, AutoButtonColor = false, FontFace = mono(W.bold), Text = cc.confirm or "CONFIRM", TextSize = 12, TextColor3 = Color3.fromHex("e0564e"), BackgroundColor3 = C.raise, BorderSizePixel = 0, Size = UDim2.new(0.5, -5, 1, 0), LayoutOrder = 2 }, { corner(2), stroke(Color3.fromHex("e0564e"), 1, 0) })
        for _, d in ipairs(ov:GetDescendants()) do pcall(function() d.ZIndex = 62 end) end
        ov.ZIndex = 60; card.ZIndex = 61
        cancel.MouseButton1Click:Connect(function() ov:Destroy() end)
        confirm.MouseButton1Click:Connect(function() ov:Destroy(); doClose() end)
    end

    -- header
    local hdr = new("Frame", { Name = "Header", Parent = Win, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54) }, { pad(0, 18, 0, 20), hlist(14) })
    new("Frame", { Parent = Win, BackgroundColor3 = C.line2, BorderSizePixel = 0, Size = UDim2.new(1, -40, 0, 1), Position = UDim2.new(0, 20, 0, 54) })
    new("TextLabel", { Parent = hdr, BackgroundTransparency = 1, FontFace = mono(W.bold), Text = track(opts.title or "SYMBIOS"), TextSize = 20, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), LayoutOrder = 1 })
    if opts.subtitle then
        new("Frame", { Parent = hdr, BackgroundColor3 = C.line2, BorderSizePixel = 0, Size = UDim2.fromOffset(1, 20), LayoutOrder = 2 })
        txt(hdr, opts.subtitle, 11, C.dim, W.med, 3)
    end
    spacer(hdr, 4)
    self.tabNow = new("TextLabel", { Parent = hdr, BackgroundTransparency = 1, FontFace = mono(W.semi), Text = "", TextSize = 11, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Right, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), LayoutOrder = 5 })
    if opts.minimizable ~= false then
        local minBtn = new("TextButton", { Parent = hdr, BackgroundTransparency = 1, FontFace = mono(W.bold), Text = "–", TextSize = 20, TextColor3 = C.ink, AutoButtonColor = false, Size = UDim2.fromOffset(18, 18), LayoutOrder = 6 })
        minBtn.MouseButton1Click:Connect(function() self.Minimize() end)
    end
    local closeBtn = new("TextButton", { Parent = hdr, BackgroundTransparency = 1, FontFace = mono(W.bold), Text = "X", TextSize = 15, TextColor3 = C.ink, AutoButtonColor = false, Size = UDim2.fromOffset(18, 18), LayoutOrder = 7 })
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = Color3.fromHex("e0564e") end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = C.ink end)
    closeBtn.MouseButton1Click:Connect(function() self.Close() end)

    -- body: sidebar + content host
    local body = new("Frame", { Parent = Win, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 55), Size = UDim2.new(1, 0, 1, -55) })
    local rail = new("Frame", { Parent = body, BackgroundTransparency = 1, Size = UDim2.new(0, 176, 1, 0) })
    new("Frame", { Parent = rail, BackgroundColor3 = C.line2, BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0) })
    self.railCol = new("Frame", { Parent = rail, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) }, { vlist(2), pad(14, 0, 12, 0) })
    new("TextLabel", { Parent = self.railCol, BackgroundTransparency = 1, FontFace = mono(W.med), Text = "  " .. (opts.railLabel or "MODULES"), TextSize = 10, TextColor3 = C.dim2, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0 })
    if opts.profile == false then
        new("TextLabel", { Parent = rail, BackgroundTransparency = 1, FontFace = mono(W.med), RichText = true, TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = (opts.status or ("■ <font color='#c7c7c2'>" .. Players.LocalPlayer.Name .. "</font>\nLINK · ACTIVE")), Position = UDim2.new(0, 18, 1, -42), Size = UDim2.new(1, -30, 0, 36) })
    else
        -- profile card footer: avatar (headshot) + name + status line (opts.statusText)
        new("Frame", { Parent = rail, BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(1, -26, 0, 1), Position = UDim2.new(0, 13, 1, -60) })
        local footer = new("Frame", { Parent = rail, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -13), Size = UDim2.new(1, -1, 0, 36) })
        local avWrap = new("Frame", { Parent = footer, BackgroundColor3 = C.raise, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 15, 0.5, 0), Size = UDim2.fromOffset(34, 34) }, { corner(4), stroke(C.line2, 1, 0), pad(2, 2, 2, 2) })
        local avatar = new("ImageLabel", { Parent = avWrap, BackgroundColor3 = C.ground, BorderSizePixel = 0, Image = "", ScaleType = Enum.ScaleType.Fit, Size = UDim2.new(1, 0, 1, 0) }, { corner(3) })
        new("TextLabel", { Parent = footer, BackgroundTransparency = 1, FontFace = mono(W.semi), Text = Players.LocalPlayer.Name, TextSize = 12, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0, 58, 0, 2), Size = UDim2.new(1, -66, 0, 15) })
        local statusRow = new("Frame", { Parent = footer, BackgroundTransparency = 1, Position = UDim2.new(0, 58, 1, -16), Size = UDim2.new(1, -66, 0, 12) }, { hlist(6) })
        new("Frame", { Parent = statusRow, BackgroundColor3 = C.ink, BorderSizePixel = 0, Size = UDim2.fromOffset(6, 6), LayoutOrder = 1 }, { corner(3) })
        new("TextLabel", { Parent = statusRow, BackgroundTransparency = 1, FontFace = mono(W.med), Text = opts.statusText or "LINK · ACTIVE", TextSize = 10, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 12), LayoutOrder = 2 })
        task.spawn(function()
            local ok, url = pcall(function() return Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
            if ok and url then avatar.Image = url end
        end)
    end
    self.contentHost = new("Frame", { Parent = body, BackgroundTransparency = 1, Position = UDim2.fromOffset(176, 0), Size = UDim2.new(1, -176, 1, 0) })

    -- window drag
    do
        local dragging, dragStart, startPos
        hdr.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = i.Position; startPos = Win.Position end end)
        UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local d = i.Position - dragStart; Win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end)
        UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
    end
    -- hide/show hotkey
    local visible = true
    UIS.InputBegan:Connect(function(input, gp)
        if gp or self._rebinding then return end
        if input.KeyCode == self.toggleKey then
            visible = not visible
            if visible then screen.Enabled = true; Tween:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = baseScale }):Play()
            else local tw = Tween:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }); tw:Play(); tw.Completed:Once(function() if not visible then screen.Enabled = false end end) end
        end
    end)

    regTree(Win)
    return self
end

function SymbiosUI:AddTab(name, icon)
    local i = #self.tabs + 1
    local frame = new("ScrollingFrame", { Parent = self.contentHost, Visible = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.line2 }, { pad(4, 22, 22, 22), vlist(0) })
    local row = new("TextButton", { Parent = self.railCol, BackgroundColor3 = C.ink, BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = i })
    local bar = new("Frame", { Parent = row, BackgroundColor3 = C.ink, BorderSizePixel = 0, Size = UDim2.fromOffset(2, 40), BackgroundTransparency = 1 })
    local ic = new("ImageLabel", { Parent = row, BackgroundTransparency = 1, Image = icon or "", ImageColor3 = C.label, Size = UDim2.fromOffset(15, 15), Position = UDim2.new(0, 18, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
    local lb = new("TextLabel", { Parent = row, BackgroundTransparency = 1, FontFace = mono(W.med), Text = name, TextSize = 12, TextColor3 = C.label, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(1, -50, 1, 0) })
    self.tabs[i] = frame
    self.navRefs[i] = { frame = row, bar = bar, icon = ic, label = lb, name = name }
    row.MouseButton1Click:Connect(function() self:SetActive(i) end)
    regTree(row)
    if i == 1 then self:SetActive(1) end
    return setmetatable({ frame = frame, ui = self, _n = 0 }, Tab)
end

function SymbiosUI:SetActive(i)
    for j, r in ipairs(self.navRefs) do
        local on = (j == i)
        r.frame.BackgroundTransparency = on and 0 or 1
        r.bar.BackgroundTransparency = on and 0 or 1
        r.label.TextColor3 = on and C.ground or C.label
        r.label.FontFace = mono(on and W.semi or W.med)
        r.icon.ImageColor3 = on and C.ground or C.label
        self.tabs[j].Visible = on
        if on then self.tabNow.Text = "› " .. r.name end
    end
end

function SymbiosUI:SetFontOffset(n) fontOffset = n; applyFontOffset() end
function SymbiosUI:SetToggleKey(k) self.toggleKey = k end

function SymbiosUI:Notify(title, body, dur)
    dur = dur or 3
    local card = new("Frame", { Parent = self._notifHost, BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.fromOffset(260, 50), AutomaticSize = Enum.AutomaticSize.Y }, { corner(2), stroke(C.line2, 1, 0), pad(9, 12, 9, 12), vlist(3) })
    new("Frame", { Parent = card, BackgroundColor3 = C.ink, BorderSizePixel = 0, Size = UDim2.fromOffset(3, 22), Position = UDim2.new(0, 0, 0, 9) })
    txt(card, tostring(title), 12, C.ink, W.semi, 1)
    new("TextLabel", { Parent = card, BackgroundTransparency = 1, FontFace = mono(W.med), Text = tostring(body), TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 })
    regTree(card)
    card.BackgroundTransparency = 1
    Tween:Create(card, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
    task.delay(dur, function() if card and card.Parent then local tw = Tween:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 }); tw:Play(); tw.Completed:Wait(); card:Destroy() end end)
end

function SymbiosUI:Destroy() if self.screen then self.screen:Destroy() end end

--========================================================================
-- ============================  DEMO  ==================================
-- Test content showing every component. Delete this block and build your own.
--========================================================================
local UI = SymbiosUI.new({
    title = "SYMBIOS", subtitle = "TEST GAME", railLabel = "MODULES",
    -- iconUrl = "https://raw.githubusercontent.com/.../logo.png", -- floating-icon image (optional)
    confirmClose = { title = "CLOSE SYMBIOS?", body = "This unloads the test UI.", confirm = "CLOSE" },
    -- profile = false,          -- set to use a plain status line instead of the avatar card
    -- statusText = "LINK · ACTIVE",
})

-- ---- Tab 1: components showcase ----
local t1 = UI:AddTab("MODULE ONE", "rbxassetid://97834078379872")
local s1 = t1:AddSection("TEST SELECTION", "DEMO")
s1:AddDropdown({ label = "MANY OPTIONS", note = "SELECT / ADD", options = { "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet", "Kilo", "Lima", "Mike" }, onChange = function(a) print("[TEST] picked:", table.concat(a, ", ")) end })
s1:AddDropdown({ label = "FEW OPTIONS", note = "EMPTY = ANY", options = { "One", "Two", "Three" }, onChange = function(a) print("[TEST] few:", #a) end })

local s2 = t1:AddSection("TEST CONTROLS")
s2:AddSwitch({ title = "SAMPLE TOGGLE", default = true, onChange = function(v) print("[TEST] toggle:", v) end })
s2:AddSlider({ label = "SAMPLE VALUE", min = 0, max = 100, default = 42, onChange = function(v) print("[TEST] value:", v) end })
local setStatus = s2:AddReadout("IDLE")
s2:AddEnable({ title = "ENABLE MODULE", sub = "Sample enable box", default = false, onChange = function(v) setStatus(v and "RUNNING…" or "IDLE"); UI:Notify("Module One", v and "Enabled" or "Disabled", 2) end })

-- ---- Tab 2: another module ----
local t2 = UI:AddTab("MODULE TWO", "rbxassetid://131996513346128")
local s3 = t2:AddSection("TEST INFO")
s3:AddParagraph("This is a paragraph component for descriptions or instructions. It wraps across lines automatically.")
s3:AddButton({ text = "TEST BUTTON", onClick = function() UI:Notify("Button", "Clicked!", 2) end })

-- ---- Tab 3: settings ----
local t3 = UI:AddTab("SETTINGS", "rbxassetid://10734950309")
local sg = t3:AddSection("GENERAL")
sg:AddSwitch({ title = "SAMPLE SETTING", sub = "A persistent-looking toggle", default = true, onChange = function(v) print("[TEST] setting:", v) end })
sg:AddSlider({ label = "FONT WEIGHT (− THIN · + THICK)", min = -2, max = 2, default = 0, int = true, onChange = function(v) UI:SetFontOffset(v) end })
sg:AddKeybind({ title = "MENU TOGGLE KEY", sub = "Hide / show the window", default = Enum.KeyCode.RightShift, onChange = function(k) UI:SetToggleKey(k); UI:Notify("Keybind", "Menu toggle → " .. k.Name, 2) end })
sg:AddInput({ placeholder = "Paste any text…", onCommit = function(t) print("[TEST] input:", t) end })
sg:AddButton({ text = "TEST NOTIFY", onClick = function() UI:Notify("SYMBIOS UI", "This is a test notification.", 3) end })

UI:Notify("SYMBIOS UI", "Template loaded — RightShift to hide/show.", 4)
