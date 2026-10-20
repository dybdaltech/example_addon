-- StatPeek: minimap button + character stats window for WoW 3.3.5 (interface 30300).
-- No external libraries.

local ADDON_NAME = "StatPeek"

-- Combat rating indices (FrameXML defines these as globals; fall back to the 3.3.5 values)
local CR_DEFENSE        = CR_DEFENSE_SKILL      or 2
local CR_DODGE_R        = CR_DODGE              or 3
local CR_PARRY_R        = CR_PARRY              or 4
local CR_BLOCK_R        = CR_BLOCK              or 5
local CR_HIT_MELEE_R    = CR_HIT_MELEE          or 6
local CR_HIT_RANGED_R   = CR_HIT_RANGED         or 7
local CR_HIT_SPELL_R    = CR_HIT_SPELL          or 8
local CR_CRIT_MELEE_R   = CR_CRIT_MELEE         or 9
local CR_CRIT_RANGED_R  = CR_CRIT_RANGED        or 10
local CR_CRIT_SPELL_R   = CR_CRIT_SPELL         or 11
local CR_RESILIENCE_R   = CR_CRIT_TAKEN_MELEE   or 15
local CR_HASTE_MELEE_R  = CR_HASTE_MELEE        or 18
local CR_HASTE_RANGED_R = CR_HASTE_RANGED       or 19
local CR_HASTE_SPELL_R  = CR_HASTE_SPELL        or 20
local CR_EXPERTISE_R    = CR_EXPERTISE          or 24
local CR_ARMOR_PEN_R    = CR_ARMOR_PENETRATION  or 25

local defaults = { minimapAngle = 220, hideMinimap = false, windowPoint = nil }

---------------------------------------------------------------------------
-- Stat helpers
---------------------------------------------------------------------------

local function pct(v) return string.format("%.2f%%", v or 0) end

local function ratingPct(cr)
	return string.format("%.2f%% (%d)", GetCombatRatingBonus(cr) or 0, GetCombatRating(cr) or 0)
end

-- Blizzard's paper doll shows the lowest value across the magic schools (2..7).
local function minSpellCrit()
	local best
	for school = 2, 7 do
		local v = GetSpellCritChance(school)
		if not best or v < best then best = v end
	end
	return best or 0
end

local function minSpellDamage()
	local best
	for school = 2, 7 do
		local v = GetSpellBonusDamage(school)
		if not best or v < best then best = v end
	end
	return best or 0
end

local function attackPower(unitFunc)
	local base, pos, neg = unitFunc("player")
	return (base or 0) + (pos or 0) + (neg or 0)
end

-- Each section: title + list of { label, function returning display text }
local SECTIONS = {
	{
		title = "Attributes",
		rows = {
			{ "Strength",  function() local _, v = UnitStat("player", 1) return v end },
			{ "Agility",   function() local _, v = UnitStat("player", 2) return v end },
			{ "Stamina",   function() local _, v = UnitStat("player", 3) return v end },
			{ "Intellect", function() local _, v = UnitStat("player", 4) return v end },
			{ "Spirit",    function() local _, v = UnitStat("player", 5) return v end },
			{ "Health",    function() return UnitHealthMax("player") end },
			{ "Mana/Power", function() return UnitPowerMax("player") end },
		},
	},
	{
		title = "Spell",
		rows = {
			{ "Spell power",   minSpellDamage },
			{ "Bonus healing", function() return GetSpellBonusHealing() end },
			{ "Spell crit",    function() return string.format("%.2f%%", minSpellCrit()) end },
			{ "Spell hit",     function() return ratingPct(CR_HIT_SPELL_R) end },
			{ "Spell haste",   function() return ratingPct(CR_HASTE_SPELL_R) end },
			{ "Spell pen.",    function() return GetSpellPenetration() end },
			{ "MP5 (casting)", function()
				local base, casting = GetManaRegen()
				return string.format("%d (%d)", (base or 0) * 5, (casting or 0) * 5)
			end },
		},
	},
	{
		title = "Melee",
		rows = {
			{ "Attack power", function() return attackPower(UnitAttackPower) end },
			{ "Melee crit",   function() return pct(GetCritChance()) end },
			{ "Melee hit",    function() return ratingPct(CR_HIT_MELEE_R) end },
			{ "Melee haste",  function() return ratingPct(CR_HASTE_MELEE_R) end },
			{ "Attack speed", function()
				local mh, oh = UnitAttackSpeed("player")
				if oh then return string.format("%.2f / %.2f", mh or 0, oh) end
				return string.format("%.2f", mh or 0)
			end },
			{ "Expertise",    function()
				local mh = GetExpertise()
				return string.format("%d (%d)", mh or 0, GetCombatRating(CR_EXPERTISE_R) or 0)
			end },
			{ "Armor pen.",   function()
				return string.format("%.2f%% (%d)", GetArmorPenetration() or 0, GetCombatRating(CR_ARMOR_PEN_R) or 0)
			end },
		},
	},
	{
		title = "Ranged",
		rows = {
			{ "Ranged AP",    function() return attackPower(UnitRangedAttackPower) end },
			{ "Ranged crit",  function() return pct(GetRangedCritChance()) end },
			{ "Ranged hit",   function() return ratingPct(CR_HIT_RANGED_R) end },
			{ "Ranged haste", function() return ratingPct(CR_HASTE_RANGED_R) end },
		},
	},
	{
		title = "Defense",
		rows = {
			{ "Armor",      function() local _, eff = UnitArmor("player") return eff end },
			{ "Defense",    function()
				local base, mod = UnitDefense("player")
				return (base or 0) + (mod or 0)
			end },
			{ "Dodge",      function() return pct(GetDodgeChance()) end },
			{ "Parry",      function() return pct(GetParryChance()) end },
			{ "Block",      function() return pct(GetBlockChance()) end },
			{ "Resilience", function() return GetCombatRating(CR_RESILIENCE_R) end },
		},
	},
}

---------------------------------------------------------------------------
-- Main window
---------------------------------------------------------------------------

local ROW_HEIGHT = 14
local COL_WIDTH = 200
local PADDING = 14

local frame = CreateFrame("Frame", "StatPeekFrame", UIParent)
frame:SetWidth(COL_WIDTH * 2 + PADDING * 3)
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:Hide()
tinsert(UISpecialFrames, "StatPeekFrame") -- close with Escape

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	StatPeekDB.windowPoint = { point, relPoint, x, y }
end)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
nameText:SetPoint("TOP", 0, -18)

local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
infoText:SetPoint("TOP", nameText, "BOTTOM", 0, -4)

local guildText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
guildText:SetPoint("TOP", infoText, "BOTTOM", 0, -2)

-- Lay sections out in two columns: Attributes/Melee/Ranged left, Spell/Defense right.
local LAYOUT = { { 1, 3, 4 }, { 2, 5 } }
local valueStrings = {}
local HEADER_TOP = 70
local tallest = 0

for col, sectionIds in ipairs(LAYOUT) do
	local x = PADDING + (col - 1) * (COL_WIDTH + PADDING)
	local y = -HEADER_TOP
	for _, id in ipairs(sectionIds) do
		local section = SECTIONS[id]
		local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOPLEFT", x + 4, y)
		title:SetText(section.title)
		y = y - ROW_HEIGHT - 2
		for _, row in ipairs(section.rows) do
			local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			label:SetPoint("TOPLEFT", x + 10, y)
			label:SetText(row[1])
			local value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			value:SetPoint("TOPRIGHT", frame, "TOPLEFT", x + COL_WIDTH, y)
			value:SetJustifyH("RIGHT")
			value:SetTextColor(1, 1, 1)
			valueStrings[#valueStrings + 1] = { fs = value, fn = row[2] }
			y = y - ROW_HEIGHT
		end
		y = y - 8
	end
	tallest = math.max(tallest, -y)
end
frame:SetHeight(tallest + PADDING)

local function Refresh()
	local name = UnitName("player")
	local className, classFile = UnitClass("player")
	local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if color then
		nameText:SetText(string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name))
	else
		nameText:SetText(name)
	end
	infoText:SetText(string.format("Level %d %s %s", UnitLevel("player"), UnitRace("player") or "", className or ""))
	local guild, rank = GetGuildInfo("player")
	guildText:SetText(guild and string.format("<%s> %s", guild, rank or "") or "")

	for _, entry in ipairs(valueStrings) do
		local ok, v = pcall(entry.fn)
		entry.fs:SetText(ok and tostring(v or 0) or "-")
	end
end

-- Stats change constantly (buffs, gear, procs), so refresh on a short timer while open.
local elapsedSince = 0
frame:SetScript("OnUpdate", function(self, elapsed)
	elapsedSince = elapsedSince + elapsed
	if elapsedSince >= 0.5 then
		elapsedSince = 0
		Refresh()
	end
end)
frame:SetScript("OnShow", function()
	elapsedSince = 0
	Refresh()
	PlaySound("igCharacterInfoOpen")
end)
frame:SetScript("OnHide", function() PlaySound("igCharacterInfoClose") end)

local function ToggleWindow()
	if frame:IsShown() then frame:Hide() else frame:Show() end
end

---------------------------------------------------------------------------
-- Minimap button (drag to move around the minimap edge)
---------------------------------------------------------------------------

local button = CreateFrame("Button", "StatPeekMinimapButton", Minimap)
button:SetWidth(31)
button:SetHeight(31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("TOPLEFT", 7, -5)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(53)
border:SetHeight(53)
border:SetPoint("TOPLEFT")

local function UpdateButtonPosition()
	local angle = math.rad(StatPeekDB.minimapAngle or defaults.minimapAngle)
	local radius = (Minimap:GetWidth() / 2) + 10
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	cx, cy = cx / scale, cy / scale
	StatPeekDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
	UpdateButtonPosition()
end

button:SetScript("OnDragStart", function(self)
	self:LockHighlight()
	self:SetScript("OnUpdate", OnDragUpdate)
end)
button:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
	self:UnlockHighlight()
end)
button:SetScript("OnClick", function() ToggleWindow() end)
button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("StatPeek")
	GameTooltip:AddLine("Click to show your character stats.", 1, 1, 1)
	GameTooltip:AddLine("Drag to move this button.", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Init + slash commands
---------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
	if name ~= ADDON_NAME then return end
	StatPeekDB = StatPeekDB or {}
	for k, v in pairs(defaults) do
		if StatPeekDB[k] == nil then StatPeekDB[k] = v end
	end
	UpdateButtonPosition()
	if StatPeekDB.hideMinimap then button:Hide() end
	local p = StatPeekDB.windowPoint
	frame:ClearAllPoints()
	if p then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("CENTER")
	end
	self:UnregisterEvent("ADDON_LOADED")
end)

SLASH_STATPEEK1 = "/statpeek"
SlashCmdList["STATPEEK"] = function(msg)
	msg = string.lower(msg or "")
	if msg == "minimap" then
		StatPeekDB.hideMinimap = not StatPeekDB.hideMinimap
		if StatPeekDB.hideMinimap then button:Hide() else button:Show() end
	elseif msg == "reset" then
		StatPeekDB.minimapAngle = defaults.minimapAngle
		StatPeekDB.windowPoint = nil
		UpdateButtonPosition()
		frame:ClearAllPoints()
		frame:SetPoint("CENTER")
		button:Show()
		StatPeekDB.hideMinimap = false
	else
		ToggleWindow()
	end
end
