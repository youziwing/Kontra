if _G.CharESP and _G.CharESP.cleanup then pcall(_G.CharESP.cleanup) end

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local MAX = 16
local TPG = 10
local FPS = 60
local SCALE = 2
local UI_URL = "https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua"

local S = { boxes = {}, tris = {}, cache = {} }
_G.CharESP = S

local cfg = {
    on = true, box = true, chams = false, teamCheck = true,
    head = true, torso = true, arms = false, legs = true,
    opacity = 0.35,
    boxCol = Color3.fromRGB(255, 50, 50),
    chamCol = Color3.fromRGB(255, 50, 50),
    aimOn = false, aimHeld = false, aimPart = "head",
    fov = 150, smooth = 6, maxSpeed = 40, sticky = true,
    showFov = true, fovCol = Color3.fromRGB(255, 255, 255),
}

S.fov = Drawing.new("Circle")
S.fov.Filled, S.fov.NumSides, S.fov.Thickness = false, 64, 1
S.fov.Transparency, S.fov.Color, S.fov.Visible = 1, cfg.fovCol, false

local ids = {}
for i = 1, MAX do ids[i] = tostring(i) end

local vis, boxOn, triN = {}, {}, {}
local myTeam

local function getBox(i)
    local b = S.boxes[i]
    if not b then
        b = Drawing.new("Square")
        b.Filled, b.Thickness, b.Transparency, b.Visible = false, 1, 1, false
        b.Color = cfg.boxCol
        S.boxes[i] = b
    end
    return b
end

local function getTri(i, k)
    local pool = S.tris[i]
    if not pool then pool = {} S.tris[i] = pool end
    local t = pool[k]
    if not t then
        t = Drawing.new("Triangle")
        t.Filled, t.Visible = true, false
        t.Color, t.Transparency = cfg.chamCol, cfg.opacity
        pool[k] = t
    end
    return t
end

local function restyle()
    for _, pool in pairs(S.tris) do
        for _, t in pairs(pool) do
            t.Color = cfg.chamCol
            t.Transparency = cfg.opacity
        end
    end
    for _, b in pairs(S.boxes) do b.Color = cfg.boxCol end
end

local function hideSlot(i)
    if not vis[i] then return end
    vis[i] = false
    if boxOn[i] then S.boxes[i].Visible = false boxOn[i] = false end
    local pool = S.tris[i]
    for k = 1, triN[i] or 0 do pool[k].Visible = false end
    triN[i] = 0
end

local function hideAll()
    for i = 1, MAX do hideSlot(i) end
end

local function pick(v) return type(v) == "table" and v[1] or v end

local function buildMenu()
    local Lib = loadstring(game:HttpGet(UI_URL))() or INSUI

    local win = Lib:CreateWindow({
        title = "Character ESP",
        subtitle = "auto",
        size = Vector2.new(640, 500),
        menuKey = "p",
        configName = "charesp",
        configFolder = "charesp",
        autoSave = true,
    })
    S.win = win
    win:AddSettingsTab("cog")

    local tab = win:Tab("ESP", "eye")

    local main = tab:Section("ESP", "Left", "characters 1-16")
    local en = main:Toggle("Enabled", cfg.on, function(v)
        cfg.on = v
        Lib:Notify("Character ESP", v and "enabled" or "disabled", 2, v and "success" or "warning")
    end)
    en:AddKeybind("n", "Toggle")

    local boxT = main:Toggle("Box", cfg.box, function(v) cfg.box = v end)
    boxT:AddColorpicker("Box color", cfg.boxCol, function(c)
        cfg.boxCol = c
        restyle()
    end)

    local chamT = main:Toggle("Chams", cfg.chams, function(v) cfg.chams = v end)
    chamT:AddColorpicker("Chams color", cfg.chamCol, function(c)
        cfg.chamCol = c
        restyle()
    end)

    main:Slider("Chams Opacity", cfg.opacity, 0.05, 0.05, 1.0, "", function(v)
        cfg.opacity = v
        restyle()
    end)
    main:Toggle("Team check", cfg.teamCheck, function(v) cfg.teamCheck = v end)

    local parts = tab:Section("Chams Body Parts", "Right", "box always covers the whole body")
    parts:Toggle("Head", cfg.head, function(v) cfg.head = v end)
    parts:Toggle("Torso", cfg.torso, function(v) cfg.torso = v end)
    parts:Toggle("Arms", cfg.arms, function(v) cfg.arms = v end)
    parts:Toggle("Legs", cfg.legs, function(v) cfg.legs = v end)

    local aimTab = win:Tab("Aim", "crosshair")

    local aim = aimTab:Section("Aim Assist", "Left", "hold the key to aim")
    local aimT = aim:Toggle("Enabled", cfg.aimOn, function(v)
        cfg.aimOn = v
        if v and not mousemoverel then
            Lib:Notify("Aim Assist", "mousemoverel is not available here", 4, "error")
        else
            Lib:Notify("Aim Assist", v and "enabled" or "disabled", 2, v and "success" or "warning")
        end
    end)
    aimT:AddKeybind("e", "Hold", function(on) cfg.aimHeld = on end)

    aim:Dropdown("Target part", {"Head"}, {"Head", "Torso", "Arms", "Legs", "Closest"}, false, function(v)
        cfg.aimPart = string.lower(tostring(pick(v)))
    end)
    aim:Slider("Smoothing", cfg.smooth, 0.5, 1, 30, "", function(v) cfg.smooth = v end)
    aim:Slider("Max speed", cfg.maxSpeed, 1, 2, 150, "px", function(v) cfg.maxSpeed = v end)
    aim:Toggle("Sticky target", cfg.sticky, function(v) cfg.sticky = v S.lock = nil end)

    local fovSec = aimTab:Section("FOV", "Right")
    fovSec:Slider("FOV radius", cfg.fov, 5, 20, 600, "px", function(v) cfg.fov = v end)
    local fovT = fovSec:Toggle("Show FOV circle", cfg.showFov, function(v) cfg.showFov = v end)
    fovT:AddColorpicker("FOV color", cfg.fovCol, function(c)
        cfg.fovCol = c
        S.fov.Color = c
    end)

    local menu = win:SettingsSection("Menu", "Right")

    menu:Keybind("Menu key", "p", function(key)
        win:SetMenuKey(key)
        Lib:Notify("Menu", "key set to " .. tostring(key), 2, "info")
    end)

    menu:Dropdown("Theme preset", {"Indigo"}, {
        "Indigo", "NeverBlox", "Lemon", "Mono", "Sunset", "Mint", "Rose", "Gold", "Crimson", "Ocean",
        "Toxic", "Lavender", "Aqua", "Ember", "Cyber", "Bubblegum", "Forest", "Slate", "Cherry",
        "Aurora", "Sky", "Magma", "Grape", "Steel", "Peach", "Neon", "Waifu",
    }, false, function(v) Lib:ApplyThemePreset(pick(v)) end, "theme presets", true)

    local accA, accB = Color3.fromRGB(122, 134, 255), Color3.fromRGB(189, 130, 255)
    menu:Colorpicker("Accent A", accA, function(c) accA = c Lib:SetAccent(accA, accB) end)
    menu:Colorpicker("Accent B", accB, function(c) accB = c Lib:SetAccent(accA, accB) end)

    menu:Dropdown("Font", {"Default"}, {
        "Default", "Bold", "Proxima", "Proggy", "Minecraft", "JetBrains", "Pixel", "Fortnite",
    }, false, function(v) Lib:SetFont(pick(v)) end)

    menu:Dropdown("Background effect", {"Off"}, {"Off", "Snow", "Matrix", "Rain"}, false,
        function(v) Lib:SetBackgroundEffect(pick(v)) end)
    menu:Colorpicker("Effect color", Color3.fromRGB(160, 90, 255), function(c)
        Lib:SetBackgroundEffectColor(c)
    end)
    menu:Textbox("Background image URL", "", function(text)
        if text and text ~= "" then Lib:SetBackgroundImage(text, 0.5) end
    end)

    menu:Slider("Opacity", 95, 1, 30, 100, "%", function(v) Lib:SetOpacity(v / 100) end)
    menu:Slider("Rounding", 1, 0.1, 0, 3, "", function(v) Lib:SetRounding(v) end)

    menu:Toggle("Tabs on top", false, function(on)
        pcall(function() Lib:SetLayout(on and "top" or "side") end)
    end)
    menu:Toggle("Row lines", true, function(on) Lib:SetRowLines(on) end)
    menu:Toggle("Checkbox style", true, function(on) Lib:SetCheckboxStyle(on) end)
    menu:Toggle("Keybind overlay", true, function(on) Lib:SetKeybindOverlay(on) end)
    menu:Toggle("Search (Ctrl+Space)", true, function(on) Lib:SetSpotlight(on) end)
    menu:Toggle("Performance mode", false, function(on) Lib:SetPerformance(on) end)

    menu:Dropdown("Game input", {"Blocked while open"},
        {"Blocked while open", "Released outside window", "Never blocked"}, false, function(v)
            local m = pick(v)
            Lib:SetGameInput(m == "Blocked while open" and false or (m == "Released outside window" and true or "always"))
        end)

    menu:Button("Open settings", function() Lib:OpenSettings() end)
        :AddButton("Open search", function() Lib:OpenSpotlight() end)

    Lib:Notify("Character ESP", "Loaded. Press P to open the menu", 4, "success")
end

local ok, err = pcall(buildMenu)
if not ok then print("[CharESP] menu failed (ESP still runs): " .. tostring(err)) end

local cX, cY, cZ, c00, c01, c02, c10, c11, c12, c20, c21, c22, fL, hW, hH

local function updCam()
    local cam = workspace.CurrentCamera
    local vp = cam.ViewportSize
    hW, hH = vp.X * 0.5, vp.Y * 0.5
    fL = hH / math.tan(math.rad(cam.FieldOfView) * 0.5)
    cX, cY, cZ, c00, c01, c02, c10, c11, c12, c20, c21, c22 = cam.CFrame:GetComponents()
end

local CX = { .5, -.5, .5, -.5, .5, -.5, .5, -.5 }
local CY = { .5, .5, -.5, -.5, .5, .5, -.5, -.5 }
local CZ = { .5, .5, .5, .5, -.5, -.5, -.5, -.5 }

local BX, BY = {}, {}
local function projectPart(part, scale, n)
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
    local s = part.Size
    local hx, hy, hz = s.X * 0.5 * scale, s.Y * 0.5 * scale, s.Z * 0.5 * scale
    for c = 1, 8 do
        local lx, ly, lz = CX[c] * hx, CY[c] * hy, CZ[c] * hz
        local dx = x + r00 * lx + r01 * ly + r02 * lz - cX
        local dy = y + r10 * lx + r11 * ly + r12 * lz - cY
        local dz = z + r20 * lx + r21 * ly + r22 * lz - cZ
        local d = -(c02 * dx + c12 * dy + c22 * dz)
        if d >= 0.01 then
            local sc = fL / d
            n = n + 1
            BX[n] = hW + (c00 * dx + c10 * dy + c20 * dz) * sc
            BY[n] = hH - (c01 * dx + c11 * dy + c21 * dz) * sc
        end
    end
    return n
end

local function projectPoint(x, y, z)
    local dx, dy, dz = x - cX, y - cY, z - cZ
    local d = -(c02 * dx + c12 * dy + c22 * dz)
    if d < 0.01 then return nil end
    local sc = fL / d
    return hW + (c00 * dx + c10 * dy + c20 * dz) * sc, hH - (c01 * dx + c11 * dy + c21 * dz) * sc
end

local P, L, H = {}, {}, {}
for k = 1, 24 do P[k] = { 0, 0 } end
local lastL = 0

local function cmp(a, b)
    if a[1] == b[1] then return a[2] < b[2] end
    return a[1] < b[1]
end

local function cross(o, a, b)
    return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
end

local function buildHull(n)
    for k = 1, n do
        local p = P[k]
        p[1], p[2] = BX[k], BY[k]
        L[k] = p
    end
    for k = n + 1, lastL do L[k] = nil end
    lastL = n
    table.sort(L, cmp)

    local hn = 0
    for k = 1, n do
        local p = L[k]
        while hn >= 2 and cross(H[hn - 1], H[hn], p) <= 0 do hn = hn - 1 end
        hn = hn + 1
        H[hn] = p
    end
    local lower = hn + 1
    for k = n - 1, 1, -1 do
        local p = L[k]
        while hn >= lower and cross(H[hn - 1], H[hn], p) <= 0 do hn = hn - 1 end
        hn = hn + 1
        H[hn] = p
    end
    return hn - 1
end

local KEYS = { "head", "torso", "arms", "legs" }
local SETS = { head = { "head" }, torso = { "torso" }, arms = { "arms" }, legs = { "legs" }, closest = KEYS }
local DEFS = {
    R15 = {
        head = { { "Head" } },
        torso = { { "UpperTorso", "LowerTorso" } },
        arms = { { "LeftUpperArm", "LeftLowerArm", "LeftHand" },
                 { "RightUpperArm", "RightLowerArm", "RightHand" } },
        legs = { { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
                 { "RightUpperLeg", "RightLowerLeg", "RightFoot" } },
    },
    R6 = {
        head = { { "Head" } },
        torso = { { "Torso" } },
        arms = { { "Left Arm" }, { "Right Arm" } },
        legs = { { "Left Leg" }, { "Right Leg" } },
    },
}

local function findPlayer(char)
    local ok, plr = pcall(function()
        local tag = char:FindFirstChild("NameTag")
        local cg = tag and tag:FindFirstChild("CanvasGroup")
        local lbl = cg and cg:FindFirstChild("PlayerName")
        local text = lbl and lbl.Text
        if not text or text == "" then return nil end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == text or p.DisplayName == text then return p end
        end
        return nil
    end)
    return ok and plr or nil
end

local function refresh(c)
    if not c.plr then c.plr = findPlayer(c.char) end
    if c.plr then
        local ok, t = pcall(function() return c.plr:GetAttribute("Team") end)
        if ok then
            c.team = t
        else
            c.plr, c.team = nil, nil
        end
    end
end

local function skip(c)
    if c.plr and c.plr == lp then return true end
    if cfg.teamCheck then
        local t = c.team
        return not (t == "T" or t == "CT") or t == myTeam
    end
    return false
end

local function buildCache(char)
    local def = char:FindFirstChild("UpperTorso") and DEFS.R15 or DEFS.R6
    local c = { char = char, groups = {}, all = {}, complete = true, wait = 0, age = 0 }
    for _, key in ipairs(KEYS) do
        local gl = {}
        for _, names in ipairs(def[key]) do
            local list = {}
            for _, name in ipairs(names) do
                local p = char:FindFirstChild(name)
                if p and p:IsA("BasePart") then
                    list[#list + 1] = p
                    c.all[#c.all + 1] = p
                else
                    c.complete = false
                end
            end
            gl[#gl + 1] = list
        end
        c.groups[key] = gl
    end
    refresh(c)
    return c
end

local stamp, frame = {}, 0

local function getCache(i, folder)
    if stamp[i] == frame then
        local c = S.cache[i]
        if c and #c.all > 0 then return c end
        return nil
    end
    stamp[i] = frame

    local char = folder:FindFirstChild(ids[i])
    if not char then
        S.cache[i] = nil
        return nil
    end

    local c = S.cache[i]
    if not c or c.char ~= char then
        c = buildCache(char)
        S.cache[i] = c
    else
        if not c.complete then
            c.wait = c.wait + 1
            if c.wait >= 30 then c = buildCache(char) S.cache[i] = c end
        end
        c.age = c.age + 1
        if c.age % 30 == 0 or (not c.plr and c.age % 10 == 0) then refresh(c) end
    end
    if #c.all == 0 then return nil end
    return c
end

local function procChar(i, folder)
    local c = getCache(i, folder)
    if not c or skip(c) then return hideSlot(i) end

    local drew = false
    local prev = triN[i] or 0
    local ti = 0

    if cfg.chams then
        for _, key in ipairs(KEYS) do
            if cfg[key] then
                for _, list in ipairs(c.groups[key]) do
                    local n = 0
                    for _, p in ipairs(list) do n = projectPart(p, SCALE, n) end
                    if n >= 3 then
                        local hn = buildHull(n)
                        if hn >= 3 then
                            local cx, cy = 0, 0
                            for k = 1, hn do cx = cx + H[k][1] cy = cy + H[k][2] end
                            local center = Vector2.new(cx / hn, cy / hn)
                            local cnt = hn < TPG and hn or TPG
                            for k = 1, cnt do
                                local nx = k % hn + 1
                                ti = ti + 1
                                local t = getTri(i, ti)
                                t.PointA = center
                                t.PointB = Vector2.new(H[k][1], H[k][2])
                                t.PointC = Vector2.new(H[nx][1], H[nx][2])
                                if ti > prev then t.Visible = true end
                            end
                        end
                    end
                end
            end
        end
    end
    local pool = S.tris[i]
    for j = ti + 1, prev do pool[j].Visible = false end
    triN[i] = ti
    if ti > 0 then drew = true end

    local boxDrawn = false
    if cfg.box then
        local n = 0
        for _, p in ipairs(c.all) do n = projectPart(p, 1, n) end
        if n > 0 then
            local minX, minY, maxX, maxY = BX[1], BY[1], BX[1], BY[1]
            for k = 2, n do
                local x, y = BX[k], BY[k]
                if x < minX then minX = x elseif x > maxX then maxX = x end
                if y < minY then minY = y elseif y > maxY then maxY = y end
            end
            if maxX > 0 and minX < hW * 2 and maxY > 0 and minY < hH * 2 then
                local box = getBox(i)
                box.Position = Vector2.new(minX, minY)
                box.Size = Vector2.new(maxX - minX, maxY - minY)
                if not boxOn[i] then box.Visible = true boxOn[i] = true end
                boxDrawn = true
                drew = true
            end
        end
    end
    if not boxDrawn and boxOn[i] then
        S.boxes[i].Visible = false
        boxOn[i] = false
    end

    vis[i] = drew
end

local remX, remY = 0, 0

local function trunc(v) return v >= 0 and math.floor(v) or math.ceil(v) end

local function groupCenter(c, key)
    local sx, sy, sz, n = 0, 0, 0, 0
    for _, list in ipairs(c.groups[key]) do
        for _, p in ipairs(list) do
            local pos = p.Position
            sx, sy, sz, n = sx + pos.X, sy + pos.Y, sz + pos.Z, n + 1
        end
    end
    if n == 0 then return nil end
    return sx / n, sy / n, sz / n
end

local function evalSlot(i, folder, mode)
    local c = getCache(i, folder)
    if not c or skip(c) then return nil end

    local bestD, bx, by
    for _, key in ipairs(SETS[mode] or SETS.head) do
        local x, y, z = groupCenter(c, key)
        if x then
            local sx, sy = projectPoint(x, y, z)
            if sx then
                local dx, dy = sx - hW, sy - hH
                local d = math.sqrt(dx * dx + dy * dy)
                if not bestD or d < bestD then bestD, bx, by = d, sx, sy end
            end
        end
    end
    return bestD, bx, by
end

local function aimStep(folder)
    if not (cfg.aimOn and cfg.aimHeld) then
        S.lock, remX, remY = nil, 0, 0
        return
    end
    if not mousemoverel then return end
    if isrbxactive and not isrbxactive() then return end

    local mode, fov = cfg.aimPart, cfg.fov
    local td, tx, ty

    if cfg.sticky and S.lock then
        local ok, d, sx, sy = pcall(evalSlot, S.lock, folder, mode)
        if ok and d and d <= fov * 1.5 then
            td, tx, ty = d, sx, sy
        else
            S.lock = nil
        end
    end

    if not td then
        local best
        for i = 1, MAX do
            local ok, d, sx, sy = pcall(evalSlot, i, folder, mode)
            if ok and d and d <= fov and (not td or d < td) then
                td, tx, ty, best = d, sx, sy, i
            end
        end
        S.lock = best
    end

    if not td then return end

    local mx, my = (tx - hW) / cfg.smooth, (ty - hH) / cfg.smooth
    local mag = math.sqrt(mx * mx + my * my)
    if mag > cfg.maxSpeed then
        local k = cfg.maxSpeed / mag
        mx, my = mx * k, my * k
    end

    mx, my = mx + remX, my + remY
    local ix, iy = trunc(mx), trunc(my)
    remX, remY = mx - ix, my - iy
    if ix ~= 0 or iy ~= 0 then mousemoverel(ix, iy) end
end

local fovOn, fovX, fovY, fovR = false, 0, 0, 0

local function hideFov()
    if fovOn then
        S.fov.Visible = false
        fovOn = false
    end
end

local function updFov()
    if cfg.aimOn and cfg.showFov then
        local f = S.fov
        if hW ~= fovX or hH ~= fovY then f.Position = Vector2.new(hW, hH) fovX, fovY = hW, hH end
        if cfg.fov ~= fovR then f.Radius = cfg.fov fovR = cfg.fov end
        if not fovOn then f.Visible = true fovOn = true end
    else
        hideFov()
    end
end

local step, acc = 1 / FPS, 0
local errShown = false

S.conn = RunService.RenderStepped:Connect(function(dt)
    acc = acc + dt
    if acc < step then return end
    acc = acc - step
    frame = frame + 1

    local folder = workspace:FindFirstChild("Characters")
    if not folder then
        hideAll()
        hideFov()
        S.lock = nil
        return
    end

    if frame % 30 == 1 then
        local ok, t = pcall(function() return lp:GetAttribute("Team") end)
        myTeam = ok and t or nil
    end

    updCam()

    if cfg.on and (cfg.box or cfg.chams) then
        for i = 1, MAX do
            local ok, e = pcall(procChar, i, folder)
            if not ok then
                S.cache[i] = nil
                hideSlot(i)
                if not errShown then
                    errShown = true
                    print("[CharESP] slot " .. i .. " error: " .. tostring(e))
                end
            end
        end
    else
        hideAll()
    end

    pcall(aimStep, folder)
    pcall(updFov)
end)

print("[CharESP] running")

S.cleanup = function()
    if S.conn then pcall(function() S.conn:Disconnect() end) end
    for _, b in pairs(S.boxes) do pcall(function() b:Remove() end) end
    for _, pool in pairs(S.tris) do
        for _, t in pairs(pool) do pcall(function() t:Remove() end) end
    end
    if S.fov then pcall(function() S.fov:Remove() end) end
    if S.win then pcall(function() S.win:Destroy() end) end
end
