local package = ...

function package:init_ui()
    InputDefaultActionMappings.OmniBar = "Z"
    InputTooltips.OmniBar = "Opens the omnibar."

    Input.BindAction("Omnibar", "Released", ToggleOmniBar)
end

local open_window, open_window_name
-- Public functions
function ToggleOmniBar(ui_priority)
    if open_window then
        return CloseOmniBar()
    end
    open_window, open_window_name = UI.AddLayout("OmniBar", ui_priority or 20)
end

function UpdateOmniBarPosition()
    if open_window then
        open_window:update_position()
        open_window:update_scale()
    end
end

local OmniBar_layout <const> =
[[
    <Scale dock=center>
        <VerticalList height=1>
            <Box bg=popup_additional_bg padding=4>
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
    open_window:RemoveFromParent()
    open_window, open_window_name = nil, nil
end

local CodexButton_layout <const> =
[[
	<Canvas>
		<Button on_click={on_select} width=320><Text text={text} width=280 halign=left wrap=true/></Button>
	</Canvas>
]]

local function interpolate(a, b, percent)
    return a + (b - a) * percent / 100
end

local catdefs = {}
local cats = {}
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

function OmniBar:update_scale()
    local profile = Game.GetProfile()
    if profile.omnibar then
        self.scale = profile.omnibar.scale / 100
    end
end

function OmniBar:construct()
    local width, height = UI.GetScreenSize()
    self.base_y = -150
    self.max_y = height / 2 + self.base_y
    self.min_y = -1 * height / 2
    self.y = self.base_y

    self.base_x = 0
    self.max_x = width / 2
    self.min_x = -1 * width / 2
    self.x = self.base_x

    self:update_position()
    self:update_scale()

    -- Animate an add fx to opening of the window.
    self:TweenFromTo("sx", 0.01, 1, 40, "OutQuad")
    self:TweenFromTo("sy", 0.01, 1, 80, "OutQuad")
    UI.PlaySound("fx_ui_WINDOW_SELECTION_MENU_OPEN")

    -- Immediately focus the search box.
    -- self.inst_search:Focus()



    -- Capture escape key to close the window or else it opens the menu.
    local process_input = function(key_name, is_down, axis, mouse_delta)
        if key_name == "ESCAPE" and open_window then
            return CloseOmniBar()
        end
        return true
    end
    Input.SetInputProcessor(function(key_name, is_down, axis, mouse_delta)
        if not is_down then
            return true
        end
        Input.ClearInputProcessor()
        self.inst_search:Focus()
        Input.SetInputProcessor(process_input)
    end)


    -- gather all categories
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

function OmniBar:destruct()
    Input.ClearInputProcessor()
    open_window, open_window_name = nil, nil
    catdefs = {}
    cats = {}
end

function OmniBar:on_filter(widget, txt)
    local filter = txt and txt ~= "" and txt:lower()
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

    -- TODO(maz): Finish implementing codex entries
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
