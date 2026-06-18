-- =========================================================
--   MENU FRAMEWORK  |  Susano API
--   Aç/Kapat : INSERT
-- =========================================================

-- ─── Config ───────────────────────────────────────────────
local CFG = {
    x        = 1670,   -- sol kenar (1920p için)
    y        = 20,     -- üst kenar
    w        = 225,    -- genişlik
    itemH    = 33,     -- toggle satır yüksekliği
    sliderH  = 42,     -- slider satır yüksekliği
    pad      = 11,     -- iç boşluk
    headerH  = 48,
    tabH     = 28,
    footerH  = 22,
    rounding = 8,
}

-- ─── Renkler ──────────────────────────────────────────────
local C = {
    bg        = { 13,  13,  19,  232 },
    headerTop = { 178, 28,  38,  255 },
    headerBot = { 108, 14,  22,  255 },
    accent    = { 220, 65,  50,  255 },
    tabActive = { 195, 42,  42,  255 },
    tabBg     = { 20,  20,  27,  255 },
    itemHover = { 30,  30,  40,  255 },
    border    = { 52,  52,  66,  175 },
    text      = { 238, 238, 245, 255 },
    textDim   = { 128, 128, 142, 200 },
    onPill    = { 68,  192, 108, 255 },
    offPill   = { 65,  65,  80,  255 },
    sliderBg  = { 36,  36,  48,  255 },
    sliderFill= { 220, 65,  50,  255 },
    footer    = { 10,  10,  15,  215 },
    -- DrawLine / DrawCircle için (0-1 range)
    accentF   = { 220/255, 65/255,  50/255,  1.0 },
    borderF   = { 52/255,  52/255,  66/255,  0.55 },
    whiteDotF = { 1.0,     1.0,     1.0,     1.0 },
    grayDotF  = { 0.70,    0.70,    0.78,    1.0 },
    sepF      = { 52/255,  52/255,  66/255,  0.22 },
}

-- ─── Tablar (kendin ekle) ──────────────────────────────────
--  Her tab bir tablo:  { name = "İsim", render = function(x, y, w, mx, my, clicked, lmbDown) ... return toplamYükseklik end }
local TABS = {
    -- Örnek:
    -- {
    --     name = "Player",
    --     render = function(x, y, w, mx, my, clicked, lmbDown)
    --         -- buraya item'ları çiz, toplam yüksekliği return et
    --         return 0
    --     end
    -- },
}

-- ─── Runtime ──────────────────────────────────────────────
local menuOpen  = false
local activeTab = 1
local lastLmb   = false
local dragging  = nil   -- slider sürükleme için kullanabilirsin

-- =========================================================
--  Yardımcı Fonksiyonlar  (tab render'larında kullanabilirsin)
-- =========================================================

-- Mouse üzerinde mi?
function MenuHit(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function MenuClamp(v, lo, hi)
    return v < lo and lo or (v > hi and hi or v)
end

function MenuLerp(a, b, t)
    return a + (b - a) * MenuClamp(t, 0, 1)
end

-- Toggle satırı çizer, hover + clicked döner
function MenuDrawToggle(x, y, w, label, on, mx, my)
    local hov = MenuHit(mx, my, x, y, w, CFG.itemH)
    if hov then
        Susano.DrawRectFilled(x, y, w, CFG.itemH,
            C.itemHover[1], C.itemHover[2], C.itemHover[3], 255)
    end
    Susano.DrawText(x + CFG.pad, y + 9, label, 13,
        C.text[1], C.text[2], C.text[3], 235)

    local pw, ph = 36, 17
    local px = x + w - CFG.pad - pw
    local py = y + math.floor((CFG.itemH - ph) / 2)

    if on then
        Susano.DrawRoundedRectFilled(px, py, pw, ph, math.floor(ph / 2),
            C.onPill[1], C.onPill[2], C.onPill[3], 255)
        Susano.DrawCircle(px + pw - math.floor(ph / 2) - 1, py + math.floor(ph / 2),
            5, true, C.whiteDotF[1], C.whiteDotF[2], C.whiteDotF[3], 1.0, 1)
    else
        Susano.DrawRoundedRectFilled(px, py, pw, ph, math.floor(ph / 2),
            C.offPill[1], C.offPill[2], C.offPill[3], 255)
        Susano.DrawCircle(px + math.floor(ph / 2) + 1, py + math.floor(ph / 2),
            5, true, C.grayDotF[1], C.grayDotF[2], C.grayDotF[3], 1.0, 1)
    end

    -- Ayraç çizgisi
    Susano.DrawLine(x + 7, y + CFG.itemH, x + w - 7, y + CFG.itemH,
        C.sepF[1], C.sepF[2], C.sepF[3], C.sepF[4], 1)

    return hov  -- dışarıda: if hov and clicked then ... end
end

-- Slider satırı çizer, sürükleme mantığı için trackX/trackW döner
function MenuDrawSlider(x, y, w, label, val, minV, maxV, mx, my, lmbDown, dragKey)
    local hov = MenuHit(mx, my, x, y, w, CFG.sliderH)

    if hov or dragging == dragKey then
        Susano.DrawRectFilled(x, y, w, CFG.sliderH,
            C.itemHover[1], C.itemHover[2], C.itemHover[3], 255)
    end

    local valStr = string.format("%.1f", val)
    Susano.DrawText(x + CFG.pad, y + 7, label, 13,
        C.text[1], C.text[2], C.text[3], 235)
    local vw = Susano.GetTextWidth(valStr, 12)
    Susano.DrawText(x + w - CFG.pad - vw, y + 8, valStr, 12,
        C.accent[1], C.accent[2], C.accent[3], 255)

    local tx  = x + CFG.pad
    local tw  = w - CFG.pad * 2
    local ty  = y + 27
    local th  = 4

    Susano.DrawRoundedRectFilled(tx, ty, tw, th, 2,
        C.sliderBg[1], C.sliderBg[2], C.sliderBg[3], 255)
    local fw = math.max(0, math.floor((val - minV) / (maxV - minV) * tw))
    if fw > 0 then
        Susano.DrawRoundedRectFilled(tx, ty, fw, th, 2,
            C.sliderFill[1], C.sliderFill[2], C.sliderFill[3], 255)
    end
    Susano.DrawCircle(tx + fw, ty + math.floor(th / 2), 6, true,
        C.accentF[1], C.accentF[2], C.accentF[3], 1.0, 1)

    Susano.DrawLine(x + 7, y + CFG.sliderH, x + w - 7, y + CFG.sliderH,
        C.sepF[1], C.sepF[2], C.sepF[3], C.sepF[4], 1)

    -- Sürükleme
    if lmbDown and hov and dragging == nil then dragging = dragKey end
    if dragging == dragKey then
        if lmbDown then
            local t = (mx - tx) / tw
            val = math.floor(MenuLerp(minV, maxV, t) * 10) / 10
        else
            dragging = nil
        end
    end

    return val  -- güncel değeri döner
end

-- =========================================================
--  İç çizim fonksiyonları  (framework - dokunma)
-- =========================================================
local function _drawBg(x, y, w, h)
    Susano.DrawRoundedRectFilled(x, y, w, h, CFG.rounding,
        C.bg[1], C.bg[2], C.bg[3], C.bg[4])
    Susano.DrawRoundedRect(x, y, w, h, CFG.rounding,
        C.border[1], C.border[2], C.border[3], C.border[4], 1)
end

local function _drawHeader(x, y, w)
    Susano.DrawRoundedRectFilled(x, y, w, CFG.headerH, CFG.rounding,
        C.headerTop[1], C.headerTop[2], C.headerTop[3], 255)
    Susano.DrawRoundedRectFilled(x, y + 16, w, CFG.headerH - 16, 0,
        C.headerBot[1], C.headerBot[2], C.headerBot[3], 90)
    Susano.DrawTextCentered(x + w / 2, y + 7, "MENU", 20,
        255, 255, 255, 255)
    Susano.DrawTextCentered(x + w / 2, y + 30, "susano.re", 11,
        255, 195, 195, 150)
    Susano.DrawLine(x + 8, y + CFG.headerH, x + w - 8, y + CFG.headerH,
        C.accentF[1], C.accentF[2], C.accentF[3], 0.75, 1.5)
end

local function _drawTabs(x, y, w, active, mx, my)
    if #TABS == 0 then return end
    local tw = math.floor(w / #TABS)
    Susano.DrawRectFilled(x, y, w, CFG.tabH,
        C.tabBg[1], C.tabBg[2], C.tabBg[3], 255)
    for i, tab in ipairs(TABS) do
        local tx = x + (i - 1) * tw
        if i == active then
            Susano.DrawRectFilled(tx, y, tw, CFG.tabH,
                C.tabActive[1], C.tabActive[2], C.tabActive[3], 255)
            Susano.DrawLine(tx + 3, y + CFG.tabH - 1, tx + tw - 3, y + CFG.tabH - 1,
                1.0, 1.0, 1.0, 0.40, 2)
            Susano.DrawTextCentered(tx + tw / 2, y + 7, tab.name, 12,
                255, 255, 255, 255)
        else
            if MenuHit(mx, my, tx, y, tw, CFG.tabH) then
                Susano.DrawRectFilled(tx, y, tw, CFG.tabH, 30, 30, 40, 180)
            end
            Susano.DrawTextCentered(tx + tw / 2, y + 7, tab.name, 12,
                C.textDim[1], C.textDim[2], C.textDim[3], C.textDim[4])
        end
    end
    Susano.DrawLine(x, y + CFG.tabH, x + w, y + CFG.tabH,
        C.borderF[1], C.borderF[2], C.borderF[3], 0.5, 1)
end

local function _drawFooter(x, y, w)
    Susano.DrawRoundedRectFilled(x, y, w, CFG.footerH, CFG.rounding,
        C.footer[1], C.footer[2], C.footer[3], C.footer[4])
    Susano.DrawTextCentered(x + w / 2, y + 5, "INSERT  -  Kapat", 11,
        C.textDim[1], C.textDim[2], C.textDim[3], 145)
end

-- =========================================================
--  Ana render thread
-- =========================================================
CreateThread(function()
    while true do
        Wait(0)

        local _, insertP = Susano.GetAsyncKeyState(0x2D)
        if insertP then
            menuOpen = not menuOpen
            Susano.EnableOverlay(menuOpen)
            if not menuOpen then Susano.ResetFrame() end
        end

        if not menuOpen then goto continue end

        local cur = Susano.GetCursorPos()
        local mx, my = cur.x, cur.y

        local lmbDown, _ = Susano.GetAsyncKeyState(0x01)
        local clicked     = lmbDown and not lastLmb
        lastLmb           = lmbDown

        -- Tab mouse click
        if #TABS > 0 then
            local tw   = math.floor(CFG.w / #TABS)
            local tabY = CFG.y + CFG.headerH
            for i = 1, #TABS do
                local tx = CFG.x + (i - 1) * tw
                if clicked and MenuHit(mx, my, tx, tabY, tw, CFG.tabH) then
                    activeTab = i
                end
            end
            -- 1-9 sayı tuşları ile tab değiştir
            for i = 1, math.min(#TABS, 9) do
                local _, p = Susano.GetAsyncKeyState(0x30 + i)
                if p then activeTab = i end
            end
        end

        -- Aktif tab içeriğini render et ve yüksekliği al
        local contentH = 0
        local contentY = CFG.y + CFG.headerH + (#TABS > 0 and CFG.tabH or 0)

        if #TABS > 0 and TABS[activeTab] and TABS[activeTab].render then
            contentH = TABS[activeTab].render(
                CFG.x, contentY, CFG.w, mx, my, clicked, lmbDown
            ) or 0
        end

        local tabBarH  = #TABS > 0 and CFG.tabH or 0
        local totalH   = CFG.headerH + tabBarH + contentH + CFG.footerH

        Susano.BeginFrame()

        _drawBg(CFG.x, CFG.y, CFG.w, totalH)
        _drawHeader(CFG.x, CFG.y, CFG.w)
        if #TABS > 0 then
            _drawTabs(CFG.x, CFG.y + CFG.headerH, CFG.w, activeTab, mx, my)
        end
        _drawFooter(CFG.x, CFG.y + totalH - CFG.footerH, CFG.w)

        Susano.SubmitFrame()

        ::continue::
    end
end)
