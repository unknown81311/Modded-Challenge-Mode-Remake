

_G["ChallengeBuilder_LoadFunctions"] = function( self )

    print("Loaded Player Functions")
    
    self.ChallengeBuilder_LOADED = function( self )
        self.selected_index = -2
        for _,tttgg in pairs(self.challenge_levels) do
            local index = _-1
            self.gui:setVisible("ChallengeItem_"..index, true)
            self.gui:setImage("Preview_"..index, tttgg.image.."")
            self.gui:setVisible("PreviewSelectBorder_"..index, false)
            self.gui:setButtonCallback( "Challenge_"..index, "client_level_SelectChallenge" )
        end
        self.gui:setButtonCallback( "ChallengeNew", "client_level_NewChallenge" )
        self.gui:setButtonCallback( "ChallengeModeMenuPack", "client_level_OpenGui")
        self.gui:setVisible("BackgroundPlateSelected", false)
        self.gui:open()
    end

    self.client_loadChallengeData = function( self )
        local index = self.selected_index+1
        if index >= 0 then
            local guid = self.challenge_levels[index].uuid..""
            local dir = self.challenge_levels[index].directory..""
            local json_object = self:client_readFile(guid, dir)
            self.gui:setText("EditText_Title", json_object.name)
            if #json_object.name > 0 then
                self.gui:setVisible("DefaultText_Title", false)
            else
                self.gui:setVisible("DefaultText_Title", true)
            end
            self.gui:setText("EditText_Description", json_object.description)
            if #json_object.description > 0 then
                self.gui:setVisible("DefaultText_Description", false)
            else
                self.gui:setVisible("DefaultText_Description", true)
            end
            self.gui:setVisible("ChallengeIcon", true)
            self.gui:setImage("ChallengeIcon", self.challenge_levels[index].image.."")
        else
            self.gui:setText("EditText_Title", "")
            self.gui:setVisible("DefaultText_Title", true)
            self.gui:setText("EditText_Description", "")
            self.gui:setVisible("DefaultText_Description", true)
            self.gui:setVisible("ChallengeIcon", false)
        end
    end

    self.client_readFile = function( self, guid, base_dir )
        local fguid = string.gsub(guid, "-", "_")
        if sm.json.fileExists( "$CONTENT_DATA/Overrides/"..fguid.."_description.json" ) then
            return sm.json.open( "$CONTENT_DATA/Overrides/"..fguid.."_description.json" )
        else
            return sm.json.open( base_dir.."/description.json" )
        end
    end

    self.client_saveFile = function( self, data )
        local fguid = string.gsub(data.guid, "-", "_")
        sm.json.save(data.json, "$CONTENT_DATA/Overrides/"..fguid.."_description.json")
    end

    self.client_saveDescriptionCurrent = function( self, description )
        local index = self.selected_index+1
        if index >= 0 then
            local uuid = self.challenge_levels[index].uuid..""
            local dir = self.challenge_levels[index].directory..""
            local json_object = self:client_readFile(uuid, dir)
            json_object.description = description
            self:client_saveFile({guid=uuid, json=json_object})
        end
    end

    self.client_saveTitleCurrent = function( self, title )
        local index = self.selected_index+1
        if index >= 0 then
            local uuid = self.challenge_levels[index].uuid..""
            local dir = self.challenge_levels[index].directory..""
            local json_object = self:client_readFile(uuid, dir)
            json_object.name = title
            self:client_saveFile({guid=uuid, json=json_object})
        end
    end

    self.client_ChangeDescription = function( self, button, text )
        self:client_saveDescriptionCurrent(text)
        if #text > 0 then
            self.gui:setVisible("DefaultText_Description", false)
        else
            self.gui:setVisible("DefaultText_Description", true)
        end
    end

    self.client_ChangeTitle = function( self, button, text )
        self:client_saveTitleCurrent(text)
        if #text > 0 then
            self.gui:setVisible("DefaultText_Title", false)
        else
            self.gui:setVisible("DefaultText_Title", true)
        end
    end

    self.client_DeselectAll = function( self )
        self.gui:setVisible("BackgroundPlateSelected", false)
        for _ in pairs(self.challenge_levels) do
            self.gui:setVisible("PreviewSelectBorder_"..(_-1), false)
        end
    end

    self.client_SelectChallenge = function( self, button )
        self:client_DeselectAll()
        self.selected_index = string.gsub(string.sub(button, -2), "_", "")
        self.gui:setVisible("PreviewSelectBorder_"..self.selected_index, true)
        self:client_loadChallengeData()
    end

    self.client_NewChallenge = function( self, button )
        self:client_DeselectAll()
        self.selected_index = -2
        self:client_loadChallengeData()
        self.gui:setVisible("BackgroundPlateSelected", true)
    end 

    self.client_PlayChallenge = function( self, button )
        local index = self.selected_index+1
        local uuid = self.challenge_levels[index].uuid..""
        sm.event.sendToGame("client_PlayBuild", {guid=uuid})
    end

    self.client_BuildChallenge = function( self, button )
        self.gui:close()
        local index = self.selected_index+1
        if index >= 0 then
            local uuid = self.challenge_levels[index].uuid..""
            sm.event.sendToGame("client_LoadBuild", {guid=uuid, index = -1, build=1})
        end
    end

    self.client_AddChallenge = function( self, button )
        print(button)
    end
end

_G["ChallengeBuilder_UnLoadFunctions"] = function( self )
    self.client_AddChallenge = nil
    self.client_BuildChallenge = nil
    self.client_PlayChallenge = nil
    self.client_NewChallenge = nil
    self.client_SelectChallenge = nil
    self.client_DeselectAll = nil
    self.client_ChangeTitle = nil
    self.client_ChangeDescription = nil
    self.client_saveFile = nil
    self.client_readFile = nil
    self.client_loadChallengeData = nil
    self.ChallengeBuilder_LOADED = nil
    self.client_setImage = nil
    self.server_getPath = nil
    self.client_OpenGui = nil
    print("Unloaded Player Functions")
end