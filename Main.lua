if _G.SoundESP and _G.SoundESP.Stop then pcall(_G.SoundESP.Stop) end
if _G.CharESP and _G.CharESP.cleanup then pcall(_G.CharESP.cleanup) end

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MAX = 16
local TPG = 10
local FPS = 60
local SCALE = 2
local JUMP = 80
local VOID_Y = -500000
local UP, DOWN = 2.6, 2.7
local TICK = 1 / 64
local MIN_HOLD = TICK * 2
local WALK_MAX = 12
local DUCK_H = 4.0
local B3W, B3H = 1.1, 2.7
local DEBUG = false
local UI_URL = "https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua"

local S = { boxes = {}, tris = {}, cache = {}, lbl = {}, lines = {}, seen = {}, gTxt = {}, gBox = {}, gDot = {} }
_G.CharESP = S
_G.Kontra = S

local rev = 0

local cfg = {
    on = true, box = true, chams = false, teamCheck = true,
    weapon = true, espNum = true, lblCol = Color3.fromRGB(255, 190, 60),
    tracer = true, tracerCol = Color3.fromRGB(255, 255, 255), tracerFrom = "bottom",
    seen = true, seenMax = 10,
    sDot = false, sBox = true, sNum = true, sWeapon = true, sTime = true,
    sDotCol = Color3.fromRGB(120, 200, 255),
    sBoxCol = Color3.fromRGB(120, 200, 255),
    sTxtCol = Color3.fromRGB(255, 255, 255),
    head = true, torso = true, arms = false, legs = true,
    opacity = 0.35,
    boxCol = Color3.fromRGB(255, 50, 50),
    chamCol = Color3.fromRGB(255, 50, 50),
    aimHeld = false, aimPart = "head",
    fov = 150, smooth = 6, maxSpeed = 40, sticky = true,
    showFov = true, fovCol = Color3.fromRGB(255, 255, 255),
    tbHeld = false, tbMode = "tap", tbReact = 0, tbHold = 40, tbGap = 45, tbJit = 25,
    tbPad = 0.1, tbVis = false, tbFocus = false, tbDebug = false, tbWall = false,
    tHead = true, tTorso = true, tArms = true, tLegs = true,
    wallMethod = "auto", wallSize = 3, wallRate = 60, wallDebug = false,
    aimWall = false, espVis = false,
    visCol = Color3.fromRGB(80, 255, 120),
    hidCol = Color3.fromRGB(255, 70, 70),
    e = {
        boxStyle = "full", boxThick = 1, fill = false, fillAlpha = 0.15,
        skel = true, skelCol = Color3.fromRGB(255, 255, 255), skelThick = 1, headDot = true,
        outline = false, outCol = Color3.fromRGB(255, 255, 255), outThick = 1, outScale = 1.1, outGlow = false,
        look = false, lookCol = Color3.fromRGB(255, 230, 80), lookLen = 5,
        arrows = true, arrowCol = Color3.fromRGB(255, 80, 80), arrowSize = 14, arrowRad = 75,
        dist = true, flags = true, scaleText = true, fade = false, maxDist = 2000,
        allyHp = true, colorMode = "static",
        closest = true, focusCol = Color3.fromRGB(255, 220, 0),
        radar = false, radarSize = 140, radarRange = 120, radarX = 20, radarY = 150,
        radarEnemy = Color3.fromRGB(255, 70, 60), radarAlly = Color3.fromRGB(90, 170, 255),
        hud = false,
    },
    snd = {
        on = true,
        teamOnly = false,
        pollRate = 0.03,
        pool = 128,
        range = 400,
        tracers = false,
        maxPerNamePerTick = 8,
        life = { step = 3.5, land = 2.5, fire = 1.6, relo = 1.4, impact = 1.4, misc = 1.6 },
         categories = { step = true, fire = true, relo = false, impact = false, misc = true },
        cols = {
            enemy = Color3.fromRGB(255, 70, 60),
            ally = Color3.fromRGB(90, 170, 255),
            unk = Color3.fromRGB(225, 225, 225),
            trac = Color3.fromRGB(255, 60, 50),
        },
    },
}

S.snd = { running = true, marks = {}, markIdx = 0, emitCount = 0, dot = {}, txt = {}, line = {} }
local SNDMAX = 128

for i = 1, SNDMAX do
    local c = Drawing.new("Circle")
    c.Thickness, c.Filled, c.NumSides, c.Radius, c.Visible = 1, true, 10, 3, false
    S.snd.dot[i] = c
    local t = Drawing.new("Text")
    t.Size, t.Center, t.Outline, t.Font, t.Color, t.Visible = 12, true, true, 2, cfg.snd.cols.unk, false
    S.snd.txt[i] = t
    local l = Drawing.new("Line")
    l.Thickness, l.Color, l.Visible = 1, cfg.snd.cols.trac, false
    S.snd.line[i] = l
end

local function kindOf(name)
    if name:sub(1, 10) == "Footsteps." then return "step" end
    if name:sub(1, 8) == "Impacts." then return "impact" end
    if name:sub(1, 8) == "Weapons." then
        if name:sub(-5):lower() == ".fire" then return "fire" end
        return "relo"
    end
    if name:sub(1, 5) == "Misc." then return "misc" end
    return nil
end

local function teamOfSound(name)
    if name:sub(-2) == "Ct" then return "CT" end
    if name:sub(-1) == "T" and name:sub(-2) ~= "Ct" then return "T" end
    return nil
end

local function matOf(name)
    local tail = name:match("%.([A-Za-z%-]+)C?T?$")
    return tail and tail:lower() or ""
end

S.snd.lastCounts, S.snd.recent = {}, {}

task.spawn(function()
    while S.snd.running do
        if cfg.snd.on then
            local deb = workspace:FindFirstChild("Debris")
            -- Current sound system: positional event Parts live in SourceSounds.
            -- Keep the old Sounds path as a fallback for older servers.
            local sounds = deb and (deb:FindFirstChild("SourceSounds") or deb:FindFirstChild("Sounds"))
            if sounds then
                local lp = Players.LocalPlayer
                local myTeam = lp and lp:GetAttribute("Team") or nil
                local parts = sounds:GetChildren()
                -- Build counts and positions in one pass.  The old code
                -- rescanned every emitter once per name (quadratic on the
                -- SourceSounds tree), which caused the new system to lag.
                local cur, grouped = {}, {}
                for i = 1, #parts do
                    local p = parts[i]
                    local name, pos = p.Name, p.Position
                    if pos then
                        cur[name] = (cur[name] or 0) + 1
                        local g = grouped[name]
                        if not g then
                            g = { positions = {}, seen = {} }
                            grouped[name] = g
                        end
                        local key = string.format("%d|%.0f|%.0f|%.0f", math.floor(pos.Y * 4), pos.X, pos.Y, pos.Z)
                        if not g.seen[key] then
                            g.seen[key] = true
                            g.positions[#g.positions + 1] = { pos = pos, key = key }
                        end
                    end
                end
                local now = tick()
                for name, cnt in pairs(cur) do
                    local kind = kindOf(name)
                    if kind and cfg.snd.categories[kind] then
                        local rec = S.snd.recent[name] or {}
                        local freshPos = {}
                        for i = 1, #grouped[name].positions do
                            local c = grouped[name].positions[i]
                            if not rec[c.key] then
                                freshPos[#freshPos + 1] = c
                            end
                        end
                        -- SourceSounds reuses emitter Parts, so the object
                        -- count often stays constant. Detect movement/new
                        -- positions instead of relying on count deltas.
                        local wanted = math.min(#freshPos, cfg.snd.maxPerNamePerTick)
                        if wanted > 0 then
                            local team = teamOfSound(name)
                            if cfg.snd.teamOnly and team and myTeam and team == myTeam then
                                for i = 1, wanted do
                                    local c = freshPos[i] or freshPos[#freshPos]
                                    if c then rec[c.key] = now end
                                end
                            else
                                local col = (team == nil and cfg.snd.cols.unk) or (team == myTeam and cfg.snd.cols.ally or cfg.snd.cols.enemy)
                                for i = 1, wanted do
                                    local c = freshPos[i] or freshPos[#freshPos]
                                    if c then
                                        rec[c.key] = now
                                        S.snd.emitCount = S.snd.emitCount + 1
                                        S.snd.markIdx = S.snd.markIdx % cfg.snd.pool + 1
                                        S.snd.marks[S.snd.markIdx] = {
                                            pos = c.pos,
                                            born = now,
                                            team = team or "unk",
                                            col = col,
                                            kind = kind,
                                            txt = kind == "step" and "step" or (kind == "impact" and ("land " .. matOf(name)) or matOf(name)),
                                            life = cfg.snd.life[kind] or 2,
                                            big = kind == "step",
                                        }
                                    end
                                end
                            end
                            for k in pairs(rec) do
                                if now - rec[k] > 4 then rec[k] = nil end
                            end
                            S.snd.recent[name] = rec
                        end
                    end
                end
                S.snd.lastCounts = cur
            end
        end
        task.wait(cfg.snd.pollRate)
    end
end)

local sndVp = Vector2.new(1920, 1080)

S.snd.conn = RunService.RenderStepped:Connect(function()
    local now = tick()
    local cam = workspace.CurrentCamera
    local camPos = cam and cam.CFrame.Position
    if cam then sndVp = cam.ViewportSize or sndVp end
    local n = math.min(cfg.snd.pool, SNDMAX)
    for i = 1, n do
        local d, t, l = S.snd.dot[i], S.snd.txt[i], S.snd.line[i]
        local m = S.snd.marks[i]
        if m and camPos then
            local age = now - m.born
            if age > m.life then
                S.snd.marks[i] = nil
                d.Visible, t.Visible, l.Visible = false, false, false
            else
                local scr, vis = WorldToScreen(m.pos)
                if vis then
                    local dist = (m.pos - camPos).Magnitude
                    if dist < cfg.snd.range then
                        local alpha = 1 - (age / m.life) * 0.9
                        d.Radius = m.big and math.clamp(240 / dist, 3.5, 7) or math.clamp(170 / dist, 2, 4.5)
                        d.Color = m.col
                        d.Transparency = 1 - alpha
                        d.Position = scr
                        d.Visible = true
                        t.Text = m.txt
                        t.Transparency = 1 - alpha
                        t.Position = Vector2.new(scr.X, scr.Y - 11)
                        t.Visible = true
                        if cfg.snd.tracers then
                            l.From = Vector2.new(sndVp.X * 0.5, sndVp.Y)
                            l.To = scr
                            l.Transparency = 1 - alpha
                            l.Visible = true
                        else
                            l.Visible = false
                        end
                    else
                        d.Visible, t.Visible, l.Visible = false, false, false
                    end
                else
                    d.Visible, t.Visible, l.Visible = false, false, false
                end
            end
        else
            d.Visible, t.Visible, l.Visible = false, false, false
        end
    end
    for i = n + 1, SNDMAX do
        S.snd.dot[i].Visible = false
        S.snd.txt[i].Visible = false
        S.snd.line[i].Visible = false
    end
end)

local function stopSounds()
    S.snd.running = false
    if S.snd.conn then pcall(function() S.snd.conn:Disconnect() end) end
    for i = 1, SNDMAX do
        S.snd.dot[i].Visible = false
        S.snd.txt[i].Visible = false
        S.snd.line[i].Visible = false
    end
    for k in pairs(S.snd.lastCounts) do S.snd.lastCounts[k] = nil end
    for k in pairs(S.snd.marks) do S.snd.marks[k] = nil end
    print("Sound ESP stopped")
end
_G.SoundESP = { Stop = stopSounds }

S.fov = Drawing.new("Circle")
S.fov.Filled, S.fov.NumSides, S.fov.Thickness = false, 64, 1
S.fov.Transparency, S.fov.Color, S.fov.Visible = 1, cfg.fovCol, false

local ids = {}
for i = 1, MAX do ids[i] = tostring(i) end

local vis, boxOn, lblOn, lnOn, lblTxt, triN = {}, {}, {}, {}, {}, {}
local gDv, gBv, gTv = {}, {}, {}
local boxSt, triSt = {}, {}

local function wipe(t)
    for k in pairs(t) do t[k] = nil end
end

local function modelFingerprint(m)
    if not m then return nil end
    local t = {}
    for _, d in ipairs(m:GetDescendants()) do
        if d.ClassName == "MeshPart" or d.ClassName == "Part" then
            local s = d.Size
            t[#t + 1] = string.format("%s:%.3f,%.3f,%.3f", d.Name, s.X, s.Y, s.Z)
        end
    end
    if #t == 0 then return nil end
    table.sort(t)
    return table.concat(t, ";")
end

local fpToWeapon, wCount = {}, 0

local function buildWeaponMap()
    local shared = RS:FindFirstChild("Shared")
    local mgr = shared and shared:FindFirstChild("Managers")
    local WM = mgr and mgr:FindFirstChild("WeaponManager")
    if not WM then return end
    local map, n = {}, 0
    for _, cat in ipairs(WM:GetChildren()) do
        if cat.ClassName == "Folder" then
            for _, wdef in ipairs(cat:GetChildren()) do
                local k = modelFingerprint(wdef:FindFirstChild("CharacterModel"))
                if k then
                    map[k] = wdef.Name
                    n = n + 1
                end
            end
        end
    end
    fpToWeapon, wCount = map, n
end
pcall(buildWeaponMap)

local function make(tbl, i, class, init)
    local d = tbl[i]
    if not d then
        d = Drawing.new(class)
        init(d)
        tbl[i] = d
    end
    return d
end

local function toggle(flags, tbl, i, on)
    if flags[i] == on then return end
    flags[i] = on
    local d = tbl[i]
    if d then d.Visible = on end
end

local function initBox(d)
    d.Filled, d.Thickness, d.Transparency, d.Visible = false, 1, 1, false
    d.Color = cfg.boxCol
end

local function initLbl(d)
    d.Size, d.Center, d.Outline, d.Font = 14, true, true, 2
    d.Color, d.Visible = cfg.lblCol, false
end

local function initLine(d)
    d.Thickness, d.Transparency, d.Visible = 1, 1, false
    d.Color = cfg.tracerCol
end

local function initGTxt(d)
    d.Size, d.Center, d.Outline, d.Font = 15, true, true, 2
    d.Color, d.Visible = cfg.sTxtCol, false
end

local function initGBox(d)
    d.Filled, d.Thickness, d.Visible = false, 1, false
    d.Color = cfg.sBoxCol
end

local function initGDot(d)
    d.Filled, d.NumSides, d.Radius, d.Thickness = true, 12, 4, 1
    d.Color, d.Visible = cfg.sDotCol, false
end

local function initFill(d)
    d.Filled, d.Thickness, d.Transparency, d.Visible = true, 1, 1, false
end

local function initHead(d)
    d.Filled, d.NumSides, d.Thickness, d.Transparency, d.Visible = false, 24, 1, 1, false
end

local function initInfo(d)
    d.Size, d.Center, d.Outline, d.Font, d.Visible = 13, true, true, 2, false
end

local function initArrow(d)
    d.Filled, d.Transparency, d.Visible = true, 1, false
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

local X = {}
S.x = X

local function xget(i)
    local x = X[i]
    if not x then
        x = { v = {} }
        X[i] = x
    end
    return x
end

local function lpool(x, name, n)
    local p = x[name]
    if not p then
        p = { n = 0, on = 0 }
        x[name] = p
    end
    while p.n < n do
        p.n = p.n + 1
        local l = Drawing.new("Line")
        l.Transparency, l.Visible = 1, false
        p[p.n] = l
    end
    return p
end

local function lend(p, used)
    for k = used + 1, p.on do p[k].Visible = false end
    p.on = used
end

local function xpool(x, name, n, want)
    if want then return lpool(x, name, n) end
    local p = x[name]
    if p and p.on > 0 then lend(p, 0) end
    return nil
end

local function seg(l, x1, y1, x2, y2, col, th, a)
    l.From, l.To = Vector2.new(x1, y1), Vector2.new(x2, y2)
    l.Color, l.Thickness, l.Transparency, l.Visible = col, th, a, true
end

local function single(x, name, class, init)
    local d = x[name]
    if not d then
        d = Drawing.new(class)
        init(d)
        x[name] = d
    end
    return d
end

local function sv(x, name, on)
    if x.v[name] == on then return end
    x.v[name] = on
    local d = x[name]
    if d then d.Visible = on end
end

local POOLS = { "skel", "corn", "b3", "out", "hp" }
local ONES = { "head", "look", "fill", "info", "arr", "arrT" }

local function hideX(i)
    local x = X[i]
    if not x then return end
    for _, name in ipairs(POOLS) do
        local p = x[name]
        if p and p.on > 0 then lend(p, 0) end
    end
    for _, name in ipairs(ONES) do sv(x, name, false) end
end

local function restyle()
    for _, pool in pairs(S.tris) do
        for _, t in pairs(pool) do
            t.Color = cfg.chamCol
            t.Transparency = cfg.opacity
        end
    end
    for _, d in pairs(S.lbl) do d.Color = cfg.lblCol end
    for _, l in pairs(S.lines) do l.Color = cfg.tracerCol end
    for _, d in pairs(S.gTxt) do d.Color = cfg.sTxtCol end
    for _, d in pairs(S.gBox) do d.Color = cfg.sBoxCol end
    for _, d in pairs(S.gDot) do d.Color = cfg.sDotCol end
    for _, d in pairs(S.snd.line) do d.Color = cfg.snd.cols.trac end
    wipe(boxSt)
    wipe(triSt)
end

local function ghostVis(i, dot, box, txt)
    toggle(gDv, S.gDot, i, dot)
    toggle(gBv, S.gBox, i, box)
    toggle(gTv, S.gTxt, i, txt)
end

local function hideGhost(i)
    if S.gTxt[i] then ghostVis(i, false, false, false) end
end

local function hideSlot(i)
    if not vis[i] then return end
    vis[i] = false
    toggle(boxOn, S.boxes, i, false)
    toggle(lblOn, S.lbl, i, false)
    toggle(lnOn, S.lines, i, false)
    hideX(i)
    local pool = S.tris[i]
    for k = 1, triN[i] or 0 do pool[k].Visible = false end
    triN[i] = 0
end

local function hideAll()
    for i = 1, MAX do
        hideSlot(i)
        hideGhost(i)
    end
end

local function pick(v) return type(v) == "table" and v[1] or v end

local function buildMenu()
    local Lib = loadstring(game:HttpGet(UI_URL))() or INSUI
    local e = cfg.e

    local win = Lib:CreateWindow({
        title = "Kontra Suite",
        subtitle = "auto",
        size = Vector2.new(640, 560),
        menuKey = "p",
        configName = "kontra",
        configFolder = "kontra",
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
    boxT:AddColorpicker("Box color", cfg.boxCol, function(c) cfg.boxCol = c end)

    local chamT = main:Toggle("Chams (filled)", cfg.chams, function(v) cfg.chams = v end)
    chamT:AddColorpicker("Chams color", cfg.chamCol, function(c)
        cfg.chamCol = c
        restyle()
    end)

    local numT = main:Toggle("Player number", cfg.espNum, function(v) cfg.espNum = v rev = rev + 1 end)
    numT:AddColorpicker("Label color", cfg.lblCol, function(c)
        cfg.lblCol = c
        restyle()
    end)
    main:Toggle("Weapon", cfg.weapon, function(v) cfg.weapon = v rev = rev + 1 end)

    local trT = main:Toggle("Tracers", cfg.tracer, function(v) cfg.tracer = v end)
    trT:AddColorpicker("Tracer color", cfg.tracerCol, function(c)
        cfg.tracerCol = c
        restyle()
    end)
    main:Dropdown("Tracer origin", {"Bottom"}, {"Bottom", "Center", "Top"}, false, function(v)
        cfg.tracerFrom = string.lower(tostring(pick(v)))
    end)

    main:Slider("Chams Opacity", cfg.opacity, 0.05, 0.05, 1.0, "", function(v)
        cfg.opacity = v
        restyle()
    end)
    main:Toggle("Team check", cfg.teamCheck, function(v) cfg.teamCheck = v end)

    local parts = tab:Section("Chams / outline parts", "Right", "box always covers the whole body")
    parts:Toggle("Head", cfg.head, function(v) cfg.head = v end)
    parts:Toggle("Torso", cfg.torso, function(v) cfg.torso = v end)
    parts:Toggle("Arms", cfg.arms, function(v) cfg.arms = v end)
    parts:Toggle("Legs", cfg.legs, function(v) cfg.legs = v end)

    local vtab = win:Tab("Visuals", "eye")

    local bx = vtab:Section("Box", "Left", "needs Box on in the ESP tab")
    bx:Dropdown("Style", {"Full"}, {"Full", "Corners", "3D"}, false, function(v)
        e.boxStyle = string.lower(tostring(pick(v)))
    end)
    bx:Slider("Thickness", e.boxThick, 1, 1, 4, "", function(v) e.boxThick = v end)
    bx:Toggle("Fill", e.fill, function(v) e.fill = v end)
    bx:Slider("Fill opacity", e.fillAlpha, 0.05, 0.05, 0.6, "", function(v) e.fillAlpha = v end)

    local sk = vtab:Section("Skeleton", "Left")
    local skT = sk:Toggle("Skeleton", e.skel, function(v) e.skel = v end)
    skT:AddColorpicker("Skeleton color", e.skelCol, function(c) e.skelCol = c end)
    sk:Slider("Thickness", e.skelThick, 0.5, 1, 4, "", function(v) e.skelThick = v end)
    sk:Toggle("Head circle", e.headDot, function(v) e.headDot = v end)

    local lk = vtab:Section("Look direction", "Left", "line out of the head")
    local lkT = lk:Toggle("Look line", e.look, function(v) e.look = v end)
    lkT:AddColorpicker("Look color", e.lookCol, function(c) e.lookCol = c end)
    lk:Slider("Length", e.lookLen, 0.5, 1, 15, "studs", function(v) e.lookLen = v end)

    local ol = vtab:Section("Outline chams", "Right", "wireframe silhouette, no fill")
    local olT = ol:Toggle("Outline", e.outline, function(v) e.outline = v end)
    olT:AddColorpicker("Outline color", e.outCol, function(c) e.outCol = c end)
    ol:Slider("Thickness", e.outThick, 0.5, 1, 4, "", function(v) e.outThick = v end)
    ol:Slider("Size", e.outScale, 0.05, 0.8, 1.6, "x", function(v) e.outScale = v end)
    ol:Toggle("Glow (second outline)", e.outGlow, function(v) e.outGlow = v end)

    local xtab = win:Tab("Extras", "eye")

    local lb = xtab:Section("Info", "Left")
    lb:Toggle("Distance", e.dist, function(v) e.dist = v end)
    lb:Toggle("Movement flags", e.flags, function(v) e.flags = v end)
    lb:Toggle("Scale text with distance", e.scaleText, function(v) e.scaleText = v end)
    lb:Toggle("Fade with distance", e.fade, function(v) e.fade = v end)
    lb:Slider("Max distance", e.maxDist, 50, 100, 5000, "studs", function(v) e.maxDist = v end)
    lb:Toggle("Ally health bar", e.allyHp, function(v) e.allyHp = v end)
    lb:Toggle("Player count", e.hud, function(v) e.hud = v end)

    local cl = xtab:Section("Colors", "Left")
    cl:Dropdown("Color mode", {"Static"}, {"Static", "Distance", "Rainbow"}, false, function(v)
        e.colorMode = string.lower(tostring(pick(v)))
    end)
    local fcT = cl:Toggle("Highlight closest to crosshair", e.closest, function(v) e.closest = v end)
    fcT:AddColorpicker("Highlight color", e.focusCol, function(c) e.focusCol = c end)

    local ar = xtab:Section("Off-screen arrows", "Right")
    local arT = ar:Toggle("Arrows", e.arrows, function(v) e.arrows = v end)
    arT:AddColorpicker("Arrow color", e.arrowCol, function(c) e.arrowCol = c end)
    ar:Slider("Size", e.arrowSize, 1, 6, 30, "px", function(v) e.arrowSize = v end)
    ar:Slider("Radius", e.arrowRad, 1, 30, 95, "%", function(v) e.arrowRad = v end)

    local rd = xtab:Section("Radar", "Right")
    rd:Toggle("Radar", e.radar, function(v) e.radar = v end)
    rd:Slider("Size", e.radarSize, 5, 80, 300, "px", function(v) e.radarSize = v end)
    rd:Slider("Range", e.radarRange, 5, 30, 600, "studs", function(v) e.radarRange = v end)
    rd:Slider("Position X", e.radarX, 5, 0, 1800, "px", function(v) e.radarX = v end)
    rd:Slider("Position Y", e.radarY, 5, 0, 1000, "px", function(v) e.radarY = v end)
    rd:Colorpicker("Enemy dot", e.radarEnemy, function(c) e.radarEnemy = c end)
    rd:Colorpicker("Ally dot", e.radarAlly, function(c) e.radarAlly = c end)

    local seenTab = win:Tab("Last seen", "eye")

    local ls = seenTab:Section("Last seen", "Left", "where they were before the server hid them")
    ls:Toggle("Enabled", cfg.seen, function(v) cfg.seen = v end)
    ls:Slider("Show for", cfg.seenMax, 1, 1, 30, "s", function(v) cfg.seenMax = v end)

    local sh = seenTab:Section("Show", "Right")
    local dotT = sh:Toggle("Dot", cfg.sDot, function(v) cfg.sDot = v end)
    dotT:AddColorpicker("Dot color", cfg.sDotCol, function(c)
        cfg.sDotCol = c
        restyle()
    end)
    local sBoxT = sh:Toggle("Box", cfg.sBox, function(v) cfg.sBox = v end)
    sBoxT:AddColorpicker("Box color", cfg.sBoxCol, function(c)
        cfg.sBoxCol = c
        restyle()
    end)
    sh:Toggle("Player number", cfg.sNum, function(v) cfg.sNum = v rev = rev + 1 end)
    sh:Toggle("Weapon", cfg.sWeapon, function(v) cfg.sWeapon = v rev = rev + 1 end)
    sh:Toggle("Time", cfg.sTime, function(v) cfg.sTime = v rev = rev + 1 end)
    sh:Colorpicker("Text color", cfg.sTxtCol, function(c)
        cfg.sTxtCol = c
        restyle()
    end)

    local sndTab = win:Tab("Sounds", "sound")

    local sndMain = sndTab:Section("Sound ESP", "Left", "positional emitters in Debris.Sounds")
    local sndT = sndMain:Toggle("Enabled", cfg.snd.on, function(v)
        cfg.snd.on = v
        Lib:Notify("Sound ESP", v and "enabled" or "disabled", 2, v and "success" or "warning")
    end)
    sndT:AddKeybind("k", "Toggle")
    sndMain:Toggle("Hide allied events", cfg.snd.teamOnly, function(v) cfg.snd.teamOnly = v end)
    sndMain:Toggle("Tracers", cfg.snd.tracers, function(v) cfg.snd.tracers = v end)
    sndMain:Slider("Range", cfg.snd.range, 5, 50, 1000, "studs", function(v) cfg.snd.range = v end)
    sndMain:Slider("Max markers", cfg.snd.pool, 8, 16, SNDMAX, "", function(v) cfg.snd.pool = math.min(v, SNDMAX) end)
    sndMain:Slider("Scan rate", cfg.snd.pollRate, 0.01, 0.01, 0.2, "s", function(v) cfg.snd.pollRate = v end)
    sndMain:Slider("Max per name/tick", cfg.snd.maxPerNamePerTick, 1, 1, 32, "", function(v) cfg.snd.maxPerNamePerTick = v end)

    local sndCat = sndTab:Section("Categories", "Right", "which events get markers")
    sndCat:Toggle("Footsteps", cfg.snd.categories.step, function(v) cfg.snd.categories.step = v end)
    sndCat:Toggle("Gunfire", cfg.snd.categories.fire, function(v) cfg.snd.categories.fire = v end)
    sndCat:Toggle("Reloads", cfg.snd.categories.relo, function(v) cfg.snd.categories.relo = v end)
    sndCat:Toggle("Impacts", cfg.snd.categories.impact, function(v) cfg.snd.categories.impact = v end)
    sndCat:Toggle("Misc", cfg.snd.categories.misc, function(v) cfg.snd.categories.misc = v end)

    local sndLife = sndTab:Section("Marker life", "Left", "seconds until fade")
    sndLife:Slider("Footstep", cfg.snd.life.step, 0.5, 0.5, 10, "s", function(v) cfg.snd.life.step = v end)
    sndLife:Slider("Gunfire", cfg.snd.life.fire, 0.5, 0.5, 10, "s", function(v) cfg.snd.life.fire = v end)
    sndLife:Slider("Impact", cfg.snd.life.impact, 0.5, 0.5, 10, "s", function(v) cfg.snd.life.impact = v end)
    sndLife:Slider("Misc", cfg.snd.life.misc, 0.5, 0.5, 10, "s", function(v) cfg.snd.life.misc = v end)

    local sndColT = sndTab:Section("Colors", "Right", "applied live to the pool")
    sndColT:Colorpicker("Enemy", cfg.snd.cols.enemy, function(c) cfg.snd.cols.enemy = c end)
    sndColT:Colorpicker("Ally", cfg.snd.cols.ally, function(c) cfg.snd.cols.ally = c end)
    sndColT:Colorpicker("Unknown", cfg.snd.cols.unk, function(c) cfg.snd.cols.unk = c end)
    sndColT:Colorpicker("Tracer", cfg.snd.cols.trac, function(c) cfg.snd.cols.trac = c end)

    local aimTab = win:Tab("Aim", "crosshair")

    local aim = aimTab:Section("Aim", "Left", "hold the key to aim")
    local holdT = aim:Toggle("Aim", cfg.aimHeld, function(v) cfg.aimHeld = v end)
    holdT:AddKeybind("e", "Hold")

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

    local trigTab = win:Tab("Trigger", "crosshair")

    local tbs = trigTab:Section("Triggerbot", "Left", "hold the key to fire")
    local tbT = tbs:Toggle("Triggerbot", cfg.tbHeld, function(v) cfg.tbHeld = v end)
    tbT:AddKeybind("t", "Hold")
    tbs:Dropdown("Fire mode", {"Tap"}, {"Tap", "Auto"}, false, function(v)
        cfg.tbMode = string.lower(tostring(pick(v)))
    end)
    tbs:Slider("Reaction", cfg.tbReact, 5, 0, 300, "ms", function(v) cfg.tbReact = v end)
    tbs:Slider("Press time", cfg.tbHold, 5, 20, 150, "ms", function(v) cfg.tbHold = v end)
    tbs:Slider("Release gap", cfg.tbGap, 5, 20, 200, "ms", function(v) cfg.tbGap = v end)
    tbs:Slider("Jitter", cfg.tbJit, 1, 0, 60, "%", function(v) cfg.tbJit = v end)
    tbs:Slider("Padding", cfg.tbPad, 0.05, 0, 1, "studs", function(v) cfg.tbPad = v end)
    tbs:Toggle("Show hitboxes", cfg.tbVis, function(v) cfg.tbVis = v end)
    tbs:Toggle("Require game focus", cfg.tbFocus, function(v) cfg.tbFocus = v end)
    tbs:Toggle("Debug (console)", cfg.tbDebug, function(v) cfg.tbDebug = v end)

    local fireOn = trigTab:Section("Fire on", "Right", "which body parts count")
    fireOn:Toggle("Head", cfg.tHead, function(v) cfg.tHead = v end)
    fireOn:Toggle("Torso", cfg.tTorso, function(v) cfg.tTorso = v end)
    fireOn:Toggle("Arms", cfg.tArms, function(v) cfg.tArms = v end)
    fireOn:Toggle("Legs", cfg.tLegs, function(v) cfg.tLegs = v end)

    local wallTab = win:Tab("Wall", "eye")

    local wc = wallTab:Section("Wall check", "Left", "is anything solid between you and them")
    wc:Dropdown("Method", {"Auto"}, {"Auto", "Raycast", "Geometry"}, false, function(v)
        cfg.wallMethod = string.lower(tostring(pick(v)))
        S.wallAuto = nil
    end)
    wc:Slider("Min wall size", cfg.wallSize, 0.5, 0, 20, "studs", function(v)
        cfg.wallSize = v
        S.geoAt = -1e9
    end)
    wc:Slider("Check rate", cfg.wallRate, 10, 0, 500, "ms", function(v) cfg.wallRate = v end)
    wc:Toggle("Debug (console)", cfg.wallDebug, function(v) cfg.wallDebug = v end)

    local use = wallTab:Section("Use it on", "Right")
    use:Toggle("Triggerbot", cfg.tbWall, function(v) cfg.tbWall = v end)
    use:Toggle("Aim", cfg.aimWall, function(v) cfg.aimWall = v end)
    use:Toggle("ESP colors", cfg.espVis, function(v)
        cfg.espVis = v
        wipe(triSt)
    end)
    use:Colorpicker("Visible color", cfg.visCol, function(c)
        cfg.visCol = c
        wipe(triSt)
    end)
    use:Colorpicker("Hidden color", cfg.hidCol, function(c)
        cfg.hidCol = c
        wipe(triSt)
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

    Lib:Notify("Kontra Suite", "Loaded. Press P to open the menu", 4, "success")
end

local menuOk, menuErr = pcall(buildMenu)
if not menuOk then print("[Kontra] menu failed (ESP still runs): " .. tostring(menuErr)) end
if not mousemoverel then print("[Kontra] mousemoverel not found, aim cannot move the mouse") end
if not (mouse1press and mouse1release) then print("[Kontra] mouse1press/mouse1release not found, triggerbot cannot fire") end

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
local TKEY = { head = "tHead", torso = "tTorso", arms = "tArms", legs = "tLegs" }
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
local BONES = {
    R15 = {
        { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
    },
    R6 = {
        { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
        { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
    },
}

local SX3 = { 1, 1, 1, 1, -1, -1, -1, -1 }
local SY3 = { 1, 1, -1, -1, 1, 1, -1, -1 }
local SZ3 = { 1, -1, 1, -1, 1, -1, 1, -1 }
local E3 = { { 1, 2 }, { 3, 4 }, { 5, 6 }, { 7, 8 }, { 1, 3 }, { 2, 4 }, { 5, 7 }, { 6, 8 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }
local PX3, PY3 = {}, {}

local function nearSelf(c)
    local dx, dy, dz = c.px - cX, c.py - cY, c.pz - cZ
    return dx * dx + dy * dy + dz * dz < 25
end

local function skip(c)
    if nearSelf(c) then return true end
    return cfg.teamCheck and c.ally
end

local function buildCache(char)
    local isR15 = char:FindFirstChild("UpperTorso") ~= nil
    local def = isR15 and DEFS.R15 or DEFS.R6
    local c = {
        char = char, groups = {}, all = {}, kinds = {}, bones = {}, complete = true, wait = 0, age = 0,
        ally = char:FindFirstChild("NameTag") ~= nil,
        root = char:FindFirstChild("HumanoidRootPart"),
        hidden = false, px = 0, py = 0, pz = 0,
        cAt = {}, cx = {}, cy = {}, cz = {},
        wt = {}, wv = {},
    }
    for _, key in ipairs(KEYS) do
        local gl = {}
        for _, names in ipairs(def[key]) do
            local list = {}
            for _, name in ipairs(names) do
                local p = char:FindFirstChild(name)
                if p and p:IsA("BasePart") then
                    list[#list + 1] = p
                    c.all[#c.all + 1] = p
                    c.kinds[#c.all] = key
                else
                    c.complete = false
                end
            end
            gl[#gl + 1] = list
        end
        c.groups[key] = gl
    end
    for _, pair in ipairs(isR15 and BONES.R15 or BONES.R6) do
        local a, b = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            c.bones[#c.bones + 1] = { a, b }
        end
    end
    return c
end

local function refreshInfo(c)
    pcall(function()
        local wm
        for _, ch in ipairs(c.char:GetChildren()) do
            if ch.ClassName == "Model" then
                wm = ch
                break
            end
        end
        local fp = modelFingerprint(wm)
        c.weapon = fp and fpToWeapon[fp] or nil
    end)
end

local function labelText(c)
    if c.lRev ~= rev or c.lNum ~= c.num or c.lWpn ~= c.weapon then
        c.lRev, c.lNum, c.lWpn = rev, c.num, c.weapon
        local parts = {}
        if cfg.espNum and c.num then parts[#parts + 1] = "Player " .. c.num end
        if cfg.weapon and c.weapon then parts[#parts + 1] = "[" .. c.weapon .. "]" end
        c.lbl = table.concat(parts, " ")
    end
    return c.lbl
end

local function trackVoid(i, c)
    local pos = c.all[1].Position
    local x, y, z = pos.X, pos.Y, pos.Z
    c.px, c.py, c.pz = x, y, z

    if not c.hidden then
        local gone = y < VOID_Y
        if c.lx and not gone then
            local dx, dy, dz = x - c.lx, y - c.ly, z - c.lz
            gone = dx * dx + dy * dy + dz * dz > JUMP * JUMP
        end
        if gone then
            c.hidden = true
            c.hx, c.hy, c.hz = x, y, z
            if DEBUG then print("[CharESP] slot " .. i .. " hidden at y=" .. string.format("%.0f", y)) end
        else
            c.lx, c.ly, c.lz = x, y, z
        end
    else
        local dx, dy, dz = x - c.hx, y - c.hy, z - c.hz
        local moved = dx * dx + dy * dy + dz * dz > JUMP * JUMP
        local up = y >= VOID_Y and c.hy < VOID_Y
        if moved or up then
            c.hidden = false
            c.lx, c.ly, c.lz = x, y, z
            if DEBUG then print("[CharESP] slot " .. i .. " visible again") end
        end
    end
end

local function motion(c, now)
    local x, y, z = c.px, c.py, c.pz
    if not c.mt then
        c.mt, c.mx, c.my, c.mz, c.spd, c.vy = now, x, y, z, 0, 0
        return
    end
    local dt = now - c.mt
    if dt < 0.12 then return end
    local dx, dy, dz = x - c.mx, y - c.my, z - c.mz
    if dt > 0.5 or dx * dx + dy * dy + dz * dz > 400 then
        c.spd, c.vy = 0, 0
    else
        c.spd = math.sqrt(dx * dx + dz * dz) / dt
        c.vy = dy / dt
    end
    c.mt, c.mx, c.my, c.mz = now, x, y, z
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
        if c.age % 10 == 0 then c.ally = char:FindFirstChild("NameTag") ~= nil end
    end
    if #c.all == 0 then return nil end
    trackVoid(i, c)
    if cfg.e.flags and not c.hidden then motion(c, tick()) end
    return c
end

local function groupCenter(c, key)
    if c.cAt[key] == frame then return c.cx[key], c.cy[key], c.cz[key] end
    c.cAt[key] = frame

    local sx, sy, sz, n = 0, 0, 0, 0
    for _, list in ipairs(c.groups[key]) do
        for _, p in ipairs(list) do
            local pos = p.Position
            sx, sy, sz, n = sx + pos.X, sy + pos.Y, sz + pos.Z, n + 1
        end
    end
    if n == 0 then
        c.cx[key], c.cy[key], c.cz[key] = nil, nil, nil
        return nil
    end
    local x, y, z = sx / n, sy / n, sz / n
    c.cx[key], c.cy[key], c.cz[key] = x, y, z
    return x, y, z
end

local function bodyCenter(c)
    local x, y, z = groupCenter(c, "torso")
    if x then return x, y, z end
    return groupCenter(c, "head")
end

local function bounds(c)
    if c.bAt == frame then return c.bx0, c.by0, c.bx1, c.by1 end
    c.bAt = frame
    local n = 0
    for _, p in ipairs(c.all) do n = projectPart(p, 1, n) end
    if n == 0 then
        c.bx0 = nil
        return nil
    end
    local minX, minY, maxX, maxY = BX[1], BY[1], BX[1], BY[1]
    for k = 2, n do
        local x, y = BX[k], BY[k]
        if x < minX then minX = x elseif x > maxX then maxX = x end
        if y < minY then minY = y elseif y > maxY then maxY = y end
    end
    c.bx0, c.by0, c.bx1, c.by1 = minX, minY, maxX, maxY
    return minX, minY, maxX, maxY
end

local function slab(d, f, h, lo, hi)
    if math.abs(f) < 1e-6 then
        if d - h > 0 or d + h < 0 then return nil end
        return lo, hi
    end
    local t1, t2 = (d - h) / f, (d + h) / f
    if t1 > t2 then t1, t2 = t2, t1 end
    if t1 > lo then lo = t1 end
    if t2 < hi then hi = t2 end
    if lo > hi then return nil end
    return lo, hi
end

local SOLID = { Part = true, MeshPart = true, UnionOperation = true }
local GEO = { list = {}, n = 0, at = -1e9, busy = false, want = nil }
S.geoAt = nil

local function geoAdd(d)
    if not SOLID[d.ClassName] then return end
    local s = d.Size
    local sx, sy, sz = s.X, s.Y, s.Z
    if math.max(sx, sy, sz) < cfg.wallSize or d.CanCollide == false or d.Transparency > 0.9 then return end
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = d.CFrame:GetComponents()
    local hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    GEO.wn = GEO.wn + 1
    GEO.work[GEO.wn] = {
        x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22,
        hx, hy, hz, math.sqrt(hx * hx + hy * hy + hz * hz),
    }
end

local function geoPump(folder, now)
    if S.geoAt then
        GEO.at, S.geoAt = S.geoAt, nil
    end
    if not GEO.busy then
        if now - GEO.at < 20 then return end
        local roots = {}
        local cam = workspace.CurrentCamera
        for _, ch in ipairs(workspace:GetChildren()) do
            if ch ~= folder and ch ~= cam and ch.ClassName ~= "Terrain" then
                roots[#roots + 1] = ch
            end
        end
        GEO.roots, GEO.ri, GEO.work, GEO.wn = roots, 0, {}, 0
        GEO.cur, GEO.ci, GEO.busy = nil, 0, true
    end

    local budget = 300
    while budget > 0 do
        if not GEO.cur then
            GEO.ri = GEO.ri + 1
            local root = GEO.roots[GEO.ri]
            if not root then
                GEO.list, GEO.n, GEO.at, GEO.busy, GEO.work = GEO.work, GEO.wn, now, false, nil
                if cfg.wallDebug then print("[CharESP] wall geometry: " .. GEO.n .. " solid parts") end
                return
            end
            pcall(geoAdd, root)
            local ok, d = pcall(function() return root:GetDescendants() end)
            GEO.cur, GEO.ci = ok and d or {}, 0
            budget = budget - 1
        else
            GEO.ci = GEO.ci + 1
            local d = GEO.cur[GEO.ci]
            if d then
                pcall(geoAdd, d)
                budget = budget - 1
            else
                GEO.cur = nil
            end
        end
    end
end

local function geoBlocked(tx, ty, tz)
    GEO.want = tick()
    local list = GEO.list
    local ax, ay, az = cX, cY, cZ
    local dx, dy, dz = tx - ax, ty - ay, tz - az
    local len2 = dx * dx + dy * dy + dz * dz
    if len2 < 0.01 then return false end

    for k = 1, GEO.n do
        local b = list[k]
        local px, py, pz = b[1] - ax, b[2] - ay, b[3] - az
        local t = (px * dx + py * dy + pz * dz) / len2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        local qx, qy, qz = px - dx * t, py - dy * t, pz - dz * t
        local r = b[16]

        if qx * qx + qy * qy + qz * qz <= r * r then
            local lax = -(b[4] * px + b[7] * py + b[10] * pz)
            local lay = -(b[5] * px + b[8] * py + b[11] * pz)
            local laz = -(b[6] * px + b[9] * py + b[12] * pz)
            local hx, hy, hz = b[13], b[14], b[15]

            if not (math.abs(lax) < hx and math.abs(lay) < hy and math.abs(laz) < hz) then
                local ldx = b[4] * dx + b[7] * dy + b[10] * dz
                local ldy = b[5] * dx + b[8] * dy + b[11] * dz
                local ldz = b[6] * dx + b[9] * dy + b[12] * dz

                local lo, hi = slab(-lax, ldx, hx, 0, 0.97)
                if lo then lo, hi = slab(-lay, ldy, hy, lo, hi) end
                if lo then lo = slab(-laz, ldz, hz, lo, hi) end
                if lo then return true end
            end
        end
    end
    return false
end

local function probeRay()
    local o = Vector3.new(cX, cY, cZ)
    local dirs = {
        Vector3.new(0, -3000, 0), Vector3.new(0, 3000, 0),
        Vector3.new(3000, 0, 0), Vector3.new(-3000, 0, 0),
        Vector3.new(0, 0, 3000), Vector3.new(0, 0, -3000),
    }
    for _, d in ipairs(dirs) do
        local ok, res = pcall(function() return workspace:Raycast(o, d) end)
        if ok and res and res.Instance then return true end
    end
    return false
end

local function wallMethod()
    local m = cfg.wallMethod
    if m == "raycast" then return "ray" end
    if m == "geometry" then return "geo" end
    if not S.wallAuto then
        S.wallAuto = probeRay() and "ray" or "geo"
        print("[CharESP] wall check method: " .. (S.wallAuto == "ray" and "raycast" or "geometry"))
    end
    return S.wallAuto
end

local function passable(inst, folder, me, cam)
    if me and inst:IsDescendantOf(me) then return true end
    if inst:IsDescendantOf(cam) or inst:IsDescendantOf(folder) then return true end
    if inst.CanCollide == false or (inst.Transparency or 0) > 0.9 then return true end
    local s = inst.Size
    return s ~= nil and math.max(s.X, s.Y, s.Z) < cfg.wallSize
end

local function rayBlocker(tx, ty, tz, char, folder)
    local cam = workspace.CurrentCamera
    local lp = Players.LocalPlayer
    local me = lp and lp.Character
    local from = Vector3.new(cX, cY, cZ)
    local to = Vector3.new(tx, ty, tz)

    for _ = 1, 8 do
        local dir = to - from
        if dir.Magnitude < 0.05 then return nil end
        local ok, res = pcall(function() return workspace:Raycast(from, dir) end)
        local inst = ok and res and res.Instance
        if not inst or inst:IsDescendantOf(char) then return nil end
        if not passable(inst, folder, me, cam) then return inst end
        from = res.Position + dir.Unit * 0.15
    end
    return nil
end

local function blocked(x, y, z, char, folder)
    if wallMethod() == "ray" then
        local inst = rayBlocker(x, y, z, char, folder)
        return inst ~= nil, inst
    end
    return geoBlocked(x, y, z), nil
end

local function exposed(c, key, x, y, z, folder, now)
    local at = c.wt[key]
    if at and now - at < cfg.wallRate / 1000 then return c.wv[key] end
    c.wt[key] = now
    local ok, isWall = pcall(blocked, x, y, z, c.char, folder)
    c.wv[key] = not (ok and isWall)
    return c.wv[key]
end

local function stateOf(c)
    if not cfg.espVis or c.shown == nil then return "b" end
    return c.shown and "v" or "h"
end

local function colorFor(st, base)
    if st == "v" then return cfg.visCol end
    if st == "h" then return cfg.hidCol end
    return base
end

local function hsv(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    i = i % 6
    local r, g, b
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return Color3.new(r, g, b)
end

local function elemColor(c, base, st, dist)
    local e = cfg.e
    if e.closest and c.focus then return e.focusCol end
    if st ~= "b" then return colorFor(st, base) end
    local m = e.colorMode
    if m == "distance" then
        local t = dist / e.maxDist
        if t > 1 then t = 1 end
        return Color3.new(1 - t * 0.7, 0.25 + t * 0.75, 0.3)
    elseif m == "rainbow" then
        return hsv((tick() * 0.3 + (c.num or 0) * 0.08) % 1, 0.85, 1)
    end
    return base
end

local function record(i, c)
    local x, y, z = bodyCenter(c)
    if not x then return end
    local r = S.seen[i]
    if not r then r = {} S.seen[i] = r end
    r.t, r.x, r.y, r.z = tick(), x, y, z
    r.weapon, r.ally, r.num = c.weapon, c.ally, c.num or i
end

local function ghostParts(i)
    return make(S.gTxt, i, "Text", initGTxt), make(S.gBox, i, "Square", initGBox), make(S.gDot, i, "Circle", initGDot)
end

local function showGhost(i)
    local r = S.seen[i]
    if not cfg.seen or not r or (cfg.teamCheck and r.ally) then return hideGhost(i) end

    local age = tick() - r.t
    if age > cfg.seenMax then return hideGhost(i) end

    local tx, ty = projectPoint(r.x, r.y + UP, r.z)
    local bx, by = projectPoint(r.x, r.y - DOWN, r.z)
    if not tx or not bx then return hideGhost(i) end

    local txt, box, dot = ghostParts(i)

    local tenth = math.floor(age * 10)
    if r.lt ~= tenth or r.lr ~= rev or r.la ~= r.t then
        r.lt, r.lr, r.la = tenth, rev, r.t

        local parts = {}
        if cfg.sNum then parts[#parts + 1] = "Player " .. r.num end
        if cfg.sWeapon and r.weapon then parts[#parts + 1] = "[" .. r.weapon .. "]" end
        if cfg.sTime then parts[#parts + 1] = string.format("%.1fs", age) end
        r.lbl = table.concat(parts, "  ")

        local fade = 1 - 0.6 * (age / cfg.seenMax)
        txt.Text = r.lbl
        txt.Transparency, box.Transparency, dot.Transparency = fade, fade, fade
    end

    local top = ty < by and ty or by
    local showDot, showBox, showTxt = cfg.sDot, cfg.sBox, r.lbl ~= ""

    if showBox then
        local h = math.abs(by - ty)
        local w = h * 0.55
        box.Position = Vector2.new(tx - w * 0.5, top)
        box.Size = Vector2.new(w, h)
    end
    if showDot then
        local mx, my = projectPoint(r.x, r.y, r.z)
        if mx then
            dot.Position = Vector2.new(mx, my)
        else
            showDot = false
        end
    end
    if showTxt then
        txt.Position = Vector2.new(tx, top - 18)
    end

    ghostVis(i, showDot, showBox, showTxt)
end

local function drawChams(i, c, st)
    local prev = triN[i] or 0
    local ti = 0

    if cfg.chams then
        for _, key in ipairs(KEYS) do
            if cfg[key] then
                for _, list in ipairs(c.groups[key]) do
                    local n = 0
                    for _, p in ipairs(list) do n = projectPart(p, SCALE, n) end
                    local hn = n >= 3 and buildHull(n) or 0
                    if hn >= 3 then
                        local cx, cy = 0, 0
                        for k = 1, hn do cx = cx + H[k][1] cy = cy + H[k][2] end
                        local center = Vector2.new(cx / hn, cy / hn)
                        for k = 1, hn < TPG and hn or TPG do
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

    local pool = S.tris[i]
    for j = ti + 1, prev do pool[j].Visible = false end
    triN[i] = ti

    if ti > prev then triSt[i] = nil end
    if ti > 0 and triSt[i] ~= st then
        local col = colorFor(st, cfg.chamCol)
        for k = 1, ti do pool[k].Color = col end
        triSt[i] = st
    end
    return ti > 0
end

local function draw3d(c, p, col, a)
    local cx, cy, cz = bodyCenter(c)
    if not cx then return 0 end

    local rx, rz, fx, fz = 1, 0, 0, 1
    if c.root then
        local _, _, _, r00, _, r02, _, _, _, r20, _, r22 = c.root.CFrame:GetComponents()
        rx, rz, fx, fz = r00, r20, r02, r22
        local rl = math.sqrt(rx * rx + rz * rz)
        if rl > 1e-3 then rx, rz = rx / rl, rz / rl end
        local fl = math.sqrt(fx * fx + fz * fz)
        if fl > 1e-3 then fx, fz = fx / fl, fz / fl end
    end

    for k = 1, 8 do
        local sx, sy, sz = SX3[k], SY3[k], SZ3[k]
        PX3[k], PY3[k] = projectPoint(
            cx + (rx * sx + fx * sz) * B3W,
            cy + sy * B3H,
            cz + (rz * sx + fz * sz) * B3W
        )
    end

    local used = 0
    for k = 1, 12 do
        local e = E3[k]
        local ax, ay, bx, by = PX3[e[1]], PY3[e[1]], PX3[e[2]], PY3[e[2]]
        if ax and bx then
            used = used + 1
            seg(p[used], ax, ay, bx, by, col, cfg.e.boxThick, a)
        end
    end
    return used
end

local function drawBoxes(i, c, x, st, dist, a, onS, x0, y0, x1, y1)
    local e = cfg.e
    local style = e.boxStyle
    local show = cfg.box and onS
    local col = show and elemColor(c, cfg.boxCol, st, dist)
    local th = e.boxThick
    local drawn = false

    if show and style == "full" then
        local b = make(S.boxes, i, "Square", initBox)
        b.Position, b.Size = Vector2.new(x0, y0), Vector2.new(x1 - x0, y1 - y0)
        b.Color, b.Thickness, b.Transparency = col, th, a
        toggle(boxOn, S.boxes, i, true)
        drawn = true
    else
        toggle(boxOn, S.boxes, i, false)
    end

    local cp = xpool(x, "corn", 8, show and style == "corners")
    if cp then
        local cw, ch = (x1 - x0) * 0.25, (y1 - y0) * 0.18
        seg(cp[1], x0, y0, x0 + cw, y0, col, th, a)
        seg(cp[2], x0, y0, x0, y0 + ch, col, th, a)
        seg(cp[3], x1, y0, x1 - cw, y0, col, th, a)
        seg(cp[4], x1, y0, x1, y0 + ch, col, th, a)
        seg(cp[5], x0, y1, x0 + cw, y1, col, th, a)
        seg(cp[6], x0, y1, x0, y1 - ch, col, th, a)
        seg(cp[7], x1, y1, x1 - cw, y1, col, th, a)
        seg(cp[8], x1, y1, x1, y1 - ch, col, th, a)
        cp.on = 8
        drawn = true
    end

    local bp = xpool(x, "b3", 12, cfg.box and style == "3d")
    if bp then
        local u = draw3d(c, bp, elemColor(c, cfg.boxCol, st, dist), a)
        lend(bp, u)
        if u > 0 then drawn = true end
    end

    if show and e.fill and (style == "full" or style == "corners") then
        local f = single(x, "fill", "Square", initFill)
        f.Position, f.Size = Vector2.new(x0, y0), Vector2.new(x1 - x0, y1 - y0)
        f.Color, f.Transparency = col, e.fillAlpha * a
        sv(x, "fill", true)
        drawn = true
    else
        sv(x, "fill", false)
    end
    return drawn
end

local function drawSkel(c, p, col, a)
    local used = 0
    local th = cfg.e.skelThick
    for k = 1, #c.bones do
        local pr = c.bones[k]
        local pa, pb = pr[1].Position, pr[2].Position
        local ax, ay = projectPoint(pa.X, pa.Y, pa.Z)
        local bx, by = projectPoint(pb.X, pb.Y, pb.Z)
        if ax and bx then
            used = used + 1
            seg(p[used], ax, ay, bx, by, col, th, a)
        end
    end
    return used
end

local function drawHeadDot(x, c, col, a)
    local hl = c.groups.head[1]
    local hp = hl and hl[1]
    if hp then
        local pos = hp.Position
        local sx, sy = projectPoint(pos.X, pos.Y, pos.Z)
        if sx then
            local d = -(c02 * (pos.X - cX) + c12 * (pos.Y - cY) + c22 * (pos.Z - cZ))
            local ci = single(x, "head", "Circle", initHead)
            ci.Position = Vector2.new(sx, sy)
            ci.Radius = math.max(2, hp.Size.Y * 0.55 * fL / d)
            ci.Color, ci.Transparency, ci.Thickness = col, a, cfg.e.skelThick
            sv(x, "head", true)
            return true
        end
    end
    sv(x, "head", false)
    return false
end

local function hullLines(p, used, c, scale, col, th, a)
    for _, key in ipairs(KEYS) do
        if cfg[key] then
            for _, list in ipairs(c.groups[key]) do
                local n = 0
                for _, part in ipairs(list) do n = projectPart(part, scale, n) end
                local hn = n >= 3 and buildHull(n) or 0
                if hn >= 3 then
                    for k = 1, hn do
                        if used >= p.n then return used end
                        local nx = k % hn + 1
                        used = used + 1
                        seg(p[used], H[k][1], H[k][2], H[nx][1], H[nx][2], col, th, a)
                    end
                end
            end
        end
    end
    return used
end

local function drawLook(x, c, col, a)
    local hl = c.groups.head[1]
    local hp = hl and hl[1]
    if hp then
        local hx, hy, hz, _, _, a02, _, _, a12, _, _, a22 = hp.CFrame:GetComponents()
        local len = cfg.e.lookLen
        local sx, sy = projectPoint(hx, hy, hz)
        local ex, ey = projectPoint(hx - a02 * len, hy - a12 * len, hz - a22 * len)
        if sx and ex then
            local l = single(x, "look", "Line", initLine)
            seg(l, sx, sy, ex, ey, col, cfg.e.skelThick, a)
            sv(x, "look", true)
            return true
        end
    end
    sv(x, "look", false)
    return false
end

local function bodyHeight(c)
    local hl = c.groups.head[1]
    local hp = hl and hl[1]
    if not hp then return nil end
    local minY
    for _, list in ipairs(c.groups.legs) do
        for _, p in ipairs(list) do
            local y = p.Position.Y
            if not minY or y < minY then minY = y end
        end
    end
    if not minY then return nil end
    return hp.Position.Y - minY
end

local function flagText(c)
    local spd, vy = c.spd or 0, c.vy or 0
    local s
    if vy > 6 or vy < -14 then s = "AIR"
    elseif spd < 0.7 then s = "STILL"
    elseif spd <= WALK_MAX then s = "WALK"
    else s = "RUN" end
    local h = bodyHeight(c)
    if h and h < DUCK_H then s = s .. " DUCK" end
    return s
end

local WHITE = Color3.fromRGB(235, 235, 235)

local function drawInfo(x, c, dist, x0, x1, y1, a)
    local e = cfg.e
    local s
    if e.dist then s = math.floor(dist) .. " studs" end
    if e.flags then
        local f = flagText(c)
        s = s and (s .. "  " .. f) or f
    end
    if not s then
        sv(x, "info", false)
        return false
    end
    local t = single(x, "info", "Text", initInfo)
    if x.itxt ~= s then
        x.itxt = s
        t.Text = s
    end
    t.Size = e.scaleText and math.max(10, math.min(14, 15 - dist / 200)) or 13
    t.Color, t.Transparency = WHITE, a
    t.Position = Vector2.new((x0 + x1) * 0.5, y1 + 3)
    sv(x, "info", true)
    return true
end

local function allyHealth(c)
    if c.hpAt and frame - c.hpAt < 10 then return c.hp end
    c.hpAt = frame
    local ok, v = pcall(function()
        local nt = c.char:FindFirstChild("NameTag")
        local cg = nt and nt:FindFirstChild("CanvasGroup")
        local hl = cg and cg:FindFirstChild("Health")
        local t = hl and hl.Text
        return t and tonumber(string.match(t, "%d+"))
    end)
    c.hp = ok and v or nil
    return c.hp
end

local function drawArrow(x, c, col, a, dist)
    local bx, by, bz = bodyCenter(c)
    if not bx then return false end

    local ex, ey, ez = bx - cX, by - cY, bz - cZ
    local ax = c00 * ex + c10 * ey + c20 * ez
    local ay = c01 * ex + c11 * ey + c21 * ez
    local len = math.sqrt(ax * ax + ay * ay)
    if len < 0.001 then ax, ay, len = 0, 1, 1 end

    local ux, uy = ax / len, -ay / len
    local rad = math.min(hW, hH) * cfg.e.arrowRad / 100
    local px, py = hW + ux * rad, hH + uy * rad
    local sz = cfg.e.arrowSize

    local tri = single(x, "arr", "Triangle", initArrow)
    tri.PointA = Vector2.new(px, py)
    tri.PointB = Vector2.new(px - ux * sz - uy * sz * 0.5, py - uy * sz + ux * sz * 0.5)
    tri.PointC = Vector2.new(px - ux * sz + uy * sz * 0.5, py - uy * sz - ux * sz * 0.5)
    tri.Color, tri.Transparency = col, a
    sv(x, "arr", true)

    if cfg.e.dist then
        local t = single(x, "arrT", "Text", initInfo)
        t.Text = tostring(math.floor(dist))
        t.Position = Vector2.new(px - ux * (sz + 14), py - uy * (sz + 14))
        t.Color, t.Transparency = col, a
        sv(x, "arrT", true)
    else
        sv(x, "arrT", false)
    end
    return true
end

local function drawExtras(c, x, st, dist, a, onS, x0, y0, x1, y1)
    local e = cfg.e
    local any = false

    local sp = xpool(x, "skel", #c.bones, e.skel and onS)
    if sp then
        local u = drawSkel(c, sp, elemColor(c, e.skelCol, st, dist), a)
        lend(sp, u)
        if u > 0 then any = true end
    end

    if e.skel and e.headDot and onS then
        if drawHeadDot(x, c, elemColor(c, e.skelCol, st, dist), a) then any = true end
    else
        sv(x, "head", false)
    end

    local op = xpool(x, "out", e.outGlow and 190 or 95, e.outline and onS)
    if op then
        local col = elemColor(c, e.outCol, st, dist)
        local u = hullLines(op, 0, c, e.outScale, col, e.outThick, a)
        if e.outGlow then u = hullLines(op, u, c, e.outScale + 0.15, col, e.outThick, a * 0.35) end
        lend(op, u)
        if u > 0 then any = true end
    end

    if e.look and onS then
        if drawLook(x, c, elemColor(c, e.lookCol, st, dist), a) then any = true end
    else
        sv(x, "look", false)
    end

    if onS and (e.dist or e.flags) then
        if drawInfo(x, c, dist, x0, x1, y1, a) then any = true end
    else
        sv(x, "info", false)
    end

    local hp = xpool(x, "hp", 2, e.allyHp and c.ally and onS)
    if hp then
        local v = allyHealth(c)
        if v then
            local frac = math.max(0, math.min(1, v / 100))
            local bx = x0 - 5
            seg(hp[1], bx, y1, bx, y0, Color3.fromRGB(0, 0, 0), 4, a)
            seg(hp[2], bx, y1, bx, y1 - (y1 - y0) * frac, Color3.new(1 - frac, frac, 0.2), 2, a)
            hp.on = 2
            any = true
        else
            lend(hp, 0)
        end
    end

    if e.arrows and not onS then
        if drawArrow(x, c, elemColor(c, e.arrowCol, st, dist), a, dist) then any = true end
    else
        sv(x, "arr", false)
        sv(x, "arrT", false)
    end
    return any
end

local function drawLabel(i, c)
    local txt = labelText(c)
    if txt ~= "" then
        local hx, hy, hz = groupCenter(c, "head")
        local sx, sy
        if hx then sx, sy = projectPoint(hx, hy + 2.5, hz) end
        if sx then
            local d = make(S.lbl, i, "Text", initLbl)
            if lblTxt[i] ~= txt then
                d.Text = txt
                lblTxt[i] = txt
            end
            d.Position = Vector2.new(sx, sy)
            toggle(lblOn, S.lbl, i, true)
            return true
        end
    end
    toggle(lblOn, S.lbl, i, false)
    return false
end

local function drawTracer(i, c)
    if cfg.tracer then
        local x, y, z = bodyCenter(c)
        local sx, sy
        if x then sx, sy = projectPoint(x, y, z) end
        if sx then
            local oy = hH * 2
            if cfg.tracerFrom == "center" then oy = hH
            elseif cfg.tracerFrom == "top" then oy = 0 end
            local ln = make(S.lines, i, "Line", initLine)
            ln.From, ln.To = Vector2.new(hW, oy), Vector2.new(sx, sy)
            toggle(lnOn, S.lines, i, true)
            return true
        end
    end
    toggle(lnOn, S.lines, i, false)
    return false
end

local function procChar(i, folder)
    local c = getCache(i, folder)
    if not c or c.hidden then
        hideSlot(i)
        return showGhost(i)
    end
    if skip(c) then
        hideSlot(i)
        return hideGhost(i)
    end

    local e = cfg.e
    local dx, dy, dz = c.px - cX, c.py - cY, c.pz - cZ
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    if dist > e.maxDist then
        hideSlot(i)
        return hideGhost(i)
    end

    if (cfg.weapon or cfg.seen) and (c.infoAt == nil or (frame + i) % 25 == 0) then
        refreshInfo(c)
        c.infoAt = frame
    end
    if cfg.seen then record(i, c) end
    hideGhost(i)

    if cfg.espVis then
        local bx, by, bz = bodyCenter(c)
        if bx then c.shown = exposed(c, "body", bx, by, bz, folder, tick()) end
    else
        c.shown = nil
    end
    local st = stateOf(c)
    local a = e.fade and math.max(0.25, 1 - dist / e.maxDist) or 1

    local x = xget(i)
    local x0, y0, x1, y1 = bounds(c)
    local onS = x0 ~= nil and x1 > 0 and x0 < hW * 2 and y1 > 0 and y0 < hH * 2

    local r1 = drawChams(i, c, st)
    local r2 = drawBoxes(i, c, x, st, dist, a, onS, x0, y0, x1, y1)
    local r3 = drawLabel(i, c)
    local r4 = drawTracer(i, c)
    local r5 = drawExtras(c, x, st, dist, a, onS, x0, y0, x1, y1)
    vis[i] = r1 or r2 or r3 or r4 or r5
end

local function drawRadar(folder, on)
    local e = cfg.e
    local R = S.radar
    if not (on and e.radar) then
        if R and R.shown then
            R.shown = false
            R.bg.Visible, R.border.Visible, R.me.Visible = false, false, false
            for k = 1, R.used do R.dots[k].Visible = false end
            R.used = 0
        end
        return
    end

    if not R then
        R = { dots = {}, used = 0 }
        R.bg = Drawing.new("Square")
        R.bg.Filled, R.bg.Color, R.bg.Transparency = true, Color3.fromRGB(10, 14, 22), 0.6
        R.border = Drawing.new("Square")
        R.border.Filled, R.border.Thickness, R.border.Color, R.border.Transparency = false, 1, Color3.fromRGB(200, 200, 200), 1
        R.me = Drawing.new("Triangle")
        R.me.Filled, R.me.Color, R.me.Transparency = true, Color3.fromRGB(255, 255, 255), 1
        S.radar = R
    end
    R.shown = true

    local size = e.radarSize
    local px0, py0 = e.radarX, e.radarY
    local cx, cy = px0 + size * 0.5, py0 + size * 0.5
    local half = size * 0.5 - 4

    R.bg.Position, R.bg.Size = Vector2.new(px0, py0), Vector2.new(size, size)
    R.border.Position, R.border.Size = Vector2.new(px0, py0), Vector2.new(size, size)
    R.me.PointA = Vector2.new(cx, cy - 5)
    R.me.PointB = Vector2.new(cx - 4, cy + 4)
    R.me.PointC = Vector2.new(cx + 4, cy + 4)
    R.bg.Visible, R.border.Visible, R.me.Visible = true, true, true

    local rx, rz = c00, c20
    local fx, fz = -c02, -c22
    local rl = math.sqrt(rx * rx + rz * rz)
    local fl = math.sqrt(fx * fx + fz * fz)
    if rl < 0.01 or fl < 0.01 then return end
    rx, rz, fx, fz = rx / rl, rz / rl, fx / fl, fz / fl

    local used = 0
    for i = 1, MAX do
        local c = getCache(i, folder)
        if c and not c.hidden and not nearSelf(c) and not (cfg.teamCheck and c.ally) then
            local ex, ez = c.px - cX, c.pz - cZ
            local dx = (ex * rx + ez * rz) / e.radarRange * half
            local dy = -(ex * fx + ez * fz) / e.radarRange * half
            local m = math.sqrt(dx * dx + dy * dy)
            if m > half then dx, dy = dx / m * half, dy / m * half end

            used = used + 1
            local d = R.dots[used]
            if not d then
                d = Drawing.new("Circle")
                d.Filled, d.NumSides, d.Radius, d.Transparency = true, 10, 3, 1
                R.dots[used] = d
            end
            d.Position = Vector2.new(cx + dx, cy + dy)
            d.Color = c.ally and e.radarAlly or e.radarEnemy
            d.Visible = true
        end
    end
    for k = used + 1, R.used do R.dots[k].Visible = false end
    R.used = used
end

local function drawHud(on, enemies, allies)
    local t = S.hudTxt
    if on and cfg.e.hud then
        if not t then
            t = Drawing.new("Text")
            t.Size, t.Center, t.Outline, t.Font, t.Color, t.Transparency = 15, true, true, 2, Color3.fromRGB(255, 255, 255), 1
            S.hudTxt = t
        end
        t.Text = "Enemies " .. enemies .. "   Allies " .. allies
        t.Position = Vector2.new(hW, 18)
        t.Visible = true
    elseif t and t.Visible then
        t.Visible = false
    end
end

local remX, remY = 0, 0

local function trunc(v) return v >= 0 and math.floor(v) or math.ceil(v) end

local function evalSlot(i, folder, mode)
    local c = getCache(i, folder)
    if not c or c.hidden or skip(c) then return nil end

    local now = tick()
    local reach = cfg.fov * 1.5
    local bestD, bx, by
    for _, key in ipairs(SETS[mode] or SETS.head) do
        local x, y, z = groupCenter(c, key)
        local sx, sy
        if x then sx, sy = projectPoint(x, y, z) end
        if sx then
            local dx, dy = sx - hW, sy - hH
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= reach and (not bestD or d < bestD)
                and (not cfg.aimWall or exposed(c, key, x, y, z, folder, now)) then
                bestD, bx, by = d, sx, sy
            end
        end
    end
    return bestD, bx, by
end

local function aimStep(folder)
    if not cfg.aimHeld or not mousemoverel then
        S.lock, remX, remY = nil, 0, 0
        return
    end

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

local tb = { down = false, since = 0, hold = 0.04, nextAt = 0, armed = nil, slot = nil,
             wallAt = 0, walled = false, chkAt = 0, ok = true, sqN = 0 }

local function jit(ms)
    local j = cfg.tbJit / 100
    return ms * (1 + (math.random() * 2 - 1) * j) / 1000
end

local function press(now)
    if pcall(mouse1press) then
        tb.down, tb.since = true, now
    end
end

local function lift()
    pcall(mouse1release)
    tb.down = false
end

local function playerAlive(now)
    if now < tb.chkAt then return tb.ok end
    tb.chkAt = now + 0.2
    tb.ok = true
    local lp = Players.LocalPlayer
    if lp then
        local ok, h = pcall(function() return lp:GetAttribute("Health") end)
        if ok and type(h) == "number" and h <= 0 then tb.ok = false end
    end
    return tb.ok
end

local function scan(c, fx, fy, fz)
    local bx, by, bz = bodyCenter(c)
    if not bx then return nil end

    local dx, dy, dz = bx - cX, by - cY, bz - cZ
    local along = dx * fx + dy * fy + dz * fz
    if along < 0.5 then return nil end

    local qx, qy, qz = dx - along * fx, dy - along * fy, dz - along * fz
    local perp2 = qx * qx + qy * qy + qz * qz
    if perp2 > 36 then return nil, nil, perp2 end

    local pad = cfg.tbPad
    local bestT, bestKey
    local all, kinds = c.all, c.kinds

    for k = 1, #all do
        local key = kinds[k]
        if cfg[TKEY[key]] then
            local p = all[k]
            local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
            local s = p.Size

            local ex, ey, ez = x - cX, y - cY, z - cZ
            local lcx = r00 * ex + r10 * ey + r20 * ez
            local lcy = r01 * ex + r11 * ey + r21 * ez
            local lcz = r02 * ex + r12 * ey + r22 * ez
            local ldx = r00 * fx + r10 * fy + r20 * fz
            local ldy = r01 * fx + r11 * fy + r21 * fz
            local ldz = r02 * fx + r12 * fy + r22 * fz

            local lo, hi = slab(lcx, ldx, s.X * 0.5 + pad, 0, 1e9)
            if lo then lo, hi = slab(lcy, ldy, s.Y * 0.5 + pad, lo, hi) end
            if lo then lo = slab(lcz, ldz, s.Z * 0.5 + pad, lo, hi) end
            if lo and (not bestT or lo < bestT) then bestT, bestKey = lo, key end
        end
    end
    return bestT, bestKey, perp2
end

local function drawHitboxes(c, on)
    local pool = S.tbSq
    local n = 0
    if c then
        if not pool then pool = {} S.tbSq = pool end
        for k = 1, #c.all do
            if projectPart(c.all[k], 1, 0) == 8 then
                local minX, minY, maxX, maxY = BX[1], BY[1], BX[1], BY[1]
                for j = 2, 8 do
                    local x, y = BX[j], BY[j]
                    if x < minX then minX = x elseif x > maxX then maxX = x end
                    if y < minY then minY = y elseif y > maxY then maxY = y end
                end
                n = n + 1
                local sq = pool[n]
                if not sq then
                    sq = Drawing.new("Square")
                    sq.Filled, sq.Thickness, sq.Transparency = false, 1, 1
                    pool[n] = sq
                end
                sq.Color = on and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(0, 255, 255)
                sq.Position = Vector2.new(minX, minY)
                sq.Size = Vector2.new(maxX - minX, maxY - minY)
                sq.Visible = true
            end
        end
    end
    for k = n + 1, tb.sqN do pool[k].Visible = false end
    tb.sqN = n
end

local function trigIdle(now)
    tb.armed, tb.slot, tb.walled = nil, nil, false
    if tb.down and now - tb.since >= tb.hold then lift() end
end

local function trigStep(folder)
    local now = tick()

    local active = cfg.tbHeld
    if active and cfg.tbFocus and isrbxactive and not isrbxactive() then
        active = false
        if cfg.tbDebug and not tb.warned then
            tb.warned = true
            print("[TB] game window not focused (isrbxactive is false)")
        end
    end
    if active and not playerAlive(now) then active = false end

    local fx, fy, fz = -c02, -c12, -c22
    local hit, hitT, hitKey, hitSlot, near, nearP

    if active or cfg.tbVis then
        for i = 1, MAX do
            local ok, c = pcall(getCache, i, folder)
            if ok and c and not c.hidden and not skip(c) then
                local ok2, t, key, perp2 = pcall(scan, c, fx, fy, fz)
                if ok2 then
                    if t and (not hitT or t < hitT) then hit, hitT, hitKey, hitSlot = c, t, key, i end
                    if perp2 and (not nearP or perp2 < nearP) then near, nearP = c, perp2 end
                end
            end
        end
    end

    local shown = cfg.tbVis and (hit or near) or nil
    if shown or tb.sqN > 0 then drawHitboxes(shown, hit ~= nil) end

    if not active then
        trigIdle(now)
        return
    end

    local ready = false
    if hit then
        if tb.slot ~= hitSlot then
            tb.slot, tb.armed, tb.walled = hitSlot, nil, false
        end
        if not tb.armed then tb.armed = now + jit(cfg.tbReact) end
        ready = now >= tb.armed

        if ready and cfg.tbWall then
            if now >= tb.wallAt then
                tb.wallAt = now + 0.05
                local px, py, pz = cX + fx * hitT, cY + fy * hitT, cZ + fz * hitT
                local okW, isWall = pcall(blocked, px, py, pz, hit.char, folder)
                tb.walled = okW and isWall == true
            end
            if tb.walled then ready = false end
        end
    else
        tb.slot, tb.armed, tb.walled = nil, nil, false
    end

    if cfg.tbMode == "auto" then
        if ready then
            if not tb.down and now >= tb.nextAt then
                tb.hold = math.max(jit(cfg.tbHold), MIN_HOLD)
                press(now)
                if cfg.tbDebug and tb.down then
                    print(string.format("[TB] hold on slot %d (%s) at %.0f studs", hitSlot, hitKey, hitT))
                end
            end
        elseif tb.down and now - tb.since >= tb.hold then
            lift()
            tb.nextAt = now + TICK
        end
    else
        if tb.down then
            if now - tb.since >= tb.hold then
                lift()
                tb.nextAt = now + math.max(jit(cfg.tbGap), MIN_HOLD)
            end
        elseif ready and now >= tb.nextAt then
            tb.hold = math.max(jit(cfg.tbHold), MIN_HOLD)
            press(now)
            if cfg.tbDebug and tb.down then
                print(string.format("[TB] tap on slot %d (%s) at %.0f studs", hitSlot, hitKey, hitT))
            end
        end
    end
end

local fovOn, fovX, fovY, fovR = false, 0, 0, 0

local function hideFov()
    if fovOn then
        S.fov.Visible = false
        fovOn = false
    end
end

local function updFov()
    if cfg.showFov then
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

local function espOn()
    local e = cfg.e
    return cfg.box or cfg.chams or cfg.weapon or cfg.espNum or cfg.tracer or cfg.seen
        or e.skel or e.outline or e.look or e.arrows or e.dist or e.flags
end

local function markFocus(folder)
    local best, bestD
    for i = 1, MAX do
        local c = getCache(i, folder)
        if c then
            c.focus = false
            if not c.hidden and not skip(c) then
                local bx, by, bz = bodyCenter(c)
                local sx, sy
                if bx then sx, sy = projectPoint(bx, by, bz) end
                if sx then
                    local dx, dy = sx - hW, sy - hH
                    local d = dx * dx + dy * dy
                    if not bestD or d < bestD then best, bestD = c, d end
                end
            end
        end
    end
    if best then best.focus = true end
end

local function drawAll(folder)
    local on = cfg.on
    local enemies, allies = 0, 0

    if on then
        for i = 1, MAX do
            local ok, c = pcall(getCache, i, folder)
            if ok and c and not nearSelf(c) then
                if c.ally then
                    allies = allies + 1
                    c.num = allies
                else
                    enemies = enemies + 1
                    c.num = enemies
                end
            end
        end
        if cfg.e.closest then pcall(markFocus, folder) end
    end

    if on and espOn() then
        for i = 1, MAX do
            local ok, err = pcall(procChar, i, folder)
            if not ok then
                S.cache[i] = nil
                hideSlot(i)
                hideGhost(i)
                if not errShown then
                    errShown = true
                    print("[Kontra] slot " .. i .. " error: " .. tostring(err))
                end
            end
        end
    else
        hideAll()
    end

    pcall(drawRadar, folder, on)
    pcall(drawHud, on, enemies, allies)
end

S.conn = RunService.RenderStepped:Connect(function(dt)
    acc = acc + dt
    local due = acc >= step
    if due then acc = acc - step end
    if not (due or cfg.tbHeld) then return end
    frame = frame + 1

    local folder = workspace:FindFirstChild("Characters")
    if not folder then
        hideAll()
        hideFov()
        drawHitboxes(nil)
        trigIdle(tick())
        pcall(drawRadar, nil, false)
        pcall(drawHud, false, 0, 0)
        S.lock = nil
        return
    end

    updCam()

    local now = tick()
    if GEO.want and now - GEO.want < 2 then pcall(geoPump, folder, now) end

    if due then
        if cfg.weapon and wCount == 0 then
            if frame % 180 == 0 then pcall(buildWeaponMap) end
            if frame == 600 and wCount == 0 then
                print("[Kontra] weapon list is empty, labels cannot be matched")
            end
        end
        drawAll(folder)
        pcall(aimStep, folder)
        pcall(updFov)
    end

    pcall(trigStep, folder)
end)

print("[Kontra] running")

S.cleanup = function()
    if S.conn then pcall(function() S.conn:Disconnect() end) end
    stopSounds()
    if tb.down and mouse1release then pcall(mouse1release) end
    for _, b in pairs(S.boxes) do pcall(function() b:Remove() end) end
    for _, d in pairs(S.lbl) do pcall(function() d:Remove() end) end
    for _, l in pairs(S.lines) do pcall(function() l:Remove() end) end
    for _, d in pairs(S.gTxt) do pcall(function() d:Remove() end) end
    for _, d in pairs(S.gBox) do pcall(function() d:Remove() end) end
    for _, d in pairs(S.gDot) do pcall(function() d:Remove() end) end
    for _, pool in pairs(S.tris) do
        for _, t in pairs(pool) do pcall(function() t:Remove() end) end
    end
    for _, x in pairs(X) do
        for _, name in ipairs(POOLS) do
            local p = x[name]
            if p then
                for k = 1, p.n do pcall(function() p[k]:Remove() end) end
            end
        end
        for _, name in ipairs(ONES) do
            local d = x[name]
            if d then pcall(function() d:Remove() end) end
        end
    end
    local R = S.radar
    if R then
        pcall(function() R.bg:Remove() end)
        pcall(function() R.border:Remove() end)
        pcall(function() R.me:Remove() end)
        for _, d in pairs(R.dots) do pcall(function() d:Remove() end) end
    end
    if S.hudTxt then pcall(function() S.hudTxt:Remove() end) end
    for i = 1, SNDMAX do
        pcall(function() S.snd.dot[i]:Remove() end)
        pcall(function() S.snd.txt[i]:Remove() end)
        pcall(function() S.snd.line[i]:Remove() end)
    end
    if S.tbSq then
        for _, q in pairs(S.tbSq) do pcall(function() q:Remove() end) end
    end
    if S.fov then pcall(function() S.fov:Remove() end) end
    if S.win then pcall(function() S.win:Destroy() end) end
end
