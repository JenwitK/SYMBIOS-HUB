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
-- ==========  MAGIC LOOT AUTO FARM LOGIC  (wired to SYMBIOS UI)  =========
-- Everything ABOVE this line is SYMBIOS-MAIN-UI.luau embedded verbatim
-- (DEMO block removed, no edits to the framework). Everything below is the
-- Magic Loot auto-farm, using SymbiosUI instead of Rayfield. Wrapped in an
-- IIFE so its locals get their own scope and can't clash with the framework.
--========================================================================
;(function()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

local SessionId = tostring(os.clock()) .. "_" .. tostring(math.random(1, 1e9))
if getgenv then
    getgenv().MagicLootFarmSession = SessionId
end
local function isCurrentSession()
    return not getgenv or getgenv().MagicLootFarmSession == SessionId
end

--============================================================
-- On-screen debug log (mobile-friendly; independent of the UI framework)
--============================================================

local DebugGui, DebugList
local debugLines = {}
local killed = false -- set true by killGui() so nothing re-creates the debug box after unload
local debugVisible = true -- toggled by the Settings "DEBUG LOG" switch

local function ensureDebugGui()
    if killed then return end
    if DebugGui and DebugGui.Parent then return end
    pcall(function()
        local old = LocalPlayer.PlayerGui:FindFirstChild("MagicLootDebug")
        if old then old:Destroy() end
    end)

    DebugGui = Instance.new("ScreenGui")
    DebugGui.Name = "MagicLootDebug"
    DebugGui.ResetOnSpawn = false
    DebugGui.IgnoreGuiInset = true
    DebugGui.Enabled = debugVisible
    DebugGui.Parent = LocalPlayer.PlayerGui

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 380, 0, 220)
    Frame.Position = UDim2.new(0, 10, 1, -230)
    Frame.BackgroundColor3 = Color3.new(0, 0, 0)
    Frame.BackgroundTransparency = 0.35
    Frame.BorderSizePixel = 0
    Frame.Parent = DebugGui

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 24)
    Title.BackgroundTransparency = 1
    Title.Text = "Magic Loot Debug Log"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 16
    Title.Parent = Frame

    DebugList = Instance.new("TextLabel")
    DebugList.Size = UDim2.new(1, -8, 1, -28)
    DebugList.Position = UDim2.new(0, 4, 0, 26)
    DebugList.BackgroundTransparency = 1
    DebugList.Text = ""
    DebugList.TextColor3 = Color3.new(1, 1, 0)
    DebugList.Font = Enum.Font.Code
    DebugList.TextSize = 13
    DebugList.TextXAlignment = Enum.TextXAlignment.Left
    DebugList.TextYAlignment = Enum.TextYAlignment.Top
    DebugList.TextWrapped = true
    DebugList.Parent = Frame
end

local function debugLog(msg)
    print("[MagicLoot] " .. tostring(msg))
    if killed then return end
    pcall(function()
        ensureDebugGui()
        table.insert(debugLines, os.date("%H:%M:%S") .. "  " .. tostring(msg))
        while #debugLines > 10 do
            table.remove(debugLines, 1)
        end
        DebugList.Text = table.concat(debugLines, "\n")
    end)
end

-- show/hide the debug log box (creates it lazily if turning on and none exists)
local function setDebugVisible(v)
    debugVisible = v and true or false
    if debugVisible then
        ensureDebugGui()
    end
    if DebugGui then
        pcall(function() DebugGui.Enabled = debugVisible end)
    end
end

debugLog("Script loaded, session=" .. SessionId)

--============================================================
-- Game modules
--============================================================

local okUtils, UtilsSystem = pcall(require, game.ReplicatedFirst.AllSideCode.UtilsSystem)
if not okUtils then
    debugLog("FATAL: could not require UtilsSystem: " .. tostring(UtilsSystem))
    return
end

local NetWork = UtilsSystem.NetWork
local NetMsg = UtilsSystem.NetMsg
local CfgFind = UtilsSystem.CfgFind
local GetData = UtilsSystem.GetData
local PlayerData = UtilsSystem.PlayerData
local EnumMgr = UtilsSystem.EnumMgr
local CollectionService = UtilsSystem.CollectionService
local TipsModule = UtilsSystem.TipsModule
local ItemType = EnumMgr.ItemType
local Alchemy = GetData.Alchemy

debugLog("UtilsSystem OK. NetWork=" .. tostring(NetWork ~= nil) .. " NetMsg=" .. tostring(NetMsg ~= nil)
    .. " PlayerData=" .. tostring(PlayerData ~= nil) .. " Backpack=" .. tostring(GetData.Backpack ~= nil))

local bagFullTipSeen = false
if TipsModule and TipsModule.ErrorTips then
    local originalErrorTips = TipsModule.ErrorTips
    TipsModule.ErrorTips = function(player, key, ...)
        if type(key) == "string" and (key:find("背包") or key:find("[Bb]ackpack")) then
            bagFullTipSeen = true
        end
        return originalErrorTips(player, key, ...)
    end
end

local tipsHookConnection = nil
local function ensureTipsHook()
    if tipsHookConnection then return end
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local TipsGui = PlayerGui and PlayerGui:FindFirstChild("TipsGui")
    local NewTipsFrame = TipsGui and TipsGui:FindFirstChild("NewTipsFrame")
    if not NewTipsFrame then return end
    local function checkLabel(inst)
        if not inst:IsA("TextLabel") then return end
        local function check()
            local text = inst.Text or ""
            if text:find("[Bb]ackpack") or text:find("背包") then
                bagFullTipSeen = true
            end
        end
        check()
        inst:GetPropertyChangedSignal("Text"):Connect(check)
    end
    for _, inst in ipairs(NewTipsFrame:GetChildren()) do
        checkLabel(inst)
    end
    tipsHookConnection = NewTipsFrame.ChildAdded:Connect(checkLabel)
end

--============================================================
-- State
--============================================================

local State = {
    AutoPickup = false,
    MinPickupPrice = 0,
    AutoSell = false,
    MaxSellPrice = 1000,
    AutoClaimOnline = false,

    AutoClaimEventQuest = false,
    AntiAFK = true,

    AutoDungeon = false,
    StageCap = 10,
    HoverHeight = 10,
    HpReturnPercent = 50,

    TeleportFarmEnabled = false,
    TeleportFarmStage = nil,

    AutoSaveConfig = false,
    ShowDebugLog = true,
}

if getgenv then
    getgenv().MagicLootFarmState = State
end

--============================================================
-- Config persistence (writefile/readfile JSON - SymbiosUI has no built-in
-- config saving like Rayfield, so we roll our own).
--============================================================

local CONFIG_FOLDER = "SYMBIOS"
local CONFIG_PATH = CONFIG_FOLDER .. "/magicloot.json"

-- only these keys are persisted
local SAVED_KEYS = {
    "AutoPickup", "MinPickupPrice", "AutoSell", "MaxSellPrice", "AutoClaimOnline",
    "AutoClaimEventQuest", "AntiAFK",
    "AutoDungeon", "StageCap", "HoverHeight", "HpReturnPercent",
    "TeleportFarmEnabled", "TeleportFarmStage", "AutoSaveConfig", "ShowDebugLog",
}

local function serializeConfig()
    local data = {}
    for _, k in ipairs(SAVED_KEYS) do
        data[k] = State[k]
    end
    local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
    if ok then return json end
    return nil
end

local function saveConfig()
    if not writefile then return false, "no writefile" end
    local json = serializeConfig()
    if not json then return false, "encode failed" end
    local ok, err = pcall(function()
        if makefolder and isfolder and not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        writefile(CONFIG_PATH, json)
    end)
    return ok, err
end

local function loadConfig()
    if not (readfile and isfile) then return false end
    if not isfile(CONFIG_PATH) then return false end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_PATH))
    end)
    if not ok or type(data) ~= "table" then return false end
    for _, k in ipairs(SAVED_KEYS) do
        if data[k] ~= nil then
            State[k] = data[k]
        end
    end
    return true
end

--============================================================
-- Anti-AFK (logic from AntiAFK.luau): on LocalPlayer.Idled, capture the
-- controller and fire a harmless right-click so the 20-min idle kick never
-- triggers. Connection is stored in getgenv so it survives script reloads
-- without stacking.
--============================================================
local function setAntiAFK(enabled)
    if getgenv then
        pcall(function()
            if getgenv().AntiAFKConnection then
                getgenv().AntiAFKConnection:Disconnect()
                getgenv().AntiAFKConnection = nil
            end
        end)
    end
    if enabled then
        local conn = LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end)
        if getgenv then getgenv().AntiAFKConnection = conn end
    end
end

-- load saved settings BEFORE the UI is built so every component can render
-- with the saved value as its default
local configLoaded = loadConfig()

-- apply the saved debug-log visibility (default on)
setDebugVisible(State.ShowDebugLog ~= false)

-- apply anti-afk (default on)
setAntiAFK(State.AntiAFK ~= false)

-- periodic autosave: when AutoSaveConfig is on, flush to disk if anything
-- changed (covers slider drags / any setting, without wiring every callback)
local lastSavedJson = nil
task.spawn(function()
    while true do
        task.wait(3)
        if not isCurrentSession() then break end
        if State.AutoSaveConfig then
            local json = serializeConfig()
            if json and json ~= lastSavedJson then
                local ok = saveConfig()
                if ok then lastSavedJson = json end
            end
        end
    end
end)

--============================================================
-- Shared helpers
--============================================================

local function getUnitPrice(itemId)
    if not itemId then return 0 end
    local okCfg, cfg = pcall(CfgFind.FindCfgByID, itemId, ItemType.Material)
    if not okCfg or not cfg then return 0 end
    local okPrice, price = pcall(GetData.GetSellPrice, LocalPlayer, cfg)
    if okPrice and type(price) == "number" then return price end
    return tonumber(cfg.GoldValue) or 0
end

-- Sells every unlocked, non-recipe-protected material below maxPrice.
-- verbose=true reports every step to the on-screen log.
local function sellJunk(maxPrice, verbose)
    local function log(msg)
        if verbose then debugLog(msg) end
    end

    local okBag, Bag = pcall(PlayerData.GetPlrDataByKey, LocalPlayer, "Bag")
    if not okBag then
        log("sellJunk: GetPlrDataByKey errored: " .. tostring(Bag))
        return 0
    end
    if type(Bag) ~= "table" then
        log("sellJunk: Bag is not a table (got " .. type(Bag) .. ")")
        return 0
    end

    local scanned, skippedLocked, skippedProtected, skippedPrice = 0, 0, 0, 0
    local sellList = {}
    for _, item in pairs(Bag) do
        if type(item) == "table" and tonumber(item.tp) == ItemType.Material then
            scanned = scanned + 1
            local locked = item.lock == 1 or item.lock == true
            if locked then
                skippedLocked = skippedLocked + 1
            else
                local itemId = tonumber(item.id)
                local protected = false
                if itemId and Alchemy then
                    local okProt, isProt = pcall(Alchemy.IsMarkedRecipeMaterial, LocalPlayer, itemId)
                    protected = okProt and isProt
                end
                if protected then
                    skippedProtected = skippedProtected + 1
                else
                    local price = getUnitPrice(itemId)
                    if price < maxPrice then
                        local onlyID = tonumber(item.onlyID)
                        if onlyID then table.insert(sellList, onlyID) end
                    else
                        skippedPrice = skippedPrice + 1
                    end
                end
            end
        end
    end

    log(string.format(
        "sellJunk: %d material items, threshold<%s -> %d queued, %d locked, %d protected, %d over price",
        scanned, tostring(maxPrice), #sellList, skippedLocked, skippedProtected, skippedPrice
    ))

    if #sellList == 0 then
        return 0
    end

    local ok, result = pcall(function()
        return NetWork.InvokeServer(NetMsg.SELL_MATERIAL, { onlyIDList = sellList })
    end)
    log(string.format("sellJunk: SELL_MATERIAL call ok=%s result=%s", tostring(ok), tostring(result)))

    return #sellList
end

local Character = {
    model = nil,
    hrp = nil,
    humanoid = nil,
}

local function refreshCharacter()
    local model = LocalPlayer.Character
    if not model then return end
    Character.model = model
    Character.hrp = model:FindFirstChild("HumanoidRootPart")
    Character.humanoid = model:FindFirstChildOfClass("Humanoid")
end

local charAddedConn = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    refreshCharacter()
    if Character.hrp then Character.hrp.Anchored = false end
end)
refreshCharacter()

local function getHpPercent()
    local hum = Character.humanoid
    if not hum or hum.MaxHealth <= 0 then return 100 end
    return (hum.Health / hum.MaxHealth) * 100
end

local function isInDungeonChallenge()
    local v = LocalPlayer:FindFirstChild("InDungeonChallenge")
    return v ~= nil and tonumber(v.Value) and v.Value > 0
end

local function isInSafeArea()
    local v = LocalPlayer:FindFirstChild("InStageSafeArea")
    return not v or tonumber(v.Value) == nil or v.Value > 0
end

local function getBagUsage()
    local okSize, size = pcall(GetData.Backpack.GetBackpackWarehouseCurrentSize, LocalPlayer)
    if okSize and type(size) == "number" then return size end
    return 0
end

local function getBagMax()
    local okSize, size = pcall(GetData.Backpack.GetBackpackWarehouseMaxSize)
    if okSize and type(size) == "number" and size > 0 then return size end
    return 999
end

local function getEligibleTeleStages()
    local careerMax = LocalPlayer:FindFirstChild("CareerMaxStage")
    careerMax = careerMax and tonumber(careerMax.Value) or 0

    local broomMax = 0
    local NowBroom = LocalPlayer:FindFirstChild("NowBroom")
    local broomId = NowBroom and tonumber(NowBroom.Value) or 0
    if broomId > 0 then
        local okCfg, cfg = pcall(CfgFind.FindCfgByID, broomId, EnumMgr.ItemType.Broom)
        if okCfg and cfg then broomMax = tonumber(cfg.Dungeon) or 0 end
    end

    local stages = {}
    local maxStage = math.min(careerMax, broomMax)
    for i = 1, maxStage do
        local okCfg, cfg = pcall(CfgFind.GetCfgByNameAndID, "dungeonConf", i)
        if okCfg and cfg and type(cfg.TeleIcon) == "string" and cfg.TeleIcon ~= "" then
            table.insert(stages, i)
        end
    end
    return stages
end

local function getDoors()
    local doors = {}
    for _, d in ipairs(CollectionService:GetTagged("DungeonFrontDoor")) do
        local stage = tonumber(d:GetAttribute("Stage"))
        if stage then doors[stage] = d end
    end
    return doors
end

local function getCurrentTargetPosition()
    local ok, obj = pcall(function()
        local v = ReplicatedStorage:FindFirstChild("NowTargetCurrent")
        return v and v.Value
    end)
    if not ok or not obj or not obj.Parent then return nil end
    if obj:IsA("Model") then
        local okPivot, cf = pcall(obj.GetPivot, obj)
        if okPivot then return cf.Position end
        return nil
    elseif obj:IsA("BasePart") then
        return obj.Position
    end
    return nil
end

local function enableAutoAttack()
    local hub = LocalPlayer:FindFirstChild("PlayerScripts")
        and LocalPlayer.PlayerScripts:FindFirstChild("Manager")
        and LocalPlayer.PlayerScripts.Manager:FindFirstChild("PlayerSkillClientManager")
        and LocalPlayer.PlayerScripts.Manager.PlayerSkillClientManager:FindFirstChild("PlayerSkillControlHub")
    if not hub then
        debugLog("enableAutoAttack: PlayerSkillControlHub not found")
        return
    end
    local okReq, ControlHub = pcall(require, hub)
    if okReq and ControlHub and ControlHub.setDebugAutoAttackEnabled then
        pcall(ControlHub.setDebugAutoAttackEnabled, true)
        debugLog("Auto-attack enabled")
    else
        debugLog("enableAutoAttack: require/setDebugAutoAttackEnabled failed: " .. tostring(ControlHub))
    end
end

local DungeonState = "PUSH" -- "PUSH" | "RETURNING"
local TeleportFarmState = "FARM" -- "FARM" | "RETURNING"

--============================================================
-- Auto Pickup
--============================================================

task.spawn(function()
    while true do
        task.wait(0.3)
        if not isCurrentSession() then break end
        if State.AutoPickup then
            local DropsClient = workspace:FindFirstChild("DropsClient")
            if DropsClient then
                for _, prompt in ipairs(DropsClient:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and prompt.Name == "PickupPrompt" then
                        local model = prompt.Parent and prompt.Parent.Parent
                        local itemId = model and tonumber(model:GetAttribute("ItemId"))
                        if itemId and getUnitPrice(itemId) >= State.MinPickupPrice then
                            local ok, err = pcall(fireproximityprompt, prompt, 0)
                            if not ok then
                                debugLog("fireproximityprompt failed: " .. tostring(err))
                            end
                        end
                    end
                end
            end
        end
    end
end)

--============================================================
-- Auto Sell (standalone loop)
--============================================================

task.spawn(function()
    while true do
        task.wait(2)
        if not isCurrentSession() then break end
        if State.AutoSell then
            sellJunk(State.MaxSellPrice, false)
        end
    end
end)

--============================================================
-- Auto Claim Online Reward
--============================================================

local function claimOnlineRewards(verbose)
    local function log(msg)
        if verbose then debugLog(msg) end
    end

    local okList, list = pcall(CfgFind.GetOnlineAwardList)
    if not okList then
        log("claimOnlineRewards: GetOnlineAwardList errored: " .. tostring(list))
        return 0
    end
    if type(list) ~= "table" then
        log("claimOnlineRewards: award list is not a table (got " .. type(list) .. ")")
        return 0
    end

    local okBox, onlineBox = pcall(PlayerData.GetPlrDataByKey, LocalPlayer, "OnlineBox")
    if not okBox then
        log("claimOnlineRewards: GetPlrDataByKey(OnlineBox) errored: " .. tostring(onlineBox))
        onlineBox = nil
    end
    log(string.format("claimOnlineRewards: %d tiers total, OnlineSeconds=%s",
        #list, tostring(onlineBox and onlineBox.OnlineSeconds)))

    local attempted, claimed = 0, 0
    for _, award in ipairs(list) do
        local claimable = true
        if onlineBox then
            local okCheck, res = pcall(CfgFind.IsOnlineTierClaimable, onlineBox, award)
            if okCheck then claimable = res end
        end
        if claimable then
            attempted = attempted + 1
            local ok, result = pcall(function()
                return NetWork.InvokeServer(NetMsg.CLAIM_ONLINE_AWARD, award.id)
            end)
            log(string.format("claimOnlineRewards: tier id=%s ok=%s result=%s",
                tostring(award.id), tostring(ok), tostring(result)))
            if ok and result then claimed = claimed + 1 end
        end
    end
    log(string.format("claimOnlineRewards: %d/%d claimable, %d claimed", attempted, #list, claimed))
    return claimed
end

task.spawn(function()
    while true do
        task.wait(5)
        if not isCurrentSession() then break end
        if State.AutoClaimOnline then
            claimOnlineRewards(false)
        end
    end
end)

--============================================================
-- Auto Claim Event Quest
-- Event task data lives at PlayerData.Event.EventTask, split into
-- Timed / Daily / Once sections. Each section has .Progress (onlyTag -> count)
-- and .Completed (onlyTag -> 1 once the reward is taken). A task is claimable
-- when progress >= cfg.need AND it isn't already completed. Claim by firing
-- EVENT_TASK_CLAIM with the task's onlyTag (server validates, so it's safe).
--============================================================

local function taskNeed(cfg)
    local need = cfg and cfg.need
    if type(need) == "table" then need = tonumber(need[1]) or 1 else need = tonumber(need) or 1 end
    return math.max(1, need)
end

local function claimEventQuests(verbose)
    local function log(msg) if verbose then debugLog(msg) end end

    local okActive, active = pcall(CfgFind.IsEventRewardActive)
    if okActive and active == false then
        log("claimEventQuests: event rewards not active")
        return 0
    end

    local ev = PlayerData.GetPlrDataByKey(LocalPlayer, "Event")
    if type(ev) ~= "table" or type(ev.EventTask) ~= "table" then
        log("claimEventQuests: no EventTask data")
        return 0
    end

    local claimed = 0
    for _, section in ipairs({ "Timed", "Daily", "Once" }) do
        local sec = ev.EventTask[section]
        if type(sec) == "table" then
            local progress = type(sec.Progress) == "table" and sec.Progress or {}
            local completed = type(sec.Completed) == "table" and sec.Completed or {}
            for onlyTag, prog in pairs(progress) do
                if tonumber(completed[onlyTag]) ~= 1 then
                    local okCfg, cfg = pcall(CfgFind.GetTaskCfgByOnlyTag, onlyTag)
                    if okCfg and cfg and (tonumber(prog) or 0) >= taskNeed(cfg) then
                        local ok, res = pcall(function()
                            return NetWork.InvokeServer(NetMsg.EVENT_TASK_CLAIM, onlyTag)
                        end)
                        log(string.format("claimEventQuests: [%s] %s ok=%s res=%s",
                            section, tostring(onlyTag), tostring(ok), tostring(res)))
                        if ok and res == true then claimed = claimed + 1 end
                    end
                end
            end
        end
    end
    if verbose then log("claimEventQuests: claimed " .. tostring(claimed) .. " tasks") end
    return claimed
end

task.spawn(function()
    while true do
        task.wait(5)
        if not isCurrentSession() then break end
        if State.AutoClaimEventQuest then
            claimEventQuests(false)
        end
    end
end)

--============================================================
-- Hover combat positioning
--============================================================

task.spawn(function()
    while true do
        task.wait(0.2)
        if not isCurrentSession() then break end
        local returning = DungeonState == "RETURNING" or TeleportFarmState == "RETURNING"
        if not returning and (State.AutoDungeon or State.TeleportFarmEnabled) and isInDungeonChallenge() and not isInSafeArea() and Character.hrp then
            local targetPos = getCurrentTargetPosition()
            if targetPos then
                local hoverPos = targetPos + Vector3.new(0, State.HoverHeight, 0)
                Character.hrp.Anchored = true
                local tween = TweenService:Create(
                    Character.hrp,
                    TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                    { CFrame = CFrame.lookAt(hoverPos, targetPos) }
                )
                tween:Play()
            else
                if Character.hrp.Anchored then
                    Character.hrp.Anchored = false
                end
            end
        elseif Character.hrp and Character.hrp.Anchored then
            Character.hrp.Anchored = false
        end
    end
end)

--============================================================
-- Dungeon push state machine
--============================================================

local pushStage = 1
local lastEnterAttempt = 0
local stageEnterTime = os.clock()
local returningEnteredAt = os.clock()
local STAGE_TIMEOUT_SECONDS = 90
local RETURNING_TIMEOUT_SECONDS = 30

local sawDropThisStage = false
local dropsClientConnection = nil

local function ensureDropsClientHook()
    if dropsClientConnection then return end
    local DropsClient = workspace:FindFirstChild("DropsClient")
    if DropsClient then
        dropsClientConnection = DropsClient.DescendantAdded:Connect(function(inst)
            -- A landed lootable drop means the stage produced loot = it's
            -- clearing. Detect by the "PickupPrompt" ProximityPrompt (its name
            -- is stable across events, and auto-pickup already relies on it)
            -- rather than the wrapper Model's name, which changes per event
            -- ("DropItem" on the Dino event, a numeric item-id like "3313" on
            -- Light-vs-Dark) - that mismatch left it stuck farming stage 1.
            if inst:IsA("ProximityPrompt") and inst.Name == "PickupPrompt" then
                sawDropThisStage = true
            end
        end)
    end
end

local function stageDoorPosition(doors, stage)
    local door = doors[stage]
    if not door then return nil end
    local okPivot, cf = pcall(door.GetPivot, door)
    if not okPivot then return nil end
    return cf.Position
end

local function enterStage(stage)
    refreshCharacter()
    local doors = getDoors()
    local pos = stageDoorPosition(doors, stage)
    if pos and Character.hrp then
        pcall(function()
            Character.hrp.Anchored = false
            Character.hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 6))
        end)
    end
    sawDropThisStage = false
    stageEnterTime = os.clock()
    ensureDropsClientHook()
end

local SAFE_RETURN_POSITION = Vector3.new(-454.74, 10.15, 88.90)
local DEEP_TOWN_POSITION = Vector3.new(-452.62, 10.09, 51.91)

local function retreatAndSell()
    refreshCharacter()
    if Character.hrp then
        pcall(function()
            Character.hrp.Anchored = false
            Character.hrp.CFrame = CFrame.new(SAFE_RETURN_POSITION)
            task.wait(0.1)

            local steps1 = 16
            for i = 1, steps1 do
                Character.hrp.CFrame = Character.hrp.CFrame + Vector3.new(0, 0, -0.35)
                task.wait(0.8 / steps1)
            end

            local startPos = Character.hrp.Position
            local steps2 = 16
            for i = 1, steps2 do
                local alpha = i / steps2
                Character.hrp.CFrame = CFrame.new(startPos:Lerp(DEEP_TOWN_POSITION, alpha))
                task.wait(0.6 / steps2)
            end
        end)
    end
    task.wait(1)
    sellJunk(math.huge, true)
    task.wait(0.5)
end

if getgenv then
    getgenv().MagicLootFarmDebug = {
        getPushStage = function() return pushStage end,
        getDungeonState = function() return DungeonState end,
        getSawDrop = function() return sawDropThisStage end,
        getBagFullTipSeen = function() return bagFullTipSeen end,
    }
end

task.spawn(function()
    enableAutoAttack()
    -- Rising-edge guard: every time AutoDungeon flips OFF->ON, restart the
    -- climb cleanly from stage 1 with FRESH timers. Relying on the UI toggle's
    -- onChange alone wasn't enough - leftover pushStage / a stale stageEnterTime
    -- (which makes the timeout fire on the first tick) made re-enabling resume
    -- at the previous run's stage instead of stage 1.
    local prevAutoDungeon = false
    while true do
        task.wait(1)
        if not isCurrentSession() then break end
        if not State.AutoDungeon then
            DungeonState = "PUSH"
            prevAutoDungeon = false
        else
            if not prevAutoDungeon then
                prevAutoDungeon = true
                pushStage = 1
                sawDropThisStage = false
                stageEnterTime = os.clock()
                lastEnterAttempt = 0
                bagFullTipSeen = false
                DungeonState = "PUSH"
            end
            if DungeonState == "PUSH" then
                ensureTipsHook()
                local bagFull = getBagUsage() >= getBagMax() or bagFullTipSeen
                local hpLow = getHpPercent() < State.HpReturnPercent
                if bagFull or hpLow then
                    returningEnteredAt = os.clock()
                    DungeonState = "RETURNING"
                else
                    ensureDropsClientHook()
                    local timedOut = (os.clock() - stageEnterTime) > STAGE_TIMEOUT_SECONDS
                    if sawDropThisStage or timedOut then
                        if pushStage < State.StageCap then
                            pushStage = pushStage + 1
                        end
                        lastEnterAttempt = 0
                    end
                    if (os.clock() - lastEnterAttempt) > 5 then
                        lastEnterAttempt = os.clock()
                        enterStage(math.min(pushStage, State.StageCap))
                    end
                end
            elseif DungeonState == "RETURNING" then
                retreatAndSell()
                local stuck = (os.clock() - returningEnteredAt) > RETURNING_TIMEOUT_SECONDS
                if getHpPercent() >= State.HpReturnPercent or stuck then
                    bagFullTipSeen = false
                    pushStage = 1
                    lastEnterAttempt = 0
                    DungeonState = "PUSH"
                end
            end
        end
    end
end)

--============================================================
-- Teleport Farm
--============================================================

local lastTeleportAttempt = 0
local teleReturningEnteredAt = os.clock()

if getgenv then
    getgenv().MagicLootFarmDebug.getTeleportFarmState = function() return TeleportFarmState end
end

task.spawn(function()
    while true do
        task.wait(1)
        if not isCurrentSession() then break end
        if not State.TeleportFarmEnabled or State.AutoDungeon or not State.TeleportFarmStage then
            TeleportFarmState = "FARM"
        else
            if TeleportFarmState == "FARM" then
                ensureTipsHook()
                local bagFull = getBagUsage() >= getBagMax() or bagFullTipSeen
                local hpLow = getHpPercent() < State.HpReturnPercent
                if bagFull or hpLow then
                    teleReturningEnteredAt = os.clock()
                    TeleportFarmState = "RETURNING"
                elseif not isInDungeonChallenge() and (os.clock() - lastTeleportAttempt) > 8 then
                    lastTeleportAttempt = os.clock()
                    pcall(function()
                        NetWork.FireServer(NetMsg.STAGE_JUMP_REQUEST, State.TeleportFarmStage)
                    end)
                end
            elseif TeleportFarmState == "RETURNING" then
                retreatAndSell()
                local stuck = (os.clock() - teleReturningEnteredAt) > RETURNING_TIMEOUT_SECONDS
                if getHpPercent() >= State.HpReturnPercent or stuck then
                    bagFullTipSeen = false
                    lastTeleportAttempt = 0
                    TeleportFarmState = "FARM"
                end
            end
        end
    end
end)

--============================================================
-- GUI  (SYMBIOS UI - framework embedded above)
--============================================================

-- forward-declared so killGui (passed into onClose below) can reference UI
local UI

-- Fully unload the hub: stop every background loop, drop connections,
-- unanchor the character, remove the debug box, and destroy the window.
local function killGui()
    killed = true
    if getgenv then getgenv().MagicLootFarmSession = nil end -- makes isCurrentSession() false -> all loops break
    pcall(function() if tipsHookConnection then tipsHookConnection:Disconnect() end end)
    pcall(function() if dropsClientConnection then dropsClientConnection:Disconnect() end end)
    pcall(function() if charAddedConn then charAddedConn:Disconnect() end end)
    setAntiAFK(false) -- drop the Idled connection
    pcall(function() if Character.hrp then Character.hrp.Anchored = false end end)
    pcall(function() if DebugGui then DebugGui:Destroy() end end)
    if UI then pcall(function() UI:Destroy() end) end
    print("[MagicLoot] GUI killed - re-run the script to use it again")
end

UI = SymbiosUI.new({
    title = "SYMBIOS",
    subtitle = "MAGIC LOOT",
    railLabel = "MODULES",
    -- floating icon shown when the window is minimized
    iconUrl = "https://raw.githubusercontent.com/JenwitK/SYMBIOS-HUB/main/SymbiosHub_logo.png",
    -- X button asks to confirm, then fully kills the GUI (not just hide)
    confirmClose = {
        title = "KILL GUI?",
        body = "This fully unloads the hub and stops all auto-farm loops. Re-run the script to use it again.",
        confirm = "KILL",
    },
    onClose = killGui,
})

-- custom tab glyph (downloaded once, cached to disk). Falls back to a built-in
-- rbxassetid glyph if the image can't be fetched (no network / file API).
local TAB_ICON = SymbiosUI.loadImage(
    "https://raw.githubusercontent.com/JenwitK/SYMBIOS-HUB/main/imgcircle.png",
    "symbios_imgcircle.png"
) or "rbxassetid://97834078379872"

-- ===== LOOT tab =====
local lootTab = UI:AddTab("LOOT", TAB_ICON)

local pickupSec = lootTab:AddSection("PICKUP & SELL")

pickupSec:AddSwitch({
    title = "AUTO PICKUP ITEM",
    sub = "Auto-collect drops (skips items below the min price)",
    default = State.AutoPickup,
    onChange = function(v) State.AutoPickup = v end,
})

pickupSec:AddInput({
    placeholder = "Min pickup price (0)",
    default = tostring(State.MinPickupPrice),
    onCommit = function(txt) State.MinPickupPrice = tonumber(txt) or 0 end,
})

pickupSec:AddSwitch({
    title = "AUTO SELL",
    sub = "Sell materials priced below the threshold",
    default = State.AutoSell,
    onChange = function(v) State.AutoSell = v end,
})

pickupSec:AddInput({
    placeholder = "Sell items under this price (1000)",
    default = tostring(State.MaxSellPrice),
    onCommit = function(txt) State.MaxSellPrice = tonumber(txt) or 0 end,
})

pickupSec:AddButton({
    text = "SELL NOW",
    onClick = function()
        debugLog("Sell Now pressed, threshold=" .. tostring(State.MaxSellPrice))
        local n = sellJunk(State.MaxSellPrice, true)
        UI:Notify("SELL", "Queued " .. tostring(n) .. " items", 3)
    end,
})

local rewardSec = lootTab:AddSection("ONLINE REWARD")

rewardSec:AddSwitch({
    title = "AUTO CLAIM ONLINE REWARD",
    sub = "Auto-claim online playtime rewards",
    default = State.AutoClaimOnline,
    onChange = function(v) State.AutoClaimOnline = v end,
})

rewardSec:AddButton({
    text = "CLAIM NOW",
    onClick = function()
        debugLog("Claim Now pressed")
        local n = claimOnlineRewards(true)
        UI:Notify("CLAIM", "Claimed " .. tostring(n) .. " tiers", 3)
    end,
})

local questSec = lootTab:AddSection("EVENT QUEST")

questSec:AddSwitch({
    title = "AUTO CLAIM EVENT QUEST",
    sub = "Auto-claim completed event/season quest rewards",
    default = State.AutoClaimEventQuest,
    onChange = function(v) State.AutoClaimEventQuest = v end,
})

questSec:AddButton({
    text = "CLAIM EVENT QUESTS NOW",
    onClick = function()
        debugLog("Claim Event Quests pressed")
        local n = claimEventQuests(true)
        UI:Notify("EVENT QUEST", "Claimed " .. tostring(n) .. " quests", 3)
    end,
})

-- ===== DUNGEON tab =====
local dungeonTab = UI:AddTab("DUNGEON", TAB_ICON)

-- forward-declared so each mode switch can turn the other off
local autoDungeonSwitch, teleportFarmSwitch

local modeSec = dungeonTab:AddSection("FARM MODE", "PICK ONE")

autoDungeonSwitch = modeSec:AddSwitch({
    title = "AUTO DUNGEON PUSH",
    sub = "Walk stage-by-stage + hover-dodge monsters",
    default = State.AutoDungeon,
    onChange = function(v)
        State.AutoDungeon = v
        if v then
            enableAutoAttack()
            pushStage = 1
            State.TeleportFarmEnabled = false
            if teleportFarmSwitch then teleportFarmSwitch.set(false) end
        end
    end,
})

modeSec:AddInput({
    placeholder = "Stage cap (10)",
    default = tostring(State.StageCap),
    onCommit = function(txt) State.StageCap = tonumber(txt) or State.StageCap end,
})

local teleSec = dungeonTab:AddSection("TELEPORT FARM", "SINGLE STAGE")

-- eligible tele stages, computed once at load (re-run the script after
-- upgrading your broom to refresh the list)
local eligible = getEligibleTeleStages()
local eligibleStr = (#eligible > 0) and table.concat(eligible, ", ") or "none right now"
teleSec:AddParagraph("Teleportable stages right now: " .. eligibleStr
    .. "  (must be cleared before + within broom range). Type a stage number below, then turn the switch on.")
-- keep a saved stage if there is one, otherwise default to first eligible
State.TeleportFarmStage = State.TeleportFarmStage or eligible[1]

teleSec:AddInput({
    placeholder = "Teleport to stage #",
    default = State.TeleportFarmStage and tostring(State.TeleportFarmStage) or "",
    onCommit = function(txt) State.TeleportFarmStage = tonumber(txt) end,
})

teleportFarmSwitch = teleSec:AddSwitch({
    title = "FARM THIS STAGE (TELEPORT)",
    sub = "Teleport in and camp; when bag is full, return, sell, teleport back",
    default = State.TeleportFarmEnabled,
    onChange = function(v)
        State.TeleportFarmEnabled = v
        if v then
            enableAutoAttack()
            State.AutoDungeon = false
            if autoDungeonSwitch then autoDungeonSwitch.set(false) end
        end
    end,
})

local combatSec = dungeonTab:AddSection("COMBAT")

combatSec:AddSlider({
    label = "HOVER HEIGHT ABOVE MONSTER",
    min = 4, max = 150, default = State.HoverHeight, int = true,
    onChange = function(v) State.HoverHeight = v end,
})

combatSec:AddSlider({
    label = "RETURN WHEN HP% BELOW",
    min = 10, max = 90, default = State.HpReturnPercent, int = true, suffix = "%",
    onChange = function(v) State.HpReturnPercent = v end,
})

combatSec:AddParagraph("Hovering above a monster dodges melee, but ranged mobs may still hit you. If HP drops below the threshold it will Return + sell + resume automatically. Watch the black log box (bottom-left) to see what the script is doing.")

-- ===== SETTINGS tab =====
local settingsTab = UI:AddTab("SETTINGS", TAB_ICON)

local cfgSec = settingsTab:AddSection("CONFIG")

cfgSec:AddSwitch({
    title = "ANTI-AFK",
    sub = "Prevents the 20-minute idle kick (recommended ON)",
    default = State.AntiAFK ~= false,
    onChange = function(v)
        State.AntiAFK = v
        setAntiAFK(v)
    end,
})

cfgSec:AddSwitch({
    title = "DEBUG LOG",
    sub = "Show the black status log box (bottom-left of screen)",
    default = State.ShowDebugLog ~= false,
    onChange = function(v)
        State.ShowDebugLog = v
        setDebugVisible(v)
    end,
})

cfgSec:AddSwitch({
    title = "AUTO SAVE CONFIG",
    sub = "Automatically save all settings to file as you change them",
    default = State.AutoSaveConfig,
    onChange = function(v)
        State.AutoSaveConfig = v
        if v then
            local ok = saveConfig()
            UI:Notify("CONFIG", ok and "Auto-save ON (saved)" or "Auto-save ON (save failed)", 3)
        else
            UI:Notify("CONFIG", "Auto-save OFF", 2)
        end
    end,
})

cfgSec:AddButton({
    text = "SAVE CONFIG NOW",
    onClick = function()
        local ok, err = saveConfig()
        debugLog("Save Config Now: ok=" .. tostring(ok) .. (ok and "" or (" err=" .. tostring(err))))
        UI:Notify("CONFIG", ok and "Config saved" or ("Save failed: " .. tostring(err)), 3)
    end,
})

cfgSec:AddParagraph("Config is saved to workspace/" .. CONFIG_PATH
    .. " and loaded automatically next time you run the script.")

local dangerSec = settingsTab:AddSection("DANGER ZONE")

dangerSec:AddButton({
    text = "KILL GUI",
    onClick = function()
        -- routes through the same confirm popup as the X button (confirmClose),
        -- then onClose = killGui fully unloads the hub
        UI:Close()
    end,
})

dangerSec:AddParagraph("Fully unloads the hub and stops all loops. Asks for confirmation first.")

UI:Notify("SYMBIOS", "Magic Loot loaded — RightShift to hide/show.", 4)
debugLog("SYMBIOS UI ready. AutoSell=" .. tostring(State.AutoSell)
    .. " MaxSellPrice=" .. tostring(State.MaxSellPrice)
    .. " configLoaded=" .. tostring(configLoaded))

end)()
