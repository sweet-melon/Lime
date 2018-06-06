
local L = LibStub("AceLocale-3.0"):GetLocale("Lime")

local _G = _G
local lime = lime
local Option = lime.optionFrame
local GetNumSpellTabs = _G.GetNumSpellTabs
local GetSpellTabInfo = _G.GetSpellTabInfo
local GetSpellLink = _G.GetSpellLink
local SpellHasRange = _G.SpellHasRange
local IsHelpfulSpell = _G.IsHelpfulSpell
local IsPassiveSpell = _G.IsPassiveSpell
local GetSpellBookItemName = _G.GetSpellBookItemName
local InCombatLockdown = _G.InCombatLockdown
local HasPetSpells = _G.HasPetSpells
local GetNumMacros = _G.GetNumMacros
local GetMacroInfo = _G.GetMacroInfo
local wipe = _G.wipe
local floor = _G.math.floor
local ceil = _G.math.ceil
local min = _G.math.min
local max = _G.math.max
-- [[8.0PH]] local GetSpellSubtext = _G.GetSpellSubtext

local LBO = LibStub("LibLimeOption-1.0")

function Option:CreateClickCastingMenu(menu, parent)
	Option.CreateClickCastingMenu = nil
	local function buttonOnClick()
		CloseDropDownMenus(1)
		LBO:Refresh(menu.clickKeys)
	end
	local buttonNames = {}
	for i = 1, lime.numMouseButtons do
		tinsert(buttonNames, { name = _G["KEY_BUTTON"..i], func = buttonOnClick, id = i })
	end
	tinsert(buttonNames, 4, { name = KEY_MOUSEWHEELUP, func = buttonOnClick, id = "WHEELUP" })
	tinsert(buttonNames, 5, { name = KEY_MOUSEWHEELDOWN, func = buttonOnClick, id = "WHEELDOWN" })
	menu.buttons = LBO:CreateWidget("Menu", parent, buttonNames)
	menu.buttons:SetBackdropBorderColor(0.6, 0.6, 0.6)
	menu.buttons:SetPoint("TOPLEFT", 6, -20)
	menu.buttons:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", 150, 6)
	menu.buttons:SetValue(1)
	menu.talentGroup =  parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	menu.talentGroup:SetPoint("BOTTOM", menu.buttons, "TOP", -2, 4)

	local dropdown = CreateFrame("Frame", "limeClickCastingDropDown", UIParent, "L_UIDropDownMenuTemplate")
	local name, start, last, spell, rank, spellId, _
	local spellBooks, numSpells = {}, 20
	local overrideSpells = {}

	do
		local function addOverrideSpells(tbl)
			if type(tbl) == "table" then
				for p, v in pairs(tbl) do
					if type(p) == "string" then
						overrideSpells[p] = v
					end
				end
			end
		end

		addOverrideSpells(lime.overrideClickCastingSpells[lime.playerClass])
		for i = 1, GetNumSpecializations() do
			addOverrideSpells(lime.overrideClickCastingSpells[GetSpecializationInfo(i)])
		end
	end

	local function getSpellName(spell, rank)
		if rank and rank ~= "" then
			local spell2 = spell.."("..rank..")"
			local spellLink = GetSpellLink(spell2)
			if spellLink and GetSpellLink(spell) ~= spellLink then
				return spell2
			end
		end
		return spell
	end

	local function checkSpell(spell, index, type)
		if spell and spell ~= "" then
			if SpellHasRange(index, type) and not IsPassiveSpell(index, type) then
				return true
			elseif SpellHasRange(spell) and not IsPassiveSpell(spell) then
				return true
			elseif overrideSpells[spell] then
				if SpellHasRange(overrideSpells[spell]) and not IsPassiveSpell(overrideSpells[spell]) then
					return true
				end
			end
		end
		return nil
	end

	local function getOverrideSpell(spell)
		local override = {}
		for overrideSpell, orgSpell in pairs(overrideSpells) do
			if orgSpell == spell then
				table.insert(override, overrideSpell)
			end
		end
		if #override > 0 then
			return override
		end
	end

	local function getOverriddenSpell(spell)
		if overrideSpells[spell] then
			return overrideSpells[spell]
		end
	end

	local function hasSpellTab(tab)
		name, _, start, last = GetSpellTabInfo(tab)
		if name then
			local cnt = 0
			for i = start + 1, start + last do
				spell = getSpellName(GetSpellBookItemName(i, BOOKTYPE_SPELL))
				if checkSpell(spell, i, BOOKTYPE_SPELL) then
					cnt = cnt + 1
				end
			end
			return cnt
		end
		return 0
	end

	local function hasPetSpell()
		for i = 1, HasPetSpells() or 0 do
			spell = getSpellName(GetSpellBookItemName(i, BOOKTYPE_PET))
			if checkSpell(spell, i, BOOKTYPE_PET) then
				return PET
			end
		end
		return nil
	end

	local function hasGuildSpell()
		if IsInGuild() then

		end
		return nil
	end

	local function checkOverride(spell, chkSpell)
		local chk = getOverrideSpell(spell)
		if not chk then return false end
		if #chk == 1 then
			if chk[1] == chkSpell then
				return true
			end
		else
			for i = 1, #chk do
				if chk[i] == chkSpell then
					return true
				end
			end
		end
		return false
	end

	local function dropDownOnClick(self)
		CloseDropDownMenus(1)
		if dropdown.arg1 ~= self.arg1 or dropdown.arg2 ~= self.arg2 then
			if self.arg1 then
				if self.arg2 then
					lime.ccdb[dropdown.modifilter..dropdown.button] = self.arg1.."__"..self.arg2
				else
				lime.ccdb[dropdown.modifilter..dropdown.button] = self.arg1
				end
			else
				lime.ccdb[dropdown.modifilter..dropdown.button] = nil
			end
			if type(dropdown.button) == "number" then
				lime:SetClickCasting(dropdown.modifilter, dropdown.button)
			else
				lime:SetClickCastingMouseWheel()
			end
			dropdown.parent:Update()
		end
	end

	local inspectMacro = "/cleartarget\n/target [@mouseover]\n/run InspectUnit('target')"
	local followMacro = "/follow mouseover"
	local assistMacro = "/assist [@mouseover]"
	local focusMacro = "/clearfocus\n/focus [@mouseover]"
	local whisperMacro = "/run ChatFrame_SendTell(GetUnitName('mouseover'))"
	local tradeMacro = "/run InitiateTrade('mouseover')"

	local function dropDownInitialize(self, level)
		if InCombatLockdown() then return CloseDropDownMenus(1) end
		if level then
			local info = L_UIDropDownMenu_CreateInfo()
			info.func = dropDownOnClick
			if level == 1 then
				info.text, info.arg1, info.arg2 = L["대상 선택"], "target"
				info.checked = self.arg1 == info.arg1 and self.arg2 == info.arg2
				L_UIDropDownMenu_AddButton(info, level)
				info.text, info.arg1, info.arg2 = L["메뉴"], "menu"
				info.checked = self.arg1 == info.arg1 and self.arg2 == info.arg2
				L_UIDropDownMenu_AddButton(info, level)
				info.text, info.arg1, info.arg2 = INSPECT, "macrotext", inspectMacro
				info.checked = self.arg1 == info.arg1 and self.arg2 == info.arg2
				L_UIDropDownMenu_AddButton(info, level)
				info.text, info.arg1, info.arg2 = FOLLOW, "macrotext", followMacro
				info.checked = self.arg1 == info.arg1 and self.arg2 == info.arg2
				L_UIDropDownMenu_AddButton(info, level)
				info.text, info.arg1, info.arg2 = BINDING_NAME_ASSISTTARGET, "macrotext", assistMacro
				info.checked = self.arg1 == info.arg1 and self.arg2 == info.arg2
				L_UIDropDownMenu_AddButton(info, level)
				info.text, info.arg1, info.arg2 = SET_FOCUS, "macrotext", focusMacro
				info.checked = self.arg1 == info.arg1 and self.arg2 == info.arg2
				L_UIDropDownMenu_AddButton(info, level)
				info.text, info.arg1, info.arg2 = WHISPER, "macrotext", whisperMacro
				info.checked = self.arg1 == info.arg1 and self.arg2 == info.arg2
				L_UIDropDownMenu_AddButton(info, level)
				info.text, info.arg1, info.arg2 = TRADE, "macrotext", tradeMacro
				info.checked = self.arg1 == info.arg1 and self.arg2 == info.arg2
				L_UIDropDownMenu_AddButton(info, level)
				info.hasArrow, info.func, info.arg1, info.arg2, info.checked = true

				local cnt = hasSpellTab(1) + hasSpellTab(2)
				if cnt > 0 then
					if cnt > numSpells then
						for i = 1, cnt, numSpells do
							info.value = math.floor(i / numSpells) + 1
							info.text = L["마법책 - "]..info.value
							L_UIDropDownMenu_AddButton(info, level)
						end
					else
						info.text = L["마법책"]
						info.value = 1
						L_UIDropDownMenu_AddButton(info, level)
					end
				end

				info.text = hasPetSpell()
				if info.text then
					info.value = "pet"
					L_UIDropDownMenu_AddButton(info, level)
				end
				info.text = hasGuildSpell()
				if info.text then
					info.value = "guild"
					L_UIDropDownMenu_AddButton(info, level)
				end
				start, last = GetNumMacros()
				if start > 20 then
					local n = ceil(start / 20)
					for i = 1, n do
						info.text = GENERAL_MACROS.." - "..i
						info.value = "macro_general"..i
						L_UIDropDownMenu_AddButton(info, level)
					end
				elseif start > 0 then
					info.text = GENERAL_MACROS
					info.value = "macro_general"
					L_UIDropDownMenu_AddButton(info, level)
				end
				if last > 0 then
					info.text = CHARACTER_SPECIFIC_MACROS:format(CHARACTER)
					info.value = "macro_character"
					L_UIDropDownMenu_AddButton(info, level)
				end
				if self.button ~= 1 and self.button ~= 2 then
					info.func, info.hasArrow = dropDownOnClick
					info.text, info.arg1, info.arg2 = NONE
					info.checked = self.arg1 == info.arg1 and self.arg2 == info.arg2
					L_UIDropDownMenu_AddButton(info, level)
				end
			elseif level == 2 then
				if type(L_UIDropDownMenu_MENU_VALUE) == "number" then
					wipe(spellBooks)
					name, _, start, last = GetSpellTabInfo(1)
					if name then
						for i = start + 1, start + last do
							info.text = getSpellName(GetSpellBookItemName(i, BOOKTYPE_SPELL))
							if checkSpell(info.text, i, BOOKTYPE_SPELL) then
								table.insert(spellBooks, i)
							end
						end
					end
					name, _, start, last = GetSpellTabInfo(2)
					if name then
						for i = start + 1, start + last do
							info.text = getSpellName(GetSpellBookItemName(i, BOOKTYPE_SPELL))
							if checkSpell(info.text, i, BOOKTYPE_SPELL) then
								table.insert(spellBooks, i)
							end
						end
					end
					if spellBooks[1] then
						start = (L_UIDropDownMenu_MENU_VALUE - 1) * numSpells + 1
						last = L_UIDropDownMenu_MENU_VALUE * numSpells
						for i = start, last do
							if spellBooks[i] then
								info.text = getSpellName(GetSpellBookItemName(spellBooks[i], BOOKTYPE_SPELL))
								info.arg1, info.arg2 = "spell", info.text
								info.checked = self.arg1 == info.arg1 and (self.arg2 == info.arg2 or self.arg2 == getOverriddenSpell(info.arg2) or checkOverride(info.arg2, self.arg2))
								info.icon = GetSpellBookItemTexture(spellBooks[i], BOOKTYPE_SPELL)
								L_UIDropDownMenu_AddButton(info, level)
							end
						end
						wipe(spellBooks)
					end
				elseif L_UIDropDownMenu_MENU_VALUE == "pet" then
					for i = 1, HasPetSpells() or 0 do
						info.text = getSpellName(GetSpellBookItemName(i, BOOKTYPE_PET))
						if checkSpell(info.text, i, BOOKTYPE_PET) then
							info.arg1, info.arg2 = "spell", info.text
							info.checked = self.arg1 == info.arg1 and self.arg2 == info.arg2
							info.icon = GetSpellBookItemTexture(i, BOOKTYPE_PET)
							L_UIDropDownMenu_AddButton(info, level)
						end
					end
				elseif L_UIDropDownMenu_MENU_VALUE == "guild" then

				elseif type(L_UIDropDownMenu_MENU_VALUE) == "string" and L_UIDropDownMenu_MENU_VALUE:find("^macro_") then
					if L_UIDropDownMenu_MENU_VALUE == "macro_general" then
						start, last = 1, GetNumMacros()
					elseif L_UIDropDownMenu_MENU_VALUE == "macro_character" then
						start = (MAX_ACCOUNT_MACROS or 120) + 1
						last = start + select(2, GetNumMacros()) - 1
					elseif L_UIDropDownMenu_MENU_VALUE:find("^macro_general%d+$") then
						local n = (tonumber(L_UIDropDownMenu_MENU_VALUE:match("^macro_general(%d+)$")) or 0) - 1
						start = n * 20 + 1
						last = min(start + 19, (GetNumMacros()))
					else
						start, last = 0, 0
					end
					for i = start, last do
						info.text, info.icon = GetMacroInfo(i)
						info.arg1, info.arg2 = "macro", info.text
						info.checked = self.arg1 == info.arg1 and self.arg2 == info.arg2
						L_UIDropDownMenu_AddButton(info, level)
					end
				end
			end
		end
	end

	L_UIDropDownMenu_Initialize(dropdown, dropDownInitialize)

	menu.clickKeys = CreateFrame("Frame", nil, parent)
	menu.clickKeys:SetBackdrop(menu.buttons:GetBackdrop())
	menu.clickKeys:SetBackdropBorderColor(menu.buttons:GetBackdropBorderColor())
	menu.clickKeys:SetPoint("TOPLEFT", menu.buttons, "TOPRIGHT", 0, 0)
	menu.clickKeys:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -6, 6)
	local modifilters = { "", "alt-", "ctrl-", "shift-", "alt-ctrl-", "alt-shift-", "ctrl-shift-" }
	local modifilterNames = { "click", "Alt + click", "Ctrl + click", "Shift + click", "Alt + Ctrl + click", "Alt + Shift + click", "Ctrl + Shift + click" }
	local function getKeyValue(modifilter)
		modifilter = modifilter..buttonNames[menu.buttons:GetValue()].id
		if lime.ccdb[modifilter] == "target" then
			modifilter = L["대상 선택"]
		elseif lime.ccdb[modifilter] == "menu" then
			modifilter = L["메뉴"]
		elseif lime.ccdb[modifilter] and lime.ccdb[modifilter]:find("(.+)__(.+)") then
			modifilter = select(2, lime.ccdb[modifilter]:match("(.+)__(.+)"))
			if modifilter == inspectMacro then
				modifilter = INSPECT
			elseif modifilter == followMacro then
				modifilter = FOLLOW
			elseif modifilter == assistMacro then
				modifilter = BINDING_NAME_ASSISTTARGET
			elseif modifilter == focusMacro then
				modifilter = SET_FOCUS
			elseif modifilter == whisperMacro then
				modifilter = WHISPER
			elseif modifilter == tradeMacro then
				modifilter = TRADE
			end
		elseif buttonNames[menu.buttons:GetValue()].id == 1 then
			modifilter = L["대상 선택"]
			return L["대상 선택"], buttonNames
		elseif buttonNames[menu.buttons:GetValue()].id == 2 then
			modifilter = L["메뉴"]
		else
			modifilter = L["없음"]
		end
		return modifilter, buttonNames
	end

	local function modKeyOnClick(self)
		dropdown.modifilter, dropdown.button = self.modifilter, buttonNames[menu.buttons:GetValue()].id
		dropdown.set = lime.ccdb[dropdown.modifilter..dropdown.button]
		if dropdown.set == "target" or dropdown.set == "menu" then
			dropdown.arg1, dropdown.arg2 = dropdown.set
		elseif dropdown.set and dropdown.set:find("(.+)__(.+)") then
			dropdown.arg1, dropdown.arg2 = dropdown.set:match("(.+)__(.+)")
		elseif dropdown.button == 1 then
			dropdown.arg1, dropdown.arg2 = "target"
		elseif dropdown.button == 2 then
			dropdown.arg1, dropdown.arg2 = "menu"
		else
			dropdown.arg1, dropdown.arg2 = nil
		end
		dropdown.parent = self:GetParent()
		ToggleDropDownMenu(1, nil, dropdown, self, 0, 0)
	end

	for i, name in ipairs(modifilterNames) do
		menu.clickKeys["mod"..i] = LBO:CreateWidget("DropDown", menu.clickKeys, name, nil, nil, nil, true, getKeyValue, nil, modifilters[i])
		menu.clickKeys["mod"..i]:SetPoint("TOP", menu.clickKeys["mod"..(i - 1)], "BOTTOM", 0, -1)
		menu.clickKeys["mod"..i].button:SetScript("OnClick", modKeyOnClick)
		menu.clickKeys["mod"..i].button.modifilter = modifilters[i]
	end
	menu.clickKeys.mod1:ClearAllPoints()
	menu.clickKeys.mod1:SetPoint("TOP", menu.clickKeys, "TOP", 0, -5)

	self.talentGroup = menu.talentGroup
	self.clickKeys = menu.clickKeys

	self:UpdateClickCasting()
end

function Option:UpdateClickCasting()
	if Option.talentGroup and Option.clickKeys then
		Option.talentGroup:SetFormattedText(L["특성: %s"], select(2, GetSpecializationInfo(GetSpecialization())))
		if Option.clickKeys:IsVisible() then
			CloseDropDownMenus(1)
			LBO:Refresh(Option.clickKeys)
		end
	end
end