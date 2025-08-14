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
        local knownNick = NormalizeName(entry.nickname or "")

        -- Exact match
        if normName == knownName or normName == knownNick then
            return true
        end

        -- Prefix match (check length first)
        if string.len(normName) >= 3 and (string.sub(normName, 1, 3) == string.sub(knownName, 1, 3) or string.sub(normName, 1, 3) == string.sub(knownNick, 1, 3)) then
            return true
        end

        -- Substring match
        if string.find(normName, knownName, 1, true) or string.find(normName, knownNick, 1, true) or
           string.find(knownName, normName, 1, true) or string.find(knownNick, normName, 1, true) then
            return true
        end

        -- Levenshtein distance (typo tolerance)
        if Levenshtein(normName, knownName) <= 3 or Levenshtein(normName, knownNick) <= 3 then
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

    if IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            local unit = "raid" .. i
            if UnitIsPlayer(unit) then
                local name = GetUnitName(unit, true)
                if name and not NamesOnDiscord_IsKnown(name) then
                    local class = UnitClass(unit)
                    table.insert(unknownMembers, NamesOnDiscord_Colorize_Player_By_Class(name, class))
                end
            end
        end
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            if UnitIsPlayer(unit) then
                local name = GetUnitName(unit, true)
                if name and not NamesOnDiscord_IsKnown(name) then
                    local class = UnitClass(unit)
                    table.insert(unknownMembers, NamesOnDiscord_Colorize_Player_By_Class(name, class))
                end
            end
        end

        local playerName = UnitName("player")
        if playerName and not NamesOnDiscord_IsKnown(playerName) then
            local class = UnitClass("player")
            table.insert(unknownMembers, NamesOnDiscord_Colorize_Player_By_Class(playerName, class))
        end
    else
        local playerName = UnitName("player")
        if playerName and not NamesOnDiscord_IsKnown(playerName) then
            local class = UnitClass("player")
            table.insert(unknownMembers, NamesOnDiscord_Colorize_Player_By_Class(playerName, class))
        end
    end

    if next(unknownMembers) then
        if IsInRaid() then
            SendChatMessage("Members not on Discord: " .. table.concat(unknownMembers, ", "), "RAID_WARNING")
            SendChatMessage("Join our Discord: https://discord.gg/3Qmegp9Df7", "RAID_WARNING")
        elseif GetNumPartyMembers() > 0 then
            SendChatMessage("Members not on Discord: " .. table.concat(unknownMembers, ", "), "PARTY")
            SendChatMessage("Join our Discord: https://discord.gg/3Qmegp9Df7", "PARTY")
        else
            DEFAULT_CHAT_FRAME:AddMessage("Members not on Discord: " .. table.concat(unknownMembers, ", "))
            DEFAULT_CHAT_FRAME:AddMessage("Join our Discord: https://discord.gg/3Qmegp9Df7")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("All members are on Discord.")
    end
end