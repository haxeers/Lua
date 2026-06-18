local Menu = {}

Menu.Visible = false
Menu.CurrentItem = 1
Menu.ItemScrollOffset = 0
Menu.ItemsPerPage = 8
Menu.SelectorY = 0
Menu.SmoothFactor = 0.22
Menu.Scale = 1.0
Menu.LoadingComplete = false
Menu.IsLoading = true
Menu.LoadingProgress = 0.0
Menu.LoadingStartTime = nil
Menu.LoadingDuration = 5000
Menu.SelectingKey = false
Menu.SelectingFeatureBind = false
Menu.BindingFeatureItem = nil
Menu.BindingFeatureKey = nil
Menu.BindingFeatureKeyName = nil
Menu.SelectedKey = nil
Menu.SelectedKeyName = nil
Menu.SectionName = "Menu"
Menu.Title = "phantom"
Menu.FooterText = "phantom.lua"
Menu.BrandAnimStart = nil
Menu.Items = {}

Menu.Banner = {
    enabled = true,
    imageUrl = "https://i.hizliresim.com/t7rdy5t.png",
    height = 100
}

Menu.bannerTexture = nil
Menu.bannerWidth = 0
Menu.bannerHeight = 0
Menu.bannerLoadFailed = false
Menu.bannerLoading = false

function Menu.IsImageBytes(data)
    if not data or #data < 4 then return false end
    local b1, b2, b3, b4 = string.byte(data, 1, 4)
    if b1 == 0x89 and b2 == 0x50 and b3 == 0x4E and b4 == 0x47 then return true end
    if b1 == 0xFF and b2 == 0xD8 and b3 == 0xFF then return true end
    if b1 == 0x42 and b2 == 0x4D then return true end
    if b1 == 0x47 and b2 == 0x49 and b3 == 0x46 then return true end
    return false
end

function Menu.ExtractImageUrlFromHtml(html)
    if not html or html == "" then return nil end
    local patterns = {
        'property=["\']og:image["\'][^>]-content=["\']([^"\']+)["\']',
        'content=["\']([^"\']+)["\'][^>]-property=["\']og:image["\']',
        '(https?://i%.hizliresim%.com/[%w%-%._]+)',
        '(https?://i%.imgur%.com/[%w%-%._]+)',
        '(https?://cdn%.discordapp%.com/attachments/[^"\']+)',
        '(https?://media%.discordapp%.net/attachments/[^"\']+)',
        '(https?://raw%.githubusercontent%.com/[^"\']+%.[pP][nN][gG])',
        '(https?://raw%.githubusercontent%.com/[^"\']+%.[jJ][pP][eE]?[gG]?)',
        'src=["\'](https?://[^"\']+%.[pP][nN][gG])["\']',
        'src=["\'](https?://[^"\']+%.[jJ][pP][eE]?[gG]?)["\']',
        'src=["\'](https?://[^"\']+%.[wW][eE][bB][pP])["\']'
    }
    for _, pattern in ipairs(patterns) do
        local found = html:match(pattern)
        if found and found ~= "" then return found end
    end
    return nil
end

function Menu.ResolveBannerCandidates(url)
    local candidates = {}
    local function add(u)
        if u and u ~= "" then
            for _, existing in ipairs(candidates) do
                if existing == u then return end
            end
            table.insert(candidates, u)
        end
    end

    add(url)

    local lower = string.lower(url or "")
    local hizId = url and url:match("hizliresim%.com/([%w%-_]+)")
    if hizId then
        hizId = hizId:gsub("%.png$", ""):gsub("%.jpg$", ""):gsub("%.jpeg$", "")
        add("https://i.hizliresim.com/" .. hizId .. ".png")
        add("https://i.hizliresim.com/" .. hizId .. ".jpg")
    end

    local imgurId = url and url:match("imgur%.com/([%w%d]+)")
    if imgurId and not lower:find("i%.imgur%.com") then
        add("https://i.imgur.com/" .. imgurId .. ".png")
        add("https://i.imgur.com/" .. imgurId .. ".jpg")
    end

    if not lower:match("%.png") and not lower:match("%.jpe?g") and not lower:match("%.webp") and not lower:match("%.gif") and not lower:match("%.bmp") then
        add(url .. ".png")
        add(url .. ".jpg")
    end

    return candidates
end

function Menu.TryLoadBannerFromBytes(body)
    if not body or #body == 0 then return false end
    if not Menu.IsImageBytes(body) then return false end
    if not Susano or not Susano.LoadTextureFromBuffer then return false end

    local ok, textureId, width, height = pcall(function()
        return Susano.LoadTextureFromBuffer(body)
    end)

    if ok and textureId and textureId ~= 0 then
        Menu.bannerTexture = textureId
        Menu.bannerWidth = width or 0
        Menu.bannerHeight = height or 0
        Menu.bannerLoadFailed = false
        return true
    end

    return false
end

function Menu.LoadBannerTexture(url)
    if not url or url == "" then return end
    if Menu.bannerLoading then return end
    if not Susano or not Susano.HttpGet then return end

    Menu.bannerLoading = true
    Menu.bannerLoadFailed = false

    CreateThread(function()
        local loaded = false
        local candidates = Menu.ResolveBannerCandidates(url)

        for _, candidate in ipairs(candidates) do
            if loaded then break end

            local ok, status, body = pcall(function()
                return Susano.HttpGet(candidate)
            end)

            if ok and status == 200 and body and #body > 0 then
                if Menu.TryLoadBannerFromBytes(body) then
                    loaded = true
                    break
                end

                local extracted = Menu.ExtractImageUrlFromHtml(body)
                if extracted and extracted ~= candidate then
                    local ok2, status2, body2 = pcall(function()
                        return Susano.HttpGet(extracted)
                    end)
                    if ok2 and status2 == 200 and body2 and Menu.TryLoadBannerFromBytes(body2) then
                        loaded = true
                        break
                    end
                end
            end
        end

        Menu.bannerLoading = false
        Menu.bannerLoadFailed = not loaded
    end)
end

function Menu.SetBannerUrl(url)
    if not url or url == "" or url == "https://hizliresim.com/t7rdy5t" then return end
    Menu.Banner.imageUrl = url
    Menu.bannerTexture = nil
    Menu.bannerWidth = 0
    Menu.bannerHeight = 0
    Menu.LoadBannerTexture(url)
end

function Menu.ColorToUnit(r, g, b, a)
    a = a or 255
    if r > 1 then r = r / 255 end
    if g > 1 then g = g / 255 end
    if b > 1 then b = b / 255 end
    if a > 1 then a = a / 255 end
    return r, g, b, a
end

Menu.Colors = {
    Accent = { r = 255, g = 255, b = 255 },
    SelectedBg = { r = 255, g = 255, b = 255 },
    TextWhite = { r = 255, g = 255, b = 255 },
    TextBlack = { r = 0, g = 0, b = 0 },
    BackgroundDark = { r = 8, g = 8, b = 8 },
    RowDark = { r = 14, g = 14, b = 14 },
    FooterBlack = { r = 0, g = 0, b = 0 }
}

Menu.Position = {
    x = 50,
    y = 100,
    width = 360,
    itemHeight = 34,
    sectionHeight = 26,
    headerHeight = 100,
    footerHeight = 26,
    footerSpacing = 5,
    sectionSpacing = 5,
    footerRadius = 4,
    itemRadius = 0,
    headerRadius = 8
}

function Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    return {
        x = Menu.Position.x,
        y = Menu.Position.y,
        width = Menu.Position.width * scale,
        itemHeight = Menu.Position.itemHeight * scale,
        sectionHeight = Menu.Position.sectionHeight * scale,
        headerHeight = Menu.Position.headerHeight * scale,
        footerHeight = Menu.Position.footerHeight * scale,
        footerSpacing = Menu.Position.footerSpacing * scale,
        sectionSpacing = Menu.Position.sectionSpacing * scale,
        footerRadius = Menu.Position.footerRadius * scale,
        itemRadius = Menu.Position.itemRadius * scale,
        headerRadius = Menu.Position.headerRadius * scale
    }
end

function Menu.DrawRect(x, y, width, height, r, g, b, a, rounding)
    r, g, b, a = Menu.ColorToUnit(r, g, b, a or 255)
    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(x, y, width, height, r, g, b, a, rounding or 0)
    end
end

function Menu.DrawText(x, y, text, size_px, r, g, b, a)
    local scale = Menu.Scale or 1.0
    size_px = (size_px or 16) * scale
    r, g, b, a = Menu.ColorToUnit(r or 255, g or 255, b or 255, a or 255)
    if Susano and Susano.DrawText then
        Susano.DrawText(x, y, text, size_px, r, g, b, a)
    end
end

function Menu.GetTextWidth(text, size_px)
    local scale = Menu.Scale or 1.0
    size_px = (size_px or 16) * scale
    if Susano and Susano.GetTextWidth then
        return Susano.GetTextWidth(text, size_px)
    end
    return string.len(text or "") * 8 * scale
end

function Menu.IsSelectableItem(item)
    if not item then return false end
    if item.isHeader or item.isSeparator then return false end
    return true
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
    local selectable = Menu.GetSelectableItems()
    for pos, entry in ipairs(selectable) do
        if entry.index == targetIndex then
            return pos
        end
    end
    return 1
end

function Menu.GetSelectableIndex(position)
    local selectable = Menu.GetSelectableItems()
    local entry = selectable[position]
    return entry and entry.index or 1
end

function Menu.FindNextSelectable(startIndex, direction)
    local selectable = Menu.GetSelectableItems()
    if #selectable == 0 then return 1 end

    local currentPos = 1
    for pos, entry in ipairs(selectable) do
        if entry.index == startIndex then
            currentPos = pos
            break
        end
    end

    local nextPos = currentPos + direction
    if nextPos < 1 then nextPos = #selectable end
    if nextPos > #selectable then nextPos = 1 end
    return selectable[nextPos].index
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

function Menu.UpdateBrandAnim()
    if Menu.Visible then
        if not Menu.BrandAnimStart then
            Menu.BrandAnimStart = GetGameTimer()
        end
    else
        Menu.BrandAnimStart = nil
    end
end

function Menu.GetBrandAnim()
    local start = Menu.BrandAnimStart or GetGameTimer()
    local elapsed = GetGameTimer() - start

    if elapsed < 350 then
        return "o", math.min(1, elapsed / 250)
    elseif elapsed < 750 then
        return "o", 1
    elseif elapsed < 1050 then
        return "o", 1 - ((elapsed - 750) / 300)
    elseif elapsed < 1550 then
        return "phantom", (elapsed - 1050) / 500
    end

    return "phantom", 1
end

function Menu.DrawShadowText(x, y, text, size_px, r, g, b, a)
    Menu.DrawText(x + 1, y + 1, text, size_px, 0, 0, 0, a or 200)
    Menu.DrawText(x, y, text, size_px, r, g, b, a or 255)
end

function Menu.UpdateLoading()
    if not Menu.IsLoading then return end
    if not Menu.LoadingStartTime then
        Menu.LoadingStartTime = GetGameTimer()
    end

    local elapsed = GetGameTimer() - Menu.LoadingStartTime
    Menu.LoadingProgress = math.min(100, (elapsed / Menu.LoadingDuration) * 100)

    if Menu.LoadingProgress >= 100 then
        Menu.IsLoading = false
        Menu.SelectingKey = true
    end
end

function Menu.DrawLoadingScreen()
    local sw = (Susano and Susano.GetScreenWidth and Susano.GetScreenWidth()) or 1920
    local sh = (Susano and Susano.GetScreenHeight and Susano.GetScreenHeight()) or 1080
    local centerX = sw / 2
    local centerY = sh / 2

    local title = "phantom"
    local titleSize = 42
    local titleWidth = Menu.GetTextWidth(title, titleSize)
    Menu.DrawShadowText(centerX - (titleWidth / 2), centerY - 80, title, titleSize, 255, 255, 255, 255)

    local barW, barH = 420, 14
    local barX = centerX - (barW / 2)
    local barY = centerY - 10
    local percent = (Menu.LoadingProgress or 0) / 100

    Menu.DrawRect(barX - 1, barY - 1, barW + 2, barH + 2, 0, 0, 0, 255, 4)
    Menu.DrawRect(barX, barY, barW, barH, 25, 25, 25, 220, 3)
    if percent > 0 then
        Menu.DrawRect(barX, barY, barW * percent, barH, 255, 255, 255, 255, 3)
    end

    local statusText = string.format("Loading... %d%%", math.floor(Menu.LoadingProgress or 0))
    local statusSize = 18
    local statusWidth = Menu.GetTextWidth(statusText, statusSize)
    Menu.DrawShadowText(centerX - (statusWidth / 2), barY + 28, statusText, statusSize, 255, 255, 255, 255)
end

Menu.KeyNames = {
    [0x08] = "Backspace", [0x09] = "Tab", [0x0D] = "Enter", [0x10] = "Shift",
    [0x11] = "Ctrl", [0x12] = "Alt", [0x1B] = "ESC", [0x20] = "Space",
    [0x25] = "Left", [0x26] = "Up", [0x27] = "Right", [0x28] = "Down",
    [0x30] = "0", [0x31] = "1", [0x32] = "2", [0x33] = "3", [0x34] = "4",
    [0x35] = "5", [0x36] = "6", [0x37] = "7", [0x38] = "8", [0x39] = "9",
    [0x41] = "A", [0x42] = "B", [0x43] = "C", [0x44] = "D", [0x45] = "E",
    [0x46] = "F", [0x47] = "G", [0x48] = "H", [0x49] = "I", [0x4A] = "J",
    [0x4B] = "K", [0x4C] = "L", [0x4D] = "M", [0x4E] = "N", [0x4F] = "O",
    [0x50] = "P", [0x51] = "Q", [0x52] = "R", [0x53] = "S", [0x54] = "T",
    [0x55] = "U", [0x56] = "V", [0x57] = "W", [0x58] = "X", [0x59] = "Y",
    [0x5A] = "Z",
    [0x70] = "F1", [0x71] = "F2", [0x72] = "F3", [0x73] = "F4",
    [0x74] = "F5", [0x75] = "F6", [0x76] = "F7", [0x77] = "F8",
    [0x78] = "F9", [0x79] = "F10", [0x7A] = "F11", [0x7B] = "F12"
}

function Menu.GetKeyName(keyCode)
    return Menu.KeyNames[keyCode] or ("0x" .. string.format("%02X", keyCode))
end

function Menu.DrawKeySelector()
    local sw = (Susano and Susano.GetScreenWidth and Susano.GetScreenWidth()) or 1920
    local sh = (Susano and Susano.GetScreenHeight and Susano.GetScreenHeight()) or 1080

    local panelW, panelH = 460, 110
    local panelX = (sw / 2) - (panelW / 2)
    local panelY = sh - panelH - 40

    Menu.DrawRect(panelX, panelY, panelW, panelH, 0, 0, 0, 230, 8)
    Menu.DrawRect(panelX, panelY, panelW, 2, 255, 255, 255, 255, 0)

    local title = "phantom"
    local titleSize = 22
    local titleW = Menu.GetTextWidth(title, titleSize)
    Menu.DrawShadowText(panelX + (panelW / 2) - (titleW / 2), panelY + 14, title, titleSize, 255, 255, 255, 255)

    local hint = "Select menu toggle key - press ENTER to confirm"
    local hintSize = 14
    local hintW = Menu.GetTextWidth(hint, hintSize)
    Menu.DrawText(panelX + (panelW / 2) - (hintW / 2), panelY + 48, hint, hintSize, 200, 200, 200, 255)

    local keyName = Menu.SelectedKeyName or "..."
    local keyBoxW, keyBoxH = 56, 34
    local keyBoxX = panelX + (panelW / 2) - (keyBoxW / 2)
    local keyBoxY = panelY + panelH - keyBoxH - 14
    Menu.DrawRect(keyBoxX, keyBoxY, keyBoxW, keyBoxH, 30, 30, 30, 255, 6)
    Menu.DrawRect(keyBoxX, keyBoxY, keyBoxW, 1, 255, 255, 255, 180, 0)

    local keySize = 18
    local keyW = Menu.GetTextWidth(keyName, keySize)
    Menu.DrawText(keyBoxX + (keyBoxW / 2) - (keyW / 2), keyBoxY + 7, keyName, keySize, 255, 255, 255, 255)
end

function Menu.HandleKeySelection()
    if not (Susano and Susano.GetAsyncKeyState) then return end

    if Menu.IsKeyJustPressed(0x0D) then
        if Menu.SelectedKey then
            Menu.SelectingKey = false
            Menu.LoadingComplete = true
            if Menu.Notify then
                Menu.Notify("success", "Menu keybind: " .. (Menu.SelectedKeyName or "?"))
            end
        end
        return
    end

    local keysToCheck = {
        0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D,
        0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A,
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
        0x20, 0x1B, 0x08, 0x09, 0x10, 0x11, 0x12,
        0x25, 0x26, 0x27, 0x28,
        0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B
    }

    for _, keyCode in ipairs(keysToCheck) do
        if keyCode ~= 0x0D and Menu.IsKeyJustPressed(keyCode) then
            Menu.SelectedKey = keyCode
            Menu.SelectedKeyName = Menu.GetKeyName(keyCode)
            break
        end
    end
end

function Menu.DrawFeatureKeySelector()
    local sw = (Susano and Susano.GetScreenWidth and Susano.GetScreenWidth()) or 1920
    local sh = (Susano and Susano.GetScreenHeight and Susano.GetScreenHeight()) or 1080

    local panelW, panelH = 480, 110
    local panelX = (sw / 2) - (panelW / 2)
    local panelY = sh - panelH - 40

    Menu.DrawRect(panelX, panelY, panelW, panelH, 0, 0, 0, 230, 8)
    Menu.DrawRect(panelX, panelY, panelW, 2, 255, 255, 255, 255, 0)

    local itemName = (Menu.BindingFeatureItem and Menu.BindingFeatureItem.name) or "Feature"
    local title = "Keybind: " .. itemName
    local titleSize = 18
    local titleW = Menu.GetTextWidth(title, titleSize)
    Menu.DrawShadowText(panelX + (panelW / 2) - (titleW / 2), panelY + 12, title, titleSize, 255, 255, 255, 255)

    local hint = "Press a key - ENTER to confirm (F9 to cancel)"
    local hintSize = 13
    local hintW = Menu.GetTextWidth(hint, hintSize)
    Menu.DrawText(panelX + (panelW / 2) - (hintW / 2), panelY + 42, hint, hintSize, 200, 200, 200, 255)

    local keyName = Menu.BindingFeatureKeyName or "..."
    local keyBoxW, keyBoxH = 56, 34
    local keyBoxX = panelX + (panelW / 2) - (keyBoxW / 2)
    local keyBoxY = panelY + panelH - keyBoxH - 12
    Menu.DrawRect(keyBoxX, keyBoxY, keyBoxW, keyBoxH, 30, 30, 30, 255, 6)
    local keyW = Menu.GetTextWidth(keyName, 18)
    Menu.DrawText(keyBoxX + (keyBoxW / 2) - (keyW / 2), keyBoxY + 7, keyName, 18, 255, 255, 255, 255)
end

function Menu.HandleFeatureKeySelection()
    if not (Susano and Susano.GetAsyncKeyState) then return end

    if Menu.IsKeyJustPressed(0x78) then
        Menu.SelectingFeatureBind = false
        Menu.BindingFeatureItem = nil
        Menu.BindingFeatureKey = nil
        Menu.BindingFeatureKeyName = nil
        return
    end

    if Menu.IsKeyJustPressed(0x0D) then
        if Menu.BindingFeatureKey and Menu.BindingFeatureItem then
            Menu.BindingFeatureItem.bindKey = Menu.BindingFeatureKey
            Menu.BindingFeatureItem.bindKeyName = Menu.BindingFeatureKeyName
            if Menu.Notify then
                Menu.Notify("success", Menu.BindingFeatureItem.name .. " bound to " .. Menu.BindingFeatureKeyName)
            end
        end
        Menu.SelectingFeatureBind = false
        Menu.BindingFeatureItem = nil
        Menu.BindingFeatureKey = nil
        Menu.BindingFeatureKeyName = nil
        return
    end

    local keysToCheck = {
        0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D,
        0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A,
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
        0x20, 0x1B, 0x08, 0x09, 0x10, 0x11, 0x12,
        0x25, 0x26, 0x27, 0x28,
        0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x79, 0x7A, 0x7B
    }

    for _, keyCode in ipairs(keysToCheck) do
        if Menu.IsKeyJustPressed(keyCode) then
            Menu.BindingFeatureKey = keyCode
            Menu.BindingFeatureKeyName = Menu.GetKeyName(keyCode)
            break
        end
    end
end

function Menu.HandleFeatureKeybinds()
    if Menu.IsLoading or Menu.SelectingKey or Menu.SelectingFeatureBind or Menu.Visible then return end
    if not Menu.LoadingComplete then return end

    for _, item in ipairs(Menu.Items or {}) do
        if item.bindKey and (item.type == "toggle" or item.type == "action") then
            if Menu.IsKeyJustPressed(item.bindKey) then
                if item.type == "toggle" then
                    item.value = not item.value
                    if Menu.Notify then
                        Menu.Notify(item.value and "success" or "info", item.name .. ": " .. (item.value and "Enabled" or "Disabled"))
                    end
                    if item.onClick then item.onClick(item.value) end
                elseif item.type == "action" then
                    if item.onClick then item.onClick() end
                    if Menu.Notify then Menu.Notify("info", item.name .. " activated") end
                end
            end
        end
    end
end

function Menu.DrawBrandText(centerX, centerY, size_px, suffix)
    local text, alpha = Menu.GetBrandAnim()
    if alpha <= 0 then return end

    suffix = suffix or ""
    local display = text .. (alpha >= 1 and suffix or "")
    local alpha255 = math.floor(alpha * 255)
    local textWidth = Menu.GetTextWidth(display, size_px)
    local drawX = centerX - (textWidth / 2)
    local drawY = centerY - (size_px / 2)

    Menu.DrawText(drawX, drawY, display, size_px, 255, 255, 255, alpha255)
end

function Menu.DrawHeader()
    local pos = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x, y = pos.x, pos.y
    local width = pos.width - 1
    local bannerHeight = Menu.Banner.enabled and (Menu.Banner.height * scale) or pos.headerHeight
    local hasBannerImage = Menu.Banner.enabled and Menu.bannerTexture and Menu.bannerTexture > 0 and Susano and Susano.DrawImage

    if hasBannerImage then
        Susano.DrawImage(Menu.bannerTexture, x, y, width, bannerHeight, 1, 1, 1, 1, pos.headerRadius)
    else
        Menu.DrawRect(x, y, width, bannerHeight, 0, 0, 0, 255, pos.headerRadius)
        local titleSize = 34 * scale
        Menu.DrawBrandText(x + (width / 2), y + (bannerHeight / 2), titleSize, "")
    end
end

function Menu.DrawSectionBar()
    local pos = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x = pos.x
    local bannerHeight = Menu.Banner.enabled and (Menu.Banner.height * scale) or pos.headerHeight
    local y = pos.y + bannerHeight
    local width = pos.width - 1
    local height = pos.sectionHeight

    Menu.DrawRect(x, y, width, height, Menu.Colors.RowDark.r, Menu.Colors.RowDark.g, Menu.Colors.RowDark.b, 255, 0)

    local text = Menu.SectionName or "Menu"
    local textSize = 16
    local textY = y + (height / 2) - ((textSize * scale) / 2) + 1
    Menu.DrawText(x + 14 * scale, textY, text, textSize, 255, 255, 255, 255)
end

function Menu.DrawToggle(x, itemY, width, itemHeight, item, isSelected)
    local scale = Menu.Scale or 1.0
    local toggleWidth = 36 * scale
    local toggleHeight = 16 * scale
    local toggleX = x + width - toggleWidth - (16 * scale)
    local toggleY = itemY + (itemHeight / 2) - (toggleHeight / 2)
    local toggleRadius = toggleHeight / 2

    if item.value then
        Menu.DrawRect(toggleX, toggleY, toggleWidth, toggleHeight, 255, 255, 255, 242, toggleRadius)
    else
        Menu.DrawRect(toggleX, toggleY, toggleWidth, toggleHeight, 40, 40, 40, 242, toggleRadius)
    end

    local circleSize = toggleHeight - 4
    local circleY = toggleY + 2
    local circleX = item.value and (toggleX + toggleWidth - circleSize - 2) or (toggleX + 2)
    local knobR, knobG, knobB = item.value and 0 or 255, item.value and 0 or 255, item.value and 0 or 255
    if isSelected and not item.value then
        knobR, knobG, knobB = 0, 0, 0
    end
    Menu.DrawRect(circleX, circleY, circleSize, circleSize, knobR, knobG, knobB, 255, circleSize / 2)

    if item.hasSlider then
        local sliderWidth = 85 * scale
        local sliderHeight = 6 * scale
        local sliderX = x + width - sliderWidth - (95 * scale)
        local sliderY = itemY + (itemHeight / 2) - (sliderHeight / 2)
        local minValue = item.sliderMin or 0
        local maxValue = item.sliderMax or 100
        local currentValue = item.sliderValue or minValue
        local percent = (currentValue - minValue) / math.max(0.0001, (maxValue - minValue))
        percent = math.max(0, math.min(1, percent))
        local trackR, trackG, trackB = isSelected and 180 or 40, isSelected and 180 or 40, isSelected and 180 or 40
        local fillR, fillG, fillB = isSelected and 0 or 255, isSelected and 0 or 255, isSelected and 0 or 255
        local valR, valG, valB = isSelected and 0 or 255, isSelected and 0 or 255, isSelected and 0 or 255

        Menu.DrawRect(sliderX, sliderY, sliderWidth, sliderHeight, trackR, trackG, trackB, 180, 3)
        if percent > 0 then
            Menu.DrawRect(sliderX, sliderY, sliderWidth * percent, sliderHeight, fillR, fillG, fillB, 255, 3)
        end

        local valueText
        if item.sliderStep and item.sliderStep >= 1 then
            valueText = string.format("%.0f", currentValue)
        else
            valueText = string.format("%.1f", currentValue)
        end
        Menu.DrawText(sliderX + sliderWidth + (8 * scale), sliderY - 2, valueText, 11, valR, valG, valB, 210)
    end
end

function Menu.DrawSlider(x, itemY, width, itemHeight, item, isSelected)
    local scale = Menu.Scale or 1.0
    local sliderWidth = 100 * scale
    local sliderHeight = 7 * scale
    local sliderX = x + width - sliderWidth - (60 * scale)
    local sliderY = itemY + (itemHeight / 2) - (sliderHeight / 2)
    local minValue = item.min or 0
    local maxValue = item.max or 100
    local currentValue = item.value or minValue
    local percent = (currentValue - minValue) / math.max(0.0001, (maxValue - minValue))
    percent = math.max(0, math.min(1, percent))
    local trackR, trackG, trackB = isSelected and 180 or 40, isSelected and 180 or 40, isSelected and 180 or 40
    local fillR, fillG, fillB = isSelected and 0 or 255, isSelected and 0 or 255, isSelected and 0 or 255
    local valR, valG, valB = isSelected and 0 or 255, isSelected and 0 or 255, isSelected and 0 or 255

    Menu.DrawRect(sliderX, sliderY, sliderWidth, sliderHeight, trackR, trackG, trackB, 180, 3)
    if percent > 0 then
        Menu.DrawRect(sliderX, sliderY, sliderWidth * percent, sliderHeight, fillR, fillG, fillB, 255, 3)
    end

    local valueText = (item.step and item.step >= 1) and string.format("%.0f", currentValue) or string.format("%.1f", currentValue)
    Menu.DrawText(sliderX + sliderWidth + (8 * scale), sliderY - 2, valueText, 11, valR, valG, valB, 210)
end

function Menu.DrawItem(x, itemY, width, itemHeight, item, isSelected)
    local scale = Menu.Scale or 1.0

    if item.isHeader then
        return
    end

    if item.isSeparator then
        Menu.DrawRect(x, itemY, width, itemHeight, Menu.Colors.BackgroundDark.r, Menu.Colors.BackgroundDark.g, Menu.Colors.BackgroundDark.b, 50, 0)
        if item.separatorText then
            local textWidth = Menu.GetTextWidth(item.separatorText, 14)
            local textX = x + (width / 2) - (textWidth / 2)
            local textY = itemY + (itemHeight / 2) - (7 * scale)
            Menu.DrawText(textX, textY, item.separatorText, 14, 255, 255, 255, 255)
        end
        return
    end

    Menu.DrawRect(x, itemY, width, itemHeight, Menu.Colors.RowDark.r, Menu.Colors.RowDark.g, Menu.Colors.RowDark.b, 255, 0)

    if isSelected then
        if Menu.SelectorY == 0 then Menu.SelectorY = itemY end
        Menu.SelectorY = Menu.SelectorY + (itemY - Menu.SelectorY) * Menu.SmoothFactor
        if math.abs(Menu.SelectorY - itemY) < 0.5 then Menu.SelectorY = itemY end
        Menu.DrawRect(x, Menu.SelectorY, width, itemHeight,
            Menu.Colors.SelectedBg.r, Menu.Colors.SelectedBg.g, Menu.Colors.SelectedBg.b, 255, 0)
    end

    local textR, textG, textB = 255, 255, 255
    if isSelected then
        textR, textG, textB = 0, 0, 0
    end

    local textX = x + (16 * scale)
    local textY = itemY + (itemHeight / 2) - (8 * scale)
    local label = item.name or ""
    if item.bindKeyName then
        label = label .. " [" .. item.bindKeyName .. "]"
    end
    Menu.DrawText(textX, textY, label, 17, textR, textG, textB, 255)

    if item.type == "toggle" then
        Menu.DrawToggle(x, itemY, width, itemHeight, item, isSelected)
    elseif item.type == "slider" then
        Menu.DrawSlider(x, itemY, width, itemHeight, item, isSelected)
    elseif item.type == "action" then
        local hint = ">"
        local hintWidth = Menu.GetTextWidth(hint, 16)
        Menu.DrawText(x + width - hintWidth - (16 * scale), textY, hint, 16, textR, textG, textB, 180)
    end
end

function Menu.GetVisibleItemCount()
    local count = 0
    for _, item in ipairs(Menu.Items or {}) do
        if not item.isHeader then
            count = count + 1
        end
    end
    return math.min(Menu.ItemsPerPage, math.max(count, 1))
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
    visible = math.max(visible, 1)
    return visible * pos.itemHeight
end

function Menu.DrawItems()
    local pos = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x = pos.x
    local bannerHeight = Menu.Banner.enabled and (Menu.Banner.height * scale) or pos.headerHeight
    local startY = pos.y + bannerHeight + pos.sectionHeight + pos.sectionSpacing
    local width = pos.width - 1
    local itemHeight = pos.itemHeight
    local maxVisible = Menu.ItemsPerPage

    local displayList = {}
    for i, item in ipairs(Menu.Items or {}) do
        if not item.isHeader then
            table.insert(displayList, { index = i, item = item })
        end
    end

    if #displayList == 0 then return end

    if Menu.CurrentItem > Menu.ItemScrollOffset + maxVisible then
        Menu.ItemScrollOffset = Menu.CurrentItem - maxVisible
    elseif Menu.CurrentItem <= Menu.ItemScrollOffset then
        Menu.ItemScrollOffset = math.max(0, Menu.CurrentItem - 1)
    end

    local visibleCount = 0
    for slot = 1, math.min(maxVisible, #displayList) do
        local entry = displayList[slot + Menu.ItemScrollOffset]
        if entry then
            visibleCount = visibleCount + 1
            local itemY = startY + (slot - 1) * itemHeight
            local isSelected = entry.index == Menu.CurrentItem
            Menu.DrawItem(x, itemY, width, itemHeight, entry.item, isSelected)
        end
    end
end

function Menu.DrawFooter()
    local pos = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x = pos.x
    local bannerHeight = Menu.Banner.enabled and (Menu.Banner.height * scale) or pos.headerHeight
    local totalHeight = bannerHeight + pos.sectionHeight + pos.sectionSpacing + Menu.GetContentHeight()
    local footerY = pos.y + totalHeight + pos.footerSpacing
    local footerWidth = pos.width - 1
    local footerHeight = pos.footerHeight

    Menu.DrawRect(x, footerY, footerWidth, footerHeight, 0, 0, 0, 255, pos.footerRadius)

    local footerSize = 13
    local textY = footerY + (footerHeight / 2)
    local brandText, alpha = Menu.GetBrandAnim()
    local suffix = (alpha >= 1 and brandText == "phantom") and ".lua" or ""
    local footerDisplay = brandText .. suffix
    local alpha255 = math.floor(alpha * 255)
    Menu.DrawText(x + 15 * scale, textY - ((footerSize * scale) / 2) + 1, footerDisplay, footerSize, 255, 255, 255, alpha255)

    local selectable = Menu.GetSelectableItems()
    local currentPos = Menu.FindSelectablePosition(Menu.CurrentItem or 1)
    local posText = string.format("%d / %d", currentPos, math.max(#selectable, 1))
    local posWidth = Menu.GetTextWidth(posText, footerSize)
    Menu.DrawText(x + footerWidth - posWidth - (15 * scale), textY, posText, footerSize, 255, 255, 255, 255)
end

function Menu.DrawBackground()
    local pos = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x, y = pos.x, pos.y
    local width = pos.width - 1
    local bannerHeight = Menu.Banner.enabled and (Menu.Banner.height * scale) or pos.headerHeight
    local totalHeight = bannerHeight + pos.sectionHeight + pos.sectionSpacing + Menu.GetContentHeight() + pos.footerSpacing + pos.footerHeight

    Menu.DrawRect(x, y, width, totalHeight, 0, 0, 0, 250, pos.headerRadius)
end

local NotificationQueue = {}
local NOTIFY_DURATION_MS = 3500

local NOTIFY_COLORS = {
    success = { r = 0.35, g = 0.85, b = 0.45, title = "SUCCESS" },
    info    = { r = 0.35, g = 0.65, b = 0.95, title = "INFO" },
    warning = { r = 0.95, g = 0.75, b = 0.2,  title = "WARNING" },
    error   = { r = 0.95, g = 0.25, b = 0.25, title = "ERROR" }
}

function Menu.Notify(notifyType, message, durationMs)
    if not message or message == "" then return end
    notifyType = notifyType or "info"
    local cfg = NOTIFY_COLORS[notifyType] or NOTIFY_COLORS.info
    durationMs = durationMs or NOTIFY_DURATION_MS
    table.insert(NotificationQueue, 1, {
        type = notifyType,
        title = cfg.title,
        message = tostring(message),
        spawnTime = GetGameTimer(),
        duration = durationMs,
        r = cfg.r, g = cfg.g, b = cfg.b
    })
end

function Menu.DrawNotifications()
    if not Susano or not Susano.DrawRectFilled or not Susano.DrawText then return end
    local sw = (Susano.GetScreenWidth and Susano.GetScreenWidth()) or 1920
    local sh = (Susano.GetScreenHeight and Susano.GetScreenHeight()) or 1080
    local nowMs = GetGameTimer()

    for i = #NotificationQueue, 1, -1 do
        if nowMs - NotificationQueue[i].spawnTime > NotificationQueue[i].duration + 300 then
            table.remove(NotificationQueue, i)
        end
    end

    local boxW, boxH = 320, 72
    local baseY = sh - 20 - boxH
    local finalX = sw - 20 - boxW

    for idx, n in ipairs(NotificationQueue) do
        local boxY = baseY - (idx - 1) * (boxH + 10)
        if boxY < 40 then break end
        local elapsed = nowMs - n.spawnTime
        local alpha = 1.0
        if elapsed < 300 then alpha = elapsed / 300 end
        if elapsed > n.duration then alpha = 1.0 - ((elapsed - n.duration) / 300) end
        alpha = math.max(0, math.min(1, alpha))

        Susano.DrawRectFilled(finalX, boxY, boxW, boxH, 0.086, 0.086, 0.102, 0.96 * alpha, 0)
        Susano.DrawRectFilled(finalX, boxY, 5, boxH, n.r, n.g, n.b, 1.0 * alpha, 0)
        Susano.DrawText(finalX + 16, boxY + 12, n.title, 16, n.r, n.g, n.b, 1.0 * alpha)
        Susano.DrawText(finalX + 16, boxY + 36, n.message, 14, 1, 1, 1, 1.0 * alpha)
    end
end

function Menu.Render()
    if not (Susano and Susano.BeginFrame) then return end

    Menu.UpdateLoading()
    Menu.UpdateSectionName()
    Menu.UpdateBrandAnim()
    Susano.BeginFrame()

    if Menu.IsLoading then
        Menu.DrawLoadingScreen()
    end

    if Menu.SelectingKey then
        Menu.DrawKeySelector()
    end

    if Menu.SelectingFeatureBind then
        Menu.DrawFeatureKeySelector()
    end

    if Menu.Visible then
        Menu.DrawBackground()
        Menu.DrawHeader()
        Menu.DrawSectionBar()
        Menu.DrawItems()
        Menu.DrawFooter()
    end

    Menu.DrawNotifications()

    if Menu.OnRender then
        pcall(Menu.OnRender)
    end

    if Susano.SubmitFrame then
        Susano.SubmitFrame()
    end

    local keepOverlay = Menu.Visible or Menu.IsLoading or Menu.SelectingKey or Menu.SelectingFeatureBind or Menu.PreventResetFrame
    if not keepOverlay then
        if Susano.ResetFrame then
            Susano.ResetFrame()
        end
    end
end

Menu.KeyStates = {}

function Menu.IsKeyJustPressed(keyCode)
    if not (Susano and Susano.GetAsyncKeyState) then return false end
    local down, pressed = Susano.GetAsyncKeyState(keyCode)
    local wasDown = Menu.KeyStates[keyCode] or false
    Menu.KeyStates[keyCode] = down == true
    if pressed == true then return true end
    if down == true and not wasDown then return true end
    return false
end

function Menu.HandleSliderChange(item, direction)
    if item.type == "slider" then
        local step = item.step or 1
        item.value = math.max(item.min or 0, math.min(item.max or 100, (item.value or item.min or 0) + (step * direction)))
        if item.onClick then item.onClick(item.value) end
    elseif item.type == "toggle" and item.hasSlider then
        local step = item.sliderStep or 0.1
        item.sliderValue = math.max(item.sliderMin or 0, math.min(item.sliderMax or 100, (item.sliderValue or item.sliderMin or 0) + (step * direction)))
        if item.onSliderChange then item.onSliderChange(item.sliderValue) end
    end
end

function Menu.ActivateCurrentItem()
    local item = Menu.Items[Menu.CurrentItem]
    if not item or not Menu.IsSelectableItem(item) then return end

    if item.type == "toggle" then
        item.value = not item.value
        if Menu.Notify then
            Menu.Notify(item.value and "success" or "info", item.name .. ": " .. (item.value and "Enabled" or "Disabled"))
        end
        if item.onClick then item.onClick(item.value) end
    elseif item.type == "action" then
        if item.onClick then item.onClick() end
    end
end

function Menu.HandleInput()
    if Menu.IsLoading then return end

    if Menu.SelectingKey then
        Menu.HandleKeySelection()
        return
    end

    if Menu.SelectingFeatureBind then
        Menu.HandleFeatureKeySelection()
        return
    end

    Menu.HandleFeatureKeybinds()

    if not Menu.LoadingComplete then return end

    local toggleKeyCode = Menu.SelectedKey
    if toggleKeyCode and Menu.IsKeyJustPressed(toggleKeyCode) then
        Menu.Visible = not Menu.Visible
        if not Menu.Visible and Susano and Susano.ResetFrame and not Menu.PreventResetFrame then
            Susano.ResetFrame()
        end
    end

    if not Menu.Visible then return end

    if Menu.IsKeyJustPressed(0x26) then
        Menu.CurrentItem = Menu.FindNextSelectable(Menu.CurrentItem, -1)
        Menu.UpdateSectionName()
    elseif Menu.IsKeyJustPressed(0x28) then
        Menu.CurrentItem = Menu.FindNextSelectable(Menu.CurrentItem, 1)
        Menu.UpdateSectionName()
    elseif Menu.IsKeyJustPressed(0x25) then
        local item = Menu.Items[Menu.CurrentItem]
        if item then Menu.HandleSliderChange(item, -1) end
    elseif Menu.IsKeyJustPressed(0x27) then
        local item = Menu.Items[Menu.CurrentItem]
        if item then Menu.HandleSliderChange(item, 1) end
    elseif Menu.IsKeyJustPressed(0x78) then
        local item = Menu.Items[Menu.CurrentItem]
        if item and Menu.IsSelectableItem(item) and (item.type == "toggle" or item.type == "action") then
            Menu.SelectingFeatureBind = true
            Menu.BindingFeatureItem = item
            Menu.BindingFeatureKey = item.bindKey
            Menu.BindingFeatureKeyName = item.bindKeyName or "..."
        end
    elseif Menu.IsKeyJustPressed(0x0D) then
        Menu.ActivateCurrentItem()
    end
end

CreateThread(function()
    while true do
        Menu.Render()
        Menu.HandleInput()
        Wait(0)
    end
end)

if Menu.Banner.enabled and Menu.Banner.imageUrl and Menu.Banner.imageUrl ~= "" and Menu.Banner.imageUrl ~= "BANNER_URL_HERE" then
    Menu.LoadBannerTexture(Menu.Banner.imageUrl)
end

CreateThread(function()
    while true do
        Wait(5000)
        if Menu.Banner.enabled and Menu.Banner.imageUrl and Menu.Banner.imageUrl ~= "" and Menu.Banner.imageUrl ~= "BANNER_URL_HERE" then
            if (not Menu.bannerTexture or Menu.bannerTexture == 0) and not Menu.bannerLoading then
                Menu.LoadBannerTexture(Menu.Banner.imageUrl)
            end
        end
    end
end)

return Menu
