local env, db = CPAPI.GetEnv(...)
local MapData = env.MapData
local MapRingButtonMixin = CreateFromMixins(CPActionButton)
local Selector = Mixin(CPAPI.EventHandler(ConsolePortMapRing, {
    'PLAYER_REGEN_DISABLED';
    'PLAYER_REGEN_ENABLED';
}), CPAPI.SecureEnvironmentMixin);

---------------------------------------------------------------
-- Constants
---------------------------------------------------------------
local MAPRING_BINDING = 'TOGGLEWORLDMAP'
local BTN_NAME_PREFIX = 'CPMR%s'

---------------------------------------------------------------
-- State
---------------------------------------------------------------
Selector.currentPage  = 1
Selector.currentChildren = {}
Selector.currentLayout   = nil
Selector.currentMapID    = nil
Selector.pendingShow     = false

---------------------------------------------------------------
-- Input configurations
---------------------------------------------------------------
Selector.Configuration = {
    Left = {
        Secondary = 'Right';
        Buttons = {
            Accept    = 'PAD1';           -- Cross: confirm/drill into
            Cancel    = 'PAD2';           -- Circle: go back/dismiss
            PagePrev  = 'PADLSHOULDER';   -- L1: previous page
            PageNext  = 'PADRSHOULDER';   -- R1: next page
        };
    };
    Right = {
        Secondary = 'Left';
        Buttons = {
            Accept    = 'PADDDOWN';
            Cancel    = 'PADDRIGHT';
            PagePrev  = 'PADLSHOULDER';
            PageNext  = 'PADRSHOULDER';
        };
    };
}

---------------------------------------------------------------
-- Secure environment
---------------------------------------------------------------
Selector:SetAttribute('numbuttons', 0)
Selector:SetAttribute(CPAPI.ActionTypePress, 'macro')
Selector:SetAttribute(CPAPI.ActionPressAndHold, true)
Selector:SetFrameRef('trigger', Selector.Trigger)
Selector:Run([[
    selector = self;
    trigger  = self:GetFrameRef('trigger');
    BUTTONS  = {};
    TRIGGERS = {};
    COMMANDS = {};
]])

Selector.PrivateEnv = {
    -- Trigger: toggle ring on click
    OnTrigger = [[
        if selector:IsVisible() then
            return selector::ClearAndHide(true)
        end
        -- Only show if world map is open
        if not selector:GetAttribute('mapOpen') then
            return
        end
        selector::EnableRing()
        for binding, action in pairs(TRIGGERS) do
            selector:SetBinding(true, binding, action)
        end

        local mods = { selector::GetActiveModifiers() };
        local name = selector:GetName();

        for binding, command in pairs(COMMANDS) do
            selector:SetBindingClick(true, binding, name, command)
            for _, mod in ipairs(mods) do
                selector:SetBindingClick(true, mod..binding, name, command)
            end
        end
    ]];
    -- Enable the ring display and set up bindings
    EnableRing = [[
        self:Show()
        self:CallMethod('OnSecureShow')
        self:CallMethod('UpdatePieSlices', true, self:GetAttribute('numbuttons'))
    ]];
    -- Enable ring with full binding setup (used when reopening from insecure code)
    EnableRingFull = [[
        selector::EnableRing()
        for binding, action in pairs(TRIGGERS) do
            selector:SetBinding(true, binding, action)
        end

        local mods = { selector::GetActiveModifiers() };
        local name = selector:GetName();

        for binding, command in pairs(COMMANDS) do
            selector:SetBindingClick(true, binding, name, command)
            for _, mod in ipairs(mods) do
                selector:SetBindingClick(true, mod..binding, name, command)
            end
        end
    ]];
    -- Clear and hide the ring
    ClearAndHide = [[
        local clearInstantly = ...;
        if clearInstantly then
            self:CallMethod('ClearInstantly')
        end

        self:Hide()
        self:ClearBindings()
        self:CallMethod('OnSecureHide')
    ]];
    -- PreClick: handle all click commands on the ring itself
    PreClick = ([[ 
        local type = %q;
        local command = button;

        -- Cancel: go back or dismiss
        if command == CANCEL then
            self:CallMethod('OnCancel')
            return
        end

        -- PagePrev/PageNext: change page
        if command == PAGEPREV then
            self:CallMethod('OnPagePrev')
            return
        end
        if command == PAGENEXT then
            self:CallMethod('OnPageNext')
            return
        end

        -- Accept (LeftButton): get focused button and navigate
        self::UpdateSize()
        local index = self::GetIndex(PRIMARY_STICK) or self::GetIndex(SECONDARY_STICK)
        if index then
            self:CallMethod('OnAccept', index)
        end
        self::ClearAndHide(true)
    ]]):format(CPAPI.ActionTypeRelease);
    -- Button post-click
    ButtonPostClick = ([[ 
        self:CallMethod('OnClear')
        self:SetAttribute(%q, self:GetAttribute('command'))
    ]]):format(CPAPI.ActionTypeRelease);
}

Selector:CreateEnvironment(Selector.PrivateEnv)
Selector:Hook(Selector.Trigger, 'OnClick', Selector.PrivateEnv.OnTrigger)
Selector:Wrap('PreClick', Selector.PrivateEnv.PreClick)

---------------------------------------------------------------
-- Secure show/hide callbacks (insecure, called from secure env)
---------------------------------------------------------------
function Selector:OnSecureShow()
    self:RefreshContent()
end

function Selector:OnSecureHide()
    local handle = db.UIHandle
    if handle then
        handle:RemoveHint(self.buttons and self.buttons.Accept)
        handle:RemoveHint(self.buttons and self.buttons.Cancel)
        handle:RemoveHint(self.buttons and self.buttons.PagePrev)
        handle:RemoveHint(self.buttons and self.buttons.PageNext)
    end
    self.PageIndicator:Hide()
end

---------------------------------------------------------------
-- Handler
---------------------------------------------------------------
function Selector:OnDataLoaded()
    local counter = CreateCounter()
    self:CreateObjectPool(function()
        return CreateFrame(
            'CheckButton',
            BTN_NAME_PREFIX:format(string.char(96 + counter())),
            self, 'ActionButtonTemplate, SecureActionButtonTemplate')
        end,
        function(_, btn)
            btn:Hide()
            btn:ClearAllPoints()
            if btn.OnClear then btn:OnClear() end
        end, MapRingButtonMixin)

    local sticks    = db.Radial:GetStickStruct(db('radialPrimaryStick'))
    local primary   = sticks[1]
    local secondary = (self.Configuration[primary] or self.Configuration.Left).Secondary

    db.Radial:Register(self, 'MapRing', {
        sticks = { primary, secondary };
        target = { primary, secondary };
        sizer  = [[ local size = ...; ]];
    })

    self:SetFixedSize(500)
    self:OnAxisInversionChanged()
    self:OnControlsChanged()
    self:OnSizingChanged()
    self.ActiveSlice:SetAlpha(0)

    -- Hook world map show/hide to track state
    if WorldMapFrame then
        WorldMapFrame:HookScript('OnShow', function()
            self:SetAttribute('mapOpen', true)
        end)
        WorldMapFrame:HookScript('OnHide', function()
            self:SetAttribute('mapOpen', false)
            if self:IsVisible() then
                self:Dismiss()
            end
        end)
        hooksecurefunc(WorldMapFrame, 'OnMapChanged', function()
            if self:IsVisible() then
                self:RefreshContent()
            elseif self.reopenAfterMapChange then
                self.reopenAfterMapChange = nil
                if not InCombatLockdown() then
                    self:RefreshContent()
                    self:Run([[ selector::EnableRingFull() ]])
                end
            end
        end)
    end

    return CPAPI.BurnAfterReading
end

function Selector:OnAxisInversionChanged()
    self.axisInversion = db('radialCosineDelta')
end

function Selector:OnSizingChanged()
    self:SetScale(db('mapRingScale') or 1.0)
    self:SetSliceTextSize(db('mapRingFontSize') or 13)
end

function Selector:OnControlsChanged()
    self:Run([[
        wipe(TRIGGERS)
        wipe(COMMANDS)
        self:ClearBindings()
    ]])

    local sticks    = db.Radial:GetStickStruct(db('radialPrimaryStick'))
    local primary   = sticks[1]
    local config    = self.Configuration[primary] or self.Configuration.Left
    local secondary = config.Secondary

    self.buttons = config.Buttons

    self:SetInterrupt({ primary, secondary })
    self:SetIntercept({ primary, secondary })

    self:Run([[
        ACCEPT, CANCEL, PAGEPREV, PAGENEXT, PRIMARY_STICK, SECONDARY_STICK = %q, %q, %q, %q, %q, %q;
        COMMANDS[ACCEPT]    = 'LeftButton';
        COMMANDS[CANCEL]    = 'Cancel';
        COMMANDS[PAGEPREV]  = 'PagePrev';
        COMMANDS[PAGENEXT]  = 'PageNext';
    ]], config.Buttons.Accept, config.Buttons.Cancel,
        config.Buttons.PagePrev, config.Buttons.PageNext,
        primary, secondary)

    -- TRIGGERS: bind Cancel and PageNext to close the map (toggle off)
    -- This allows closing the map/world map with modifier+Cancel/PageNext
    for modifier in db:For('Gamepad/Index/Modifier/Active') do
        self:Run([[
            local binding, modifier = %q, %q;
            TRIGGERS[modifier..%q] = binding;
            TRIGGERS[modifier..%q] = binding;
        ]], MAPRING_BINDING, modifier,
            config.Buttons.Cancel, config.Buttons.PageNext)
    end
end

---------------------------------------------------------------
-- Combat lockdown handling
---------------------------------------------------------------
function Selector:PLAYER_REGEN_DISABLED()
    if self:IsVisible() then
        self.pendingShow = true
        self:Dismiss()
    end
end

function Selector:PLAYER_REGEN_ENABLED()
    if self.pendingShow then
        self.pendingShow = nil
        self:RefreshContent()
        self:Run([[ selector::EnableRingFull() ]])
    end
end

---------------------------------------------------------------
-- Content management
---------------------------------------------------------------
function Selector:RefreshContent()
    local mapID = MapData.GetCurrentMapID()
    if not mapID then return end

    self.currentMapID = mapID
    local children, parentMapID = MapData.GetChildrenForMap(mapID)
    self.currentChildren = children
    self.currentLayout = MapData.GetLayout(#children)

    if not self.currentLayout then
        -- No child maps for current map, dismiss ring
        self:Dismiss()
        return
    end

    self.currentPage = 1
    self:UpdatePage()
end

function Selector:UpdatePage()
    local layout = self.currentLayout
    if not layout then return end

    local pageItems = MapData.GetPage(self.currentChildren, self.currentPage, layout.perPage)
    local numItems = #pageItems

    -- Adjust ring size for layout
    if layout.size ~= self.fixedSize then
        self:SetFixedSize(layout.size)
    end

    -- Clear existing buttons and secure references
    self:ReleaseAll()
    self:Run([[ wipe(BUTTONS) ]])

    -- Update secure attributes
    self:SetAttribute('size', numItems)
    self:SetAttribute('numbuttons', numItems)
    self:SetDynamicRadius(numItems)

    -- Add buttons for this page
    for i, data in ipairs(pageItems) do
        self:AddButton(i, data, numItems)
    end

    -- Update visual elements
    self:UpdatePageIndicator()
    self:UpdateHints()
    self:UpdatePieSlices(true, numItems)
end

function Selector:AddButton(i, data, size)
    local button, newObj = self:Acquire(i)
    local p, x, y = self:GetPointForIndex(i, size)
    if newObj then
        button:SetSize(60, 60)
        button:RegisterForClicks('AnyUp')
        button:SetAttribute(CPAPI.ActionPressAndHold, true)
        button.Name:Hide()
    end
    button:SetPoint(p, x, self.axisInversion * y)
    button:SetRotation(self:GetRotation(x, y))
    button:SetID(i)
    button:Show()
    button:SetData(data)
    self:SetAttribute('numbuttons', math.max(i, self:GetAttribute('numbuttons')))
    self:SetFrameRef(tostring(i), button)
    self:Run([[
        local index  = %d;
        local button = self:GetFrameRef(tostring(index))
        BUTTONS[index] = button;
    ]], i)
    self:Hook(button, 'PostClick', self.PrivateEnv.ButtonPostClick)
end

---------------------------------------------------------------
-- Page navigation (called from secure environment via CallMethod)
---------------------------------------------------------------
function Selector:OnPagePrev()
    if not self.currentLayout or not self.currentLayout.needPaging then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        return
    end

    if self.currentPage > 1 then
        self.currentPage = self.currentPage - 1
        PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        self:UpdatePage()
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
end

function Selector:OnPageNext()
    if not self.currentLayout or not self.currentLayout.needPaging then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        return
    end

    if self.currentPage < self.currentLayout.totalPages then
        self.currentPage = self.currentPage + 1
        PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        self:UpdatePage()
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
end

---------------------------------------------------------------
-- Navigation actions (called from secure environment via CallMethod)
---------------------------------------------------------------
function Selector:OnAccept(index)
    if not self.currentChildren then return end

    local pageItems = MapData.GetPage(self.currentChildren, self.currentPage, self.currentLayout.perPage)
    local item = pageItems[index]
    if not item then return end

    -- Navigate to the selected map
    MapData.NavigateToMap(item.mapID)

    -- If the item has children, mark that ring should reopen after map change
    if item.hasChildren then
        self.reopenAfterMapChange = true
    end
end

function Selector:OnCancel()
    if not self.currentMapID then
        self:Dismiss()
        return
    end

    local _, parentMapID = MapData.GetChildrenForMap(self.currentMapID)
    if parentMapID and parentMapID ~= 0 then
        -- Navigate to parent, keep ring open with new content
        MapData.NavigateToMap(parentMapID)
        self:RefreshContent()
    else
        -- Already at root, dismiss ring
        self:Dismiss()
    end
end

---------------------------------------------------------------
-- Dismiss the ring
---------------------------------------------------------------
function Selector:Dismiss()
    self:ClearInstantly()
    self:Hide()
    if not InCombatLockdown() then
        self:Run([[ self:ClearBindings() ]])
    end
    self:OnSecureHide()
end

---------------------------------------------------------------
-- Page indicator
---------------------------------------------------------------
function Selector:UpdatePageIndicator()
    local layout = self.currentLayout
    if not layout or not layout.needPaging then
        self.PageIndicator:Hide()
        return
    end

    self.PageIndicator.Text:SetFormattedText('%d / %d', self.currentPage, layout.totalPages)
    self.PageIndicator:Show()
end

---------------------------------------------------------------
-- Hints
---------------------------------------------------------------
function Selector:UpdateHints()
    local layout = self.currentLayout
    if not layout or not self.buttons then return end

    local handle = db.UIHandle
    if not handle then return end

    handle:RemoveHint(self.buttons.Accept)
    handle:RemoveHint(self.buttons.Cancel)
    handle:RemoveHint(self.buttons.PagePrev)
    handle:RemoveHint(self.buttons.PageNext)

    handle:AddHint(self.buttons.Accept, SELECT)
    handle:AddHint(self.buttons.Cancel, BACK)

    if layout.needPaging then
        handle:AddHint(self.buttons.PagePrev, PREVIOUS)
        handle:AddHint(self.buttons.PageNext, NEXT)
    end
end

---------------------------------------------------------------
-- Input handler
---------------------------------------------------------------
function Selector:OnInput(x, y, len)
    self:SetFocusByIndex(self:GetIndexForPos(x, y, len, self:GetNumActive()))
    self:ReflectStickPosition(self.axisInversion * x, self.axisInversion * y, len, len > self:GetValidThreshold())

    local handle = db.UIHandle
    if not handle or not self.buttons then return end

    if len < self:GetValidThreshold() then
        handle:AddHint(self.buttons.Accept, CLOSE)
        handle:RemoveHint(self.buttons.Cancel)
    else
        handle:AddHint(self.buttons.Cancel, BACK)
    end
end

function Selector:SetSliceText(...)
    CPPieMenuMixin.SetSliceText(self, ...)
end

---------------------------------------------------------------
-- Button mixin
---------------------------------------------------------------
local ActionButton = LibStub('ConsolePortActionButton')

function MapRingButtonMixin:Update()
    ActionButton.Skin.RingButton(self)
    RunNextFrame(function()
        self.Name:SetText(self.text)
        if self.atlas then
            self.icon:SetAtlas(self.atlas)
        elseif self.img then
            self.icon:SetTexCoord(0, 1, 0, 1)
            self.icon:SetTexture(self.img)
        end
        self:GetParent():SetSliceText(self:GetID(), self:GetSliceText())
    end)
end

function MapRingButtonMixin:SetData(data)
    if not data then return end

    self.mapID       = data.mapID
    self.text        = data.name or ''
    self.hasChildren = data.hasChildren

    if data.iconAtlas then
        self.atlas = data.iconAtlas
        self.img = nil
    else
        self.img = [[Interface\ICONS\INV_Misc_Map_01]]
        self.atlas = nil
    end

    -- Secure click: this button triggers Accept on the parent ring
    self:SetAttribute(CPAPI.ActionTypeRelease, 'custom')
    self:SetAttribute('command', 'Accept')

    self:Update()
end

function MapRingButtonMixin:OnFocus()
    if not self.isFocused then
        PlaySound(SOUNDKIT.SCROLLBAR_STEP, 'SFX', true)
        self.isFocused = true
    end
    self:LockHighlight()
    local parent = self:GetParent()
    local hint = self.hasChildren and (self.text .. ' ▸') or self.text
    if parent.buttons and db.UIHandle then
        db.UIHandle:AddHint(parent.buttons.Accept, hint)
    end
    parent:SetActiveSliceText(self:GetSliceText())
end

function MapRingButtonMixin:GetSliceText()
    local suffix = self.hasChildren and ('\n|cffffffff▸|r') or ''
    return ('%s%s'):format(self.text or '', suffix)
end

function MapRingButtonMixin:OnClear()
    self.isFocused = nil
    self:UnlockHighlight()
    self:SetChecked(false)
    self:GetParent():SetActiveSliceText(nil)
end

---------------------------------------------------------------
-- Callbacks
---------------------------------------------------------------
db:RegisterSafeCallback('Settings/radialCosineDelta', Selector.OnAxisInversionChanged, Selector)
db:RegisterSafeCallbacks(Selector.OnControlsChanged, Selector,
    'OnModifierChanged',
    'Settings/radialPrimaryStick'
)
db:RegisterSafeCallbacks(Selector.OnSizingChanged, Selector,
    'Settings/mapRingScale',
    'Settings/mapRingFontSize'
)
