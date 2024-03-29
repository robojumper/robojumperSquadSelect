//---------------------------------------------------------------------------------------
//  FILE:   X2DownloadableContentInfo_robojumperSquadSelect.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_robojumperSquadSelect extends X2DownloadableContentInfo;

// if (for any reason) the built in squad size patch causes issues, turn it off here
var config bool bDontTouchSquadSize;

var config bool bDontTouchAttachmentGraphics;

struct NewAttachmentIcon
{
	var name TemplateName;
	var string strIcon;	
};

var config array<NewAttachmentIcon> NewIcons;

struct ModUsesUpgradeSlot
{
	var name DLCName;
	var name ItemCat;
	var name WeaponCat;
};

var config array<ModUsesUpgradeSlot> ShowUpgradesWhenModIsInstalled;

/// <summary>
/// Called after the Templates have been created (but before they are validated) while this DLC / Mod is installed.
/// </summary>
static event OnPostTemplatesCreated()
{
	class'robojumper_SquadSelectConfig'.static.Initialize();
	PatchSquadSize();
	ChangeAttachmentGraphics();
	AllowUpgradesWhenModIsInstalled();
}

static function PatchSquadSize()
{
	if (!default.bDontTouchSquadSize)
	{
		class'X2StrategyGameRulesetDataStructures'.default.m_iMaxSoldiersOnMission = class'robojumper_SquadSelectConfig'.static.GetSquadSize();
	}
	else
	{
		`log("RJSS: Not touching squad size because third-party mod wants to handle squad size itself");
	}
}

static function ChangeAttachmentGraphics()
{
	local X2ItemTemplateManager Mgr;
	local array<X2DataTemplate> DifficultyVariants;
	local X2WeaponUpgradeTemplate Template;
	local int i, j, k;

	if (default.bDontTouchAttachmentGraphics) return;

	Mgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	
	for (i = 0; i < default.NewIcons.Length; i++)
	{
		DifficultyVariants.Length = 0;
		Mgr.FindDataTemplateAllDifficulties(default.NewIcons[i].TemplateName, DifficultyVariants);
		for (j = 0; j < DifficultyVariants.Length; j++)
		{
			Template = X2WeaponUpgradeTemplate(DifficultyVariants[j]);
			for (k = 0; k < Template.UpgradeAttachments.Length; k++)
			{
				Template.UpgradeAttachments[k].InventoryCategoryIcon = default.NewIcons[i].strIcon;
			}
		}
	}
}

static function AllowUpgradesWhenModIsInstalled()
{
	local robojumper_SquadSelect_Helpers HelpersObj;
	local ModUsesUpgradeSlot Entry;

	HelpersObj = robojumper_SquadSelect_Helpers(class'XComEngine'.static.GetClassDefaultObject(class'robojumper_SquadSelect_Helpers'));

	foreach default.ShowUpgradesWhenModIsInstalled(Entry)
	{
		if (IsDLCNameEnabled(Entry.DLCName))
		{
			if (Entry.ItemCat != '')
			{
				HelpersObj.UpgradeableItemCats.AddItem(Entry.ItemCat);
			}

			if (Entry.WeaponCat != '')
			{
				HelpersObj.UpgradeableWeaponCats.AddItem(Entry.WeaponCat);
			}
		}
	}
}

static function bool IsDLCNameEnabled(name TargetDLCName)
{
	local int i;
	local name DLCName;
	local XComOnlineEventMgr Mgr;

	Mgr = `ONLINEEVENTMGR;

	for (i = Mgr.GetNumDLC() - 1; i >= 0; i--)
	{
		DLCName = Mgr.GetDLCNames(i);
		if (DLCName == TargetDLCName)
		{
			return true;
		}
	}

	return false;
}

exec function PushControllerMap()
{
	local UIScreen TempScreen;
	local XComPresentationLayerBase Pres;
	Pres = `PRESBASE;

	if (Pres.ScreenStack.IsNotInStack(class'robojumper_SquadSelectControllerMap'))
	{
		TempScreen = Pres.Spawn(class'robojumper_SquadSelectControllerMap', Pres);
		Pres.ScreenStack.Push(TempScreen, Pres.Get2DMovie());
	}
}

exec function LogCameraTPOV()
{
	local TPOV CamTPOV;
	CamTPOV = class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().PlayerCamera.CameraCache.POV;
	`log(`showvar(CamTPOV.Location.X));
	`log(`showvar(CamTPOV.Location.Y));
	`log(`showvar(CamTPOV.Location.Z));
	`log(`showvar(CamTPOV.Rotation.Pitch));
	`log(`showvar(CamTPOV.Rotation.Roll));
	`log(`showvar(CamTPOV.Rotation.Yaw));
}

exec function FinalMissionSkipCutscenes()
{
	local robojumper_UISquadSelect SquadScreen;

	SquadScreen = robojumper_UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'robojumper_UISquadSelect'));
	if (SquadScreen != none)
		SquadScreen.bSkipFinalMissionCutscenes = !SquadScreen.bSkipFinalMissionCutscenes;
}

exec function NukeSquad()
{
	local XComGameState NewGameState;
	local XComGameState_HeadquartersXCom XComHQ;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Clear Squad");
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', `XCOMHQ.ObjectID));
	XComHQ.Squad.Length = 0;
	XComHQ.AllSquads.Length = 0;
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);	
}
