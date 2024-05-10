--[[--------------------------------------------------------------
Disenchant Crafted Items
by Sunsequent

A button in profession window for fast disenchanting of crafted
items without the need to target them in bags.

Version 2.3.2
Release Date 13.07.2023
--------------------------------------------------------------]]
--

--[[ CHANGELOG ]]
--[[
Version 2.3.2
- Update and fixes for patch 10.1.5

Version 2.3.1
- Fix for button occasionally not being displayed

Version 2.3.0
- Update for patch 10.1
- Fix button position
- Faster auto looting of disenchanted materials
- Add icon for addon

Version 2.2.2
- Restore functionality to use the button from Guild Profession Window and from Linked Profession Window to disenchant items from professions which are not learned on current character
- Button now also appears in Enchanting Window allowing to disenchant Wands
- Additional bugfixes

Version 2.2.1
- Ignore Cosmetic items

Version 2.2.0
- Updated for Dragonflight
]]
--
-- Configuration Parameters
local ignoreSoulbound = true;

-- Variables
local selectedItemID;
local numberOfItems = 0;
local itemLocations = {};
local disenchantCasting = false;
local itemLocked = false;
local lootOpen = false;
local locationDisenchantStarted;
local previousItemBagSlot;


-- Localization
local locale;
local disenchantName;
local tailoringName;
local leatherworkingName;
local blacksmithingName;
local jewelcraftingName;
local engineeringName;
local inscriptionName;
local professionsForButton;
local itemCountText;
local buttonWidth;
local buttonLocX;

SLASH_DISENCHANTCRAFTEDITEMS1, SLASH_DISENCHANTCRAFTEDITEMS2 = "/disenchantcrafteditems", "/dci";

_G["BINDING_HEADER_DISENCHANTCRAFTEDITEMS"] = "Disenchant Crafted Items";

function SlashCmdList.DISENCHANTCRAFTEDITEMS(msg, editbox)
	if msg == "soulbound" then
		if ignoreSoulbound then
			ignoreSoulbound = false;
			DCI_IgnoreSoulbound = ignoreSoulbound;

			print("Soulbound crafted items are included in disenchanting.");
		else
			ignoreSoulbound = true;
			DCI_IgnoreSoulbound = ignoreSoulbound;

			print("Soulbound crafted items are excluded from disenchanting.");
		end

		return;
	end

	if msg == "status" then
		if not ignoreSoulbound then
			print("Soulbound crafted items are included in disenchanting.");
		else
			print("Soulbound crafted items are excluded from disenchanting.");
		end

		return;
	end

	print("Disenchant Crafted Items (also /dci) commands:");
	print("/disenchantcrafteditems soulbound");
	print("/disenchantcrafteditems status");
end

local function SetLocalization()
	-- Localization:
	-- enUS Items in backpack			Disenchant
	-- deDE Gegenstände im Rucksack		Entzaubern
	-- esES Artículos en la mochila		Desencantar
	-- esMX Artículos en la mochila		Desencantar
	-- frFR Articles dans le sac à dos	Désenchanter
	-- itIT Oggetti nello zaino			Disincantamento
	-- koKR 배낭에있는 물건들			마력 추출
	-- ptBR Itens na mochila			Desencantar
	-- ruRU Предметы в рюкзаке			Распыление
	-- zhCN 背包里的物品					分解
	-- zhTW 背包里的物品					分解

	locale = GetLocale();

	disenchantName = GetSpellInfo(13262);
	tailoringName = GetSpellInfo(3908);
	leatherworkingName = GetSpellInfo(2108);
	blacksmithingName = GetSpellInfo(2018);
	jewelcraftingName = GetSpellInfo(25229);
	engineeringName = GetSpellInfo(4036);
	inscriptionName = GetSpellInfo(45357);
	enchantingName = GetSpellInfo(7412);
	professionsForButton = { tailoringName, leatherworkingName, blacksmithingName, jewelcraftingName, engineeringName,
		inscriptionName, enchantingName };

	_G["BINDING_NAME_CLICK DisenchantCraftedItemsButton:LeftButton"] = disenchantName .. " Button";

	buttonWidth = 100;
	buttonLocX = -17;

	if locale == "enUS" then
		itemCountText = "Items in backpack";
	elseif locale == "deDE" then
		itemCountText = "Gegenstände im Rucksack";
	elseif locale == "esES" then
		itemCountText = "Artículos en la mochila";
	elseif locale == "esMX" then
		itemCountText = "Artículos en la mochila";
	elseif locale == "frFR" then
		itemCountText = "Articles dans le sac à dos";
	elseif locale == "itIT" then
		itemCountText = "Oggetti nello zaino";
		buttonWidth = buttonWidth + 30;
		buttonLocX = buttonLocX - 30;
	elseif locale == "koKR" then
		itemCountText = "배낭에있는 물건들";
	elseif locale == "ptBR" then
		itemCountText = "Itens na mochila";
	elseif locale == "ruRU" then
		itemCountText = "Предметы в рюкзаке";
	elseif locale == "zhCN" then
		itemCountText = "背包里的物品";
	elseif locale == "zhTW" then
		itemCountText = "背包里的物品";
	end
end

local function StringSplit(inputString, separator)
	if not separator then
		separator = "%s";
	end

	local splitTable = {};
	local splitCounter = 1;

	for str in string.gmatch(inputString, "([^" .. separator .. "]+)") do
		splitTable[splitCounter] = str;
		splitCounter = splitCounter + 1;
	end

	return splitTable;
end

local soulboundTooltip = CreateFrame("GameTooltip", "CheckSoulboundTooltip", nil, "GameTooltipTemplate");

local function IsSoulbound(bag, slot)
	soulboundTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	soulboundTooltip:SetBagItem(bag, slot);
	soulboundTooltip:Show();

	for i = 1, soulboundTooltip:NumLines() do
		if _G["CheckSoulboundTooltipTextLeft" .. i]:GetText() == ITEM_SOULBOUND then
			soulboundTooltip:Hide();
			return true;
		end
	end

	soulboundTooltip:Hide()
	return false
end

local function IsDisenchantable(itemID)
	if IsSpellKnown(13262) then
		if itemID then
			local _, _, quality, _, _, _, itemSubType, _, _, _, _, class, subClass = GetItemInfo(tonumber(itemID))

			if ((class == 2 and subClass ~= 14) or class == 4 or class == 19 or (class == 3 and subClass == 11)) and itemSubType ~= "Cosmetic" then
				if quality > 1 and quality < 5 then
					return true;
				end
			end
		end
	end

	return false;
end

local function GetBagItemList(selectedItemID)
	itemLocations = {};
	local itemCounter = 0;

	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			itemID = C_Container.GetContainerItemID(bag, slot)

			if tonumber(itemID) == tonumber(selectedItemID) then
				if not IsSoulbound(bag, slot) then
					if IsDisenchantable(selectedItemID) then
						itemCounter = itemCounter + 1;
						itemLocations[itemCounter] = bag .. " " .. slot;
					end
				else
					if not ignoreSoulbound then
						if IsDisenchantable(selectedItemID) then
							itemCounter = itemCounter + 1;
							itemLocations[itemCounter] = bag .. " " .. slot;
						end
					end
				end
			end
		end
	end

	return itemCounter;
end

local button = CreateFrame("Button", "DisenchantAllCraftedItemsButton", UIParent, "SecureActionButtonTemplate");
local frameItemCount = CreateFrame("Frame", "DisenchantCraftedItemsCount");
local frameStateTracker = CreateFrame("Frame", "DisenchantCraftedItemsStateTracker");
local function CreateDCIFrames()
	frameItemCount:SetSize(250, 25);
	frameItemCount.text = frameItemCount.text or frameItemCount:CreateFontString(nil, "OVERLAY", "GameFontNormal"); --GameFontNormal GameFontNormalLarge GameFontHighlight
	frameItemCount.text:SetAllPoints(true);
	frameItemCount.text:SetJustifyH("LEFT");
	frameItemCount.text:SetJustifyV("TOP");
	frameItemCount.text:SetTextColor(1, 0.8046, 0, 1); --1,0.8046,0,1  1,0.84,0,1

	button:SetSize(buttonWidth, 22);                --Width, Height
	button:SetText(disenchantName);
	button:SetNormalFontObject("GameFontNormal");
	button:SetDisabledFontObject("GameFontDisable")
	local ntex = button:CreateTexture();
	ntex:SetTexture("Interface/Buttons/UI-Panel-Button-Up");
	ntex:SetTexCoord(0, 0.625, 0, 0.6875);
	ntex:SetAllPoints();
	button:SetNormalTexture(ntex);

	local htex = button:CreateTexture();
	htex:SetTexture("Interface/Buttons/UI-Panel-Button-Highlight");
	htex:SetTexCoord(0, 0.625, 0, 0.6875);
	htex:SetAllPoints();
	button:SetHighlightTexture(htex);

	local ptex = button:CreateTexture();
	ptex:SetTexture("Interface/Buttons/UI-Panel-Button-Down");
	ptex:SetTexCoord(0, 0.625, 0, 0.6875);
	ptex:SetAllPoints();
	button:SetPushedTexture(ptex);

	local dtex = button:CreateTexture();
	dtex:SetTexture("Interface/Buttons/UI-Panel-Button-Disabled");
	dtex:SetTexCoord(0, 0.625, 0, 0.6875);
	dtex:SetAllPoints();
	button:SetDisabledTexture(dtex);
end

local function UpdateDCIState(event, ...)
	--print("|cFF30A0A0UpdateDCIFrames: |r" .. event);
	if event == "UNIT_SPELLCAST_START" then
		local unit, spellName, spellID = select(1, ...)

		if unit == "player" and spellID == 13262 then
			disenchantCasting = true;
		end
	end

	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, spellName, spellID = select(1, ...)

		if unit == "player" and spellID == 13262 then
			locationDisenchantStarted = itemLocations[1];
		end
	end

	if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		local unit, spellName, spellID = select(1, ...)

		if unit == "player" and spellID == 13262 then
			disenchantCasting = false;
		end
	end

	if event == "ITEM_LOCKED" then
		local bag, slot = select(1, ...)

		if bag and slot then
			if itemLocations[1] == bag .. " " .. slot then
				itemLocked = true;
			end
		end
	end

	if event == "ITEM_UNLOCKED" then
		local bag, slot = select(1, ...)

		if bag and slot then
			if itemLocations[1] == bag .. " " .. slot then
				itemLocked = false;
			end
		else
			itemLocked = false;
		end
	end
end
local function HideDCIFrames()
	locationDisenchantStarted = nil;
	disenchantCasting = false;
	lootOpen = false;
	itemLocked = false;

	frameItemCount:Hide();
	button:Hide();
	button:SetAttribute("type", ATTRIBUTE_NOOP);
	button:SetAttribute("spell", ATTRIBUTE_NOOP);
	button:SetAttribute("target-bag", ATTRIBUTE_NOOP);
	button:SetAttribute("target-item", ATTRIBUTE_NOOP);
end

local function UpdateDCIFrames(event, ...)
	local openedProfession = ProfessionsFrameTitleText:GetText();
	local isCraftingProfession = false;
	for key, value in pairs(professionsForButton) do
		if openedProfession and openedProfession:find(value) then
			isCraftingProfession = true;
			break;
		end
	end

	if not isCraftingProfession then
		HideDCIFrames()
		return
	end

	local isGuildProfessionFrame = C_TradeSkillUI.IsTradeSkillGuild();
	local isLinkedProfessionFrame = C_TradeSkillUI.IsTradeSkillLinked();

	frameItemCount:ClearAllPoints();
	button:ClearAllPoints();

	if not isGuildProfessionFrame and not isLinkedProfessionFrame then
		frameItemCount:SetParent(ProfessionsFrame.CraftingPage.CreateButton);
		frameItemCount:SetPoint("TOPLEFT", ProfessionsFrame.CraftingPage.CreateButton, "TOPLEFT", buttonLocX - 185,
			25);
		button:SetParent(ProfessionsFrame.CraftingPage.CreateButton);
		button:SetPoint("TOPLEFT", ProfessionsFrame.CraftingPage.CreateButton, "TOPLEFT", buttonLocX, 29);
	elseif isGuildProfessionFrame then
		frameItemCount:SetParent(ProfessionsFrame.CraftingPage.ViewGuildCraftersButton);
		frameItemCount:SetPoint("TOPLEFT", ProfessionsFrame.CraftingPage.ViewGuildCraftersButton, "TOPLEFT",
			buttonLocX - 120, 25);
		button:SetParent(ProfessionsFrame.CraftingPage.ViewGuildCraftersButton);
		button:SetPoint("TOPLEFT", ProfessionsFrame.CraftingPage.ViewGuildCraftersButton, "TOPLEFT", buttonLocX + 50,
			29);
	elseif isLinkedProfessionFrame then
		frameItemCount:SetParent(ProfessionsFrame.CraftingPage.SchematicForm);
		frameItemCount:SetPoint("TOPLEFT", ProfessionsFrame.CraftingPage.SchematicForm, "BOTTOMRIGHT",
			buttonLocX - 260, 22);
		button:SetParent(ProfessionsFrame.CraftingPage.SchematicForm);
		button:SetPoint("TOPLEFT", ProfessionsFrame.CraftingPage.SchematicForm, "BOTTOMRIGHT", buttonLocX - 83, 24);
	end

	local recipeID;

	if ProfessionsFrame.CraftingPage.SchematicForm and ProfessionsFrame.CraftingPage.SchematicForm.currentRecipeInfo then
		recipeID = ProfessionsFrame.CraftingPage.SchematicForm.currentRecipeInfo.recipeID;
	end
	if not recipeID then
		HideDCIFrames()
		return
	end
	local itemLink = C_TradeSkillUI.GetRecipeItemLink(recipeID);

	if itemLink == nil then
		HideDCIFrames()
		return
	end
	selectedItemID = select(3, strfind(itemLink, "item:(%d+)"))

	if not selectedItemID then
		HideDCIFrames()
		return
	end
	--print("|cFFA03030UpdateDCIFrames: |r" .. event);
	numberOfItems = GetBagItemList(selectedItemID);
	if numberOfItems <= 0 then
		HideDCIFrames()
	end

	frameItemCount.text:SetText(itemCountText .. ": " .. numberOfItems);
	if previousItemBagSlot ~= itemLocations[1] then
		previousItemBagSlot = itemLocations[1];
		locationDisenchantStarted = nil;
		disenchantCasting = false;
		itemLocked = false;
	end
	local spell = nil;
	local bagID = nil;
	local slotID = nil;

	if not disenchantCasting and
		not lootOpen and
		not itemLocked and
		(not locationDisenchantStarted or locationDisenchantStarted ~= itemLocations[1]) then
		if itemLocations[1] then
			spell = disenchantName;
			bagID = StringSplit(itemLocations[1], nil)[1];
			slotID = StringSplit(itemLocations[1], nil)[2];
		end
	end

	if not disenchantCasting and not lootOpen and not itemLocked and locationDisenchantStarted == itemLocations[1] then
		if itemLocations[2] then
			spell = disenchantName;
			bagID = StringSplit(itemLocations[2], nil)[1];
			slotID = StringSplit(itemLocations[2], nil)[2];
		end
	end

	if itemLocations[1] then
		frameItemCount:Show();
		button:SetAttribute("type", "spell");
		button:SetAttribute("spell", spell);
		button:SetAttribute("target-bag", bagID);
		button:SetAttribute("target-slot", slotID);
		button:Show();
		return;
	end

	HideDCIFrames();
end

local f = CreateFrame("Frame", "DisenchantCraftedItemsEventFrame")
f:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		loadedAddon = select(1, ...);

		if loadedAddon == "DisenchantCraftedItems" then
			if not DCI_IgnoreSoulbound then
				DCI_IgnoreSoulbound = ignoreSoulbound;
			else
				ignoreSoulbound = DCI_IgnoreSoulbound;
			end

			SetLocalization();
		elseif loadedAddon == "Blizzard_Professions" then
			CreateDCIFrames();
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		frameItemCount:Hide();
	elseif event == "PLAYER_REGEN_ENABLED" and ProfessionsFrame then
		if ProfessionsFrame:IsShown() then
			UpdateDCIFrames(event, ...);
		else
			HideDCIFrames();
		end
	end
end)
f:RegisterEvent("ADDON_LOADED");
f:RegisterEvent("PLAYER_REGEN_DISABLED");
f:RegisterEvent("PLAYER_REGEN_ENABLED");

local lastUpdate = time()
frameItemCount:SetScript("OnEvent", function(self, event, ...)
	local shouldUpdate = difftime(time(), lastUpdate) > 0.25

	-- print("|cFFAE00AEShould update?|r " .. tostring(shouldUpdate));
	if shouldUpdate and not InCombatLockdown() and ProfessionsFrame then
		if ProfessionsFrame:IsShown() then
			lastUpdate = time()
			UpdateDCIFrames(event, ...);
		else
			HideDCIFrames();
		end
	end
end)

frameStateTracker:SetScript("OnEvent", function(self, event, ...)
	UpdateDCIState(event, ...)
end)
frameItemCount:RegisterEvent("BAG_UPDATE");
frameItemCount:RegisterEvent("SPELL_DATA_LOAD_RESULT");

frameStateTracker:RegisterEvent("ITEM_LOCKED");
frameStateTracker:RegisterEvent("ITEM_UNLOCKED");
frameStateTracker:RegisterUnitEvent("UNIT_SPELLCAST_START", "player");
frameStateTracker:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player");
frameStateTracker:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player");
frameStateTracker:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player");
