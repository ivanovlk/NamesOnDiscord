local NamesOnDiscord_knownPlayers = {}
local NamesOnDiscord_RAID_CLASS_COLORS = {}

NamesOnDiscord_RAID_CLASS_COLORS["HUNTER"]   = { colorStr = "ffabd473" }
NamesOnDiscord_RAID_CLASS_COLORS["WARLOCK"]  = { colorStr = "ff8788ee" }
NamesOnDiscord_RAID_CLASS_COLORS["PRIEST"]   = { colorStr = "ffffffff" }
NamesOnDiscord_RAID_CLASS_COLORS["PALADIN"]  = { colorStr = "fff58cba" }
NamesOnDiscord_RAID_CLASS_COLORS["MAGE"]     = { colorStr = "ff3fc7eb" }
NamesOnDiscord_RAID_CLASS_COLORS["ROGUE"]    = { colorStr = "fffff569" }
NamesOnDiscord_RAID_CLASS_COLORS["DRUID"]    = { colorStr = "ffff7d0a" }
NamesOnDiscord_RAID_CLASS_COLORS["SHAMAN"]   = { colorStr = "ff0070de" }
NamesOnDiscord_RAID_CLASS_COLORS["WARRIOR"]  = { colorStr = "ffc79c6e" }

local function NormalizeName(name)
    return string.lower(string.gsub(name or "", "[^%w]", ""))
end

local function Levenshtein(a, b)
    if a == b then return 0 end
    local len_a, len_b = string.len(a), string.len(b)
    if len_a == 0 then return len_b end
    if len_b == 0 then return len_a end
    local matrix = {}
    for i = 0, len_a do matrix[i] = {[0] = i} end
    for j = 0, len_b do matrix[0][j] = j end
    for i = 1, len_a do
        for j = 1, len_b do
            local cost = (string.sub(a, i, i) == string.sub(b, j, j)) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,
                matrix[i][j-1] + 1,
                matrix[i-1][j-1] + cost
            )
        end
    end
    return matrix[len_a][len_b]
end

local function NamesOnDiscord_IsKnown(name)
    local normName = NormalizeName(name)
    for _, entry in ipairs(NamesOnDiscord_knownPlayers) do
        local knownName = NormalizeName(entry.username or "")
        local knownNick = NormalizeName(entry.nickname or entry.username)
        local knownDisplay = NormalizeName(entry.displayname or entry.username)

        -- Exact match
        if normName == knownName or normName == knownNick or normName == knownDisplay then
            return true
        end

        -- Prefix match (check length first)
        if string.len(normName) >= 4 and (
            string.sub(normName, 1, 4) == string.sub(knownName, 1, 4) or
            string.sub(normName, 1, 4) == string.sub(knownNick, 1, 4) or
            string.sub(normName, 1, 4) == string.sub(knownDisplay, 1, 4)
        ) then
            print(string.format(
                "Auto-matched method 1a: %s to (%s, %s, %s)",
                name, entry.username or "", entry.displayname or "", entry.nickname or ""
            ))
            return true
        end

        -- Substring match
    if (string.len(knownName) >= 4 and string.len(normName) >= 4 and string.find(normName, knownName, 1, true)) or
        (string.len(knownNick) >= 4 and string.len(normName) >= 4 and string.find(normName, knownNick, 1, true)) or
        (string.len(knownDisplay) >= 4 and string.len(normName) >= 4 and string.find(normName, knownDisplay, 1, true)) or
        (string.len(normName) >= 4 and string.len(knownName) >= 4 and string.find(knownName, normName, 1, true)) or
        (string.len(normName) >= 4 and string.len(knownNick) >= 4 and string.find(knownNick, normName, 1, true)) or
        (string.len(normName) >= 4 and string.len(knownDisplay) >= 4 and string.find(knownDisplay, normName, 1, true))
        then
            print(string.format(
                "Auto-matched method 2a: %s to (%s, %s, %s)",
                name, entry.username or "", entry.displayname or "", entry.nickname or ""
            ))
            return true
        end

        -- Levenshtein distance (typo tolerance)
        if Levenshtein(normName, knownName) <= 2 or
           Levenshtein(normName, knownNick) <= 2 or
           Levenshtein(normName, knownDisplay) <= 2
        then
            print(string.format(
                "Auto-matched method 3a: %s to (%s, %s, %s)",
                name, entry.username or "", entry.displayname or "", entry.nickname or ""
            ))
            return true
        end
    end
    return false
end

function NamesOnDiscord_Colorize_Player_By_Class( name, class )
  if not class then return name end
  local color = NamesOnDiscord_RAID_CLASS_COLORS[ string.upper( class ) ].colorStr
  if not color then
    local c = NamesOnDiscord_RAID_CLASS_COLORS[ string.upper( class ) ]
    color = string.format( "ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255 )
  end
  return "|c" .. color .. name .. FONT_COLOR_CODE_CLOSE
end

function NamesOnDiscord_CheckGroupMembers()
    NamesOnDiscord_knownPlayers = json.decode( UnitXP( "clientRead", "http://192.168.0.6:5261/api/voice/members/1225934997836402772" ) )
    local unknownMembers = {}
    local groupMembers = {}
    local normalizedGroupNames = {}

    -- Collect normalized group member names
    if IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            local unit = "raid" .. i
            if UnitIsPlayer(unit) then
                local name = GetUnitName(unit, true)
                if name then
                    normalizedGroupNames[NormalizeName(name)] = true
                    if not NamesOnDiscord_IsKnown(name) then
                        local class = UnitClass(unit)
                        table.insert(unknownMembers, NamesOnDiscord_Colorize_Player_By_Class(name, class))
                    end
                end
            end
        end
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            if UnitIsPlayer(unit) then
                local name = GetUnitName(unit, true)
                if name then
                    normalizedGroupNames[NormalizeName(name)] = true
                    if not NamesOnDiscord_IsKnown(name) then
                        local class = UnitClass(unit)
                        table.insert(unknownMembers, NamesOnDiscord_Colorize_Player_By_Class(name, class))
                    end
                end
            end
        end

        local playerName = UnitName("player")
        if playerName then
            normalizedGroupNames[NormalizeName(playerName)] = true
            if not NamesOnDiscord_IsKnown(playerName) then
                local class = UnitClass("player")
                table.insert(unknownMembers, NamesOnDiscord_Colorize_Player_By_Class(playerName, class))
            end
        end
    else
        local playerName = UnitName("player")
        if playerName then
            normalizedGroupNames[NormalizeName(playerName)] = true
            if not NamesOnDiscord_IsKnown(playerName) then
                local class = UnitClass("player")
                table.insert(unknownMembers, NamesOnDiscord_Colorize_Player_By_Class(playerName, class))
            end
        end
    end

    -- Find Discord members not in group and not automatched
    local discordNotInGroup = {}
    for _, entry in ipairs(NamesOnDiscord_knownPlayers) do
        local normName = NormalizeName(entry.username or "")
        local normNick = NormalizeName(entry.nickname or entry.username)
        local normDisplay = NormalizeName(entry.displayname or entry.username)

        local matched = false
        for groupNormName, _ in pairs(normalizedGroupNames) do
            -- Use same automatch logic as NamesOnDiscord_IsKnown
            if groupNormName == normName or groupNormName == normNick or groupNormName == normDisplay then
                matched = true
                break
            end
            if string.len(groupNormName) >= 4 and (
                string.sub(groupNormName, 1, 4) == string.sub(normName, 1, 4) or
                string.sub(groupNormName, 1, 4) == string.sub(normNick, 1, 4) or
                string.sub(groupNormName, 1, 4) == string.sub(normDisplay, 1, 4)
            ) then
                print(string.format(
                    "Auto-matched method 1b: %s to %s, %s, %s)",
                    groupNormName, entry.username or "", entry.displayname or "", entry.nickname or ""
                ))
                matched = true
                break
            end
                if (string.len(groupNormName) >= 4 and string.len(normName) >= 4 and string.find(groupNormName, normName, 1, true)) or
                    (string.len(groupNormName) >= 4 and string.len(normNick) >= 4 and string.find(groupNormName, normNick, 1, true)) or
                    (string.len(groupNormName) >= 4 and string.len(normDisplay) >= 4 and string.find(groupNormName, normDisplay, 1, true)) or
                    (string.len(normName) >= 4 and string.len(groupNormName) >= 4 and string.find(normName, groupNormName, 1, true)) or
                    (string.len(normNick) >= 4 and string.len(groupNormName) >= 4 and string.find(normNick, groupNormName, 1, true)) or
                    (string.len(normDisplay) >= 4 and string.len(groupNormName) >= 4 and string.find(normDisplay, groupNormName, 1, true))
            then
                print(string.format(
                    "Auto-matched method 2b: %s to %s, %s, %s)",
                    groupNormName, entry.username or "", entry.displayname or "", entry.nickname or ""
                ))
                matched = true
                break
            end
            if Levenshtein(groupNormName, normName) <= 2 or
               Levenshtein(groupNormName, normNick) <= 2 or
               Levenshtein(groupNormName, normDisplay) <= 2
            then
                print(string.format(
                    "Auto-matched method 3b: %s to %s, %s, %s)",
                    groupNormName, entry.username or "", entry.displayname or "", entry.nickname or ""
                ))
                matched = true
                break
            end
        end

        if not matched then
            local display = entry.displayname or entry.username or entry.nickname or "Unknown"
            table.insert(discordNotInGroup, display)
        end
    end

    local function tableCount(t)
        local count = 0
        for _ in pairs(t) do count = count + 1 end
        return count
    end

    -- Output results
    if next(unknownMembers) then
        local msgParts = {}
        local unknownCount = tableCount(unknownMembers)
        for i = 1, unknownCount, 9 do
            local chunk = {}
            for j = i, math.min(i+8, unknownCount) do
                table.insert(chunk, unknownMembers[j])
            end
            table.insert(msgParts, "Members not on Discord: " .. table.concat(chunk, ", "))
        end
        if IsInRaid() then
            for _, part in ipairs(msgParts) do
                SendChatMessage(part, "RAID_WARNING")
            end
            SendChatMessage("Join our Discord: https://discord.gg/3Qmegp9Df7", "RAID_WARNING")
        elseif GetNumPartyMembers() > 0 then
            for _, part in ipairs(msgParts) do
                SendChatMessage(part, "PARTY")
            end
            SendChatMessage("Join our Discord: https://discord.gg/3Qmegp9Df7", "PARTY")
        else
            for _, part in ipairs(msgParts) do
                DEFAULT_CHAT_FRAME:AddMessage(part)
            end
            DEFAULT_CHAT_FRAME:AddMessage("Join our Discord: https://discord.gg/3Qmegp9Df7")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("All members are on Discord.")
    end

    if next(discordNotInGroup) then
        local msgParts = {}
        local discordCount = tableCount(discordNotInGroup)
        for i = 1, discordCount, 9 do
            local chunk = {}
            for j = i, math.min(i+8, discordCount) do
                table.insert(chunk, discordNotInGroup[j])
            end
            table.insert(msgParts, "Discord members not in group: " .. table.concat(chunk, ", "))
        end
        if IsInRaid() then
            for _, part in ipairs(msgParts) do
                SendChatMessage(part, "RAID_WARNING")
            end
        elseif GetNumPartyMembers() > 0 then
            for _, part in ipairs(msgParts) do
                SendChatMessage(part, "PARTY")
            end
        else
            for _, part in ipairs(msgParts) do
                DEFAULT_CHAT_FRAME:AddMessage(part)
            end
        end
    end
end
