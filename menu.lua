--[[
    Susano Menu Framework
    Docs: https://docs.susano.re/api-reference/drawing-functions
    Toggle: INSERT (0x2D)
    Drag:   Hold LMB on header
--]]

local Menu = {}

-- ════════════════════════════════════════════
--  Config
-- ════════════════════════════════════════════
local CFG = {
    -- Position (updated on drag)
    x       = 50,
    y       = 80,
    width   = 240,

    -- Heights
    headerH = 52,
    tabH    = 28,
    itemH   = 30,
    footerH = 20,
    pad     = 10,
    round   = 6,

    -- Title & footer text
    title   = "MENU",   -- <-- change to your menu name
    footer  = "",        -- <-- e.g. "mysite.gg" or leave blank

    -- Banner image path (PNG/JPG). Set to "" to disable and show plain header.
    -- Example: bannerPath = "C:/Users/Emre/Desktop/banner.png"
    bannerPath  = "",

    -- Colors  { R, G, B, A }  0-255
    bg          = { 10, 12, 20, 240 },
    header      = { 12, 16, 30, 255 },
    accent      = { 40,  110, 230, 255 },   -- blue
    accentHover = { 25,  80,  180, 255 },   -- blue hover
    tabActive   = { 20,  26,  50, 255 },
    tabIdle     = { 12,  15,  28, 200 },
    itemHover   = { 22,  30,  58, 180 },
    text        = { 235, 235, 235, 255 },
    textDim     = { 120, 135, 165, 255 },
    sliderBg    = { 28,  35,  60, 255 },
    sliderFg    = { 40,  110, 230, 220 },   -- blue
    toggleOn    = { 40,  110, 230, 255 },   -- blue
    toggleOff   = { 45,  50,  72, 255 },
    border      = { 40,  60,  110, 160 },
}

-- ════════════════════════════════════════════
--  Internal State
-- ════════════════════════════════════════════
local _state = {
    open        = false,
    activeTab   = 1,
    dragging    = false,
    dragOffX    = 0,
    dragOffY    = 0,
    sliderDrag  = nil,   -- { tab=int, idx=int }
    bannerTex   = nil,   -- texture handle (loaded once)
    bannerW     = 0,
    bannerH     = 0,
}

-- ════════════════════════════════════════════
--  Tabs / Items storage
-- ════════════════════════════════════════════
local _tabs = {}

-- ════════════════════════════════════════════
--  Public API
-- ════════════════════════════════════════════

--- Add a category tab. Returns the tab index.
function Menu.AddTab(name)
    _tabs[#_tabs + 1] = { name = name, items = {} }
    return #_tabs
end

--- Add a toggle item.
--- @param tabIdx   number   tab index returned by AddTab
--- @param label    string   display name
--- @param default  boolean  initial state
--- @param onChange function called with (bool) when changed
--- @return item index inside the tab
function Menu.AddToggle(tabIdx, label, default, onChange)
    local t = _tabs[tabIdx]; if not t then return end
    t.items[#t.items + 1] = {
        type     = "toggle",
        label    = label,
        value    = default or false,
        onChange = onChange,
    }
    return #t.items
end

--- Add a slider item.
--- @param tabIdx   number
--- @param label    string
--- @param min      number
--- @param max      number
--- @param default  number
--- @param step     number   e.g. 0.1 or 1
--- @param onChange function called with (number)
function Menu.AddSlider(tabIdx, label, min, max, default, step, onChange)
    local t = _tabs[tabIdx]; if not t then return end
    t.items[#t.items + 1] = {
        type     = "slider",
        label    = label,
        min      = min,
        max      = max,
        value    = default or min,
        step     = step or 1,
        onChange = onChange,
    }
    return #t.items
end

--- Add a clickable button item.
--- @param tabIdx  number
--- @param label   string
--- @param onClick function called on click
function Menu.AddButton(tabIdx, label, onClick)
    local t = _tabs[tabIdx]; if not t then return end
    t.items[#t.items + 1] = {
        type    = "button",
        label   = label,
        onClick = onClick,
    }
    return #t.items
end

--- Get the current value of any item.
function Menu.GetValue(tabIdx, itemIdx)
    local t = _tabs[tabIdx]; if not t then return nil end
    local it = t.items[itemIdx]; if not it then return nil end
    return it.value
end

--- Set the value of a toggle or slider programmatically (no callback fired).
function Menu.SetValue(tabIdx, itemIdx, value)
    local t = _tabs[tabIdx]; if not t then return end
    local it = t.items[itemIdx]; if not it then return end
    it.value = value
end

-- ════════════════════════════════════════════
--  Helpers
-- ════════════════════════════════════════════
local function inRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function snapToStep(v, step)
    return math.floor(v / step + 0.5) * step
end

local function fmtNum(v, step)
    if step >= 1 then
        return tostring(math.floor(v + 0.5))
    else
        -- count decimal places in step
        local s = tostring(step)
        local dot = s:find("%.")
        local dec = dot and (#s - dot) or 0
        return string.format("%." .. dec .. "f", v)
    end
end

-- ════════════════════════════════════════════
--  Draw
-- ════════════════════════════════════════════
local function drawMenu(mx, my, lmbDown, lmbPress)
    local x, y = CFG.x, CFG.y
    local w    = CFG.width
    local pad  = CFG.pad
    local r    = CFG.round

    -- ── Geometry
    local tabCount = math.max(1, #_tabs)
    local tabW     = math.floor((w - pad * 2) / tabCount)
    local curTab   = _tabs[_state.activeTab]
    local itemCount = curTab and #curTab.items or 0
    local contentH = itemCount * CFG.itemH + pad
    local totalH   = CFG.headerH + CFG.tabH + contentH + CFG.footerH

    -- ── Drop shadow
    Susano.DrawRoundedRectFilled(x + 5, y + 6, w, totalH, r, 0, 0, 0, 90)

    -- ── Background
    Susano.DrawRoundedRectFilled(x, y, w, totalH, r,
        CFG.bg[1], CFG.bg[2], CFG.bg[3], CFG.bg[4])

    -- ── Header
    Susano.DrawRoundedRectFilled(x, y, w, CFG.headerH, r,
        CFG.header[1], CFG.header[2], CFG.header[3], CFG.header[4])

    if _state.bannerTex then
        -- Draw banner image stretched to fill the header, with same corner rounding
        -- Bottom corners are NOT rounded (the bg below continues)
        Susano.DrawImage(_state.bannerTex, x, y, w, CFG.headerH,
            1, 1, 1, 1, r)
        -- Dark gradient overlay so the accent line is still visible
        Susano.DrawRectFilled(x, y + CFG.headerH - 18, w, 18,
            0, 0, 0, 120)
    else
        -- Fallback: top→bottom gradient  (blue tint at top, fades to dark)
        -- Colors are 0..1 floats: TL, TR, BR, BL corners
        local ar = CFG.accent[1] / 255
        local ag = CFG.accent[2] / 255
        local ab = CFG.accent[3] / 255
        Susano.DrawRectGradient(x, y, w, CFG.headerH,
            ar, ag, ab, 0.22,   -- top-left
            ar, ag, ab, 0.22,   -- top-right
            0,  0,  0,  0.0,    -- bottom-right
            0,  0,  0,  0.0,    -- bottom-left
            r)
        -- title only shown when there is no banner
        Susano.DrawTextCentered(x + w / 2, y + CFG.headerH / 2 - 9, CFG.title, 18,
            CFG.text[1], CFG.text[2], CFG.text[3], CFG.text[4])
    end

    -- accent underline on header (always visible)
    Susano.DrawRectFilled(x, y + CFG.headerH - 2, w, 2,
        CFG.accent[1], CFG.accent[2], CFG.accent[3], CFG.accent[4])

    -- ── Tabs
    local tabY = y + CFG.headerH
    for i, tab in ipairs(_tabs) do
        local tx      = x + pad + (i - 1) * tabW
        local isActive = (i == _state.activeTab)
        local tc      = isActive and CFG.tabActive or CFG.tabIdle

        Susano.DrawRoundedRectFilled(tx, tabY + 2, tabW - 2, CFG.tabH - 3, 4,
            tc[1], tc[2], tc[3], tc[4])

        if isActive then
            Susano.DrawRectFilled(tx, tabY + CFG.tabH - 3, tabW - 2, 2,
                CFG.accent[1], CFG.accent[2], CFG.accent[3], CFG.accent[4])
        end

        Susano.DrawTextCentered(tx + (tabW - 2) / 2, tabY + 6, tab.name, 12,
            CFG.text[1], CFG.text[2], CFG.text[3], CFG.text[4])

        if lmbPress and inRect(mx, my, tx, tabY, tabW - 2, CFG.tabH) then
            _state.activeTab = i
        end
    end

    -- ── Items
    if curTab then
        local iy = tabY + CFG.tabH + pad / 2
        for idx, item in ipairs(curTab.items) do
            local ix      = x + pad
            local iw      = w - pad * 2
            local ih      = CFG.itemH
            local hovered = inRect(mx, my, ix, iy, iw, ih)

            -- hover bg
            if hovered then
                Susano.DrawRoundedRectFilled(ix, iy, iw, ih - 2, 4,
                    CFG.itemHover[1], CFG.itemHover[2], CFG.itemHover[3], CFG.itemHover[4])
            end

            -- ── TOGGLE ──────────────────────────────────────
            if item.type == "toggle" then
                -- label
                Susano.DrawText(ix + 7, iy + ih / 2 - 7, item.label, 13,
                    CFG.text[1], CFG.text[2], CFG.text[3], CFG.text[4])

                -- pill background
                local pillW, pillH = 30, 16
                local px = ix + iw - pillW - 6
                local py = iy + ih / 2 - pillH / 2
                local pc = item.value and CFG.toggleOn or CFG.toggleOff
                Susano.DrawRoundedRectFilled(px, py, pillW, pillH, 8,
                    pc[1], pc[2], pc[3], pc[4])

                -- knob
                local knobX = item.value and (px + pillW - 13) or (px + 3)
                Susano.DrawRoundedRectFilled(knobX, py + 3, 10, 10, 5, 225, 225, 225, 255)

                -- click
                if lmbPress and hovered then
                    item.value = not item.value
                    if item.onChange then item.onChange(item.value) end
                end

            -- ── SLIDER ──────────────────────────────────────
            elseif item.type == "slider" then
                local valStr = item.label .. ": " .. fmtNum(item.value, item.step)
                Susano.DrawText(ix + 7, iy + 5, valStr, 12,
                    CFG.text[1], CFG.text[2], CFG.text[3], CFG.text[4])

                local sw   = iw - 14
                local sx   = ix + 7
                local sy   = iy + ih - 10
                local sh   = 5
                local pct  = (item.value - item.min) / (item.max - item.min)
                local fillW = math.max(sh, sw * pct)

                -- track
                Susano.DrawRoundedRectFilled(sx, sy, sw, sh, 3,
                    CFG.sliderBg[1], CFG.sliderBg[2], CFG.sliderBg[3], CFG.sliderBg[4])
                -- fill
                Susano.DrawRoundedRectFilled(sx, sy, fillW, sh, 3,
                    CFG.sliderFg[1], CFG.sliderFg[2], CFG.sliderFg[3], CFG.sliderFg[4])
                -- thumb
                local thumbX = sx + sw * pct - 5
                Susano.DrawRoundedRectFilled(thumbX, sy - 4, 10, 13, 4,
                    CFG.accent[1], CFG.accent[2], CFG.accent[3], 255)

                -- begin drag
                if lmbDown and inRect(mx, my, sx - 4, sy - 6, sw + 8, sh + 12) then
                    if not _state.sliderDrag then
                        _state.sliderDrag = { tab = _state.activeTab, idx = idx }
                    end
                end

                -- apply drag
                if _state.sliderDrag
                    and _state.sliderDrag.tab == _state.activeTab
                    and _state.sliderDrag.idx == idx
                then
                    local raw  = (mx - sx) / sw
                    local newV = snapToStep(
                        item.min + clamp(raw, 0, 1) * (item.max - item.min),
                        item.step
                    )
                    newV = clamp(newV, item.min, item.max)
                    if newV ~= item.value then
                        item.value = newV
                        if item.onChange then item.onChange(newV) end
                    end
                end

            -- ── BUTTON ──────────────────────────────────────
            elseif item.type == "button" then
                local bc = hovered and CFG.accentHover or { 32, 32, 46, 220 }
                Susano.DrawRoundedRectFilled(ix + 6, iy + 5, iw - 12, ih - 10, 4,
                    bc[1], bc[2], bc[3], bc[4])
                Susano.DrawTextCentered(ix + iw / 2, iy + ih / 2 - 7, item.label, 13,
                    CFG.text[1], CFG.text[2], CFG.text[3], CFG.text[4])

                if lmbPress and hovered then
                    if item.onClick then item.onClick() end
                end
            end

            iy = iy + ih
        end
    end

    -- ── Footer
    if CFG.footer ~= "" then
        local fy = y + totalH - CFG.footerH
        Susano.DrawRectFilled(x, fy, w, 1,
            CFG.accent[1], CFG.accent[2], CFG.accent[3], 80)
        Susano.DrawTextCentered(x + w / 2, fy + 4, CFG.footer, 11,
            CFG.textDim[1], CFG.textDim[2], CFG.textDim[3], CFG.textDim[4])
    end

    -- ── Border outline
    Susano.DrawRoundedRect(x, y, w, totalH, r,
        CFG.border[1], CFG.border[2], CFG.border[3], CFG.border[4], 1)

    -- ── Drag (LMB held on header)
    if lmbDown and inRect(mx, my, x, y, w, CFG.headerH) then
        if not _state.dragging then
            _state.dragging = true
            _state.dragOffX = mx - x
            _state.dragOffY = my - y
        end
    end
    if not lmbDown then
        _state.dragging  = false
        _state.sliderDrag = nil
    end
    if _state.dragging then
        CFG.x = mx - _state.dragOffX
        CFG.y = my - _state.dragOffY
    end
end

-- ════════════════════════════════════════════
--  Banner loader  (called once at startup)
-- ════════════════════════════════════════════
local function loadBanner()
    if CFG.bannerPath ~= "" then
        local id, bw, bh = Susano.LoadTexture(CFG.bannerPath)
        if id then
            _state.bannerTex = id
            _state.bannerW   = bw
            _state.bannerH   = bh
        end
    end
end

-- ════════════════════════════════════════════
--  Example tabs  —  REPLACE WITH YOUR OWN
-- ════════════════════════════════════════════
local function setupTabs()
    -- ── Tab 1: Player
    local t1 = Menu.AddTab("Player")
    Menu.AddToggle(t1, "God Mode",    false, function(v)
        -- TODO
    end)
    Menu.AddToggle(t1, "Invisible",   false, function(v)
        -- TODO
    end)
    Menu.AddSlider(t1, "Walk Speed",  1, 10, 1, 0.1, function(v)
        -- TODO
    end)
    Menu.AddButton(t1, "Heal",  function()
        -- TODO
    end)

    -- ── Tab 2: Vehicle
    local t2 = Menu.AddTab("Vehicle")
    Menu.AddToggle(t2, "No Damage",   false, function(v)
        -- TODO
    end)
    Menu.AddSlider(t2, "Boost",  1.0, 5.0, 1.0, 0.1, function(v)
        -- TODO
    end)
    Menu.AddButton(t2, "Repair", function()
        -- TODO
    end)

    -- ── Tab 3: World
    local t3 = Menu.AddTab("World")
    Menu.AddToggle(t3, "No Cops",    false, function(v)
        -- TODO
    end)
    Menu.AddSlider(t3, "Time Hour", 0, 23, 12, 1, function(v)
        -- TODO
    end)
end

-- ════════════════════════════════════════════
--  Main loop
-- ════════════════════════════════════════════
CreateThread(function()
    loadBanner()
    setupTabs()

    while true do
        Wait(0)

        -- Read inputs once per frame
        local lmbDown,  lmbPress  = Susano.GetAsyncKeyState(0x01)  -- LMB
        local _, insertPress      = Susano.GetAsyncKeyState(0x2D)   -- INSERT

        -- Toggle menu with INSERT
        if insertPress then
            _state.open = not _state.open
            Susano.EnableOverlay(_state.open)
            if not _state.open then
                Susano.ResetFrame()
            end
        end

        if _state.open then
            local cur    = Susano.GetCursorPos()
            local mx, my = cur.x, cur.y

            Susano.BeginFrame()
            drawMenu(mx, my, lmbDown, lmbPress)
            Susano.SubmitFrame()
        end
    end
end)

return Menu
