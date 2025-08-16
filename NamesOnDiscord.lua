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
        if string.len(normName) >= 3 and (
            string.sub(normName, 1, 3) == string.sub(knownName, 1, 3) or
            string.sub(normName, 1, 3) == string.sub(knownNick, 1, 3) or
            string.sub(normName, 1, 3) == string.sub(knownDisplay, 1, 3)
        ) then
            print(string.format(
                "Auto-matched 1: %s to (%s, %s, %s)",
                name, entry.username or "", entry.displayname or "", entry.nickname or ""
            ))
            return true
        end

        -- Substring match
        if string.find(normName, knownName, 1, true) or
           string.find(normName, knownNick, 1, true) or
           string.find(normName, knownDisplay, 1, true) or
           string.find(knownName, normName, 1, true) or
           string.find(knownNick, normName, 1, true) or
           string.find(knownDisplay, normName, 1, true)
        then
            print(string.format(
                "Auto-matched 2: %s to (%s, %s, %s)",
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
                "Auto-matched 3: %s to (%s, %s, %s)",
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
            if string.len(groupNormName) >= 3 and (
                string.sub(groupNormName, 1, 3) == string.sub(normName, 1, 3) or
                string.sub(groupNormName, 1, 3) == string.sub(normNick, 1, 3) or
                string.sub(groupNormName, 1, 3) == string.sub(normDisplay, 1, 3)
            ) then
                matched = true
                break
            end
            if string.find(groupNormName, normName, 1, true) or
               string.find(groupNormName, normNick, 1, true) or
               string.find(groupNormName, normDisplay, 1, true) or
               string.find(normName, groupNormName, 1, true) or
               string.find(normNick, groupNormName, 1, true) or
               string.find(normDisplay, groupNormName, 1, true)
            then
                matched = true
                break
            end
            if Levenshtein(groupNormName, normName) <= 2 or
               Levenshtein(groupNormName, normNick) <= 2 or
               Levenshtein(groupNormName, normDisplay) <= 2
            then
                matched = true
                break
            end
        end

        if not matched then
            local display = entry.displayname or entry.username or entry.nickname or "Unknown"
            table.insert(discordNotInGroup, display)
        end
    end

    -- Output results
    if next(unknownMembers) then
        local msg = "Members not on Discord: " .. table.concat(unknownMembers, ", ")
        if IsInRaid() then
            SendChatMessage(msg, "RAID_WARNING")
            SendChatMessage("Join our Discord: https://discord.gg/3Qmegp9Df7", "RAID_WARNING")
        elseif GetNumPartyMembers() > 0 then
            SendChatMessage(msg, "PARTY")
            SendChatMessage("Join our Discord: https://discord.gg/3Qmegp9Df7", "PARTY")
        else
            DEFAULT_CHAT_FRAME:AddMessage(msg)
            DEFAULT_CHAT_FRAME:AddMessage("Join our Discord: https://discord.gg/3Qmegp9Df7")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("All members are on Discord.")
    end

    if next(discordNotInGroup) then
        local msg = "Discord members not in group: " .. table.concat(discordNotInGroup, ", ")
        if IsInRaid() then
            SendChatMessage(msg, "RAID_WARNING")
        elseif GetNumPartyMembers() > 0 then
            SendChatMessage(msg, "PARTY")
        else
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    end
end
