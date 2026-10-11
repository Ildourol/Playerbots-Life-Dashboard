local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Widgets = {}
LifeDashboard.Widgets = Widgets

-- Standard dark backdrop for 3.3.5
function Widgets:ApplyDarkBackdrop(frame, bgAlpha, edgeAlpha)
    bgAlpha = bgAlpha or 0.85
    edgeAlpha = edgeAlpha or 0.6
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame:SetBackdropColor(0.08, 0.08, 0.12, bgAlpha)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.45, edgeAlpha)
end

function Widgets:ApplyCardBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame:SetBackdropColor(0.12, 0.14, 0.18, 0.8)
    frame:SetBackdropBorderColor(0.4, 0.45, 0.6, 0.5)
end

-- ─── Stat Card Creator ────────────────────────────────────────────────────────
function Widgets:CreateStatCard(parent, width, height, titleText)
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(width)
    card:SetHeight(height)
    self:ApplyCardBackdrop(card)

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
    title:SetText(titleText)
    title:SetTextColor(0.8, 0.8, 0.9)
    card.Title = title

    local value = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    value:SetPoint("CENTER", card, "CENTER", 0, -4)
    value:SetText("0")
    value:SetTextColor(1, 0.82, 0)
    card.Value = value

    local subtext = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtext:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 8, 5)
    subtext:SetText("")
    card.Subtext = subtext

    return card
end

-- ─── Virtualized Table Frame (HybridScrollFrame Pattern) ──────────────────────
function Widgets:CreateVirtualizedTable(parent, width, height, rowHeight, columns, onBindRow)
    local container = CreateFrame("Frame", nil, parent)
    container:SetWidth(width)
    container:SetHeight(height)
    self:ApplyDarkBackdrop(container, 0.4, 0.3)

    -- Header row
    local headerBar = CreateFrame("Frame", nil, container)
    headerBar:SetWidth(width - 24)
    headerBar:SetHeight(22)
    headerBar:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -4)

    local curX = 0
    headerBar.columns = {}
    for i, col in ipairs(columns) do
        local btn = CreateFrame("Button", nil, headerBar)
        btn:SetWidth(col.width)
        btn:SetHeight(20)
        btn:SetPoint("LEFT", headerBar, "LEFT", curX, 0)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
        fs:SetText(col.name)
        btn.Text = fs
        headerBar.columns[i] = btn
        curX = curX + col.width
    end

    -- ScrollFrame container
    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -28)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -22, 4)

    -- ScrollBar
    local scrollBar = CreateFrame("Slider", nil, container, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -40)
    scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 24)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(1)
    scrollBar:SetWidth(16)
    container.ScrollBar = scrollBar

    -- Pool of visible rows
    local visibleRowCount = math.floor((height - 32) / rowHeight)
    local rows = {}
    for i = 1, visibleRowCount do
        local row = CreateFrame("Button", nil, scrollFrame)
        row:SetWidth(width - 24)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((i - 1) * rowHeight))

        -- Highlight texture on mouse hover
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetAlpha(0.25)

        -- Cell font strings
        row.cells = {}
        local cellX = 0
        for cIdx, col in ipairs(columns) do
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetWidth(col.width - 6)
            fs:SetHeight(rowHeight)
            fs:SetPoint("LEFT", row, "LEFT", cellX + 4, 0)
            fs:SetJustifyH(col.align or "LEFT")
            row.cells[cIdx] = fs
            cellX = cellX + col.width
        end

        rows[i] = row
    end
    container.Rows = rows
    container.RowHeight = rowHeight
    container.VisibleRowCount = visibleRowCount
    container.DataList = {}

    local function UpdateDisplay()
        local data = container.DataList or {}
        local total = #data
        local maxScroll = math.max(0, total - visibleRowCount)
        scrollBar:SetMinMaxValues(0, maxScroll)

        local offset = math.floor(scrollBar:GetValue())
        for i = 1, visibleRowCount do
            local dataIdx = offset + i
            local row = rows[i]
            if dataIdx <= total then
                row:Show()
                local item = data[dataIdx]
                if onBindRow then
                    onBindRow(row, item, dataIdx)
                end
            else
                row:Hide()
            end
        end
    end

    scrollBar:SetScript("OnValueChanged", function(self, value)
        UpdateDisplay()
    end)

    container:EnableMouseWheel(true)
    container:SetScript("OnMouseWheel", function(self, delta)
        local cur = scrollBar:GetValue()
        scrollBar:SetValue(cur - delta * 3)
    end)

    container.SetData = function(self, dataList)
        self.DataList = dataList or {}
        UpdateDisplay()
    end

    container.Refresh = UpdateDisplay

    return container
end

-- ─── Search Box Creator ───────────────────────────────────────────────────────
function Widgets:CreateSearchBox(parent, width, placeholder, onTextChanged)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetWidth(width)
    eb:SetHeight(22)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetAutoFocus(false)
    eb:SetTextInsets(6, 6, 2, 2)
    self:ApplyDarkBackdrop(eb, 0.7, 0.5)

    local ph = eb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", eb, "LEFT", 6, 0)
    ph:SetText(placeholder or "Search...")

    eb:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text == "" then
            ph:Show()
        else
            ph:Hide()
        end
        if onTextChanged then
            onTextChanged(text)
        end
    end)

    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return eb
end
