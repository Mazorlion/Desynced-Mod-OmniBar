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
-- Toggles the omnibar, returns true if it was created false otherwise.
function ToggleOmniBar(is_for_settings)
    if open_window then
        CloseOmniBar()
        return false
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
    return true
end

function UpdateOmniBarPosition()
    if open_window then
        open_window:update_position()
        open_window:update_scale()
    end
end

function CloseOmniBar()
    -- If it's anchored that above won't trigger.
    if anchor then
        return anchor:RemoveFromParent()
    end
    if open_window then
        open_window:RemoveFromParent()
    end
end

-- ==== Internals ===

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

local catdefs = {}
local cats = {}

function OmniBar:destruct()
    Input.ClearInputProcessor()
    -- Remove reference to ourselves.
    open_window = nil
    -- Clear codex stuff.
    catdefs = {}
    cats = {}
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

    -- Doesnt work yet.
    self:show_instruction_variables()

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

-- Updates the scale of the bar based on profile and UI settings.
function OmniBar:update_scale()
    local profile = Game.GetProfile()
    -- Default to UI scale.
    local scale = UI.GetScale()
    if profile.omnibar and profile.omnibar.scale then
        scale = scale * profile.omnibar.scale / 100
    end
    self.scale = scale
end

-- Layout for codex buttons in the results.
local CodexButton_layout <const> =
[[
	<Canvas>
		<Button on_click={on_select} width=320><Text text={text} width=280 halign=left wrap=true/></Button>
	</Canvas>
]]

-- Filters the items to appear in `results` by `txt`.
function OmniBar:on_filter(widget, txt)
    local filter = txt and txt ~= "" and txt:lower()
    -- Always clear results even if the search is empty.
    self.results:Clear()
    if not filter then
        return
    end

    local main_window, window_name = GetMainWindow()
    if window_name == "Program" then
        -- Order instructions first when editing behaviors.
        self:filter_instructions(filter)
        self:filter_unlockables(filter)
    else
        self:filter_unlockables(filter)
        self:filter_instructions(filter)
    end

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

function OmniBar:filter_unlockables(filter)
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
        local inst = {
            [1] = { id = def.id },
            op = "omnibar_drag"
        }
        catwrap:Add("<Reg bg=item_default on_drag_start={omnibar_unlockable_drag_start}/>",
            {
                def = def,
                ui_icon = def.texture,
                -- Arguments for instruction register dropping.
                -- From Program.lua
                reg_idx = -5000,
                arg_idx = 1,
                inst = inst,
                -- Arguments for dropping on frame/component reg.
                -- Cheat and say we're an item.
                -- From FrameView.lua
                dragtype = "ITEM",
                slot = { id = def.id }
            })
    end)
end

local Instruction_layout <const> = [[
	<Box on_drag_start={on_instruction_drag_start}>
		<HorizontalList>
			<Image image={icon} width=30 height=30 valign=center color=ui_light/>
			<Text text={title} width=186 wrap=true margin=2 valign=center/>
		</HorizontalList>
	</Box>
]]

function OmniBar:on_instruction_drag_start(payload)
    local bar = UI.New(Instruction_layout, { title = payload.title, op = payload.op, icon = payload.icon })
    -- Close the bar to unblock the behavior.
    CloseOmniBar()
    return bar
end

---@param haystack string
---@param needle string
---@return
---| 1 # Equal
---| 2 # Match at start
---| 3 # Match at start of a word
---| 4 # Match somewhere
---| false # No match
local function match_score(haystack, needle)
    haystack = string.lower(haystack)
    -- Equal
    if needle == haystack then
        return 1
    end

    local pos = string.find(haystack, needle, 1, true)
    -- Match at start
    if pos == 1 then
        return 2
    end
    -- Match at start of a word
    if pos and string.find(haystack, " "..needle, 1, true) then
        return 3
    end
    -- Match somewhere
    if pos then
        return 4
    end
    -- No match
    return false
end

local function score_compare(a, b)
    if a._score ~= b._score then
        return a._score < b._score
    else
        return a.title < b.title
    end
end

---@param filter string Lowercase search text
function OmniBar:filter_instructions(filter)
    -- === INSTRUCTIONS ===
    local found_instructions = {}
    for op, inst in pairs(data.instructions) do
        if inst.name then
            local l_name = L(inst.name)
            local l_desc = L(inst.desc)
            local score = match_score(l_name, filter)
            if not score and inst.desc then
                score = match_score(l_desc, filter)
                if score then
                    score = score + 5
                end
            end
            if score then
                table.insert(found_instructions, {
                    title = l_name,
                    op = op,
                    tooltip = l_desc,
                    icon = inst.icon,
                    _score = score
                })
            end
        end
    end

    if #found_instructions > 0 then
        table.sort(found_instructions, score_compare)
        self.results:Add("Spacer", { height = 10 })
        self.results:Add("Text", { text = "Instructions" })
        local last_score = nil
        for _, inst in ipairs(found_instructions) do
            -- Visually separate match types
            if last_score and last_score ~= inst._score then
                self.results:Add("Spacer", { height = 10 })
                -- Note description matches
                if last_score < 5 and inst._score >= 5 then
                    self.results:Add("Text", { text = "Instructions (Description match)"})
                end
            end
            last_score = inst._score
            self.results:Add(Instruction_layout, inst)
        end
    end
end

function OmniBar:omnibar_unlockable_drag_start(payload)
    local drag_reg = UI.New("<Reg width=32 height=32/>", { ui_icon = payload.ui_icon })
    -- Hide the bar to unblock the screen.
    CloseOmniBar()
    return drag_reg
end

-- TODO(maz): Make this work.
function OmniBar:show_instruction_variables()
    local main_window, window_name = GetMainWindow()
    if window_name == "Program" and main_window and main_window.vars then
        local var_list = self.results:Add("<HorizontalList/>")
        for k, v in pairs(main_window.vars) do
            var_list:Add("<Reg width=48 height=48 on_drag_start={omnibar_unlockable_drag_start}/>",
                { num = k, reg_idx = v })
                :Add(
                    "<Image image=icon_small_register_var color=#FF00FF dock=center/>")
        end
    end
end
