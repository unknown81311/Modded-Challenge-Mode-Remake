if _G["ChallengeModeMenuPack_LoadFunctions"] == nil then
    _G["ChallengeModeMenuPack_LoadFunctions"] = function( self )

        print("Loaded Player Functions Pack")

        self.ChallengeModeMenuPack_LOADED = function( self )
            self.selected_index = -2
            if sm.exists(self.gui) then
                for _,challenge in pairs(self.challenge_packs) do
                    local index = _-1
                    if index > 99 then break end
                    local data = sm.json.open("$CONTENT_"..challenge.uuid.."/description.json")
                    self.gui:setText("Name_"..index, data.name)
                    local author = data.fileId ~= nil and data.fileId or "Author not supported"
                    self.gui:setText("ByLine_"..index, author.."")
                    if data.fileId == nil then self.gui:setVisible("ModIcon_"..index, false) end
                    self.gui:setVisible("ChallengePack_"..index, true)
                    self.gui:setImage("Preview_"..index, challenge.image)
                    self.gui:setVisible("PreviewSelectBorder_"..index, false)
                    self.gui:setVisible("SelectBorder_"..index, false)
                    self.gui:setText("LeftValue_"..index, "0")
                    self.gui:setText("RightValue_"..index, ""..#challenge.levelList)
                    self.gui:setButtonCallback( "ChallengeButton_"..index, "client_SelectChallenge" )
                end
                self.gui:open()
            end
        end

        self.client_SelectChallenge = function( self, button )
            self:client_DeselectAll()
            self.selected_index = string.gsub(string.sub(button, -2), "_", "")
            self.gui:setVisible("PreviewSelectBorder_"..self.selected_index, true)
            self.gui:setVisible("SelectBorder_"..self.selected_index, true)
        end

        self.client_DeselectAll = function( self )
            for _,challenge in pairs(self.challenge_packs) do
                self.gui:setVisible("PreviewSelectBorder_"..(_-1), false)
                self.gui:setVisible("SelectBorder_"..(_-1), false)
            end
        end

        self.client_CloseMenu = function( self, button )
            sm.localPlayer.setLockedControls( false )
            --self.network:sendToServer("server_EnableControls")
            self.gui:close()
            self.gui:destroy()
        end

        self.client_SelectPack = function( self, button )
            local uuid = self.challenge_packs[self.selected_index+1].uuid
            self.network:sendToServer("server_initializeChallengeGame", uuid)
        end

        self.client_OpenGui = function( self, button )
            --local uuid = self.challenge_packs[self.selected_index+1].uuid
            --self:client_initializeLevelMenu()
        end
    end
end

if _G["ChallengeModeMenuPack_UnLoadFunctions"] == nil then
    _G["ChallengeModeMenuPack_UnLoadFunctions"] = function( self )
        self.ChallengeModeMenuPack_LOADED = nil
        self.client_OpenGui = nil
        self.client_SelectPack = nil
        self.client_CloseMenu = nil
        self.client_DeselectAll = nil
        self.client_SelectChallenge = nil
        print("Unloaded Player Functions PACK")
    end
end