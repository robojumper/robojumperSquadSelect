class robojumper_SquadSelect_Helpers extends Object config(robojumperSquadSelect);

var config array<name> UpgradeableItemCats;
var config array<name> UpgradeableWeaponCats;


static function GetCurrentAndMaxStatForUnit(XComGameState_Unit UnitState, ECharStatType Stat, out int CurrStat, out int MaxStat)
{
	CurrStat = UnitState.GetCurrentStat(Stat) + UnitState.GetUIStatFromInventory(Stat) + UnitState.GetUIStatFromAbilities(Stat);
	MaxStat = UnitState.GetMaxStat(Stat) + UnitState.GetUIStatFromInventory(Stat) + UnitState.GetUIStatFromAbilities(Stat);
}

static function bool UnitParticipatesInWillSystem(XComGameState_Unit UnitState)
{
	return UnitState.UsesWillSystem();
}

static function GetSoldierAndGlobalAP(XComGameState_Unit UnitState, out int iSoldierAP, out int iGlobalAP)
{
	iSoldierAP = UnitState.AbilityPoints;
	iGlobalAP = `XCOMHQ.GetAbilityPoints();
}

static function bool CanHaveWeaponUpgrades(XComGameState_Item ItemState)
{
	local X2EquipmentTemplate Template;
	local X2WeaponTemplate WeaponTemplate;

	// Weapon upgrades are enabled by research
	if (!`XCOMHQ.bModularWeapons)
	{
		return false;
	}

	// this is not checked in UIArmory_WeaponUpgrade but in UIArmory_MainMenu essentially (via UIUtilities_Strategy.GetWeaponUpgradeAvailability())
	if (GetBaseNumUpgradeSlots(ItemState) <= 0)
	{
		return false;
	}

	// Primary weapons support them, but the user can choose to see them on all weapons
	if (ItemState.InventorySlot == eInvSlot_PrimaryWeapon || !class'robojumper_SquadSelectConfig'.static.DontShowSecondaryUpgradeIconsAvailable())
	{
		return true;
	}

	// otherwise, mods can request that their stuff always be shown with upgrade slots
	Template = X2EquipmentTemplate(ItemState.GetMyTemplate());
	if (Template != none && default.UpgradeableItemCats.Find(Template.ItemCat) != INDEX_NONE)
	{
		return true;
	}

	WeaponTemplate = X2WeaponTemplate(Template);
	if (WeaponTemplate != none && default.UpgradeableWeaponCats.Find(WeaponTemplate.WeaponCat) != INDEX_NONE)
	{
		return true;
	}

	return false;
}

// keep in sync with UIArmory_WeaponUpgrade.UpdateSlots(). Thanks Firaxis
static function int GetBaseNumUpgradeSlots(XComGameState_Item ItemState)
{
	if (class'robojumper_SquadSelectConfig'.static.IsCHHLMinVersionInstalled(1, 22))
	{
		return ItemState.GetNumUpgradeSlots();
	}
	else if (X2WeaponTemplate(ItemState.GetMyTemplate()) != none)
	{
		return X2WeaponTemplate(ItemState.GetMyTemplate()).NumUpgradeSlots;
	}
	else
	{
		return 0;
	}
}