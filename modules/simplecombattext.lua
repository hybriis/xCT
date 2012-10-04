local ADDON_NAME, addon = ...

-- Shorten my handle
local x = addon.engine

-- up values
local sformat, mfloor, sgsub = string.format, math.floor, string.gsub
local tostring, tonumber, select, unpack = tostring, tonumber, select, unpack


-- TODO: finish this module
x.player = {
  unit = "player",
  guid = nil, -- dont get the id until we load
}

function x:UpdatePlayer()
  x.player.guid = UnitGUID("player")
end


-- Registers or Updates the combat text event frame
function x:UpdateCombatTextEvents(enable)
  local f = nil
  
  if x.combatEvents then
    x.combatEvents:UnregisterAllEvents()
    f = x.combatEvents
  else
    f = CreateFrame"FRAME"
  end
  
  if enable then
    f:RegisterEvent("COMBAT_TEXT_UPDATE")
    f:RegisterEvent("UNIT_HEALTH")
    f:RegisterEvent("UNIT_MANA")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("UNIT_COMBO_POINTS")
    f:RegisterEvent("UNIT_ENTERED_VEHICLE")
    f:RegisterEvent("UNIT_EXITING_VEHICLE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    -- if runes
    f:RegisterEvent("RUNE_POWER_UPDATE")
    
    -- if loot
    f:RegisterEvent("CHAT_MSG_LOOT")
    f:RegisterEvent("CHAT_MSG_MONEY")
    
    -- damage and healing
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- Class combo points
    f:RegisterEvent("UNIT_AURA")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    
    x.combatEvents = f
    
    f:SetScript("OnEvent", x.OnCombatTextEvent)
  else
    f:SetScript("OnEvent", nil)
  end
end

-- helper simple option checks
local function ShowMissTypes() return COMBAT_TEXT_SHOW_DODGE_PARRY_MISS == "1" end
local function ShowResistances() return COMBAT_TEXT_SHOW_RESISTANCES == "1" end
local function ShowHonor() return COMBAT_TEXT_SHOW_HONOR_GAINED == "1" end
local function ShowFaction() return COMBAT_TEXT_SHOW_REPUTATION == "1" end
local function ShowReactives() return COMBAT_TEXT_SHOW_REACTIVES == "1" end
local function ShowLowResources() return COMBAT_TEXT_SHOW_LOW_HEALTH_MANA == "1" end
local function ShowCombatState() return COMBAT_TEXT_SHOW_COMBAT_STATE == "1" end

local function ShowDamage() return x.db.profile.frames["outgoing"].enableOutDmg end
local function ShowHealing() return x.db.profile.frames["outgoing"].enableOutHeal end
local function ShowPetDamage() return x.db.profile.frames["outgoing"].enablePetDmg end
local function ShowAutoAttack() return x.db.profile.frames["outgoing"].enableAutoAttack end
local function ShowDots() return x.db.profile.frames["outgoing"].enableDotDmg end
local function ShowHots() return x.db.profile.frames["outgoing"].enableHots end
local function ShowImmunes() return x.db.profile.frames["outgoing"].enableImmunes end -- outgoing immunes
local function ShowMisses() return x.db.profile.frames["outgoing"].enableMisses end -- outgoing misses

-- string formatters
local format_fade = "-%s"
local format_gain = "+%s"
local format_resist = "-%s (%s %s)"
local format_energy = "+%s %s"
local format_honor = sgsub(COMBAT_TEXT_HONOR_GAINED, "%%s", "+%%s")
local format_faction = "%s +%s"
local format_crit = "%s%s%s"

local COMBATLOG_FILTER_MY_VEHICLE = bit.bor( COMBATLOG_OBJECT_AFFILIATION_MINE,
  COMBATLOG_OBJECT_REACTION_FRIENDLY, COMBATLOG_OBJECT_CONTROL_PLAYER, COMBATLOG_OBJECT_TYPE_GUARDIAN )

function x.OnCombatTextEvent(self, event, ...)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, srcFlags2, destGUID, destName, destFlags, destFlags2 = select(1, ...)
    if sourceGUID == x.player.guid or ( sourceGUID == UnitGUID("pet") and ShowPetDamage() ) or sourceFlags == COMBATLOG_FILTER_MY_VEHICLE then
      if x.outgoing_events[eventType] then
        x.outgoing_events[eventType](...)
      end
    end
  elseif event == "COMBAT_TEXT_UPDATE" then
    local subevent, arg2, arg3 = ...
    if x.combat_events[subevent] then
      x.combat_events[subevent](arg2, arg3)
    end
  else
    if x.events[event] then
      x.events[event](...)
    end
  end
end

-- icon formater
function x:GetSpellTextureFormatted(spellID, iconSize)
  local message = ""

  if spellID == PET_ATTACK_TEXTURE then
    message = " \124T"..PET_ATTACK_TEXTURE..":"..iconSize..":"..iconSize..":0:0:64:64:5:59:5:59\124t"
  else
    local icon = GetSpellTexture(spellID)
    if icon then
      message = " \124T"..icon..":"..iconSize..":"..iconSize..":0:0:64:64:5:59:5:59\124t"
    else
      message = " \124T"..ct.blank..":"..iconSize..":"..iconSize..":0:0:64:64:5:59:5:59\124t"
    end
  end
  return message
end

-- event handlers for combat text events
x.combat_events = {
  -- TODO: Add critical options
  ["DAMAGE"] = function(amount) x:AddMessage("damage", sformat(format_fade, amount), "damage") end,
  ["DAMAGE_CRIT"] = function(amount) x:AddMessage("damage", sformat(format_fade, amount), "damage_crit") end,
  ["SPELL_DAMAGE"] = function(amount) x:AddMessage("damage", sformat(format_fade, amount), "spell_damage") end,
  ["SPELL_DAMAGE_CRIT"] = function(amount) x:AddMessage("damage", sformat(format_fade, amount), "spell_damage_crit") end,
  
  -- TODO: Add player names
  ["HEAL"] = function(healer_name, amount) x:AddMessage("healing", sformat(format_gain, amount), "heal") end,
  ["HEAL_CRIT"] = function(healer_name, amount) x:AddMessage("healing", sformat(format_gain, amount), "heal_crit") end,
  ["PERIODIC_HEAL"] = function(healer_name, amount) x:AddMessage("healing", sformat(format_gain, amount), "heal_peri") end,
  
  -- TODO: Add filter?
  ["SPELL_CAST"] = function(spell_name) x:AddMessage("procs", spell_name, "spell_cast") end,
  
  ["MISS"] = function() if ShowMissTypes() then x:AddMessage("damage", MISS, "misstype_generic") end end,
  ["DODGE"] = function() if ShowMissTypes() then x:AddMessage("damage", DODGE, "misstype_generic") end end,
  ["PARRY"] = function() if ShowMissTypes() then x:AddMessage("damage", PARRY, "misstype_generic") end end,
  ["EVADE"] = function() if ShowMissTypes() then x:AddMessage("damage", EVADE, "misstype_generic") end end,
  ["IMMUNE"] = function() if ShowMissTypes() then x:AddMessage("damage", IMMUNE, "misstype_generic") end end,
  ["DEFLECT"] = function() if ShowMissTypes() then x:AddMessage("damage", DEFLECT, "misstype_generic") end end,
  ["REFLECT"] = function() if ShowMissTypes() then x:AddMessage("damage", REFLECT, "misstype_generic") end end,
  
  -- TODO: Add purple color to misstypes
  ["SPELL_MISS"] = function() if ShowMissTypes() then x:AddMessage("damage", MISS, "misstype_generic") end end,
  ["SPELL_DODGE"] = function() if ShowMissTypes() then x:AddMessage("damage", DODGE, "misstype_generic") end end,
  ["SPELL_PARRY"] = function() if ShowMissTypes() then x:AddMessage("damage", PARRY, "misstype_generic") end end,
  ["SPELL_EVADE"] = function() if ShowMissTypes() then x:AddMessage("damage", EVADE, "misstype_generic") end end,
  ["SPELL_IMMUNE"] = function() if ShowMissTypes() then x:AddMessage("damage", IMMUNE, "misstype_generic") end end,
  ["SPELL_DEFLECT"] = function() if ShowMissTypes() then x:AddMessage("damage", DEFLECT, "misstype_generic") end end,
  ["SPELL_REFLECT"] = function() if ShowMissTypes() then x:AddMessage("damage", REFLECT, "misstype_generic") end end,
  
  ["SPELL_ACTIVE"] = function(spellname) if ShowReactives() then x:AddMessage("general", spellname, "spell_reactive") end end,
  
  ["RESIST"] = function(amount, resisted)
      if resisted then
        if ShowResistances() then
          x:AddMessage("damage", sformat(format_resist, amount, RESIST, resisted), "resist_generic")
        else
          x:AddMessage("damage", amount, "damage")
        end
      elseif ShowResistances() then
        x:AddMessage("damage", RESIST, "misstype_generic")
      end
    end,
  ["BLOCK"] = function(amount, resisted)
      if resisted then
        if ShowResistances() then
          x:AddMessage("damage", sformat(format_resist, amount, BLOCK, resisted), "resist_generic")
        else
          x:AddMessage("damage", amount, "damage")
        end
      elseif ShowResistances() then
        x:AddMessage("damage", BLOCK, "misstype_generic")
      end
    end,
  ["ABSORB"] = function(amount, resisted)
      if resisted then
        if ShowResistances() then
          x:AddMessage("damage", sformat(format_resist, amount, ABSORB, resisted), "resist_generic")
        else
          x:AddMessage("damage", amount, "damage")
        end
      elseif ShowResistances() then
        x:AddMessage("damage", ABSORB, "misstype_generic")
      end
    end,
  ["SPELL_RESIST"] = function(amount, resisted)
      if resisted then
        if ShowResistances() then
          x:AddMessage("damage", sformat(format_resist, amount, RESIST, resisted), "resist_spell")
        else
          x:AddMessage("damage", amount, "damage")
        end
      elseif ShowResistances() then
        x:AddMessage("damage", RESIST, "misstype_generic")
      end
    end,
  ["SPELL_BLOCK"] = function(amount, resisted)
      if resisted then
        if ShowResistances() then
          x:AddMessage("damage", sformat(format_resist, amount, BLOCK, resisted), "resist_spell")
        else
          x:AddMessage("damage", amount, "damage")
        end
      elseif ShowResistances() then
        x:AddMessage("damage", BLOCK, "misstype_generic")
      end
    end,
  ["SPELL_ABSORB"] = function(amount, resisted)
      if resisted then
        if ShowResistances() then
          x:AddMessage("damage", sformat(format_resist, amount, ABSORB, resisted), "resist_spell")
        else
          x:AddMessage("damage", amount, "damage")
        end
      elseif ShowResistances() then
        x:AddMessage("damage", ABSORB, "misstype_generic")
      end
    end,
  ["ENERGIZE"] = function(amount, energy_type)
      if tonumber(amount) > 0 then
        if energy_type and energy_type == "MANA"
            or energy_type == "RAGE" or energy_type == "FOCUS"
            or energy_type == "ENERGY" or energy_type == "RUINIC_POWER"
            or energy_type == "SOUL_SHARDS" or energy_type == "HOLY_POWER" then
          local color = {PowerBarColor[energy_type].r, PowerBarColor[energy_type].g, PowerBarColor[energy_type].b}
          x:AddMessage("energy", sformat(format_energy, amount, energy_type), color)
        end
      end
    end,
  ["PERIODIC_ENERGIZE"] = function(amount, energy_type)
      if tonumber(amount) > 0 then
        if energy_type and energy_type == "MANA"
            or energy_type == "RAGE" or energy_type == "FOCUS"
            or energy_type == "ENERGY" or energy_type == "RUINIC_POWER"
            or energy_type == "SOUL_SHARDS" or energy_type == "HOLY_POWER" then
          local color = {PowerBarColor[energy_type].r, PowerBarColor[energy_type].g, PowerBarColor[energy_type].b}
          x:AddMessage("energy", sformat(format_energy, amount, energy_type), color)
        end
      end
    end,
  ["SPELL_AURA_START"] = function(spellname) x:AddMessage("general", sformat(format_gain, spellname), "aura_start") end,
  ["SPELL_AURA_END"] = function(spellname) x:AddMessage("general", sformat(format_fade, spellname), "aura_end") end,
  ["SPELL_AURA_START_HARMFUL"] = function(spellname) x:AddMessage("general", sformat(format_gain, spellname), "aura_start_harm") end,
  ["SPELL_AURA_END_HARMFUL"] = function(spellname) x:AddMessage("general", sformat(format_fade, spellname), "aura_end") end,
  
  -- TODO: Create a merger for faction and honor xp
  ["HONOR_GAINED"] = function(amount)
      local num = mfloor(tonumber(amount) or 0)
      if num > 0 and ShowHonor() then
        x:AddMessage("general", sformat(format_honor, HONOR, amount), "honor")
      end
    end,
  ["FACTION"] = function(faction, amount)
      local num = mfloor(tonumber(amount) or 0)
      if num > 0 and ShowFaction() then
        x:AddMessage("general", sformat(format_faction, faction, amount), "honor")
      end
    end,
}

x.events = {
  ["UNIT_HEALTH"] = function()
      if ShowLowResources() and UnitHealth(x.player.unit) / UnitHealthMax(x.player.unit) <= COMBAT_TEXT_LOW_HEALTH_THRESHOLD then
        if not x.lowHealth then
          x.AddMessage("general", HEALTH_LOW, "low_health")
          x.lowHealth = true
        end
      else
        x.lowHealth = false
      end
    end,
  ["UNIT_MANA"] = function()
      if select(2, UnitPowerType(x.player.unit)) == "MANA" and ShowLowResources() and UnitPower(x.player.unit) / UnitPowerMax(x.player.unit) <= COMBAT_TEXT_LOW_MANA_THRESHOLD then
        if not x.lowMana then
          x.AddMessage("general", MANA_LOW, "low_mana")
          x.lowMana = true
        end
      else
        x.lowMana = false
      end
    end,
  
  ["PLAYER_REGEN_ENABLED"] = function() if ShowCombatState() then x:AddMessage("general", sformat(format_fade, LEAVING_COMBAT), "combat_end") end end,
  ["PLAYER_REGEN_DISABLED"] = function() if ShowCombatState() then x:AddMessage("general", sformat(format_gain, ENTERING_COMBAT), "combat_begin") end end,
  
  -- TODO: Finish Combo Points and Runes
  ["UNIT_COMBO_POINTS"] = function() end,
  ["RUNE_POWER_UPDATE"] = function() end,
  ["UNIT_ENTERED_VEHICLE"] = function(unit) if unit == "player" then x:UpdatePlayer() end end,
  ["UNIT_EXITING_VEHICLE"] = function(unit) if unit == "player" then x:UpdatePlayer() end end,
  ["PLAYER_ENTERING_WORLD"] = function() x:UpdatePlayer() end,
  
  -- TODO: Finish Loot Stuff
  ["CHAT_MSG_LOOT"] = function() end,
  ["CHAT_MSG_MONEY"] = function() end,
}

x.outgoing_events = {
  ["SPELL_PERIODIC_HEAL"] = function(...)
      if ShowHealing() and ShowHots() then
        -- output = the output frame; list of incoming args
        local spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = select(12, ...)
        local outputFrame, message, outputColor = "outgoing", amount, "heal_out"
        
        -- TODO: Add Healing Filter
        
        -- Check for Critical
        if critical then 
          message = sformat(format_crit, x.db.profile.frames["critical"].critPrefix, amount, x.db.profile.frames["critical"].critPostfix)
          outputColor = "heal_out"
          outputFrame = "critical"
        end
        
        -- Add Icons
        if x.db.profile.frames["outgoing"].iconsEnabled then
          if critical then
            message = message .. x:GetSpellTextureFormatted(spellId, x.db.profile.frames["outgoing"].iconsSize)
          else
            message = message .. x:GetSpellTextureFormatted(spellId, x.db.profile.frames["critical"].iconsSize)
          end
        end
        
        x:AddMessage(outputFrame, message, outputColor)
      end
    end,
  ["SPELL_HEAL"] = function(...)
      if ShowHealing() then
        -- output = the output frame; list of incoming args
        local spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = select(12, ...)
        local outputFrame, message, outputColor = "outgoing", amount, "heal_out"
        
        -- TODO: Add Healing Filter
        
        -- Check for Critical
        if critical then 
          message = sformat(format_crit, x.db.profile.frames["critical"].critPrefix, amount, x.db.profile.frames["critical"].critPostfix)
          outputColor = "heal_out"
          outputFrame = "critical"
        end
        
        -- Add Icons
        if x.db.profile.frames["outgoing"].iconsEnabled then
          if critical then
            message = message .. x:GetSpellTextureFormatted(spellId, x.db.profile.frames["outgoing"].iconsSize)
          else
            message = message .. x:GetSpellTextureFormatted(spellId, x.db.profile.frames["critical"].iconsSize)
          end
        end
        
        x:AddMessage(outputFrame, message, outputColor)
      end
    end,
    
    
    
    
  ["SWING_DAMAGE"] = function(...)
      local _, _, _, sourceGUID, _, sourceFlags, _, _, _, _, _, amount, _, _, _, _, _, critical = select(12, ...)
      local outputFrame, message, outputColor = "outgoing", amount, "out_damage"
      
      -- Check for Critical
      if critical then  -- TODO: Filter Criticals
        message = sformat(format_crit, x.db.profile.frames["critical"].critPrefix, amount, x.db.profile.frames["critical"].critPostfix)
        outputColor = "heal_out"
        outputFrame = "critical"
      end
      
      local spellID = 6603
      if (sourceGUID == UnitGUID("pet") and ShowPetDamage()) or sourceFlags == gflags then
        spellNameOrID = PET_ATTACK_TEXTURE
      end
      
      -- Add Icons
      if x.db.profile.frames["outgoing"].iconsEnabled then
        if critical then
          message = message .. x:GetSpellTextureFormatted(spellID, x.db.profile.frames["outgoing"].iconsSize)
        else
          message = message .. x:GetSpellTextureFormatted(spellID, x.db.profile.frames["critical"].iconsSize)
        end
      end
      
      x:AddMessage("outgoing", message, "out_damage")
    end,
    
    
    
    
    
  ["RANGE_DAMAGE"] = function(...) end,
  ["SPELL_DAMAGE"] = function(...) end,
  ["SPELL_PERIODIC_DAMAGE"] = function(...) end,
  ["SWING_MISSED"] = function(...) end,
  ["SPELL_MISSED"] = function(...) end,
  ["RANGE_MISSED"] = function(...) end,
  ["SPELL_DISPEL"] = function(...) end,
  ["SPELL_INTERRUPT"] = function(...) end,
  ["SPELL_STOLEN"] = function(...) end,
  ["PARTY_KILL"] = function(...) end,
}