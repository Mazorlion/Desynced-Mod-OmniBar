local package = ...

function package:init_ui()
    InputDefaultActionMappings.OmniBar = "Z"
    InputTooltips.OmniBar = "Opens the omnibar."

    Input.BindAction("Omnibar", "Released", ToggleOmniBar)
end

-- If not nil, the open omnibar widget.
local open_window
-- If not nil, the anchor for the omnibar and open_window is a MenuPopup.
local anchor
-- Public functions
function ToggleOmniBar(is_for_settings)
    if open_window then
        return CloseOmniBar()
    end
    if is_for_settings then
        -- Create a non-popup omnibar so it moves visibly for tweaking settings.
        open_window = UI.AddLayout("OmniBar", 200)
    else
        anchor = UI.AddLayout([[<Box dock=center/>]], {
            destruct = function()
                anchor = nil
            end
        }, 20)
        local width, height = UI.GetScreenSize()
        open_window = UI.MenuPopup("OmniBar", "DOWN", "MIDDLE", anchor, width / 2, height / 2)
    end
end

function UpdateOmniBarPosition()
    if open_window then
        open_window:update_position()
        open_window:update_scale()
    end
end

local OmniBar_layout <const> =
[[
    <Scale dock=center blocking=false>
        <VerticalList height=1 blocking=false>
            <Box bg=popup_additional_bg padding=4 blocking=false>
                <VerticalList child_padding=4>
                    <TextSearch id=inst_search margin=3 on_refresh={on_filter} width=500/>
                </VerticalList>
            </Box>
            <Box bg=popup_additional_bg padding=4 blocking=false>
                <ScrollList orientation=vertical id=results max_height=500/>
            </Box>
        </VerticalList>
    </Scale>
]]

local OmniBar <const> = {}
UI.Register("OmniBar", OmniBar_layout, OmniBar)


function CloseOmniBar()
    -- If it's anchored that above won't trigger.
    if anchor then
        return anchor:RemoveFromParent()
    end
    if open_window then
        open_window:RemoveFromParent()
    end
end

local CodexButton_layout <const> =
[[
	<Canvas>
		<Button on_click={on_select} width=320><Text text={text} width=280 halign=left wrap=true/></Button>
	</Canvas>
]]

local catdefs = {}
local cats = {}
function OmniBar:update_scale()
    local profile = Game.GetProfile()
    -- Default to UI scale.
    local scale = UI.GetScale()
    if profile.omnibar and profile.omnibar.scale then
        scale = scale * profile.omnibar.scale / 100
    end
    self.scale = scale
end

function OmniBar:construct()
    -- Calculate the breakpoints for interpolation.
    local width, height = UI.GetScreenSize()
    -- Put the bar slghtly above center-screen.
    self.base_y = -150
    -- Absolute y_offset taking screen size into account.
    self.max_y = height / 2 + self.base_y
    self.min_y = -1 * height / 2
    self.y = self.base_y

    -- Center on the X axis.
    self.base_x = 0
    self.max_x = width / 2
    self.min_x = -1 * width / 2
    self.x = self.base_x

    -- Update our position based on thoese values and the profile.
    self:update_position()
    self:update_scale()

    -- Animate and add fx to the opening of the window.
    self:TweenFromTo("sx", 0.01, 1, 40, "OutQuad")
    self:TweenFromTo("sy", 0.01, 1, 80, "OutQuad")
    UI.PlaySound("fx_ui_WINDOW_SELECTION_MENU_OPEN")

    -- Capture escape key to close the window or else it opens the main menu.
    local process_input = function(key_name, is_down, axis, mouse_delta)
        if key_name == "ESCAPE" and open_window then
            return CloseOmniBar()
        end
        return true
    end
    -- We delay focusing the search box so we don't prevent things like
    -- stopping camera panning because we let the text box eat a keyup event.
    Input.SetInputProcessor(function(key_name, is_down, axis, mouse_delta)
        -- Pan lock can still happen if a key is pressed after opening the menu.
        -- Not really worried about that part so much.
        if is_down then
            -- This input is intended for the omnibar, set everything up.
            Input.ClearInputProcessor()
            self.inst_search:Focus()
            Input.SetInputProcessor(process_input)
        end
        return true
    end)

    -- TODO(maz): Finish implementing codex entries below.
    if true then
        return
    end

    -- === CODEX ENTRIES ===
    -- Gather all categories
    local faction = Game.GetLocalPlayerFaction()
    for id, def in pairs(data.codex) do
        if faction:IsUnlocked(id) and def.category then
            local cat = def.category
            if not catdefs[cat] then
                catdefs[cat] = {}
                table.insert(cats, cat)
            end
            table.insert(catdefs[cat], def)
        end
    end
    table.sort(cats)
end

-- Returns a value found by moving `a` towards `b` by `percent`.
-- If `percent` is negative, moves away in the same proportions.
local function interpolate(a, b, percent)
    return a + (b - a) * percent / 100
end
function OmniBar:update_position()
    local profile = Game.GetProfile()
    if profile.omnibar then
        local y_offset = profile.omnibar.y_offset or 0
        if y_offset < 0 then
            self.y = interpolate(self.base_y, self.min_y, math.abs(y_offset))
        else
            self.y = interpolate(self.base_y, self.max_y, y_offset)
        end
        local x_offset = profile.omnibar.x_offset or 0
        if x_offset < 0 then
            self.x = interpolate(self.base_x, self.min_x, math.abs(x_offset))
        else
            self.x = interpolate(self.base_x, self.max_x, x_offset)
        end
    end
end

function OmniBar:destruct()
    Input.ClearInputProcessor()
    -- Remove reference to ourselves.
    open_window = nil
    -- Clear codex stuff.
    catdefs = {}
    cats = {}
end

-- Filters the items to appear in `results` by `txt`.
function OmniBar:on_filter(widget, txt)
    local filter = txt and txt ~= "" and txt:lower()

    -- Always clear results even if the search is empty.
    self.results:Clear()

    if not filter then
        return
    end

    local lastcat, catwrap
    ProcessUnlockedDefinitions(function(id, def, category)
        local found = not filter or string.find(string.lower(L(def.name or "")), filter) -- filter by text
        if not found then return end
        if lastcat ~= category then
            lastcat = category
            self.results:Add("Spacer", { height = 10 })
            self.results:Add("Text", { text = category.name })
            self.results:Add("Spacer", { height = 5 })
            catwrap = self.results:Add("<Wrap child_padding=4/>")
        end
        catwrap:Add("<Reg bg=item_default/>", { def = def })
    end)

    -- TODO(maz): Finish implementing codex entries below.
    if true then
        return
    end

    local extra = Game.GetLocalPlayerExtra()
    local read_codex = extra.read_codex or {}
    for _, cat_id in ipairs(cats) do
        local defs = catdefs[cat_id]
        -- self.results:Add("<Text color=ui_light margin_bottom=5 margin_top=10/>", { text = cat_id })
        table.sort(defs,
            function(a, b)
                if a.index and b.index then return a.index < b.index end
                return a.title < b.title
            end)
        for _, def in ipairs(defs) do
            if string.find(string.lower(def.title), filter) then
                local newbutton = self.results:Add(CodexButton_layout, {
                    def = def,
                    text = def.title,
                    infohidden = read_codex[def.id],
                })
            end
            -- if openid and openid == def.id then
            --     self:on_select(newbutton)
            --     openid = nil
            -- end
        end
    end
end
