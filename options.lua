local profile = Game.GetProfile()

return UI.New([[
	<VerticalList child_padding=8>
        <Button id=toggle on_click={toggle_omnibar} width=32 height=32
            text="Toggle OmniBar" />
        <Text size=16 text="Position" color=ui_light/>
        <Button id=reset_location width=32 height=32>
            <Text text="Reset Location"/>
        </Button>
        <HorizontalList child_align=center>
            <Text fill=true text="Y Offset:"/>
            <Text id=y_offset_text margin_right=5/>
            <Slider width=460 height=42 min=-100 max=100 step=1 id=y_offset/>
        </HorizontalList>
        <HorizontalList child_align=center>
            <Text fill=true text="X Offset:"/>
            <Text id=x_offset_text margin_right=5/>
            <Slider width=460 height=42 min=-100 max=100 step=1 id=x_offset/>
        </HorizontalList>
        <Spacer/>
        <Text size=16 text="Size" color=ui_light/>
        <Button id=reset_scale width=32 height=32>
            <Text text="Reset Size"/>
        </Button>
        <HorizontalList child_align=center>
            <Text fill=true text="Scale:"/>
            <Text id=scale_text margin_right=5/>
            <Slider width=460 height=42 min=20 max=300 step=1 id=scale/>
        </HorizontalList>
	</VerticalList>
	]], {
    construct = function(menu)
        -- Init profile.
        if not profile.omnibar then
            profile.omnibar = {
                y_offset = 0,
                x_offset = 0,
                scale = 100,
            }
        end

        -- If the game isn't loaded we can't actually show the bar.
        if not ToggleOmniBar then
            menu.toggle.text = "Toggle OmniBar (Disabled - Load Game to Test)"
            menu.toggle.disabled = true
        end

        -- Updates a given slider and its text with `val`
        local update = function(key, val)
            menu[key .. "_text"].text = string.format("%.0f%%", val)
            menu[key].value = val
        end

        -- Initially set the sliders to the profile values.
        for key, val in pairs(profile.omnibar) do
            update(key, val)
            -- On slider change, update the text (via `update`) and save it.
            menu[key].on_change = function(slider, val)
                update(slider.id, val)
                profile.omnibar[key] = val
                -- If the game is loaded, immediately move the bar.
                if UpdateOmniBarPosition then
                    UpdateOmniBarPosition()
                end
            end
        end

        -- Set offsets to zero on reset.
        menu.reset_location.on_click = function()
            for key, val in pairs(profile.omnibar) do
                if string.find(key, "offset") then
                    menu[key].on_change(menu[key], 0)
                end
            end
        end
        -- Set scales to zero on reset.
        menu.reset_scale.on_click = function()
            menu.scale.on_change(menu.scale, 100)
        end
    end,
    toggle_omnibar = function(self)
        self.toggle.active = ToggleOmniBar(true)
    end,
    destruct = function(self)
        -- Close the bar if the menu closes.
        CloseOmniBar()
    end
})
