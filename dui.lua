-- phantom.lua | susano menu
-- banner: https://i.hizliresim.com/gmgbp7w.png

local Menu = {}

Menu.Visible          = false
Menu.CurrentItem      = 1
Menu.ItemScrollOffset = 0
Menu.ItemsPerPage     = 9
Menu.SelectorY        = 0
Menu.SmoothFactor     = 0.30
Menu.Scale            = 1.0
Menu.LoadingComplete  = true
Menu.SelectedKey      = 0x2D   -- Insert
Menu.SelectedKeyName  = "Insert"
Menu.SectionName      = "Menu"
Menu.Title            = "phantom"
Menu.BrandAnimStart   = nil
Menu.OpenAnimStart    = nil
Menu.Items            = {}

-- Banner
Menu.Banner = {
    enabled  = true,
    imageUrl = "https://i.hizliresim.com/gmgbp7w.png",
    height   = 96,
}
Menu.bannerTexture = nil
Menu.bannerWidth   = 0
Menu.bannerHeight  = 0

-- ─── Theme (all RGB 0-255) ───────────────────────────────────────────────────
-- Neon cyber theme (matches Emre.Lua banner): cyan + gold on deep navy
local C = {
    accent   = {  45, 226, 230 },  -- #2DE2E6 cyan/teal neon (primary)
    accent2  = { 240, 184,  64 },  -- #F0B840 gold/amber (secondary)
    panel    = {   8,  14,  26 },  -- deep navy base
    panelTop = {  14,  23,  41 },  -- lighter navy
    row      = {  11,  18,  33 },
    rowAlt   = {  14,  24,  43 },
    line     = {  30,  48,  76 },  -- navy-blue border
    text     = { 226, 240, 248 },  -- cool white
    textDim  = { 118, 150, 182 },  -- muted blue-gray
    textOnAccent = {  4,  16,  24 },  -- dark text on cyan/gold
    track    = {  26,  42,  64 },
}
Menu.C = C

-- ─── Layout ──────────────────────────────────────────────────────────────────
Menu.Position = {
    x             = 60,
    y             = 110,
    width         = 340,
    itemHeight    = 32,
    sectionHeight = 26,
    headerHeight  = 96,
    footerHeight  = 26,
    radius        = 10,
}

function Menu.GetScaledPosition()
    local s = Menu.Scale or 1.0
    local p = Menu.Position
    return {
        x             = p.x,
        y             = p.y,
        width         = p.width         * s,
        itemHeight    = p.itemHeight    * s,
        sectionHeight = p.sectionHeight * s,
        headerHeight  = p.headerHeight  * s,
        footerHeight  = p.footerHeight  * s,
        radius        = p.radius        * s,
        bannerHeight  = (Menu.Banner.enabled and Menu.Banner.height or p.headerHeight) * s,
    }
end

-- ─── Texture loader ──────────────────────────────────────────────────────────
function Menu.LoadBannerTexture(url)
    if not url or url == "" then return end
    if not (Susano and Susano.HttpGet and Susano.LoadTextureFromBuffer) then return end
    CreateThread(function()
        pcall(function()
            local status, body = Susano.HttpGet(url)
            if status == 200 and body and #body > 0 then
                local tid, w, h = Susano.LoadTextureFromBuffer(body)
                if tid and tid ~= 0 then
                    Menu.bannerTexture = tid
                    Menu.bannerWidth   = w
                    Menu.bannerHeight  = h
                end
            end
        end)
    end)
end

-- ─── Low-level draw helpers ───────────────────────────────────────────────────
local function un(v) return (v and v > 1) and v / 255 or (v or 0) end

function Menu.Rect(x, y, w, h, col, a, rnd)
    if not (Susano and Susano.DrawRectFilled) then return end
    a = a == nil and 255 or a
    Susano.DrawRectFilled(x, y, w, h, un(col[1]), un(col[2]), un(col[3]), un(a), rnd or 0)
end

-- Vertical 2-color gradient (top -> bottom). Falls back to a solid blend.
function Menu.VGrad(x, y, w, h, topCol, botCol, a, rnd)
    a = a == nil and 255 or a
    if Susano and Susano.DrawRectGradient then
        Susano.DrawRectGradient(x, y, w, h,
            un(topCol[1]), un(topCol[2]), un(topCol[3]), un(a),
            un(topCol[1]), un(topCol[2]), un(topCol[3]), un(a),
            un(botCol[1]), un(botCol[2]), un(botCol[3]), un(a),
            un(botCol[1]), un(botCol[2]), un(botCol[3]), un(a),
            rnd or 0)
    else
        Menu.Rect(x, y, w, h, {
            (topCol[1] + botCol[1]) / 2,
            (topCol[2] + botCol[2]) / 2,
            (topCol[3] + botCol[3]) / 2,
        }, a, rnd)
    end
end

function Menu.Text(x, y, text, size, col, a)
    if not (Susano and Susano.DrawText) then return end
    local s = Menu.Scale or 1.0
    a = a == nil and 255 or a
    Susano.DrawText(x, y, text, (size or 14) * s, un(col[1]), un(col[2]), un(col[3]), un(a))
end

function Menu.TextW(text, size)
    local s = Menu.Scale or 1.0
    if Susano and Susano.GetTextWidth then
        return Susano.GetTextWidth(text, (size or 14) * s)
    end
    return string.len(text or "") * 7 * s
end

-- ─── Animation ────────────────────────────────────────────────────────────────
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function Menu.Pulse(speed, lo, hi)
    local v = 0.5 + 0.5 * math.sin((GetGameTimer() / 1000.0) * (speed or 2) * math.pi)
    return (lo or 0) + v * ((hi or 1) - (lo or 0))
end

function Menu.UpdateAnims()
    if Menu.Visible then
        if not Menu.BrandAnimStart then Menu.BrandAnimStart = GetGameTimer() end
        if not Menu.OpenAnimStart  then Menu.OpenAnimStart  = GetGameTimer() end
    else
        Menu.BrandAnimStart = nil
        Menu.OpenAnimStart  = nil
    end
end

function Menu.OpenProgress()
    if not Menu.OpenAnimStart then return 1 end
    local e = GetGameTimer() - Menu.OpenAnimStart
    local t = clamp(e / 180, 0, 1)
    return 1 - (1 - t) * (1 - t)   -- ease-out
end

function Menu.GetBrandAnim()
    local start   = Menu.BrandAnimStart or GetGameTimer()
    local e = GetGameTimer() - start
    if e < 350  then return "o",       clamp(e / 250, 0, 1) end
    if e < 750  then return "o",       1 end
    if e < 1050 then return "o",       1 - ((e - 750) / 300) end
    if e < 1550 then return "phantom", (e - 1050) / 500 end
    return "phantom", 1
end

-- ─── Item helpers ─────────────────────────────────────────────────────────────
function Menu.IsSelectableItem(item)
    return item and not (item.isHeader or item.isSeparator)
end

function Menu.GetSelectableItems()
    local list = {}
    for i, item in ipairs(Menu.Items or {}) do
        if Menu.IsSelectableItem(item) then
            list[#list + 1] = { index = i, item = item }
        end
    end
    return list
end

function Menu.FirstSelectableIndex()
    local sel = Menu.GetSelectableItems()
    return sel[1] and sel[1].index or 1
end

function Menu.FindSelectablePosition(target)
    for pos, e in ipairs(Menu.GetSelectableItems()) do
        if e.index == target then return pos end
    end
    return 1
end

function Menu.FindNextSelectable(startIndex, dir)
    local sel = Menu.GetSelectableItems()
    if #sel == 0 then return 1 end
    local cur = nil
    for pos, e in ipairs(sel) do
        if e.index == startIndex then cur = pos break end
    end
    if not cur then
        if dir > 0 then
            for _, e in ipairs(sel) do if e.index > startIndex then return e.index end end
            return sel[1].index
        else
            for pos = #sel, 1, -1 do if sel[pos].index < startIndex then return sel[pos].index end end
            return sel[#sel].index
        end
    end
    local nxt = cur + dir
    if nxt < 1 then nxt = #sel end
    if nxt > #sel then nxt = 1 end
    return sel[nxt].index
end

function Menu.UpdateSectionName()
    local section = "Menu"
    for i = 1, (Menu.CurrentItem or 1) do
        local item = Menu.Items[i]
        if item and item.isHeader and item.name and item.name ~= "" then
            section = item.name
        end
    end
    Menu.SectionName = section
end

function Menu.GetContentHeight()
    local pos = Menu.GetScaledPosition()
    local visible = 0
    for _, item in ipairs(Menu.Items or {}) do
        if not item.isHeader then
            visible = visible + 1
            if visible >= Menu.ItemsPerPage then break end
        end
    end
    return math.max(visible, 1) * pos.itemHeight
end

function Menu.TotalHeight()
    local pos = Menu.GetScaledPosition()
    return pos.bannerHeight + pos.sectionHeight + Menu.GetContentHeight() + pos.footerHeight
end

-- ─── DRAW: panel / shadow ─────────────────────────────────────────────────────
function Menu.DrawPanel()
    local pos = Menu.GetScaledPosition()
    local w   = pos.width
    local total = Menu.TotalHeight()

    -- soft drop shadow
    if Susano and Susano.DrawShadowRect then
        Susano.DrawShadowRect(pos.x, pos.y, w, total, un(C.panel[1]), un(C.panel[2]), un(C.panel[3]), 0.98, pos.radius)
    else
        for i = 1, 4 do
            local p = i * 2
            Menu.Rect(pos.x - p, pos.y - p, w + p * 2, total + p * 2, {0, 0, 0}, 22 / i, pos.radius + p)
        end
    end

    -- panel body
    Menu.Rect(pos.x, pos.y, w, total, C.panel, 250, pos.radius)
end

-- ─── DRAW: header / banner ────────────────────────────────────────────────────
function Menu.DrawHeader()
    local pos  = Menu.GetScaledPosition()
    local s    = Menu.Scale or 1.0
    local x, y = pos.x, pos.y
    local w    = pos.width
    local bh   = pos.bannerHeight
    local rnd  = pos.radius

    if Menu.Banner.enabled and Menu.bannerTexture and Menu.bannerTexture > 0 and Susano and Susano.DrawImage then
        Susano.DrawImage(Menu.bannerTexture, x, y, w, bh, 1, 1, 1, 1, rnd)
    else
        Menu.VGrad(x, y, w, bh, C.accent, C.panelTop, 255, rnd)
    end

    -- bottom fade so the banner blends into the panel (no hard edge)
    local fadeH = bh * 0.55
    local fy    = y + bh - fadeH
    if Susano and Susano.DrawRectGradient then
        -- smooth transparent -> panel vertical fade (no banding)
        Susano.DrawRectGradient(x, fy, w, fadeH,
            un(C.panel[1]), un(C.panel[2]), un(C.panel[3]), 0.0,
            un(C.panel[1]), un(C.panel[2]), un(C.panel[3]), 0.0,
            un(C.panel[1]), un(C.panel[2]), un(C.panel[3]), 0.95,
            un(C.panel[1]), un(C.panel[2]), un(C.panel[3]), 0.95,
            0)
    else
        Menu.Rect(x, y + bh - fadeH * 0.5, w, fadeH * 0.5, C.panel, 200, 0)
    end

    -- thin neon baseline: cyan -> gold horizontal gradient (with fallback)
    local pulse = Menu.Pulse(0.8, 150, 235) / 255
    local ly = y + bh - 2 * s
    if Susano and Susano.DrawRectGradient then
        Susano.DrawRectGradient(x, ly, w, 2 * s,
            un(C.accent[1]),  un(C.accent[2]),  un(C.accent[3]),  pulse,
            un(C.accent2[1]), un(C.accent2[2]), un(C.accent2[3]), pulse,
            un(C.accent2[1]), un(C.accent2[2]), un(C.accent2[3]), pulse,
            un(C.accent[1]),  un(C.accent[2]),  un(C.accent[3]),  pulse,
            0)
    else
        Menu.Rect(x, ly, w, 2 * s, C.accent, pulse * 255, 0)
    end

    -- brand bottom-left (classic cheat layout)
    local text, alpha = Menu.GetBrandAnim()
    if alpha > 0 then
        local size = 22
        local a    = math.floor(alpha * 255)
        local tx   = x + 16 * s
        local ty   = y + bh - (size * s) - 12 * s
        Menu.Text(tx + 1, ty + 1, text, size, {0, 0, 0}, math.floor(a * 0.6))
        Menu.Text(tx, ty, text, size, C.text, a)
        if alpha >= 1 then
            local bw = Menu.TextW(text, size)
            Menu.Text(tx + bw + 4 * s, ty + 4 * s, ".lua", 12, C.accent2, 235)
        end
    end
end

-- ─── DRAW: section bar ────────────────────────────────────────────────────────
function Menu.DrawSectionBar()
    local pos = Menu.GetScaledPosition()
    local s   = Menu.Scale or 1.0
    local x   = pos.x
    local y   = pos.y + pos.bannerHeight
    local w   = pos.width
    local h   = pos.sectionHeight

    Menu.Rect(x, y, w, h, C.panelTop, 255, 0)
    Menu.Rect(x, y + h - 1, w, 1, C.line, 255, 0)

    local label = string.upper(Menu.SectionName or "MENU")
    local size  = 11
    local ty    = y + h / 2 - (size * s) / 2
    Menu.Text(x + 16 * s, ty, label, size, C.textDim, 255)

    -- accent tick on the right (gold)
    local tickW = 22 * s
    Menu.Rect(x + w - tickW - 16 * s, y + h / 2 - 1, tickW, 2, C.accent2, 255, 0)
end

-- ─── Widgets ──────────────────────────────────────────────────────────────────
function Menu.DrawToggle(x, itemY, w, ih, item, isSel)
    local s  = Menu.Scale or 1.0
    local tW = 32 * s
    local tH = 16 * s
    local tX = x + w - tW - 16 * s
    local tY = itemY + ih / 2 - tH / 2
    local r  = tH / 2

    if item.value then
        Menu.Rect(tX, tY, tW, tH, C.accent, 255, r)
    else
        Menu.Rect(tX, tY, tW, tH, C.track, 255, r)
    end
    local k = tH - 4
    local kx = item.value and (tX + tW - k - 2) or (tX + 2)
    Menu.Rect(kx, tY + 2, k, k, {255, 255, 255}, 255, k / 2)
end

function Menu.DrawSliderTrack(x, itemY, w, ih, item, isSel, valueRightPad)
    local s   = Menu.Scale or 1.0
    local mn  = item.min   or item.sliderMin   or 0
    local mx  = item.max   or item.sliderMax   or 100
    local cv  = item.value or item.sliderValue or mn
    local pct = clamp((cv - mn) / math.max(0.0001, mx - mn), 0, 1)

    local slW = 96 * s
    local slH = 5  * s
    local slX = x + w - slW - (valueRightPad or 50) * s
    local slY = itemY + ih / 2 - slH / 2

    -- value text on far right
    local step = item.step or item.sliderStep
    local valText = (step and step >= 1) and string.format("%.0f", cv) or string.format("%.1f", cv)
    local valCol  = isSel and C.textOnAccent or C.text
    Menu.Text(slX + slW + 8 * s, slY - 4 * s, valText, 11, valCol, isSel and 255 or 220)

    Menu.Rect(slX, slY, slW, slH, isSel and {255,255,255} or C.track, isSel and 70 or 255, slH / 2)
    if pct > 0 then
        local fill = isSel and {255, 255, 255} or C.accent
        Menu.Rect(slX, slY, slW * pct, slH, fill, 255, slH / 2)
        local th = slH + 4 * s
        Menu.Rect(slX + slW * pct - th / 2, slY - 2 * s, th, th, fill, 255, th / 2)
    end
end

-- ─── DRAW: rows ───────────────────────────────────────────────────────────────
function Menu.DrawItem(x, itemY, w, ih, item, isSel)
    local s = Menu.Scale or 1.0

    if item.isSeparator then
        Menu.Rect(x, itemY, w, ih, C.panel, 255, 0)
        if item.separatorText then
            local tw = Menu.TextW(item.separatorText, 11)
            Menu.Text(x + w / 2 - tw / 2, itemY + ih / 2 - 6 * s, item.separatorText, 11, C.textDim, 180)
        end
        return
    end

    -- base row (alternating)
    local base = (item._idx and item._idx % 2 == 0) and C.rowAlt or C.row
    Menu.Rect(x, itemY, w, ih, base, 255, 0)

    if isSel then
        if Menu.SelectorY == 0 then Menu.SelectorY = itemY end
        Menu.SelectorY = Menu.SelectorY + (itemY - Menu.SelectorY) * Menu.SmoothFactor
        if math.abs(Menu.SelectorY - itemY) < 0.5 then Menu.SelectorY = itemY end
        local selY = Menu.SelectorY
        -- clean solid accent highlight + left bar
        Menu.Rect(x, selY, w, ih, C.accent, 255, 0)
        Menu.Rect(x, selY, 3 * s, ih, {255, 255, 255}, 230, 0)
    end

    local txtCol = isSel and C.textOnAccent or C.text
    local tx = x + 16 * s
    local ty = itemY + ih / 2 - 7 * s
    Menu.Text(tx, ty, item.name or "", 14, txtCol, 255)

    if item.type == "toggle" then
        if item.hasSlider then
            Menu.DrawSliderTrack(x, itemY, w, ih, item, isSel, 86)
        end
        Menu.DrawToggle(x, itemY, w, ih, item, isSel)
    elseif item.type == "slider" then
        Menu.DrawSliderTrack(x, itemY, w, ih, item, isSel, 50)
    elseif item.type == "action" then
        local hint = ">"
        local hw   = Menu.TextW(hint, 14)
        Menu.Text(x + w - hw - 16 * s, ty, hint, 14, txtCol, isSel and 255 or 140)
    end

    -- right-side badge (only when not a control occupies that space)
    if item.badge and item.type ~= "toggle" and item.type ~= "slider" then
        local bw = Menu.TextW(item.badge, 10) + 12 * s
        local bhh = 15 * s
        local bx = x + w - bw - 16 * s
        local by = itemY + ih / 2 - bhh / 2
        local bgCol = isSel and {255,255,255} or C.accent2
        Menu.Rect(bx, by, bw, bhh, bgCol, isSel and 60 or 40, 4)
        local btw = Menu.TextW(item.badge, 10)
        Menu.Text(bx + (bw - btw) / 2, by + bhh / 2 - 5 * s, item.badge, 10, isSel and C.textOnAccent or C.accent2, 235)
    end
end

function Menu.DrawItems()
    local pos    = Menu.GetScaledPosition()
    local s      = Menu.Scale or 1.0
    local x      = pos.x
    local startY = pos.y + pos.bannerHeight + pos.sectionHeight
    local w      = pos.width
    local ih     = pos.itemHeight
    local maxVis = Menu.ItemsPerPage

    local dlist = {}
    for i, item in ipairs(Menu.Items or {}) do
        if not item.isHeader then dlist[#dlist + 1] = { index = i, item = item } end
    end
    if #dlist == 0 then return end

    -- scroll offset is expressed in display-list slots
    local curDisplay = 0
    for slot, e in ipairs(dlist) do
        if e.index == Menu.CurrentItem then curDisplay = slot break end
    end
    if curDisplay > Menu.ItemScrollOffset + maxVis then
        Menu.ItemScrollOffset = curDisplay - maxVis
    elseif curDisplay <= Menu.ItemScrollOffset then
        Menu.ItemScrollOffset = math.max(0, curDisplay - 1)
    end

    local visCount = 0
    for slot = 1, math.min(maxVis, #dlist) do
        local e = dlist[slot + Menu.ItemScrollOffset]
        if e then
            visCount = visCount + 1
            e.item._idx = slot
            local iy = startY + (slot - 1) * ih
            Menu.DrawItem(x, iy, w, ih, e.item, e.index == Menu.CurrentItem)
        end
    end

    -- scrollbar
    if #dlist > maxVis then
        local totalH = visCount * ih
        local sbW = 3 * s
        local sbX = x + w - sbW - 2 * s
        Menu.Rect(sbX, startY, sbW, totalH, C.line, 200, sbW / 2)
        local thumbH = totalH * (maxVis / #dlist)
        local thumbY = startY + (Menu.ItemScrollOffset / #dlist) * totalH
        Menu.Rect(sbX, thumbY, sbW, thumbH, C.accent, 255, sbW / 2)
    end
end

-- ─── DRAW: footer ─────────────────────────────────────────────────────────────
function Menu.DrawFooter()
    local pos = Menu.GetScaledPosition()
    local s   = Menu.Scale or 1.0
    local x   = pos.x
    local y   = pos.y + pos.bannerHeight + pos.sectionHeight + Menu.GetContentHeight()
    local w   = pos.width
    local h   = pos.footerHeight

    Menu.Rect(x, y, w, h, C.panelTop, 255, 0)
    Menu.Rect(x, y, w, 1, C.line, 255, 0)

    local size = 11
    local ty   = y + h / 2 - (size * s) / 2
    Menu.Text(x + 14 * s, ty, "phantom.lua", size, C.accent, 230)

    local sel    = Menu.GetSelectableItems()
    local curPos = Menu.FindSelectablePosition(Menu.CurrentItem or 1)
    local pt     = string.format("%d / %d", curPos, math.max(#sel, 1))
    local ptw    = Menu.TextW(pt, size)
    Menu.Text(x + w - ptw - 14 * s, ty, pt, size, C.textDim, 220)
end

-- ─── Notifications ────────────────────────────────────────────────────────────
local NotifyQueue = {}
local NOTIFY_DUR  = 3200

local NOTIFY_CFG = {
    success = { c = {64, 220, 150}, title = "SUCCESS" },
    info    = { c = {45, 226, 230}, title = "INFO"    },
    warning = { c = {240, 184, 64}, title = "WARNING" },
    error   = { c = {245, 70, 70},  title = "ERROR"   },
}

function Menu.Notify(ntype, message, dur)
    if not message or message == "" then return end
    local cfg = NOTIFY_CFG[ntype or "info"] or NOTIFY_CFG.info
    NotifyQueue[#NotifyQueue + 1] = {
        title = cfg.title, message = tostring(message), c = cfg.c,
        spawn = GetGameTimer(), duration = dur or NOTIFY_DUR,
    }
end

function Menu.DrawNotifications()
    if not (Susano and Susano.DrawRectFilled and Susano.DrawText) then return end
    local sw  = (Susano.GetScreenWidth  and Susano.GetScreenWidth())  or 1920
    local sh  = (Susano.GetScreenHeight and Susano.GetScreenHeight()) or 1080
    local now = GetGameTimer()
    local boxW, boxH = 300, 60

    for i = #NotifyQueue, 1, -1 do
        if now - NotifyQueue[i].spawn > NotifyQueue[i].duration + 350 then
            table.remove(NotifyQueue, i)
        end
    end

    local baseY = sh - 28 - boxH
    local finX  = sw - 28 - boxW
    for idx, n in ipairs(NotifyQueue) do
        local boxY = baseY - (idx - 1) * (boxH + 10)
        if boxY < 40 then break end
        local e = now - n.spawn
        local alpha = 1.0
        if e < 220 then alpha = e / 220 end
        if e > n.duration then alpha = 1.0 - (e - n.duration) / 350 end
        alpha = clamp(alpha, 0, 1)
        local slide = (1 - alpha) * 40
        local bx = finX + slide

        Menu.Rect(bx, boxY, boxW, boxH, C.panel, 244 * alpha, 8)
        Menu.Rect(bx, boxY, 4, boxH, n.c, 255 * alpha, 0)
        Menu.Text(bx + 16, boxY + 11, n.title, 13, n.c, 255 * alpha)
        Menu.Text(bx + 16, boxY + 32, n.message, 12, C.text, 235 * alpha)
    end
end

-- ─── FEATURES ────────────────────────────────────────────────────────────────
local F = { animCancel = false }

-- 1) Anim Cancel (toggle): X tusuna (control 73) basinca animasyonu iptal eder
function F.SetAnimCancel(v)
    F.animCancel = v
    Menu.Notify(v and "success" or "info", "Anim Cancel: " .. (v and "ON" or "OFF"))
end

CreateThread(function()
    while true do
        Wait(0)
        if F.animCancel and IsControlJustPressed(0, 73) then
            ClearPedTasksImmediately(PlayerPedId())
        end
    end
end)

-- 2) Revive (action)
function F.Revive()
    CreateThread(function()
        Wait(1000)
        TriggerEvent('hospital:client:Revive')
        SetEntityHealth(PlayerPedId(), 200)
        SetPedArmour(PlayerPedId(), 100)
        CreateThread(function()
            Wait(2000)
            for i = 1, 5 do
                SetNotificationTextEntry("STRING")
                DrawNotification(false, true)
                Wait(1000)
            end
        end)
    end)
    Menu.Notify("success", "Revive tetiklendi")
end

-- ─── MENU ITEMS ──────────────────────────────────────────────────────────────
Menu.Items = {
    { isHeader = true, name = "MAIN" },
    { name = "Anim Cancel", type = "toggle", value = false, onClick = function(v) F.SetAnimCancel(v) end },
    { name = "Revive", type = "action", badge = "HEAL", onClick = function() F.Revive() end },
}

-- ─── RENDER ───────────────────────────────────────────────────────────────────
function Menu.Render()
    if not (Susano and Susano.BeginFrame) then return end
    Menu.UpdateSectionName()
    Menu.UpdateAnims()

    Susano.BeginFrame()

    if Menu.Visible then
        -- each section guarded independently so one failure can't blank the rest
        pcall(Menu.DrawPanel)
        pcall(Menu.DrawHeader)
        pcall(Menu.DrawSectionBar)
        pcall(Menu.DrawItems)
        pcall(Menu.DrawFooter)
    end

    pcall(Menu.DrawNotifications)

    if Menu.OnRender then pcall(Menu.OnRender) end
    if Susano.SubmitFrame then Susano.SubmitFrame() end

    if not Menu.Visible and not Menu.PreventResetFrame and Susano.ResetFrame then
        Susano.ResetFrame()
    end
end

-- ─── INPUT ────────────────────────────────────────────────────────────────────
Menu.KeyStates   = {}
Menu.RepeatState = {}
local REPEAT_DELAY    = 350
local REPEAT_INTERVAL = 90

function Menu.IsKeyJustPressed(key)
    if not (Susano and Susano.GetAsyncKeyState) then return false end
    local isDown = (Susano.GetAsyncKeyState(key)) == true
    local was = Menu.KeyStates[key] or false
    Menu.KeyStates[key] = isDown
    return isDown and not was
end

function Menu.IsKeyPressedOrRepeat(key)
    if not (Susano and Susano.GetAsyncKeyState) then return false end
    local isDown = (Susano.GetAsyncKeyState(key)) == true
    local st = Menu.RepeatState[key]
    if not st then st = { down = false, nextFire = 0 }; Menu.RepeatState[key] = st end
    local now = GetGameTimer()
    if isDown and not st.down then
        st.down = true
        st.nextFire = now + REPEAT_DELAY
        return true
    elseif isDown and st.down then
        if now >= st.nextFire then st.nextFire = now + REPEAT_INTERVAL return true end
        return false
    else
        st.down = false
        return false
    end
end

function Menu.HandleSliderChange(item, dir)
    if item.type == "slider" then
        local step = item.step or 1
        item.value = clamp((item.value or item.min or 0) + step * dir, item.min or 0, item.max or 100)
        if item.onClick then item.onClick(item.value) end
    elseif item.type == "toggle" and item.hasSlider then
        local step = item.sliderStep or 0.1
        item.sliderValue = clamp((item.sliderValue or item.sliderMin or 0) + step * dir, item.sliderMin or 0, item.sliderMax or 100)
        if item.onSliderChange then item.onSliderChange(item.sliderValue) end
    end
end

function Menu.ActivateCurrentItem()
    local item = Menu.Items[Menu.CurrentItem]
    if not Menu.IsSelectableItem(item) then return end
    if item.type == "toggle" then
        item.value = not item.value
        if item.onClick then item.onClick(item.value) end
    elseif item.type == "action" then
        if item.onClick then item.onClick() end
    end
end

function Menu.HandleInput()
    if not Menu.LoadingComplete then return end

    if Menu.IsKeyJustPressed(Menu.SelectedKey or 0x2D) then
        Menu.Visible = not Menu.Visible
        if Menu.Visible then
            if not Menu.IsSelectableItem(Menu.Items[Menu.CurrentItem]) then
                Menu.CurrentItem = Menu.FirstSelectableIndex()
            end
            Menu.UpdateSectionName()
        elseif Susano and Susano.ResetFrame and not Menu.PreventResetFrame then
            Susano.ResetFrame()
        end
    end

    if not Menu.Visible then return end

    if Menu.IsKeyPressedOrRepeat(0x26) then          -- Up
        Menu.CurrentItem = Menu.FindNextSelectable(Menu.CurrentItem, -1)
        Menu.UpdateSectionName()
    elseif Menu.IsKeyPressedOrRepeat(0x28) then      -- Down
        Menu.CurrentItem = Menu.FindNextSelectable(Menu.CurrentItem, 1)
        Menu.UpdateSectionName()
    elseif Menu.IsKeyPressedOrRepeat(0x25) then      -- Left
        local item = Menu.Items[Menu.CurrentItem]
        if item then Menu.HandleSliderChange(item, -1) end
    elseif Menu.IsKeyPressedOrRepeat(0x27) then      -- Right
        local item = Menu.Items[Menu.CurrentItem]
        if item then Menu.HandleSliderChange(item, 1) end
    elseif Menu.IsKeyJustPressed(0x0D) then          -- Enter
        Menu.ActivateCurrentItem()
    end
end

-- ─── MAIN THREAD ─────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Menu.Render()
        Menu.HandleInput()
        Wait(0)
    end
end)

if Menu.Banner.enabled and Menu.Banner.imageUrl ~= "" then
    Menu.LoadBannerTexture(Menu.Banner.imageUrl)
end

return Menu
