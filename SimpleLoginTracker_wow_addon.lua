/*
-- SimpleLoginTracker.lua
Author: Lynn
Project: WoW Data Engineering Pipeline - WoW Addon
Goal: Addon that tracks in-game data, such as monster kills, levels, spells etc
*/

local frame = CreateFrame("Frame")

-- Initialize SavedVariables
if not SimpleLoginTrackerDB then
    SimpleLoginTrackerDB = {}
end

-- Current session data (not saved until logout)
local session = {
    today = date("%Y-%m-%d %H:%M:%S"),
    charachter = nil,
    kills = 0,
    eliteKills = 0,
    levelsGained = 0,
    itemsLooted = 0,
    spellCombatCount = {},
    spellProfessionCount = {},
    herbGathering = 0,
    alchemyCreations = 0

}

-- Helper to get gold in gold units
local function GetGold()
    return GetMoney() / 10000 -- Converting from copper to gold
end

-- Jump counter
local function JumpTrackerUpdate(self, elapsed)
    self.timeSinceLastCheck = (self.timeSinceLastCheck or 0) + elapsed

    if self.timeSinceLastCheck > 0.1 then
        local isFalling = IsFalling()
        if not self.lastFallState and isFalling then
            session.jumpCount = (session.jumpCount or 0) + 1
        end
        self.lastFallState = isFalling
        self.timeSinceLastCheck = 0
    end
end

-- Function to handles events
frame:SetScript("OnEvent", function(self, event, ...)

    if event == "PLAYER_LOGIN" then
        local today = date("%Y-%m-%d %H:%M:%S")
        local name = UnitName("player")
        session.character = name

        -- Gold
        session.startGold = GetGold() --Gold when Login
        session.lastGold = session.startGold -- Gold from last lession
        session.goldEarned = 0
        session.goldSpent = 0

        -- Levels
        session.startLevel = UnitLevel("player")
        session.levelsGained = 0

        -- Quests
        session.questsTurnedIn = 0

        -- Session time & time spent in zone
        session.sessionStart = time()
        session.currentZone = GetZoneText()
        session.lastZoneEntry = time()
        session.zonesVisited = {}
        session.zoneDurations = {}
        session.sessionDuration = 0

        -- Jumping Counter
        session.jumpCount = 0
        -- Start tracking jumps
        self:SetScript("OnUpdate", JumpTrackerUpdate)

        print("|cff00ff00[SimpleLoginTracker]|r Started session for " .. session.character)

    -- Monster kill count
    --elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
      --  local msg = ...
        -- Basic filter: only count kills that grant XP
        --if string.find(msg, "experience") then
          --  session.kills = session.kills + 1
            
            --local class = UnitClassification("target")
            --if class == "elite" or class == "rareelite" then
              --  session.elitKills = session.elitKills + 1
            --end
        --end
    
    -- Player gold earned & spend
    elseif event == "PLAYER_MONEY" then
        local newGold = GetGold()
        local diff = newGold - session.lastGold

        -- Checks for differeatons in gold, either it's earned or it's spent
        if diff > 0 then 
            session.goldEarned = session.goldEarned + diff
        elseif diff < 0 then
            session.goldSpent = session.goldSpent + math.abs(diff)
        end

        session.lastGold = newGold
    
    -- Player level count    
    elseif event == "PLAYER_LEVEL_UP" then
        local newLevel = ...
        session.levelsGained = session.levelsGained + 1

    -- Player quest turn ins
    elseif event == "QUEST_TURNED_IN" then
        local newQuests = ...
        session.questsTurnedIn = session.questsTurnedIn + 1
    
    -- Looting & Crafting items count
    elseif event == "CHAT_MSG_LOOT" then
        local msg = ...
        local character = UnitName("player")
        local alchemyKeyWords = {"Flask","Elixir","Potion"}
        local itemName = string.match(msg, "%[(.-)%]")

        -- Check for quantities like "x2" or "2 [Item]"
        local quantity = tonumber(string.match(msg, "x(%d+)")) or tonumber(string.match(msg, "(%d+)%s*%["))
        if not quantity then quantity = 1 end -- default to 1 if no number is found

        -- Checks for looted items
        if string.find(msg, "You receive loot:") or string.find(msg, character .. " receives loot") then
            session.itemsLooted = session.itemsLooted + quantity
        end

        -- Checks for looted hrbs
        --if string.find(msg, "You receive loot:") or string.find(msg, character .. " receives loot") then
          --  for i, keyword in ipairs(herbingKeyWords) then
            --    if string.find(itemName, keyword) do        
              --      session.herbsLooted = session.hernsLooted + quantity       
                --end
            ---end
        ---end
        -- Checks for Crafted items
        if string.find(msg, "You create:") then
            for i, keyword in ipairs(alchemyKeyWords) do
                if string.find(itemName, keyword) then
                    session.alchemyCreations = session.alchemyCreations + quantity
                end
            end
        end
    
    -- Spell counter, combat & prfessions
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            --local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellName, spellSchool = CombatLogGetCurrentEventInfo()
            local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool = CombatLogGetCurrentEventInfo()
            local combatSpells = {"Shadow Bolt", "Summon Imp", "Summon Voidwalker", "Summon Succubus", "Summon Felhunter", "Create Healthstone"}
            local playerGUID = UnitGUID("player")

            -- Checks for successful spell casts
            if subevent == "SPELL_CAST_SUCCESS" and sourceName == UnitName("player") then
                for _, spell in ipairs(combatSpells) do
                    if spellName == spell then
                        session.spellCombatCount[spell] = (session.spellCombatCount[spell] or 0) + 1
                    end
                end
            end

            -- Monster kill count, only counts if I or my pet kills the mobs
            if subevent == "PARTY_KILL" and sourceGUID == playerGUID then
                session.kills = (session.kills or 0) + 1

                if UnitExists("target") and UnitGUID("target") == destGUID then
                    local classification = UnitClassification("target")
                    if classification == "elite" or classification == "rareelite" then
                        session.eliteKills = (session.eliteKills or 0) + 1
                    end
                end
            end

    
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget, castGUID, spellID = ...
        if unitTarget == "player" then 
            local spellName = GetSpellInfo(spellID)
            local professionSpells = {"Herb Gathering"}
            for _, spell in ipairs(professionSpells) do
                if spellName == spell then
                    session.spellProfessionCount[spell] = (session.spellProfessionCount[spell] or 0) + 1
                    session.herbGathering = (session.herbGathering or 0) + 1
                end
            end
        end
    
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        local now = time()
        local currentZone = GetZoneText()
        local previousZone = session.currentZone
        local timeInPreviousZone = now - session.lastZoneEntry

        -- Checks zones visited
        if currentZone and not session.zonesVisited[currentZone] and currentZone ~= "" then
            session.zonesVisited[currentZone] = true
            print("New zone visited: " .. currentZone)
        end

        -- Checks the time spent in previous zone
        if previousZone and previousZone ~= "" then
            session.zoneDurations[previousZone] = (session.zoneDurations[previousZone] or 0) + timeInPreviousZone
        end

        -- Update the session info
        session.currentZone = currentZone
        session.lastZoneEntry = now

        --print("Moved to zone: " .. session.currentZone .. " | Time spent in previous zone: " .. timeInPreviousZone .. "s")

    
    elseif event == "PLAYER_LOGOUT" then
        -- Save session when logging out
        session.endGold = GetMoney() / 10000 -- Gold when logout
        --local goldEarned = session.endGold - session.startGold
        --local calculatedNet = session.goldEarned - session.goldSpent
        session.goldNetChange = session.endGold - session.startGold

        -- Sesson time & zones
        local endTime = time()
        -- Calculating total session time
        local sessionTime = endTime - session.sessionStart

        -- Checks the time spent in the Current Zone (aka the last zone the player is)
        local timeInCurrentZone = endTime - session.lastZoneEntry
        if session.currentZone then
            session.zoneDurations[session.currentZone] = (session.zoneDurations[session.currentZone] or 0) + timeInCurrentZone
        end

        table.insert(SimpleLoginTrackerDB, {
            date = session.today,
            character = session.character,
            kills = session.kills, 
            eliteKills = session.eliteKills,
            goldEarned = session.goldEarned,
            goldSpent = session.goldSpent,
            goldNetChange = session.goldNetChange,
            startLevel = session.startLevel,
            levelsGained = session.levelsGained,
            questsTurnedIn = session.questsTurnedIn,
            itemsLooted = session.itemsLooted,
            spellCombatCount = session.spellCombatCount,
            spellProfessionCount = session.spellProfessionCount,
            herbGathering = session.herbGathering,
            alchemyCreations = session.alchemyCreations,
            zonesVisited = session.zonesVisited,
            zoneDurations = session.zoneDurations,
            sessionDuration = sessionTime,
            jumpCount = session.jumpCount
        })
        --print(string.format("|cff00ff00[SimpleLoginTracker]|r Saved session for %s (Earned: %.2f, Spent: %.2f)",
            --session.character, session.goldEarned, session.goldSpent))
    end

end)

-- Register events we care about
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_LOGOUT")
