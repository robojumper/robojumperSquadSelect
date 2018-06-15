class robojumper_SquadSelectConfig extends Object config(robojumperSquadSelect_NullConfig);

`define DEFOBJ robojumper_SquadSelectConfig(class'Engine'.static.FindClassDefaultObject("robojumperSquadSelect.robojumper_SquadSelectConfig"))

var config bool bShowWeaponUpgradeIcons, bSkipSecondaryUpgradeIconsAvailable, bShowBGImages, bShowMeTheSkills, bSkipInitialAbilities, bAutofillSquad, bShowStats, bDisallowInfiniteScrolling;

`if(`isdefined(WITH_WOTC))
var config bool bHideTrainingCenterButton;
`endif

var config int iSquadSize;
var config int iVersion;

var bool bShowWeaponUpgradeIcons_def, bSkipSecondaryUpgradeIconsAvailable_def, bShowBGImages_def, bShowMeTheSkills_def, bSkipInitialAbilities_def, bAutofillSquad_def, bShowStats_def, bDisallowInfiniteScrolling_def;
`if(`isdefined(WITH_WOTC))
var bool bHideTrainingCenterButton_def;
`endif

var int iVersion_def;

static function Initialize()
{
	local robojumper_SquadSelectConfig DefaultObj;
	DefaultObj = `DEFOBJ;

	if (default.iVersion_def > default.iVersion)	
	{
		DefaultObj.iVersion = default.iVersion_def;
		DefaultObj.bShowWeaponUpgradeIcons = default.bShowWeaponUpgradeIcons_def;
		DefaultObj.bSkipSecondaryUpgradeIconsAvailable = default.bSkipSecondaryUpgradeIconsAvailable_def;
		DefaultObj.bShowBGImages = default.bShowBGImages_def;
		DefaultObj.bShowMeTheSkills = default.bShowMeTheSkills_def;
		DefaultObj.bSkipInitialAbilities = default.bSkipInitialAbilities_def;
		DefaultObj.bAutofillSquad = default.bAutofillSquad_def;
		DefaultObj.bShowStats = default.bShowStats_def;
		DefaultObj.bDisallowInfiniteScrolling = default.bDisallowInfiniteScrolling_def;
`if(`isdefined(WITH_WOTC))
		DefaultObj.bHideTrainingCenterButton = default.bHideTrainingCenterButton_def;
`endif
		// messes with LW2
		if (!class'X2DownloadableContentInfo_robojumperSquadSelect'.default.bDontTouchSquadSize)
		{
			DefaultObj.iSquadSize = class'X2StrategyGameRulesetDataStructures'.default.m_iMaxSoldiersOnMission;
		}
		StaticSaveConfig();
	}
	// we are allowed to change squad size and we haven't already read squad size from vanilla
	if (default.iSquadSize == 0 && !class'X2DownloadableContentInfo_robojumperSquadSelect'.default.bDontTouchSquadSize)
	{
		// so do it now. This prevents problems with squad size being 10 when starting to use this mod with LW2 and then going back to "vanilla"
		DefaultObj.iSquadSize = class'X2StrategyGameRulesetDataStructures'.default.m_iMaxSoldiersOnMission;
		StaticSaveConfig();
	}
}

static function robojumper_SquadSelectConfig GetDefObj()
{
	return `DEFOBJ;	
}

static function int GetSquadSize()
{
	return default.iSquadSize;
}

static function bool ShowWeaponUpgradeIcons()
{
	return default.bShowWeaponUpgradeIcons;
}

static function bool DontShowSecondaryUpgradeIconsAvailable()
{
	return default.bSkipSecondaryUpgradeIconsAvailable;
}

static function bool ShowBGImages()
{
	return default.bShowBGImages;	
}

static function bool ShowMeTheSkills()
{
	return default.bShowMeTheSkills;
}

static function bool DontShowInitialAbilities()
{
	return default.bSkipInitialAbilities;
}

static function bool ShouldAutoFillSquad()
{
	return default.bAutofillSquad;
}

static function bool ShouldShowStats()
{
	return default.bShowStats;
}

static function bool DisAllowInfiniteScrolling()
{
	return default.bDisallowInfiniteScrolling;
}

`if(`isdefined(WITH_WOTC))
static function bool HideTrainingCenterButton()
{
	return default.bHideTrainingCenterButton;	
}
`endif

`if(`notdefined(WITH_WOTC))
// this would normally check for CH, but since the features in LWHL are a subset of the CH, just check
// for LWHL
static function bool IsLWHLMinVersionInstalled(int iMajor, int iMinor)
{
	local X2StrategyElementTemplate VersionTemplate;

	VersionTemplate = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate('LWXComGameVersion');
	if (VersionTemplate == none)
	{
		return false;
	}
	else
	{
		// DANGER TERRITORY
		// if this runs without the LWHL or equivalent installed, it crashes
		return LWXComGameVersionTemplate(VersionTemplate).MajorVersion > iMajor ||  (LWXComGameVersionTemplate(VersionTemplate).MajorVersion == iMajor && LWXComGameVersionTemplate(VersionTemplate).MinorVersion >= iMinor);
	}
}
`endif


`if(`isdefined(WITH_WOTC))
static function bool IsCHHLMinVersionInstalled(int iMajor, int iMinor)
{
	local X2StrategyElementTemplate VersionTemplate;

	VersionTemplate = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate('CHXComGameVersion');
	if (VersionTemplate == none)
	{
		return false;
	}
	else
	{
		// DANGER TERRITORY
		// if this runs without the CHHL or equivalent installed, it crashes
		return CHXComGameVersionTemplate(VersionTemplate).MajorVersion > iMajor ||  (CHXComGameVersionTemplate(VersionTemplate).MajorVersion == iMajor && CHXComGameVersionTemplate(VersionTemplate).MinorVersion >= iMinor);
	}
}
`endif

defaultproperties
{
	bShowWeaponUpgradeIcons_def=true
	bSkipSecondaryUpgradeIconsAvailable_def=true
	bShowBGImages_def=true
	bShowMeTheSkills_def=true
	bSkipInitialAbilities_def=true
	bAutofillSquad_def=true
	bShowStats_def=false
	bDisallowInfiniteScrolling_def=false

`if(`isdefined(WITH_WOTC))
	bHideTrainingCenterButton_def=false
`endif

	iVersion_def=1
}