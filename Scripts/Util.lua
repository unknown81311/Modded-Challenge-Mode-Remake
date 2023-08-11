dofile("$CONTENT_DATA/Scripts/ChallengeModeMenuPack.lua")

sm.old = { challenge = sm.challenge }

sm.challenge = {
    private = {
        hasStarted = false,
        uuid = tostring(sm.uuid.getNil())
    },
    setChallengeUuid = function(uuid)
        sm.challenge.private.uuid = tostring(uuid)
    end,
    resolveContentPath = function(string)
        return string.gsub(string, "$CONTENT_DATA", "$CONTENT_"..sm.challenge.private.uuid)
    end,
    hasStarted = function()
        return sm.challenge.private.hasStarted
    end,
    takePicturesForMenu = function()
        print("this is sad. no photo, even tho we want one :(")
    end,
    stop = function()
        sm.challenge.private.hasStarted = false
    end,
    start = function(world)
        sm.challenge.private.hasStarted = true
    end,
    getSaveData = function(string)
        print("get save")
        return sm.old.challenge.getSaveData(string)
    end,
    levelCompleted = function(string, time, data)
        print("level complete")
        sm.old.challenge.levelCompleted(string, time, data)
    end,
    getCompletionTime = function(string, time, data)
        print("get level complete")
        return sm.old.challenge.getCompletionTime(string)
    end,
    isMasterMechanicTrial = function() return false end
}

sm.gui.exitToMenu = function()
    
end

if _G.ChallengeGame == nil then
    dofile("$CONTENT_DATA/Scripts/ChallengeModeScripts/challenge/ChallengeGame.lua")
end

if _G.ChallengePlayer == nil then
    dofile("$CONTENT_DATA/Scripts/ChallengeModeScripts/game/ChallengePlayer.lua")
end

if _G.States == nil then
    _G.States = {
        To = function ( string )
            if string == "PackMenu" then return 0
            elseif string == "LevelMenu" then return 1
            elseif string == "Play" then return 2
            elseif string == "BuildPlay" then return 3
            elseif string == "Build" then return 4
            end
        end,
        From = function ( Int )
            if Int == 0 then return "PackMenu"
            elseif string == 1 then return "LevelMenu"
            elseif string == 2 then return "Play"
            elseif string == 3 then return "BuildPlay"
            elseif string == 4 then return "Build"
            end
        end
    }
end

if _G.FormatPath == nil then
    _G.FormatPath = function( path, uuid )
	    return string.gsub( path, "$CONTENT_DATA/", "$CONTENT_"..uuid.."/")
    end
end

if _G.LoadChallengeData == nil then
    _G.LoadChallengeData = function()
        local file = sm.json.open("$CONTENT_DATA/Scripts/ChallengeList.json")
        local challenge_levels = {}
        local challenge_packs = {}

        for _,uuid in pairs(file.challenges) do
            if select(1, pcall(sm.json.fileExists, "$CONTENT_" .. uuid .. "/description.json")) then
                local challenge, ctype = GetChallengesAndPacks( uuid )
                if ctype == "level" then
                    for _,t in pairs(challenge_levels) do
                        if t.uuid == uuid then kg = true end
                    end
                    if not kg then
                        challenge.uuid = uuid
                        challenge.inPack = false
                        challenge.isPack = false
                        challenge.directory = "$CONTENT_"..uuid
                        table.insert(challenge_levels, challenge)
                    end
                elseif ctype == "pack" then
                    challenge.uuid = uuid
                    challenge.isPack = true
                    challenge.directory = "$CONTENT_"..uuid
                    table.insert(challenge_packs, challenge)
                    for _,c in pairs(challenge.levelList) do
                        local kg = false
                        for _,t in pairs(challenge_levels) do
                            if t.uuid == c.uuid then kg = true end
                        end
                        if not kg then
                            c.inPack = true
                            c.isPack = false
                            c.packUuid = uuid
                            c.image = FormatPath(c.largeIcon, uuid)
                            c.directory = "$CONTENT_"..uuid--.."/"..c.uuid
                            table.insert(challenge_levels, c)
                        end
                    end
                end
            end
        end
        return { levels = challenge_levels, packs = challenge_packs  }
    end
end

if _G.GetChallengesAndPacks == nil then
    _G.GetChallengesAndPacks = function( uuid )
        local dir = "$CONTENT_"..uuid
        local content = nil
        local c_type = "fail"
        if sm.json.fileExists(dir.."/challengeLevel.json") then
            c_type = "level"
            content = sm.json.open(dir.."/challengeLevel.json")
            content.image = dir.."/icon_small.png"
        elseif sm.json.fileExists(dir.."/challengePack.json") then
            c_type = "pack"
            content = sm.json.open(dir.."/challengePack.json")
            local item = content.levelList[1]
            content.image = FormatPath(item.smallIcon, uuid)
        end
        return content, c_type
    end
end