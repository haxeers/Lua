local Menu = {}

Menu.Visible = false
Menu.CurrentItem = 1
Menu.ItemScrollOffset = 0
Menu.ItemsPerPage = 8
Menu.SelectorY = 0
Menu.SmoothFactor = 0.22
Menu.Scale = 1.0
Menu.LoadingComplete = true
Menu.IsLoading = false
Menu.SelectedKey = 0x51
Menu.SelectedKeyName = "Q"
Menu.SectionName = "Menu"
Menu.Title = "phantom"
Menu.FooterText = "phantom.lua"
Menu.BrandAnimStart = nil
Menu.Items = {}

Menu.Banner = {
    enabled = true,
    imageUrl = "",
    height = 100
}

Menu.bannerTexture = nil
Menu.bannerWidth = 0
Menu.bannerHeight = 0

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

function Menu.LoadBannerTexture(url)
    if not url or url == "" then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end

    CreateThread(function()
        pcall(function()
            local status, body = Susano.HttpGet(url)
            if status == 200 and body and #body > 0 then
                local textureId, width, height = Susano.LoadTextureFromBuffer(body)
                if textureId and textureId ~= 0 then
                    Menu.bannerTexture = textureId
                    Menu.bannerWidth = width
                    Menu.bannerHeight = height
                end
            end
        end)
    end)
end

function Menu.ColorToUnit(r, g, b, a)
    a = a or 255
    if r > 1 then r = r / 255 end
    if g > 1 then g = g / 255 end
    if b > 1 then b = b / 255 end
    if a > 1 then a = a / 255 end
    return r, g, b, a
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

    if Menu.Banner.enabled and Menu.bannerTexture and Menu.bannerTexture > 0 and Susano and Susano.DrawImage then
        Susano.DrawImage(Menu.bannerTexture, x, y, width, bannerHeight, 1, 1, 1, 1, pos.headerRadius)
        Menu.DrawRect(x, y, width, bannerHeight, 0, 0, 0, 140, pos.headerRadius)
    else
        Menu.DrawRect(x, y, width, bannerHeight, 0, 0, 0, 255, pos.headerRadius)
    end

    local titleSize = 34 * scale
    Menu.DrawBrandText(x + (width / 2), y + (bannerHeight / 2), titleSize, "")
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
    Menu.DrawText(textX, textY, item.name or "", 17, textR, textG, textB, 255)

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

    Menu.UpdateSectionName()
    Menu.UpdateBrandAnim()
    Susano.BeginFrame()

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

    if not Menu.Visible and not Menu.PreventResetFrame then
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
    if not Menu.LoadingComplete then return end

    local toggleKeyCode = Menu.SelectedKey or 0x51
    if Menu.IsKeyJustPressed(toggleKeyCode) then
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

if Menu.Banner.enabled and Menu.Banner.imageUrl and Menu.Banner.imageUrl ~= "" then
    Menu.LoadBannerTexture(Menu.Banner.imageUrl)
end

return Menu
