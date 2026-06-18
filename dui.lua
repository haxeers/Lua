-- phantom.lua | modern susano menu
-- banner: https://i.hizliresim.com/gmgbp7w.png

local Menu = {}

Menu.Visible         = false
Menu.CurrentItem     = 1
Menu.ItemScrollOffset= 0
Menu.ItemsPerPage    = 8
Menu.SelectorY       = 0
Menu.SmoothFactor    = 0.18
Menu.Scale           = 1.0
Menu.LoadingComplete = true
Menu.IsLoading       = false
Menu.SelectedKey     = 0x51   -- Q
Menu.SelectedKeyName = "Q"
Menu.SectionName     = "Menu"
Menu.Title           = "phantom"
Menu.BrandAnimStart  = nil
Menu.Items           = {}

-- Banner
Menu.Banner = {
    enabled  = true,
    imageUrl = "https://i.hizliresim.com/gmgbp7w.png",
    height   = 100
}
Menu.bannerTexture = nil
Menu.bannerWidth   = 0
Menu.bannerHeight  = 0

-- ─── Color theme ─────────────────────────────────────────────────────────────
-- All r/g/b values 0–255; alpha 0–255 or 0–1 passed directly to helpers
Menu.Colors = {
    Accent          = { r = 108, g = 60,  b = 255 },  -- #6C3CFF  violet
    AccentAlt       = { r = 60,  g = 120, b = 255 },  -- #3C78FF  blue
    AccentGlow      = { r = 108, g = 60,  b = 255, a = 55 },
    BackgroundDark  = { r = 7,   g = 7,   b = 14  },
    RowDark         = { r = 12,  g = 12,  b = 20  },
    RowAlt          = { r = 16,  g = 14,  b = 26  },
    TextWhite       = { r = 255, g = 255, b = 255 },
    TextDim         = { r = 160, g = 155, b = 190 },
    TextSelected    = { r = 255, g = 255, b = 255 },
    FooterBg        = { r = 5,   g = 5,   b = 10  },
    SectionBg       = { r = 10,  g = 9,   b = 18  },
}

-- ─── Layout ──────────────────────────────────────────────────────────────────
Menu.Position = {
    x              = 50,
    y              = 100,
    width          = 365,
    itemHeight     = 36,
    sectionHeight  = 28,
    headerHeight   = 100,
    footerHeight   = 28,
    footerSpacing  = 6,
    sectionSpacing = 0,
    footerRadius   = 6,
    itemRadius     = 0,
    headerRadius   = 10,
    scrollBarW     = 3,
}

function Menu.GetScaledPosition()
    local s = Menu.Scale or 1.0
    local p = Menu.Position
    return {
        x              = p.x,
        y              = p.y,
        width          = p.width          * s,
        itemHeight     = p.itemHeight     * s,
        sectionHeight  = p.sectionHeight  * s,
        headerHeight   = p.headerHeight   * s,
        footerHeight   = p.footerHeight   * s,
        footerSpacing  = p.footerSpacing  * s,
        sectionSpacing = p.sectionSpacing * s,
        footerRadius   = p.footerRadius   * s,
        itemRadius     = p.itemRadius     * s,
        headerRadius   = p.headerRadius   * s,
        scrollBarW     = p.scrollBarW     * s,
    }
end

-- ─── Texture loader ──────────────────────────────────────────────────────────
function Menu.LoadBannerTexture(url)
    if not url or url == "" then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end
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
local function u(v) return v > 1 and v / 255 or v end  -- 0-255 → 0-1

function Menu.DrawRect(x, y, w, h, r, g, b, a, rnd)
    if not (Susano and Susano.DrawRectFilled) then return end
    Susano.DrawRectFilled(x, y, w, h, u(r), u(g), u(b), u(a or 255), rnd or 0)
end

-- Gradient rect – colors in 0-255. Falls back to a solid rect if the
-- gradient native is unavailable, so highlights/sliders always stay visible.
function Menu.DrawGrad(x, y, w, h, r1,g1,b1,a1, r2,g2,b2,a2, r3,g3,b3,a3, r4,g4,b4,a4, rnd)
    if Susano and Susano.DrawRectGradient then
        Susano.DrawRectGradient(x, y, w, h,
            u(r1),u(g1),u(b1),u(a1 or 255),
            u(r2),u(g2),u(b2),u(a2 or 255),
            u(r3),u(g3),u(b3),u(a3 or 255),
            u(r4),u(g4),u(b4),u(a4 or 255),
            rnd or 0)
    else
        -- average the 4 corners for a reasonable solid color
        local ar = (r1 + r2 + r3 + r4) / 4
        local ag = (g1 + g2 + g3 + g4) / 4
        local ab = (b1 + b2 + b3 + b4) / 4
        local aa = ((a1 or 255) + (a2 or 255) + (a3 or 255) + (a4 or 255)) / 4
        Menu.DrawRect(x, y, w, h, ar, ag, ab, aa, rnd or 0)
    end
end

-- Glowing rect: draws a semi-transparent blurred "halo" then the solid rect
function Menu.DrawGlow(x, y, w, h, r, g, b, intensity, rnd)
    intensity = intensity or 0.18
    local a = math.floor(intensity * 255)
    for i = 1, 3 do
        local pad = i * 2.5
        Menu.DrawRect(x - pad, y - pad, w + pad*2, h + pad*2, r, g, b, a / i, (rnd or 0) + pad)
    end
end

function Menu.DrawText(x, y, text, size_px, r, g, b, a)
    local s = Menu.Scale or 1.0
    size_px = (size_px or 16) * s
    if Susano and Susano.DrawText then
        Susano.DrawText(x, y, text, size_px, u(r or 255), u(g or 255), u(b or 255), u(a or 255))
    end
end

function Menu.DrawTextOutlined(x, y, text, size_px, r, g, b, a)
    local s = Menu.Scale or 1.0
    size_px = (size_px or 16) * s
    if Susano and Susano.DrawTextOutlined then
        Susano.DrawTextOutlined(x, y, text, size_px, u(r or 255), u(g or 255), u(b or 255), u(a or 255))
    else
        Menu.DrawText(x, y, text, size_px / s, r, g, b, a)
    end
end

function Menu.DrawTextCentered(cx, y, text, size_px, r, g, b, a)
    local s = Menu.Scale or 1.0
    size_px = (size_px or 16) * s
    if Susano and Susano.DrawTextCentered then
        Susano.DrawTextCentered(cx, y, text, size_px, u(r or 255), u(g or 255), u(b or 255), u(a or 255))
    else
        local tw = Menu.GetTextWidth(text, size_px / s)
        Menu.DrawText(cx - tw / 2, y, text, size_px / s, r, g, b, a)
    end
end

function Menu.GetTextWidth(text, size_px)
    local s = Menu.Scale or 1.0
    size_px = (size_px or 16) * s
    if Susano and Susano.GetTextWidth then
        return Susano.GetTextWidth(text, size_px)
    end
    return string.len(text or "") * 8 * s
end

-- ─── Animation helpers ────────────────────────────────────────────────────────
function Menu.Pulse(speed, lo, hi)
    local t = GetGameTimer() / 1000.0
    local v = 0.5 + 0.5 * math.sin(t * (speed or 2) * math.pi)
    lo = lo or 0; hi = hi or 1
    return lo + v * (hi - lo)
end

function Menu.UpdateBrandAnim()
    if Menu.Visible then
        if not Menu.BrandAnimStart then Menu.BrandAnimStart = GetGameTimer() end
    else
        Menu.BrandAnimStart = nil
    end
end

function Menu.GetBrandAnim()
    local start   = Menu.BrandAnimStart or GetGameTimer()
    local elapsed = GetGameTimer() - start
    if elapsed < 350  then return "o",       math.min(1, elapsed / 250) end
    if elapsed < 750  then return "o",       1 end
    if elapsed < 1050 then return "o",       1 - ((elapsed - 750)  / 300) end
    if elapsed < 1550 then return "phantom", (elapsed - 1050) / 500 end
    return "phantom", 1
end

-- ─── Item helpers ─────────────────────────────────────────────────────────────
function Menu.IsSelectableItem(item)
    if not item then return false end
    return not (item.isHeader or item.isSeparator)
end

function Menu.GetSelectableItems()
    local list = {}
    for i, item in ipairs(Menu.Items or {}) do
        if Menu.IsSelectableItem(item) then
            table.insert(list, { index = i, item = item })
        end
    end
    return list
end

function Menu.FindSelectablePosition(targetIndex)
    for pos, entry in ipairs(Menu.GetSelectableItems()) do
        if entry.index == targetIndex then return pos end
    end
    return 1
end

function Menu.FirstSelectableIndex()
    local sel = Menu.GetSelectableItems()
    return sel[1] and sel[1].index or 1
end

function Menu.FindNextSelectable(startIndex, direction)
    local sel = Menu.GetSelectableItems()
    if #sel == 0 then return 1 end

    -- locate the current position; if startIndex is a header/non-selectable,
    -- snap to the nearest selectable so the first key press always moves.
    local cur = nil
    for pos, entry in ipairs(sel) do
        if entry.index == startIndex then cur = pos; break end
    end

    if not cur then
        -- startIndex is not selectable: pick the closest selectable in the
        -- requested direction without skipping an extra item.
        if direction > 0 then
            for pos, entry in ipairs(sel) do
                if entry.index > startIndex then return entry.index end
            end
            return sel[1].index
        else
            for pos = #sel, 1, -1 do
                if sel[pos].index < startIndex then return sel[pos].index end
            end
            return sel[#sel].index
        end
    end

    local nxt = cur + direction
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

-- ─── DRAW COMPONENTS ─────────────────────────────────────────────────────────

function Menu.DrawBackground()
    local pos = Menu.GetScaledPosition()
    local s   = Menu.Scale or 1.0
    local bh  = Menu.Banner.enabled and (Menu.Banner.height * s) or pos.headerHeight
    local total = bh + pos.sectionHeight + pos.sectionSpacing + Menu.GetContentHeight()
                + pos.footerSpacing + pos.footerHeight
    -- outer shadow
    Menu.DrawGlow(pos.x, pos.y, pos.width - 1, total,
        Menu.Colors.Accent.r, Menu.Colors.Accent.g, Menu.Colors.Accent.b, 0.08, pos.headerRadius)
    -- main bg
    Menu.DrawRect(pos.x, pos.y, pos.width - 1, total,
        Menu.Colors.BackgroundDark.r, Menu.Colors.BackgroundDark.g, Menu.Colors.BackgroundDark.b,
        252, pos.headerRadius)
end

function Menu.DrawHeader()
    local pos  = Menu.GetScaledPosition()
    local s    = Menu.Scale or 1.0
    local x, y = pos.x, pos.y
    local w    = pos.width - 1
    local bh   = Menu.Banner.enabled and (Menu.Banner.height * s) or pos.headerHeight
    local rnd  = pos.headerRadius

    -- banner image or animated gradient fallback
    if Menu.Banner.enabled and Menu.bannerTexture and Menu.bannerTexture > 0 and Susano and Susano.DrawImage then
        Susano.DrawImage(Menu.bannerTexture, x, y, w, bh, 1, 1, 1, 1, rnd)
        -- dark vignette overlay so text is readable
        Menu.DrawRect(x, y, w, bh, 0, 0, 0, 120, rnd)
    else
        -- animated 4-corner gradient
        local t  = GetGameTimer() / 3200.0
        local s1 = 0.5 + 0.5 * math.abs(math.sin(t * 1.1))
        local s2 = 0.5 + 0.5 * math.abs(math.sin(t * 0.7 + 1))
        -- top-left: accent violet
        local tl_r, tl_g, tl_b = 108 * s1, 60 * s1, 255 * s1
        -- top-right: accent blue
        local tr_r, tr_g, tr_b = 60 * s2, 120 * s2, 255 * s2
        -- bottom-right: dark
        local br_r, br_g, br_b = 7, 7, 14
        -- bottom-left: slightly lit
        local bl_r, bl_g, bl_b = 30 * s1, 20 * s1, 60 * s1

        Menu.DrawGrad(x, y, w, bh,
            tl_r, tl_g, tl_b, 255,
            tr_r, tr_g, tr_b, 255,
            br_r, br_g, br_b, 255,
            bl_r, bl_g, bl_b, 255,
            rnd)
    end

    -- accent glow line at bottom of header
    local pulse  = Menu.Pulse(1.2, 160, 255)
    local lineH  = 2 * s
    Menu.DrawGrad(x, y + bh - lineH, w, lineH,
        Menu.Colors.Accent.r,    Menu.Colors.Accent.g,    Menu.Colors.Accent.b,    pulse,
        Menu.Colors.AccentAlt.r, Menu.Colors.AccentAlt.g, Menu.Colors.AccentAlt.b, pulse,
        Menu.Colors.AccentAlt.r, Menu.Colors.AccentAlt.g, Menu.Colors.AccentAlt.b, pulse,
        Menu.Colors.Accent.r,    Menu.Colors.Accent.g,    Menu.Colors.Accent.b,    pulse,
        0)

    -- brand text (animated on open)
    local text, alpha = Menu.GetBrandAnim()
    if alpha > 0 then
        local titleSize = 34
        local a255  = math.floor(alpha * 255)
        local cx    = x + w / 2
        local cy    = y + bh / 2 - (titleSize * s) / 2
        -- soft drop shadow
        Menu.DrawTextCentered(cx + 1, cy + 1, text, titleSize, 0, 0, 0, math.floor(a255 * 0.5))
        Menu.DrawTextOutlined(cx - Menu.GetTextWidth(text, titleSize) / 2, cy, text, titleSize, 255, 255, 255, a255)
    end
end

function Menu.DrawSectionBar()
    local pos = Menu.GetScaledPosition()
    local s   = Menu.Scale or 1.0
    local x   = pos.x
    local bh  = Menu.Banner.enabled and (Menu.Banner.height * s) or pos.headerHeight
    local y   = pos.y + bh
    local w   = pos.width - 1
    local h   = pos.sectionHeight

    -- gradient section bar
    Menu.DrawGrad(x, y, w, h,
        Menu.Colors.SectionBg.r + 8, Menu.Colors.SectionBg.g + 6, Menu.Colors.SectionBg.b + 18, 255,
        Menu.Colors.SectionBg.r + 8, Menu.Colors.SectionBg.g + 6, Menu.Colors.SectionBg.b + 18, 255,
        Menu.Colors.SectionBg.r,     Menu.Colors.SectionBg.g,     Menu.Colors.SectionBg.b,     255,
        Menu.Colors.SectionBg.r,     Menu.Colors.SectionBg.g,     Menu.Colors.SectionBg.b,     255,
        0)

    -- small accent dot before section name
    local dotSize = 5 * s
    local dotX    = x + 12 * s
    local dotY    = y + h / 2 - dotSize / 2
    local dp      = Menu.Pulse(1.5, 180, 255)
    Menu.DrawRect(dotX, dotY, dotSize, dotSize,
        Menu.Colors.Accent.r, Menu.Colors.Accent.g, Menu.Colors.Accent.b, dp, dotSize / 2)

    local textSize = 13
    local textY    = y + h / 2 - (textSize * s) / 2
    Menu.DrawText(dotX + dotSize + 7 * s, textY, Menu.SectionName or "Menu",
        textSize, Menu.Colors.TextDim.r, Menu.Colors.TextDim.g, Menu.Colors.TextDim.b, 255)
end

-- Toggle widget
function Menu.DrawToggle(x, itemY, w, ih, item, isSel)
    local s         = Menu.Scale or 1.0
    local tW, tH   = 36 * s, 16 * s
    local tX        = x + w - tW - (16 * s)
    local tY        = itemY + ih / 2 - tH / 2
    local tRnd      = tH / 2

    if item.value then
        Menu.DrawRect(tX, tY, tW, tH,
            Menu.Colors.Accent.r, Menu.Colors.Accent.g, Menu.Colors.Accent.b, 240, tRnd)
        -- glow when on
        Menu.DrawGlow(tX, tY, tW, tH,
            Menu.Colors.Accent.r, Menu.Colors.Accent.g, Menu.Colors.Accent.b, 0.12, tRnd)
    else
        Menu.DrawRect(tX, tY, tW, tH, 35, 33, 52, 240, tRnd)
    end

    local knobSize = tH - 4
    local knobY    = tY + 2
    local knobX    = item.value and (tX + tW - knobSize - 2) or (tX + 2)
    Menu.DrawRect(knobX, knobY, knobSize, knobSize,
        255, 255, 255, 255, knobSize / 2)

    -- optional inline slider
    if item.hasSlider then
        local slW   = 85 * s
        local slH   = 5  * s
        local slX   = x  + w - slW - (95 * s)
        local slY   = itemY + ih / 2 - slH / 2
        local mn    = item.sliderMin  or 0
        local mx    = item.sliderMax  or 100
        local cv    = item.sliderValue or mn
        local pct   = math.max(0, math.min(1, (cv - mn) / math.max(0.0001, mx - mn)))
        Menu.DrawRect(slX, slY, slW, slH, 40, 38, 55, 180, 3)
        if pct > 0 then
            Menu.DrawGrad(slX, slY, slW * pct, slH,
                Menu.Colors.Accent.r,    Menu.Colors.Accent.g,    Menu.Colors.Accent.b,    255,
                Menu.Colors.AccentAlt.r, Menu.Colors.AccentAlt.g, Menu.Colors.AccentAlt.b, 255,
                Menu.Colors.AccentAlt.r, Menu.Colors.AccentAlt.g, Menu.Colors.AccentAlt.b, 255,
                Menu.Colors.Accent.r,    Menu.Colors.Accent.g,    Menu.Colors.Accent.b,    255,
                3)
        end
        local valText = (item.sliderStep and item.sliderStep >= 1)
                        and string.format("%.0f", cv) or string.format("%.1f", cv)
        local vr, vg, vb = isSel and 0 or 200, isSel and 0 or 195, isSel and 0 or 230
        Menu.DrawText(slX + slW + 6 * s, slY - 1, valText, 10, vr, vg, vb, 210)
    end
end

-- Standalone slider widget
function Menu.DrawSlider(x, itemY, w, ih, item, isSel)
    local s   = Menu.Scale or 1.0
    local slW = 110 * s
    local slH = 6   * s
    local slX = x + w - slW - (60 * s)
    local slY = itemY + ih / 2 - slH / 2
    local mn  = item.min   or 0
    local mx  = item.max   or 100
    local cv  = item.value or mn
    local pct = math.max(0, math.min(1, (cv - mn) / math.max(0.0001, mx - mn)))

    Menu.DrawRect(slX, slY, slW, slH, 40, 38, 55, 180, 3)
    if pct > 0 then
        Menu.DrawGrad(slX, slY, slW * pct, slH,
            Menu.Colors.Accent.r,    Menu.Colors.Accent.g,    Menu.Colors.Accent.b,    255,
            Menu.Colors.AccentAlt.r, Menu.Colors.AccentAlt.g, Menu.Colors.AccentAlt.b, 255,
            Menu.Colors.AccentAlt.r, Menu.Colors.AccentAlt.g, Menu.Colors.AccentAlt.b, 255,
            Menu.Colors.Accent.r,    Menu.Colors.Accent.g,    Menu.Colors.Accent.b,    255,
            3)
        -- thumb dot
        local thumbR = slH
        Menu.DrawRect(slX + slW * pct - thumbR / 2, slY - (thumbR - slH) / 2,
            thumbR, thumbR,
            Menu.Colors.Accent.r, Menu.Colors.Accent.g, Menu.Colors.Accent.b, 255, thumbR / 2)
    end

    local valText = (item.step and item.step >= 1) and string.format("%.0f", cv) or string.format("%.1f", cv)
    local vr, vg, vb = isSel and 0 or 200, isSel and 0 or 195, isSel and 0 or 230
    Menu.DrawText(slX + slW + 7 * s, slY - 1, valText, 10, vr, vg, vb, 210)
end

function Menu.DrawItem(x, itemY, w, ih, item, isSel)
    local s = Menu.Scale or 1.0

    if item.isHeader then return end

    if item.isSeparator then
        Menu.DrawRect(x, itemY, w, ih,
            Menu.Colors.BackgroundDark.r, Menu.Colors.BackgroundDark.g, Menu.Colors.BackgroundDark.b, 40, 0)
        if item.separatorText then
            local tw  = Menu.GetTextWidth(item.separatorText, 12)
            local sep_x = x + (w / 2) - (tw / 2)
            local sep_y = itemY + ih / 2 - 6 * s
            Menu.DrawText(sep_x, sep_y, item.separatorText, 12,
                Menu.Colors.TextDim.r, Menu.Colors.TextDim.g, Menu.Colors.TextDim.b, 160)
        end
        return
    end

    -- alternating row tint
    local rowAlpha = (item._idx and item._idx % 2 == 0) and 255 or 240
    Menu.DrawRect(x, itemY, w, ih,
        Menu.Colors.RowDark.r, Menu.Colors.RowDark.g, Menu.Colors.RowDark.b, rowAlpha, 0)

    if isSel then
        -- smooth selector
        if Menu.SelectorY == 0 then Menu.SelectorY = itemY end
        Menu.SelectorY = Menu.SelectorY + (itemY - Menu.SelectorY) * Menu.SmoothFactor
        if math.abs(Menu.SelectorY - itemY) < 0.5 then Menu.SelectorY = itemY end

        -- accent gradient background for selected
        local selY = Menu.SelectorY
        Menu.DrawGrad(x, selY, w, ih,
            Menu.Colors.Accent.r,    Menu.Colors.Accent.g,    Menu.Colors.Accent.b,    220,
            Menu.Colors.AccentAlt.r, Menu.Colors.AccentAlt.g, Menu.Colors.AccentAlt.b, 200,
            Menu.Colors.AccentAlt.r, Menu.Colors.AccentAlt.g, Menu.Colors.AccentAlt.b, 200,
            Menu.Colors.Accent.r,    Menu.Colors.Accent.g,    Menu.Colors.Accent.b,    220,
            0)

        -- left accent bar
        Menu.DrawRect(x, selY, 3 * s, ih,
            255, 255, 255, 200, 0)
    end

    local tr, tg, tb = 255, 255, 255
    if isSel then tr, tg, tb = 255, 255, 255 end

    local textX = x + 16 * s
    local textY = itemY + ih / 2 - 8 * s
    Menu.DrawText(textX, textY, item.name or "", 15, tr, tg, tb, 255)

    if item.type == "toggle" then
        Menu.DrawToggle(x, itemY, w, ih, item, isSel)
    elseif item.type == "slider" then
        Menu.DrawSlider(x, itemY, w, ih, item, isSel)
    elseif item.type == "action" then
        local hint = "›"
        local hw   = Menu.GetTextWidth(hint, 16)
        local ha   = isSel and 255 or 100
        Menu.DrawText(x + w - hw - 16 * s, textY, hint, 16,
            Menu.Colors.Accent.r, Menu.Colors.Accent.g, Menu.Colors.Accent.b, ha)
    end

    -- right-side description / value badge
    if item.badge then
        local bw   = Menu.GetTextWidth(item.badge, 11) + 14 * s
        local bh2  = 16 * s
        local bx   = x + w - bw - 16 * s
        local by   = itemY + ih / 2 - bh2 / 2
        Menu.DrawRect(bx, by, bw, bh2,
            Menu.Colors.Accent.r, Menu.Colors.Accent.g, Menu.Colors.Accent.b, 40, 4)
        local btw = Menu.GetTextWidth(item.badge, 11)
        Menu.DrawText(bx + (bw - btw) / 2, by + bh2 / 2 - 5 * s, item.badge, 11,
            Menu.Colors.Accent.r, Menu.Colors.Accent.g, Menu.Colors.Accent.b, 220)
    end
end

function Menu.GetContentHeight()
    local pos     = Menu.GetScaledPosition()
    local visible = 0
    for _, item in ipairs(Menu.Items or {}) do
        if not item.isHeader then
            visible = visible + 1
            if visible >= Menu.ItemsPerPage then break end
        end
    end
    return math.max(visible, 1) * pos.itemHeight
end

function Menu.DrawItems()
    local pos     = Menu.GetScaledPosition()
    local s       = Menu.Scale or 1.0
    local x       = pos.x
    local bh      = Menu.Banner.enabled and (Menu.Banner.height * s) or pos.headerHeight
    local startY  = pos.y + bh + pos.sectionHeight + pos.sectionSpacing
    local w       = pos.width - 1
    local ih      = pos.itemHeight
    local maxVis  = Menu.ItemsPerPage

    local dlist = {}
    for i, item in ipairs(Menu.Items or {}) do
        if not item.isHeader then
            table.insert(dlist, { index = i, item = item })
        end
    end
    if #dlist == 0 then return end

    if Menu.CurrentItem > Menu.ItemScrollOffset + maxVis then
        Menu.ItemScrollOffset = Menu.CurrentItem - maxVis
    elseif Menu.CurrentItem <= Menu.ItemScrollOffset then
        Menu.ItemScrollOffset = math.max(0, Menu.CurrentItem - 1)
    end

    local visCount = 0
    for slot = 1, math.min(maxVis, #dlist) do
        local entry = dlist[slot + Menu.ItemScrollOffset]
        if entry then
            visCount = visCount + 1
            entry.item._idx = slot
            local iy  = startY + (slot - 1) * ih
            local sel = entry.index == Menu.CurrentItem
            Menu.DrawItem(x, iy, w, ih, entry.item, sel)
        end
    end

    -- scrollbar
    if #dlist > maxVis then
        local totalH  = visCount * ih
        local sbW     = pos.scrollBarW
        local sbX     = x + w - sbW - 2 * s
        local sbTrackY = startY
        Menu.DrawRect(sbX, sbTrackY, sbW, totalH, 30, 28, 45, 180, sbW / 2)

        local thumbH = totalH * (maxVis / #dlist)
        local thumbY = sbTrackY + (Menu.ItemScrollOffset / #dlist) * totalH
        Menu.DrawGrad(sbX, thumbY, sbW, thumbH,
            Menu.Colors.Accent.r,    Menu.Colors.Accent.g,    Menu.Colors.Accent.b,    255,
            Menu.Colors.AccentAlt.r, Menu.Colors.AccentAlt.g, Menu.Colors.AccentAlt.b, 255,
            Menu.Colors.AccentAlt.r, Menu.Colors.AccentAlt.g, Menu.Colors.AccentAlt.b, 255,
            Menu.Colors.Accent.r,    Menu.Colors.Accent.g,    Menu.Colors.Accent.b,    255,
            sbW / 2)
    end
end

function Menu.DrawFooter()
    local pos  = Menu.GetScaledPosition()
    local s    = Menu.Scale or 1.0
    local x    = pos.x
    local bh   = Menu.Banner.enabled and (Menu.Banner.height * s) or pos.headerHeight
    local y    = pos.y + bh + pos.sectionHeight + pos.sectionSpacing + Menu.GetContentHeight() + pos.footerSpacing
    local fw   = pos.width - 1
    local fh   = pos.footerHeight
    local rnd  = pos.footerRadius

    -- gradient footer
    Menu.DrawGrad(x, y, fw, fh,
        Menu.Colors.FooterBg.r + 5, Menu.Colors.FooterBg.g + 4, Menu.Colors.FooterBg.b + 12, 255,
        Menu.Colors.FooterBg.r + 5, Menu.Colors.FooterBg.g + 4, Menu.Colors.FooterBg.b + 12, 255,
        Menu.Colors.FooterBg.r,     Menu.Colors.FooterBg.g,     Menu.Colors.FooterBg.b,     255,
        Menu.Colors.FooterBg.r,     Menu.Colors.FooterBg.g,     Menu.Colors.FooterBg.b,     255,
        rnd)

    local fs         = 12
    local textY      = y + fh / 2 - (fs * s) / 2
    local brand, alpha = Menu.GetBrandAnim()
    local suffix     = (alpha >= 1 and brand == "phantom") and ".lua" or ""
    local a255       = math.floor(alpha * 255)

    -- brand name in accent color
    Menu.DrawText(x + 14 * s, textY, brand .. suffix, fs,
        Menu.Colors.Accent.r, Menu.Colors.Accent.g, Menu.Colors.Accent.b, a255)

    -- position counter right
    local sel      = Menu.GetSelectableItems()
    local curPos   = Menu.FindSelectablePosition(Menu.CurrentItem or 1)
    local posText  = string.format("%d / %d", curPos, math.max(#sel, 1))
    local ptw      = Menu.GetTextWidth(posText, fs)
    Menu.DrawText(x + fw - ptw - 14 * s, textY, posText, fs,
        Menu.Colors.TextDim.r, Menu.Colors.TextDim.g, Menu.Colors.TextDim.b, 200)
end

-- ─── Notifications ────────────────────────────────────────────────────────────
local NotifyQueue = {}
local NOTIFY_DUR  = 3500

local NOTIFY_CFG = {
    success = { r = 0.25, g = 0.85, b = 0.45, title = "SUCCESS" },
    info    = { r = 0.42, g = 0.24, b = 1.00, title = "INFO"    },
    warning = { r = 0.95, g = 0.75, b = 0.20, title = "WARNING" },
    error   = { r = 0.95, g = 0.25, b = 0.25, title = "ERROR"   },
}

function Menu.Notify(ntype, message, dur)
    if not message or message == "" then return end
    ntype = ntype or "info"
    local cfg = NOTIFY_CFG[ntype] or NOTIFY_CFG.info
    dur = dur or NOTIFY_DUR
    table.insert(NotifyQueue, 1, {
        type      = ntype,
        title     = cfg.title,
        message   = tostring(message),
        spawnTime = GetGameTimer(),
        duration  = dur,
        r = cfg.r, g = cfg.g, b = cfg.b
    })
end

function Menu.DrawNotifications()
    if not (Susano and Susano.DrawRectFilled and Susano.DrawText) then return end
    local sw    = (Susano.GetScreenWidth  and Susano.GetScreenWidth())  or 1920
    local sh    = (Susano.GetScreenHeight and Susano.GetScreenHeight()) or 1080
    local now   = GetGameTimer()
    local boxW  = 330
    local boxH  = 70
    local baseY = sh - 24 - boxH
    local finX  = sw - 24 - boxW

    for i = #NotifyQueue, 1, -1 do
        local n = NotifyQueue[i]
        if now - n.spawnTime > n.duration + 350 then
            table.remove(NotifyQueue, i)
        end
    end

    for idx, n in ipairs(NotifyQueue) do
        local boxY   = baseY - (idx - 1) * (boxH + 10)
        if boxY < 40 then break end
        local elapsed = now - n.spawnTime
        local alpha   = 1.0
        if elapsed < 280 then alpha = elapsed / 280 end
        if elapsed > n.duration then alpha = 1.0 - (elapsed - n.duration) / 350 end
        alpha = math.max(0, math.min(1, alpha))

        -- bg with rounded corners
        Susano.DrawRectFilled(finX,     boxY, boxW, boxH, 0.05, 0.05, 0.08, 0.95 * alpha, 6)
        -- accent left bar
        Susano.DrawRectFilled(finX,     boxY, 4,    boxH, n.r,  n.g,  n.b,  1.0  * alpha, 0)
        -- top glow line
        Susano.DrawRectFilled(finX + 4, boxY, boxW - 4, 1, n.r, n.g, n.b, 0.5 * alpha, 0)
        -- title
        Susano.DrawText(finX + 18, boxY + 13, n.title,   15, n.r, n.g,  n.b,  1.0 * alpha)
        -- message
        Susano.DrawText(finX + 18, boxY + 36, n.message, 13, 0.9, 0.88, 0.95, 0.9 * alpha)
    end
end

-- ─── FREECAM SYSTEM ──────────────────────────────────────────────────────────
local FreeCam = {
    active    = false,
    x = 0.0, y = 0.0, z = 0.0,
    speed     = 8.0,
}

function FreeCam.Enable()
    if not (Susano and Susano.LockCameraPos and Susano.SetCameraPos) then
        Menu.Notify("error", "FreeCam: Susano API unavailable")
        return
    end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped, true)
    FreeCam.x = pos.x
    FreeCam.y = pos.y
    FreeCam.z = pos.z + 1.5
    Susano.LockCameraPos(true)
    Susano.SetCameraPos(FreeCam.x, FreeCam.y, FreeCam.z)
    FreeCam.active = true
    Menu.Notify("success", "FreeCam enabled  [WASD/Space/Ctrl]")
end

function FreeCam.Disable()
    FreeCam.active = false
    if Susano and Susano.LockCameraPos then
        Susano.LockCameraPos(false)
    end
    Menu.Notify("info", "FreeCam disabled")
end

function FreeCam.Update()
    if not FreeCam.active then return end
    if not (Susano and Susano.GetCameraAngles and Susano.SetCameraPos and Susano.GetAsyncKeyState) then return end

    local ax, ay, az = Susano.GetCameraAngles()
    -- az = yaw heading
    local yawRad   = math.rad(az or 0)
    local dt       = 0.016   -- ~60 fps assumption

    local wDown  = select(1, Susano.GetAsyncKeyState(0x57))  -- W
    local sDown  = select(1, Susano.GetAsyncKeyState(0x53))  -- S
    local aDown  = select(1, Susano.GetAsyncKeyState(0x41))  -- A
    local dDown  = select(1, Susano.GetAsyncKeyState(0x44))  -- D
    local spDown = select(1, Susano.GetAsyncKeyState(0x20))  -- Space
    local ctDown = select(1, Susano.GetAsyncKeyState(0x11))  -- Ctrl
    local shDown = select(1, Susano.GetAsyncKeyState(0x10))  -- Shift (boost)

    local spd = FreeCam.speed * (shDown and 3.5 or 1.0) * dt

    local mx, my, mz = 0.0, 0.0, 0.0
    if wDown  then mx = mx + math.sin(yawRad) * spd;  my = my + math.cos(yawRad) * spd  end
    if sDown  then mx = mx - math.sin(yawRad) * spd;  my = my - math.cos(yawRad) * spd  end
    if aDown  then mx = mx - math.cos(yawRad) * spd;  my = my + math.sin(yawRad) * spd  end
    if dDown  then mx = mx + math.cos(yawRad) * spd;  my = my - math.sin(yawRad) * spd  end
    if spDown then mz = mz + spd end
    if ctDown then mz = mz - spd end

    FreeCam.x = FreeCam.x + mx
    FreeCam.y = FreeCam.y + my
    FreeCam.z = FreeCam.z + mz

    Susano.SetCameraPos(FreeCam.x, FreeCam.y, FreeCam.z)
end

-- ─── FEATURE CALLBACKS ───────────────────────────────────────────────────────
local Features = {}

-- God Mode
Features.godMode = false
function Features.SetGodMode(state)
    Features.godMode = state
    local ped = PlayerPedId()
    SetEntityInvincible(ped, state)
    SetPlayerInvincible(PlayerId(), state)
    Menu.Notify(state and "success" or "info", "God Mode: " .. (state and "ON" or "OFF"))
end

-- Speed Hack
Features.speedActive = false
Features.speedMult   = 1.5
function Features.SetSpeed(state, mult)
    Features.speedActive = state
    Features.speedMult   = mult or Features.speedMult
    local ped = PlayerPedId()
    if state then
        SetPedMoveRateOverride(ped, Features.speedMult)
    else
        SetPedMoveRateOverride(ped, 1.0)
    end
    if state then Menu.Notify("success", string.format("Speed x%.1f enabled", Features.speedMult)) end
end

-- No Ragdoll
Features.noRagdoll = false
function Features.SetNoRagdoll(state)
    Features.noRagdoll = state
    local ped = PlayerPedId()
    SetPedCanRagdoll(ped, not state)
    Menu.Notify(state and "success" or "info", "No Ragdoll: " .. (state and "ON" or "OFF"))
end

-- Invisible
Features.invisible = false
function Features.SetInvisible(state)
    Features.invisible = state
    local ped = PlayerPedId()
    if state then
        SetEntityAlpha(ped, 0, false)
    else
        ResetEntityAlpha(ped)
    end
    Menu.Notify(state and "success" or "info", "Invisible: " .. (state and "ON" or "OFF"))
end

-- Teleport to Waypoint
function Features.TeleportToWaypoint()
    local blip = GetFirstBlipInfoId(8)
    if blip and DoesBlipExist(blip) then
        local coords = GetBlipInfoIdCoord(blip)
        local ped    = PlayerPedId()
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        SetEntityCoords(ped, coords.x, coords.y, coords.z + 1.0, false, false, false, true)
        Menu.Notify("success", "Teleported to waypoint")
    else
        Menu.Notify("warning", "No waypoint set on map")
    end
end

-- Noclip (simple move-by-camera)
Features.noclip = false
Features.noclipZ = 0.0
function Features.SetNoclip(state)
    Features.noclip = state
    local ped = PlayerPedId()
    SetEntityCollision(ped, not state, true)
    if not state then
        FreezeEntityPosition(ped, false)
    end
    Menu.Notify(state and "success" or "info", "NoClip: " .. (state and "ON" or "OFF"))
end

function Features.UpdateNoclip()
    if not Features.noclip then return end
    if not (Susano and Susano.GetCameraAngles and Susano.GetAsyncKeyState) then return end

    local ax, ay, az = Susano.GetCameraAngles()
    local yawRad     = math.rad(az or 0)
    local dt         = 0.016

    local wDown  = select(1, Susano.GetAsyncKeyState(0x57))
    local sDown  = select(1, Susano.GetAsyncKeyState(0x53))
    local aDown  = select(1, Susano.GetAsyncKeyState(0x41))
    local dDown  = select(1, Susano.GetAsyncKeyState(0x44))
    local spDown = select(1, Susano.GetAsyncKeyState(0x20))
    local ctDown = select(1, Susano.GetAsyncKeyState(0x11))
    local shDown = select(1, Susano.GetAsyncKeyState(0x10))

    local spd = 6.0 * (shDown and 3.5 or 1.0) * dt
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped, true)
    local mx, my, mz = 0.0, 0.0, 0.0

    if wDown  then mx = mx + math.sin(yawRad) * spd;  my = my + math.cos(yawRad) * spd  end
    if sDown  then mx = mx - math.sin(yawRad) * spd;  my = my - math.cos(yawRad) * spd  end
    if aDown  then mx = mx - math.cos(yawRad) * spd;  my = my + math.sin(yawRad) * spd  end
    if dDown  then mx = mx + math.cos(yawRad) * spd;  my = my - math.sin(yawRad) * spd  end
    if spDown then mz = mz + spd end
    if ctDown then mz = mz - spd end

    if mx ~= 0 or my ~= 0 or mz ~= 0 then
        SetEntityVelocity(ped, 0, 0, 0)
        SetEntityCoords(ped, pos.x + mx, pos.y + my, pos.z + mz, false, false, false, false)
    else
        FreezeEntityPosition(ped, true)
    end
end

-- ─── MENU ITEMS ──────────────────────────────────────────────────────────────
Menu.Items = {
    -- ── PLAYER ──
    { isHeader = true, name = "PLAYER" },
    {
        name  = "God Mode",
        type  = "toggle",
        value = false,
        badge = "PLAYER",
        onClick = function(v) Features.SetGodMode(v) end
    },
    {
        name  = "No Ragdoll",
        type  = "toggle",
        value = false,
        onClick = function(v) Features.SetNoRagdoll(v) end
    },
    {
        name  = "Invisible",
        type  = "toggle",
        value = false,
        onClick = function(v) Features.SetInvisible(v) end
    },
    {
        name      = "Speed Hack",
        type      = "toggle",
        value     = false,
        hasSlider = true,
        sliderMin = 1.0,
        sliderMax = 5.0,
        sliderValue = 1.5,
        sliderStep  = 0.1,
        onClick = function(v)
            local item = Menu.Items[Menu.CurrentItem]
            Features.SetSpeed(v, item and item.sliderValue or 1.5)
        end,
        onSliderChange = function(v)
            Features.speedMult = v
            if Features.speedActive then
                SetPedMoveRateOverride(PlayerPedId(), v)
            end
        end
    },
    {
        name  = "No Clip",
        type  = "toggle",
        value = false,
        badge = "BETA",
        onClick = function(v) Features.SetNoclip(v) end
    },

    -- ── WORLD ──
    { isHeader = true, name = "WORLD" },
    {
        name  = "FreeCam",
        type  = "toggle",
        value = false,
        badge = "CAM",
        onClick = function(v)
            if v then FreeCam.Enable() else FreeCam.Disable() end
        end
    },
    {
        name  = "FreeCam Speed",
        type  = "slider",
        value = 8.0,
        min   = 1.0,
        max   = 50.0,
        step  = 0.5,
        onClick = function(v)
            FreeCam.speed = v
        end
    },
    {
        name  = "Teleport to Waypoint",
        type  = "action",
        onClick = function() Features.TeleportToWaypoint() end
    },

    -- ── MISC ──
    { isHeader = true, name = "MISC" },
    {
        name  = "Test Notification",
        type  = "action",
        onClick = function()
            Menu.Notify("success", "phantom is loaded  ✓")
        end
    },
    {
        name  = "Menu Scale",
        type  = "slider",
        value = 1.0,
        min   = 0.8,
        max   = 1.4,
        step  = 0.05,
        onClick = function(v)
            Menu.Scale = v
        end
    },
}

-- ─── RENDER ───────────────────────────────────────────────────────────────────
function Menu.Render()
    if not (Susano and Susano.BeginFrame) then return end

    Menu.UpdateSectionName()
    Menu.UpdateBrandAnim()

    Susano.BeginFrame()

    if Menu.Visible then
        -- guard drawing so a single bad native can never freeze input
        pcall(function()
            Menu.DrawBackground()
            Menu.DrawHeader()
            Menu.DrawSectionBar()
            Menu.DrawItems()
            Menu.DrawFooter()
        end)
    end

    pcall(Menu.DrawNotifications)

    if Menu.OnRender then pcall(Menu.OnRender) end

    if Susano.SubmitFrame then Susano.SubmitFrame() end

    if not Menu.Visible and not Menu.PreventResetFrame then
        if Susano.ResetFrame then Susano.ResetFrame() end
    end
end

-- ─── INPUT ────────────────────────────────────────────────────────────────────
Menu.KeyStates = {}

function Menu.IsKeyJustPressed(key)
    if not (Susano and Susano.GetAsyncKeyState) then return false end
    local down, pressed = Susano.GetAsyncKeyState(key)
    local was = Menu.KeyStates[key] or false
    Menu.KeyStates[key] = down == true
    if pressed == true then return true end
    if down == true and not was then return true end
    return false
end

function Menu.HandleSliderChange(item, dir)
    if item.type == "slider" then
        local step = item.step or 1
        item.value = math.max(item.min or 0, math.min(item.max or 100,
            (item.value or item.min or 0) + step * dir))
        if item.onClick then item.onClick(item.value) end
    elseif item.type == "toggle" and item.hasSlider then
        local step = item.sliderStep or 0.1
        item.sliderValue = math.max(item.sliderMin or 0, math.min(item.sliderMax or 100,
            (item.sliderValue or item.sliderMin or 0) + step * dir))
        if item.onSliderChange then item.onSliderChange(item.sliderValue) end
    end
end

function Menu.ActivateCurrentItem()
    local item = Menu.Items[Menu.CurrentItem]
    if not item or not Menu.IsSelectableItem(item) then return end
    if item.type == "toggle" then
        item.value = not item.value
        if item.onClick then item.onClick(item.value) end
    elseif item.type == "action" then
        if item.onClick then item.onClick() end
    end
end

function Menu.HandleInput()
    if not Menu.LoadingComplete then return end

    if Menu.IsKeyJustPressed(Menu.SelectedKey or 0x51) then
        Menu.Visible = not Menu.Visible
        if Menu.Visible then
            -- make sure we open on a real, selectable item (not a header)
            if not Menu.IsSelectableItem(Menu.Items[Menu.CurrentItem]) then
                Menu.CurrentItem = Menu.FirstSelectableIndex()
            end
            Menu.UpdateSectionName()
        elseif Susano and Susano.ResetFrame and not Menu.PreventResetFrame then
            Susano.ResetFrame()
        end
    end

    if not Menu.Visible then return end

    if Menu.IsKeyJustPressed(0x26) then            -- Arrow Up
        Menu.CurrentItem = Menu.FindNextSelectable(Menu.CurrentItem, -1)
        Menu.UpdateSectionName()
    elseif Menu.IsKeyJustPressed(0x28) then         -- Arrow Down
        Menu.CurrentItem = Menu.FindNextSelectable(Menu.CurrentItem, 1)
        Menu.UpdateSectionName()
    elseif Menu.IsKeyJustPressed(0x25) then         -- Arrow Left
        local item = Menu.Items[Menu.CurrentItem]
        if item then Menu.HandleSliderChange(item, -1) end
    elseif Menu.IsKeyJustPressed(0x27) then         -- Arrow Right
        local item = Menu.Items[Menu.CurrentItem]
        if item then Menu.HandleSliderChange(item, 1) end
    elseif Menu.IsKeyJustPressed(0x0D) then         -- Enter
        Menu.ActivateCurrentItem()
    end
end

-- ─── MAIN THREAD ─────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        FreeCam.Update()
        Features.UpdateNoclip()
        -- keep god mode / speed hack persistent
        if Features.godMode then
            SetEntityInvincible(PlayerPedId(), true)
            SetPlayerInvincible(PlayerId(), true)
        end
        if Features.speedActive then
            SetPedMoveRateOverride(PlayerPedId(), Features.speedMult)
        end
        if Features.noRagdoll then
            SetPedCanRagdoll(PlayerPedId(), false)
        end
        Menu.Render()
        Menu.HandleInput()
        Wait(0)
    end
end)

-- ─── INIT ────────────────────────────────────────────────────────────────────
if Menu.Banner.enabled and Menu.Banner.imageUrl ~= "" then
    Menu.LoadBannerTexture(Menu.Banner.imageUrl)
end

return Menu
