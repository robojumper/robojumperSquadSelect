// Notes on CreateStateObject, AddStateObject and ModifyStateObject
// The first two shouldn't be used anymore, but are still fully functional
// ModifyStateObject reduces the number of bugs that can be written
// however, for the sake of keeping this a version for both, I'm not going to change it for WotC
class robojumper_UISquadSelect extends UISquadSelect;

// scroll is amount of slots
var float fScroll; // fInterpCurr
var float fInterpCurrTime; // [0, INTERP_TIME]
var float fInterpStart, fInterpGoal;
var float INTERP_TIME;


struct SquadSelectInterpKeyframe
{
	var vector Location;
	var rotator Rotation;
};

var array<SquadSelectInterpKeyframe> Keyframes;

struct GremlinStruct
{
	var XComUnitPawn GremlinPawn;
	var vector LocOffset;
};

var array<GremlinStruct> GremlinPawns;
var Matrix TransformMatrix;
///////////////////////////////////////////
var bool bUpperView;
var string UIDisplayCam_Overview;
///////////////////////////////////////////
var SimpleShapeManager m_ShapeMgr;
///////////////////////////////////////////                                   
var robojumper_UIList_SquadEditor SquadList;
var robojumper_UIMouseGuard_SquadSelect MouseGuard;
var int iDefSlotY;
///////////////////////////////////////////
var bool bInfiniteScrollingDisallowed;
///////////////////////////////////////////
var localized string strSwitchPerspective;
var localized string strSwitchPerspectiveTooltip;

var localized string strUnequipSquad, strUnequipBarracks; // nav help
var localized string strUnequipSquadTooltip, strUnequipBarracksTooltip; // nav help tooltip
var localized string strUnequipSquadConfirm, strUnequipBarracksConfirm; // dialogue box title
var localized string strUnequipSquadWarning, strUnequipBarracksWarning; // dialogue box text
///////////////////////////////////////////
var bool bSkipFinalMissionCutscenes;
///////////////////////////////////////////
var bool bSkipDirty;



// Constructor
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local XComGameState NewGameState;
	local GeneratedMissionData MissionData;
	local XComGameState_MissionSite MissionState;
	local int listX, maxListWidth;
	local X2SitRepTemplate SitRepTemplate;
	local XComNarrativeMoment SitRepNarrative;

	super(UIScreen).InitScreen(InitController, InitMovie, InitName);

//	Navigator.HorizontalNavigation = true;
	bInfiniteScrollingDisallowed = class'robojumper_SquadSelectConfig'.static.DisAllowInfiniteScrolling();

	m_kMissionInfo = Spawn(class'UISquadSelectMissionInfo', self).InitMissionInfo();
	m_kPawnMgr = Spawn(class'UIPawnMgr', Owner);
	m_ShapeMgr = Spawn(class'SimpleShapeManager');

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
	MissionData = XComHQ.GetGeneratedMissionData(XComHQ.MissionRef.ObjectID);
	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));

	SoldierSlotCount = class'X2StrategyGameRulesetDataStructures'.static.GetMaxSoldiersAllowedOnMission(MissionState);
	MaxDisplayedSlots = SoldierSlotCount;
	SquadCount = MissionData.Mission.SquadCount;
	SquadMinimums = MissionData.Mission.SquadSizeMin;

	if (SquadCount == 0)
	{
		SquadCount = 1;
	}

	while (SquadMinimums.Length < SquadCount) // fill in minimums that don't exist with minimum's of 1
	{
		SquadMinimums.AddItem( 1 );
	}

	// Check for a SITREP template, used for possible narrative line
	if (MissionData.SitReps.Length > 0)
	{
		SitRepTemplate = class'X2SitRepTemplateManager'.static.GetSitRepTemplateManager().FindSitRepTemplate(MissionData.SitReps[0]);
		
		if (SitRepTemplate.DataName == 'TheHorde')
		{
			// Do not trigger a skulljack event on these missions, since no ADVENT will spawn
			bBlockSkulljackEvent = true;
		}
	}

	// Enter Squad Select Event
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Enter Squad Select Event Hook");
	`XEVENTMGR.TriggerEvent('EnterSquadSelect', , , NewGameState);
	if (IsRecoveryBoostAvailable())
	{
		`XEVENTMGR.TriggerEvent('OnRecoveryBoostSquadSelect', , , NewGameState);
	}

	if (MissionData.Mission.MissionName == 'LostAndAbandonedA')
	{
		`XEVENTMGR.TriggerEvent('OnLostAndAbandonedSquadSelect', , , NewGameState);
	}
	else if (MissionData.Mission.MissionName == 'ChosenAvengerDefense')
	{
		`XEVENTMGR.TriggerEvent('OnAvengerAssaultSquadSelect', , , NewGameState);
	}
	else if (SitRepTemplate != none && SitRepTemplate.SquadSelectNarrative != "" && !MissionState.bHasPlayedSITREPNarrative)
	{
		SitRepNarrative = XComNarrativeMoment(`CONTENT.RequestGameArchetype(SitRepTemplate.SquadSelectNarrative));
		if (SitRepNarrative != None)
		{
			`HQPRES.UINarrative(SitRepNarrative);
		}

		MissionState = XComGameState_MissionSite(NewGameState.ModifyStateObject(class'XComGameState_MissionSite', MissionState.ObjectID));
		MissionState.bHasPlayedSITREPNarrative = true;
	}
	else if (SoldierSlotCount <= 3)
	{
		`XEVENTMGR.TriggerEvent('OnSizeLimitedSquadSelect', , , NewGameState);
	}
	else if (SoldierSlotCount > 5 && SquadCount > 1)
	{
		`XEVENTMGR.TriggerEvent('OnSuperSizeSquadSelect', , , NewGameState);
	}
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState); 
	
	// MAGICK!
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Squad size adjustment from mission parameters");
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	if (XComHQ.Squad.Length > SoldierSlotCount || XComHQ.AllSquads.Length > 0)
	{
		NewGameState.AddStateObject(XComHQ);
		CollapseSquad(XComHQ);
		if (XComHQ.Squad.Length > SoldierSlotCount)
		{
			XComHQ.Squad.Length = SoldierSlotCount;
		}
		XComHQ.AllSquads.Length = 0;
	}
	// do it like LW2 because why not?
	`XEVENTMGR.TriggerEvent('OnUpdateSquadSelectSoldiers', XComHQ, XComHQ, NewGameState); // hook to allow mods to adjust who is in the squad
	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	else
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
	}
	
	maxListWidth = 6 * (class'robojumper_UISquadSelect_ListItem'.default.width + LIST_ITEM_PADDING) - LIST_ITEM_PADDING;
	// TODO: How does this interact with wide-screen?
	// HAX: always spawn it on the left, move it afterwards
	listX = (Movie.UI_RES_X / 2) - (maxListWidth / 2);
	SquadList = Spawn(class'robojumper_UIList_SquadEditor', self).InitSquadList('', listX, iDefSlotY, SoldierSlotCount, 6, class'robojumper_UISquadSelect_ListItem', LIST_ITEM_PADDING);
	SquadList.GetScrollDelegate = GetScroll;
	SquadList.ScrollCallback = OnStickMouseScrollCB;
	SquadList.GetScrollGoalDelegate = GetScrollGoal;

	if (SoldierSlotCount < 6)
	{
		fScroll = -((6.0 - SoldierSlotCount) / 2.0);
		fInterpGoal = fScroll;
	}

	Navigator.SetSelected(SquadList);
	
	MouseGuard = robojumper_UIMouseGuard_SquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'robojumper_UIMouseGuard_SquadSelect'));
	// for reasons I can't explain, 1.0 / 282 is ten times too fast
	MouseGuard.mouseMoveScalar = 0.3 / class'robojumper_UISquadSelect_ListItem'.default.width;
	MouseGuard.StickRotationMultiplier = 0.01;
	MouseGuard.ValueChangeCallback = OnStickMouseScrollCB;
	MouseGuard.StartUpdate();


	`XSTRATEGYSOUNDMGR.PlaySquadSelectMusic();

	bDisableEdit = class'XComGameState_HeadquartersXCom'.static.GetObjectiveStatus('T0_M3_WelcomeToHQ') == eObjectiveState_InProgress;
	bDisableDismiss = bDisableEdit; // disable both buttons for now
	bDisableLoadout = false;

	//Make sure the kismet variables are up to date
	WorldInfo.MyKismetVariableMgr.RebuildVariableMap();

	BuildWorldCoordinates();

	CreateOrUpdateLaunchButton();

	UpdateData(class'robojumper_SquadSelectConfig'.static.ShouldAutoFillSquad());
	UpdateNavHelp();
	UpdateMissionInfo();
	UpdateSitRep();

	if (MissionData.Mission.AllowDeployWoundedUnits)
	{
		`HQPRES.UIWoundedSoldiersAllowed();
	}
	// snap first to not mess up the first transition
	`HQPRES.CAMLookAtNamedLocation(UIDisplayCam_Overview, 0);
	SetTimer(0.1f, false, nameof(StartPreMissionCinematic));
	XComHeadquartersController(`HQPRES.Owner).SetInputState('None');

}

function CreateOrUpdateLaunchButton()
{
	local string SingleLineLaunch;
	
	// TTP14257 - loc is locked down, so, I'm making the edit. No space in Japanese. -bsteiner 
	if( GetLanguage() == "JPN" )
		SingleLineLaunch = m_strNextSquadLine1 $ m_strNextSquadLine2;
	else 
		SingleLineLaunch = m_strNextSquadLine1 @ m_strNextSquadLine2;

	if(LaunchButton == none)
	{
		LaunchButton = Spawn(class'UILargeButton', self);
		LaunchButton.bAnimateOnInit = false;
	}

	if(XComHQ.AllSquads.Length < (SquadCount - 1))
	{
		if( `ISCONTROLLERACTIVE )
		{
			LaunchButton.InitLargeButton(,class'UIUtilities_Text'.static.InjectImage(
					class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_START, 26, 26, -10) @ SingleLineLaunch,, OnNextSquad);
		}
		else
		{
			LaunchButton.InitLargeButton(, m_strNextSquadLine2, m_strNextSquadLine1, OnNextSquad);
		}

		LaunchButton.SetDisabled(false); //bsg-hlee (05.12.17): The button should not be disabled if set to OnNextSquad function.
	}
	else
	{
		if( `ISCONTROLLERACTIVE )
		{
			LaunchButton.InitLargeButton(,class'UIUtilities_Text'.static.InjectImage(
					class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_START, 26, 26, -13) @ m_strLaunch @ m_strMission,, OnLaunchMission);
		}
		else
		{
			LaunchButton.InitLargeButton(, m_strMission, m_strLaunch, OnLaunchMission);
		}
	}

	LaunchButton.AnchorTopCenter();
	LaunchButton.DisableNavigation();
	LaunchButton.ShowBG(true);

	UpdateNavHelp();
}

// bsg-jrebar (5/16/17): Select First item and lose/gain focus on first list item
simulated function SelectFirstListItem()
{
	// Override, our navigation system is smarter than this
}
// bsg-jrebar (5/16/17): end

simulated function bool AllowScroll()
{
	return SoldierSlotCount > 6;
}

simulated function AddHiddenSoldiersToSquad(int NumSoldiersToAdd)
{
	// commented out -- we don't have any hidden soldiers. We always show all the slots
}

simulated function UpdateData(optional bool bFillSquad)
{
	local XComGameStateHistory History;
	local int i;
	local int SlotIndex;	//Index into the list of places where a soldier can stand in the after action scene, from left to right
	local int SquadIndex;	//Index into the HQ's squad array, containing references to unit state objects
	local int ListItemIndex;//Index into the array of list items the player can interact with to view soldier status and promote

	

	local robojumper_UISquadSelect_ListItem ListItem;
	local XComGameState_Unit UnitState;
	local XComGameState_MissionSite MissionState;
	local GeneratedMissionData MissionData;
	local bool bAllowWoundedSoldiers, bSpecialSoldierFound;
	local array<name> RequiredSpecialSoldiers;
	local int iMaxExtraHeight;

	History = `XCOMHISTORY;
	// test: don't clear pawns
	ClearPawns();

	// get existing states
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();

	MissionData = XComHQ.GetGeneratedMissionData(XComHQ.MissionRef.ObjectID);
	bAllowWoundedSoldiers = MissionData.Mission.AllowDeployWoundedUnits;
	RequiredSpecialSoldiers = MissionData.Mission.SpecialSoldiers;

	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));
	bHasRankLimits = MissionState.HasRankLimits(MinRank, MaxRank);
	// add a unit to the squad if there is one pending
	if (PendingSoldier.ObjectID > 0 && m_iSelectedSlot != -1)
		XComHQ.Squad[m_iSelectedSlot] = PendingSoldier;

	// if this mission requires special soldiers, check to see if they already exist in the squad
	if (RequiredSpecialSoldiers.Length > 0)
	{
		for (i = 0; i < RequiredSpecialSoldiers.Length; i++)
		{
			bSpecialSoldierFound = false;
			for (SquadIndex = 0; SquadIndex < XComHQ.Squad.Length; SquadIndex++)
			{
				UnitState = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.Squad[SquadIndex].ObjectID));
				if (UnitState != none && UnitState.GetMyTemplateName() == RequiredSpecialSoldiers[i])
				{
					bSpecialSoldierFound = true;
					break;
				}
			}

			if (!bSpecialSoldierFound)
				break; // If a special soldier is missing, break immediately and reset the squad
		}

		// If no special soldiers are found, clear the squad, search for them, and add them
		if (!bSpecialSoldierFound)
		{
			UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Add special soldier to squad");
			XComHQ = XComGameState_HeadquartersXCom(UpdateState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
			UpdateState.AddStateObject(XComHQ);
			XComHQ.Squad.Length = 0;

			foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
			{
				// If this unit is one of the required special soldiers, add them to the squad
				if (RequiredSpecialSoldiers.Find(UnitState.GetMyTemplateName()) != INDEX_NONE)
				{
					UnitState = XComGameState_Unit(UpdateState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
					
					// safety catch: somehow Central has no appearance in the alien nest mission. Not sure why, no time to figure it out - dburchanowski
					if(UnitState.GetMyTemplate().bHasFullDefaultAppearance && UnitState.kAppearance.nmTorso == '')
					{
						`Redscreen("Special Soldier " $ UnitState.ObjectID $ " with template " $ UnitState.GetMyTemplateName() $ " has no appearance, restoring default!");
						UnitState.kAppearance = UnitState.GetMyTemplate().DefaultAppearance;
					}

					UpdateState.AddStateObject(UnitState);
					UnitState.ApplyBestGearLoadout(UpdateState); // Upgrade the special soldier to have the best possible gear
					
					if (XComHQ.Squad.Length < SoldierSlotCount) // Only add special soldiers up to the squad limit
					{
						XComHQ.Squad.AddItem(UnitState.GetReference());
					}
				}
			}

			StoreGameStateChanges();
		}
	}

	// fill out the squad as much as possible
	if(bFillSquad)
	{
		// create change states
		UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Fill Squad");
		XComHQ = XComGameState_HeadquartersXCom(UpdateState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		UpdateState.AddStateObject(XComHQ);
		// Remove tired soldiers from the squad, and remove soldiers that don't fit the rank limits (if they exist)
		for(i = 0; i < XComHQ.Squad.Length; i++)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.Squad[i].ObjectID));

			if(UnitState != none && (UnitState.GetMentalState() != eMentalState_Ready || 
				(bHasRankLimits && (UnitState.GetRank() < MinRank || UnitState.GetRank() > MaxRank))))
			{
				XComHQ.Squad[i].ObjectID = 0;
			}
		}

		for(i = 0; i < SoldierSlotCount; i++)
		{
			if(XComHQ.Squad.Length == i || XComHQ.Squad[i].ObjectID == 0)
			{
				if(bHasRankLimits)
				{
					UnitState = XComHQ.GetBestDeployableSoldier(true, bAllowWoundedSoldiers, MinRank, MaxRank);
				}
				else
				{
					UnitState = XComHQ.GetBestDeployableSoldier(true, bAllowWoundedSoldiers);
				}

				if(UnitState != none)
					XComHQ.Squad[i] = UnitState.GetReference();
			}
		}
		StoreGameStateChanges();

		TriggerEventsForWillStates();

		if (!bBlockSkulljackEvent)
		{
			SkulljackEvent();
		}
	}

	// This method iterates all soldier templates and empties their backpacks if they are not already empty
	BlastBackpacks();

	// Everyone have their Xpad?
	ValidateRequiredLoadouts();

	// Clear Utility Items from wounded soldiers inventory
	if (!bAllowWoundedSoldiers)
	{
		MakeWoundedSoldierItemsAvailable();
	}

	// create change states
	CreatePendingStates();

	ListItemIndex = 0;
	iMaxExtraHeight = 0; 		                                                                                
	UnitPawns.Length = Max(SoldierSlotCount, UnitPawns.Length);
	for (SlotIndex = 0; SlotIndex < SoldierSlotCount; ++SlotIndex)
	{
		SquadIndex = SlotIndex;
		// We want the slots to match the visual order of the pawns in the slot list.
		ListItem = robojumper_UISquadSelect_ListItem(SquadList.GetItem(ListItemIndex));
		// test: avoid unneccessarily refreshing all the stuff, which causes units to flicker
		if (bDirty || (SquadIndex < XComHQ.Squad.length && XComHQ.Squad[SquadIndex].ObjectID > 0 && ListItem.bDirty))
		{

			if (UnitPawns[SquadIndex] != none)
			{
				// TODO: Can we reach this if XComHQ.Squad[SquadIndex].ObjectID == 0?
				//m_kPawnMgr.ReleaseCinematicPawn(self, UnitPawns[SquadIndex].ObjectID);
				m_kPawnMgr.ReleaseCinematicPawn(self, XComHQ.Squad[SquadIndex].ObjectID);
			}

			UnitPawns[SquadIndex] = CreatePawn(XComHQ.Squad[SquadIndex], SquadIndex);
		}

		if(bDirty || ListItem.bDirty)
		{
			if (SquadIndex < XComHQ.Squad.Length)
				UnitState = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.Squad[SquadIndex].ObjectID));
			else
				UnitState = none;

			if (RequiredSpecialSoldiers.Length > 0 && UnitState != none && RequiredSpecialSoldiers.Find(UnitState.GetMyTemplateName()) != INDEX_NONE)
				ListItem.UpdateData(SquadIndex, true, true, false, UnitState.GetSoldierClassTemplate().CannotEditSlots); // Disable customization or removing any special soldier required for the mission
			else
				ListItem.UpdateData(SquadIndex, bDisableEdit, bDisableDismiss, bDisableLoadout);
		}
		iMaxExtraHeight = Max(iMaxExtraHeight, ListItem.GetExtraHeight());
		++ListItemIndex;
	}
	UnitPawns.Length = SoldierSlotCount;
	SquadList.SetY(iDefSlotY - iMaxExtraHeight);
	StoreGameStateChanges();
	bDirty = false;

	if (MissionState.GetMissionSource().RequireLaunchMissionPopupFn != none && MissionState.GetMissionSource().RequireLaunchMissionPopupFn(MissionState))
	{
		// If the mission source requires a unique launch mission warning popup which has not yet been displayed, show it now
		if (!MissionState.bHasSeenLaunchMissionWarning)
		{
			`HQPRES.UILaunchMissionWarning(MissionState);
		}
	}
}



simulated function int GetTotalSlots()
{
	return SoldierSlotCount;
}


simulated function UpdateNavHelp()
{
	local UINavigationHelp NavHelp;
	local XComHeadquartersCheatManager CheatMgr;
	local string BoostTooltip;

	LaunchButton.SetDisabled(!CanLaunchMission());
	LaunchButton.SetTooltipText(GetTooltipText());
	Movie.Pres.m_kTooltipMgr.TextTooltip.SetUsePartialPath(LaunchButton.CachedTooltipId, true);

	if (`HQPRES != none)
	{
		NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;
		CheatMgr = XComHeadquartersCheatManager(GetALocalPlayerController().CheatManager);
		NavHelp.ClearButtonHelp();

		// moved down (up in code) because it's a long string and shouldn't conflict with the list
		if (`ISCONTROLLERACTIVE)
		{
			NavHelp.AddLeftStackHelp(class'UIPauseMenu'.default.m_sControllerMap, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RSCLICK_R3);
		}

		if (!bNoCancel || (XComHQ.AllSquads.Length > 0 && XComHQ.AllSquads.Length < (SquadCount)))
		{
			if (!NavHelp.bBackButton)
			{
				NavHelp.bBackButton = true;
				if (`ISCONTROLLERACTIVE)
				{
					NavHelp.AddLeftStackHelp(NavHelp.m_strBackButtonLabel, class'UIUtilities_Input'.static.GetBackButtonIcon(), CloseScreen);
				}
				else
				{
					NavHelp.SetButtonType("XComButtonIconPC");
					NavHelp.AddLeftStackHelp("4", "4", CloseScreen);
					NavHelp.SetButtonType("");
				}
			}
		}

		if (`ISCONTROLLERACTIVE)
		{
			NavHelp.AddLeftStackHelp(class'UIUtilities_Text'.default.m_strGenericSelect, class'UIUtilities_Input'.static.GetAdvanceButtonIcon());
			NavHelp.AddLeftStackHelp(class'UISquadSelect_ListItem'.default.m_strEdit, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE);
			NavHelp.AddLeftStackHelp(class'UISquadSelect_ListItem'.default.m_strDismiss, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
		}

		if (CheatMgr == none || !CheatMgr.bGamesComDemo)
		{
			if (!`ISCONTROLLERACTIVE)
			{
				NavHelp.AddCenterHelp(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(strUnequipSquad), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $class'UIUtilities_Input'.const.ICON_LT_L2,
					OnUnequipSquad, false, strUnequipSquadTooltip);
				NavHelp.AddCenterHelp(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(strUnequipBarracks), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $class'UIUtilities_Input'.const.ICON_RT_R2,
					OnUnequipBarracks, false, strUnequipBarracksTooltip);
			}
			else
			{
				NavHelp.AddCenterHelp(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(class'UIManageEquipmentMenu'.default.m_strTitleLabel), class'UIUtilities_Input'.const.ICON_LT_L2);
			}
		}

		if (class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T0_M5_WelcomeToEngineering'))
		{
			NavHelp.AddCenterHelp(m_strBuildItems, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LB_L1, 
				OnBuildItems, false, m_strTooltipBuildItems);
		}

		// Add the button for the Recovery Booster if it is available	
		if(ShowRecoveryBoostButton())
		{
			// bsg-jrebar (5/3/17): Adding a button for the controls
			if (IsRecoveryBoostAvailable(BoostTooltip) || `ISCONTROLLERACTIVE)
				`HQPRES.m_kAvengerHUD.NavHelp.AddCenterHelp(m_strBoostSoldier, class'UIUtilities_Input'.const.ICON_RT_R2, OnBoostSoldier, false, BoostTooltip);
			else
				`HQPRES.m_kAvengerHUD.NavHelp.AddCenterHelp(m_strBoostSoldier, "", , true, BoostTooltip);
		}

		if (AllowScroll())
		{
			// todo
			NavHelp.AddCenterHelp(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(strSwitchPerspective), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RB_R1, 
				SwitchPerspective, false, strSwitchPerspectiveTooltip);
		}
/*
		// Re-enabling this option for Steam builds to assist QA testing, TODO: disable this option before release
`if(`notdefined(FINAL_RELEASE))
		if (CheatMgr == none || !CheatMgr.bGamesComDemo)
		{
			NavHelp.AddCenterHelp("SIM COMBAT", class'UIUtilities_Input'.static.GetGamepadIconPrefix() $class'UIUtilities_Input'.const.ICON_BACK_SELECT,
				OnSimCombat, !CanLaunchMission(), GetTooltipText());
		}	
`endif
*/
	}
}

simulated function OnNextSquad(UIButton Button)
{
	if(CurrentSquadHasEnoughSoldiers())
		bDirty = true;
	super.OnNextSquad(Button);
}

simulated function CloseScreen()
{
	if (!bLaunched && XComHQ.AllSquads.Length > 0)
	{
		bDirty = true;
	}
	super.CloseScreen();
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!bIsVisible || !bReceivedWalkupEvent)
	{
		return true;
	}
	
	if (bLaunched)
	{
		return false;
	}

	if (IsTimerActive(nameof(GoToBuildItemScreen)))
	{
		return false;
	}
	if ( SquadList.OnUnrealCommand(cmd, arg) )
		return true;
		
	// Only pay attention to presses or repeats; ignoring other input types
	// NOTE: Ensure repeats only occur with arrow keys
	if ( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	bHandled = true;
	switch( cmd )
	{

		case class'UIUtilities_Input'.static.GetBackButtonInputCode():
		case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
			if(!bNoCancel || XComHQ.AllSquads.Length > 0)
			{
				CloseScreen();
				Movie.Pres.PlayUISound(eSUISound_MenuClose);
			}
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_LTRIGGER:
			OnManageEquipmentPressed();
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_RTRIGGER:
			OnBoostSoldier();
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER:
			if (class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T0_M5_WelcomeToEngineering'))
			{
				OnBuildItems();
			}
			break;

		case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER:
			if (AllowScroll())
			{
				SwitchPerspective();
			}
			break;
/*
`if(`notdefined(FINAL_RELEASE))
		case class'UIUtilities_Input'.const.FXS_BUTTON_SELECT:
			OnSimCombat();
			break;
`endif
*/
		case class'UIUtilities_Input'.const.FXS_BUTTON_R3:
			if (`ISCONTROLLERACTIVE)
			{
				`SCREENSTACK.Push(Spawn(class'robojumper_SquadSelectControllerMap', Movie.Pres));
				break;
			}

		case class'UIUtilities_Input'.const.FXS_BUTTON_START:
			if(XComHQ.AllSquads.Length < (SquadCount - 1))
			{
				OnNextSquad(LaunchButton);
			}
			else
			{
				OnLaunchMission(LaunchButton);
			}
			break;
		default:
			bHandled = false;
			break;
	}

	return bHandled || super(UIScreen).OnUnrealCommand(cmd, arg);
}

simulated function OnUnequipSquad()
{
	local TDialogueBoxData DialogData;
	DialogData.eType = eDialog_Normal;
	DialogData.strTitle = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(strUnequipSquadConfirm);
	DialogData.strText = strUnequipSquadWarning;
	DialogData.fnCallback = OnUnequipSquadDialogueCallback;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
	DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
	Movie.Pres.UIRaiseDialog(DialogData);
}
simulated function OnUnequipSquadDialogueCallback(name eAction)
{
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local array<EInventorySlot> RelevantSlots;
	local array<EInventorySlot> SlotsToClear;
	local array<EInventorySlot> LockedSlots;
	local EInventorySlot LockedSlot;
	local array<XComGameState_Unit> Soldiers;
	local int idx;

	if(eAction == 'eUIAction_Accept')
	{
		History = `XCOMHISTORY;
		UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Unequip Squad");
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class' XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(UpdateState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		UpdateState.AddStateObject(XComHQ);
		Soldiers = XComHQ.GetSoldiers(false	, true);

		RelevantSlots.AddItem(eInvSlot_Armor);
		RelevantSlots.AddItem(eInvSlot_PrimaryWeapon);
		RelevantSlots.AddItem(eInvSlot_SecondaryWeapon);
		RelevantSlots.AddItem(eInvSlot_HeavyWeapon);
		RelevantSlots.AddItem(eInvSlot_Utility);
		RelevantSlots.AddItem(eInvSlot_GrenadePocket);
		RelevantSlots.AddItem(eInvSlot_AmmoPocket);

		for(idx = 0; idx < Soldiers.Length; idx++)
		{
			if (XComHQ.IsUnitInSquad(Soldiers[idx].GetReference()))
			{
				UnitState = XComGameState_Unit(UpdateState.CreateStateObject(class'XComGameState_Unit', Soldiers[idx].ObjectID));

				SlotsToClear = RelevantSlots;
				LockedSlots = UnitState.GetSoldierClassTemplate().CannotEditSlots;
				foreach LockedSlots(LockedSlot)
				{
					if (SlotsToClear.Find(LockedSlot) != INDEX_NONE)
					{
						SlotsToClear.RemoveItem(LockedSlot);
					}
				}

				UpdateState.AddStateObject(UnitState);
				UnitState.MakeItemsAvailable(UpdateState, false, SlotsToClear);
			}
		}

		`GAMERULES.SubmitGameState(UpdateState);
	}
	bDirty = true;
	UpdateData();
	UpdateNavHelp();
}



simulated function OnUnequipBarracks()
{
	local TDialogueBoxData DialogData;
	DialogData.eType = eDialog_Normal;
	DialogData.strTitle = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(strUnequipBarracksConfirm);
	DialogData.strText = strUnequipBarracksWarning;
	DialogData.fnCallback = OnUnequipBarracksDialogueCallback;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
	DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
	Movie.Pres.UIRaiseDialog(DialogData);
}
simulated function OnUnequipBarracksDialogueCallback(name eAction)
{
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local array<EInventorySlot> RelevantSlots;
	local array<EInventorySlot> SlotsToClear;
	local array<EInventorySlot> LockedSlots;
	local EInventorySlot LockedSlot;
	local array<XComGameState_Unit> Soldiers;
	local int idx;

	if(eAction == 'eUIAction_Accept')
	{
		History = `XCOMHISTORY;
		UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Unequip Barracks");
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class' XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(UpdateState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		UpdateState.AddStateObject(XComHQ);
		Soldiers = XComHQ.GetSoldiers(true, true);

		RelevantSlots.AddItem(eInvSlot_Armor);
		RelevantSlots.AddItem(eInvSlot_PrimaryWeapon);
		RelevantSlots.AddItem(eInvSlot_SecondaryWeapon);
		RelevantSlots.AddItem(eInvSlot_HeavyWeapon);
		RelevantSlots.AddItem(eInvSlot_Utility);
		RelevantSlots.AddItem(eInvSlot_GrenadePocket);
		RelevantSlots.AddItem(eInvSlot_AmmoPocket);

		for(idx = 0; idx < Soldiers.Length; idx++)
		{
				UnitState = XComGameState_Unit(UpdateState.CreateStateObject(class'XComGameState_Unit', Soldiers[idx].ObjectID));

				SlotsToClear = RelevantSlots;
				LockedSlots = UnitState.GetSoldierClassTemplate().CannotEditSlots;
				foreach LockedSlots(LockedSlot)
				{
					if (SlotsToClear.Find(LockedSlot) != INDEX_NONE)
					{
						SlotsToClear.RemoveItem(LockedSlot);
					}
				}

				UpdateState.AddStateObject(UnitState);
				UnitState.MakeItemsAvailable(UpdateState, false, SlotsToClear);
		}

		`GAMERULES.SubmitGameState(UpdateState);
	}
	UpdateNavHelp();
}


event OnRemoteEvent(name RemoteEventName)
{
	super(UIScreen).OnRemoteEvent(RemoteEventName);

	// Only show screen if we're at the top of the state stack
	if(RemoteEventName == 'PreM_LineupUI' && (`SCREENSTACK.GetCurrentScreen() == self || `SCREENSTACK.GetCurrentScreen().IsA('UIAlert') || `SCREENSTACK.IsCurrentClass(class'UIRedScreen') || `SCREENSTACK.HasInstanceOf(class'UIProgressDialogue'))) //bsg-jneal (5.10.17): allow remote events to call through even with dialogues up)
	{
		ShowLineupUI();
	}
	else if(RemoteEventName == 'PreM_Exit')
	{
		GoToGeoscape();
	}
	else if(RemoteEventName == 'PreM_StartIdle' || RemoteEventName == 'PreM_SwitchToLineup')
	{
		GotoState('Cinematic_PawnsIdling');
	}
	else if(RemoteEventName == 'PreM_SwitchToSoldier')
	{
		GotoState('Cinematic_PawnsCustomization');
	}
	else if(RemoteEventName == 'PreM_StopIdle_S2')
	{
		GotoState('Cinematic_PawnsWalkingAway');    
	}		
	else if(RemoteEventName == 'PreM_CustomizeUI_Off')
	{
		UpdateData();
	}
}

function GoToGeoscape()
{	
	local StateObjectReference EmptyRef;
	local XComGameState_MissionSite MissionState;

	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));

	if(bLaunched)
	{
		if(MissionState.GetMissionSource().DataName == 'MissionSource_Final' && !bSkipFinalMissionCutscenes)
		{
			`MAPS.AddStreamingMap("CIN_TP_Dark_Volunteer_pt2_Hallway_Narr", vect(0, 0, 0), Rot(0, 0, 0), true, false, true, OnVolunteerMatineeIsVisible);
			return;
		}
		else if(!MissionState.GetMissionSource().bRequiresSkyrangerTravel) //Some missions, like avenger defense, may not require the sky ranger to go anywhere
		{			
			MissionState.ConfirmMission();
		}
		else
		{
			MissionState.SquadSelectionCompleted();
		}
	}
	else
	{
		XComHQ.MissionRef = EmptyRef;
		MissionState.SquadSelectionCancelled();
		`XSTRATEGYSOUNDMGR.PlayGeoscapeMusic();
	}

	`XCOMGRI.DoRemoteEvent('CIN_UnhideArmoryStaff'); //Show the armory staff now that we are done

	Movie.Stack.Pop(self);
}


function ShowLineupUI()
{
	local int l, r, visSlots, shownSlots;
	local float AnimateRate, AnimateValue;

	bReceivedWalkupEvent = true; 
	CheckForWalkupAlerts();

	// last chance
	SquadList.UpdateScroll();
	Show();
	UpdateNavHelp();

	AnimateRate = 0.2;
	AnimateValue = 0.0;
	visSlots = Min(6, SoldierSlotCount);
	shownSlots = 0;
	// odd, so animate centered first
	if (visSlots % 2 == 1)
	{
		l = visSlots / 2;
		r = l;
		UISquadSelect_ListItem(SquadList.GetItem(l)).AnimateIn(AnimateValue);
		AnimateValue += AnimateRate;
		l--;
		r++;
		shownSlots++;
	}
	else
	{
		r = visSlots / 2;
		l = r - 1;
	}
	// since all remaining slots are now an even number, we are guaranteed to not hit a slot twice
	while (shownSlots < SoldierSlotCount)
	{
		if (r >= SoldierSlotCount)
		{
			r = 0;
		}
		UISquadSelect_ListItem(SquadList.GetItem(r)).AnimateIn(AnimateValue);
		r++;
		if (l < 0)
		{
			l = SoldierSlotCount - 1;
		}
		UISquadSelect_ListItem(SquadList.GetItem(l)).AnimateIn(AnimateValue);
		l--;
		AnimateValue += AnimateRate;
		shownSlots += 2;
	}
}

simulated function SnapCamera()
{
	MoveCamera(0);
}

simulated function MoveCamera(float fInterpTime)
{
	if (bUpperView)
		`HQPRES.CAMLookAtNamedLocation(UIDisplayCam_Overview, fInterpTime);
	else
		`HQPRES.CAMLookAtNamedLocation(UIDisplayCam, fInterpTime);
}

simulated function SwitchPerspective()
{
	bUpperView = !bUpperView;
	MoveCamera(`HQINTERPTIME / 2);
}


// our squad may have more soldiers than we can normally display but it may have empty entries
// collapse first
function CollapseSquad(XComGameState_HeadquartersXCom HQ)
{
	local int i;
	for (i = HQ.Squad.Length - 1; i >= 0; i--)
	{
		if (HQ.Squad[i].ObjectID <= 0)	
		{
			HQ.Squad.Remove(i, 1);
		}
	}
}



function vector WorldSpaceForEllipseAngle(float gamma)
{
	local vector EllipseVector, NewVector;

	EllipseVector.X = Cos(gamma);
	EllipseVector.Y = -Sin(gamma); // minus because reasons

	NewVector = TransformVector(TransformMatrix, EllipseVector);
	
	return NewVector;
}
// 1 = one item
simulated function OnStickMouseScrollCB(float fChange)
{
	if (AllowScroll())
	{
		LerpTo(fInterpGoal + fChange);
	}
}

simulated function float GetScroll()
{
	return fScroll;
}
simulated function float GetScrollGoal()
{
	return fInterpGoal;
}

simulated function float easeOutQuad(float t, float b, float c, float d)
{
	return (-c) * ((t/d) * ((t/d) - 2)) + b;
}

// not linear, whatever
simulated function LerpTo(float fGoal)
{
	if (bInfiniteScrollingDisallowed && AllowScroll())
	{
		fGoal = FClamp(fGoal, 0, SoldierSlotCount - 6);
	}
	fInterpStart = fScroll;
	fInterpGoal = fGoal;
	fInterpCurrTime = 0;
}

simulated function Tick(float fDeltaTime)
{
	super.Tick(fDeltaTime);
	if (fScroll ~= fInterpGoal)
		return;

	fInterpCurrTime += fDeltaTime;
	fInterpCurrTime = FClamp(fInterpCurrTime, 0.0, INTERP_TIME);

	fScroll = easeOutQuad(fInterpCurrTime, fInterpStart, fInterpGoal - fInterpStart, INTERP_TIME);

	UpdateScroll();
}

simulated function SquadSelectInterpKeyframe GetPosRotForIndex(int idx)
{
	local int a, b;
	local float f, fakeScroll;
	local SquadSelectInterpKeyframe RetKeyframe;
	fakeScroll = -fScroll;
	while (fakeScroll < 0)
	{
		fakeScroll += float(SoldierSlotCount);
	}

	a = (FFloor(fakeScroll) + idx) % Keyframes.Length;
	b = (FCeil(fakeScroll) + idx) % Keyframes.Length;
	f = fakeScroll - FFloor(fakeScroll);
	//RetKeyframe.Location = Keyframes[a].Location + (f * (Keyframes[b].Location - Keyframes[a].Location));
	//RetKeyframe.Rotation = Keyframes[a].Rotation + (f * (Keyframes[b].Rotation - Keyframes[a].Rotation));
	RetKeyframe.Location = VLerp(Keyframes[a].Location, Keyframes[b].Location, f);
	RetKeyframe.Rotation = RLerp(Keyframes[a].Rotation, Keyframes[b].Rotation, f, true);
	return RetKeyframe;
}

simulated function UpdateScroll()
{
	local int i;
	local vector NewLoc;
	local rotator NewRot;
	local SquadSelectInterpKeyframe Keyfr;
	if (bLaunched) return;

	for (i = 0; i < UnitPawns.Length; i++)
	{
		if (UnitPawns[i] == none) continue;
		Keyfr = GetPosRotForIndex(i);
		NewLoc = Keyfr.Location;
		NewRot = Keyfr.Rotation;

		UnitPawns[i].SetLocation(NewLoc);
		UnitPawns[i].SetRotation(NewRot);

		if (GremlinPawns[i].GremlinPawn != none)
		{
			GremlinPawns[i].GremlinPawn.SetLocation(NewLoc);
			GremlinPawns[i].GremlinPawn.SetRotation(NewRot);
		}
	}
	SquadList.UpdateScroll();
}

// Unused in vanilla, override for consistency though
simulated function int GetSlotIndexForUnit(StateObjectReference UnitRef)
{
	local int SlotIndex;	//Index into the list of places where a soldier can stand in the after action scene, from left to right
	local int SquadIndex;	//Index into the HQ's squad array, containing references to unit state objects

	for(SlotIndex = 0; SlotIndex < SoldierSlotCount; ++SlotIndex)
	{
		SquadIndex = SlotIndex;
		if(SquadIndex < XComHQ.Squad.Length)
		{
			if(XComHQ.Squad[SquadIndex].ObjectID == UnitRef.ObjectID)
				return SlotIndex;
		}
	}

	return -1;
}


simulated function BuildWorldCoordinates()
{
	local int i;
	local Actor Point;
	local SquadSelectInterpKeyframe NewKeyframe, EmptyKeyframe;
	local int ExtraSlots;
	local vector center, sPoint, mPoint;
//	local vector f1;
	
	local float lowerBound, upperBound;

	Keyframes.Length = 0;

	for (i = 0; i < SlotListOrder.Length; i++)
	{
		Point = class'robojumper_SquadSelect_WorldConfiguration'.static.GetTaggedActor(name(m_strPawnLocationIdentifier $ SlotListOrder[i]), class'PointInSpace');
		NewKeyframe = EmptyKeyframe;
		NewKeyframe.Location = Point.Location;
		NewKeyframe.Rotation = Point.Rotation;
		Keyframes.AddItem(NewKeyframe);
//		m_ShapeMgr.DrawSphere(NewKeyframe.Location, Vect(10, 10, 10), MakeLinearColor(1, 0, 0, 1), true);
	}
	ExtraSlots = SoldierSlotCount - 6;
	// don't do all that phish if we don't need it
	if (ExtraSlots <= 0)
	{
//		return;
	}
	// MOM, GET THE CAMERA
	class'robojumper_SquadSelect_WorldConfiguration'.static.GetTaggedActor(name(UIDisplayCam_Overview), class'CameraActor');
	// build the matrix that translates "ellipse space" into world space
	// as well as info about the ellipse
	center = class'robojumper_SquadSelect_WorldConfiguration'.static.GetTaggedActor('EllipseCenter', class'PointInSpace').Location;
//	f1 = class'robojumper_SquadSelect_WorldConfiguration'.static.GetTaggedActor('EllipseF1', class'PointInSpace').Location;
	sPoint = class'robojumper_SquadSelect_WorldConfiguration'.static.GetTaggedActor('EllipseS', class'PointInSpace').Location;
	mPoint = class'robojumper_SquadSelect_WorldConfiguration'.static.GetTaggedActor('EllipseM1', class'PointInSpace').Location;
/*	m_ShapeMgr.DrawSphere(center, Vect(5, 5, 5), MakeLinearColor(0, 0, 1, 1), true);
	m_ShapeMgr.DrawSphere(f1, Vect(5, 5, 5), MakeLinearColor(0, 0, 1, 1), true);
	m_ShapeMgr.DrawSphere(sPoint, Vect(5, 5, 5), MakeLinearColor(0, 0, 1, 1), true);
	m_ShapeMgr.DrawSphere(mPoint, Vect(5, 5, 5), MakeLinearColor(0, 0, 1, 1), true);
*/

	TransformMatrix.XPlane.X = center.X - mPoint.X;
	TransformMatrix.XPlane.Y = center.Y - mPoint.Y;
	TransformMatrix.YPlane.X = center.X - sPoint.X;
	TransformMatrix.YPlane.Y = center.Y - sPoint.Y;
	TransformMatrix.ZPlane.Z = 1;
	TransformMatrix.WPlane.X = center.X;
	TransformMatrix.WPlane.Y = center.Y;
	TransformMatrix.WPlane.Z = center.Z;
	TransformMatrix.WPlane.W = 1;

	// we place keyframes in regular intervals between [0, PI] on the ellipsis
	// if we are less than 6 additional soldiers, fill them up from the middle and don't make them entirely regular
	// if we are 6 or more, space them out
	if (ExtraSlots < 6)
	{
		lowerBound = (Pi / 2) - ((ExtraSlots - 1) * (Pi / 12));
		upperBound = (PI / 2) + ((ExtraSlots - 1) * (Pi / 12));
	}
	else
	{
		lowerBound = 0;
		upperBound = Pi;
	}
	
	for (i = SlotListOrder.Length; i < SoldierSlotCount; i++)
	{
		NewKeyframe = EmptyKeyframe;
		NewKeyframe.Location = WorldSpaceForEllipseAngle(Lerp(lowerBound, upperBound, float(i - SlotListOrder.Length) / Max(ExtraSlots - 1, 1)));
		NewKeyframe.Rotation = Keyframes[0].Rotation; // just use the same rotation
		Keyframes.AddItem(NewKeyframe);
//		m_ShapeMgr.DrawSphere(NewKeyframe.Location, Vect(10, 10, 10), MakeLinearColor(1, 0, 0, 1), true);
	}
/*
	// test the ellipsis
	for (i = 0; i < 360; i++)
	{
		m_ShapeMgr.DrawSphere(WorldSpaceForEllipseAngle(Lerp(0, 2 * Pi, float(i) / 360)), Vect(1, 1, 1), MakeLinearColor(0, float(i) / Max(360 - 1, 1), 0, 1), true);
	}
*/
}



// override -- use our attachment system
simulated function XComUnitPawn CreatePawn(StateObjectReference UnitRef, int index)
{
	local SquadSelectInterpKeyframe Keyfr;
	local XComGameState_Unit UnitState;
	local XComUnitPawn UnitPawn, GremlinPawn;
	local array<AnimSet> GremlinHQAnims;

	if (UnitRef.ObjectID <= 0) return none;

	Keyfr = GetPosRotForIndex(index);
	
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));		
	UnitPawn = m_kPawnMgr.RequestCinematicPawn(self, UnitRef.ObjectID, Keyfr.Location, Keyfr.Rotation, /*name("Soldier"$(index + 1))*/'', '', true);

	                                                                
	UnitPawn.GotoState('CharacterCustomization');
	                                             
	UnitPawn.CreateVisualInventoryAttachments(m_kPawnMgr, UnitState, , , true); // spawn weapons and other visible equipment

	GremlinPawn = m_kPawnMgr.GetCosmeticPawn(eInvSlot_SecondaryWeapon, UnitRef.ObjectID);
	if (GremlinPawn != none)
	{
//		SetGremlinMatineeVariable(name("Gremlin"$(index + 1)), GremlinPawn);
		GremlinPawn.SetTickGroup(TG_PostAsyncWork);
		GremlinHQAnims.AddItem(AnimSet(`CONTENT.RequestGameArchetype("HQ_ANIM.Anims.AS_Gremlin")));
		GremlinPawn.XComAddAnimSetsExternal(GremlinHQAnims);
		GremlinPawn.GotoState('Gremlin_Idle');

	}
	GremlinPawns.Add(Max(index - GremlinPawns.Length + 1, 0));
	GremlinPawns[index].GremlinPawn = GremlinPawn;
	if (GremlinPawn != none)
	{
		GremlinPawns[index].LocOffset = GremlinPawn.Location - UnitPawn.Location;
	}
	// need to force an update for our newly created pawn so it gets moved to the right location
	SetTimer(0.001, false, nameof(UpdateScroll));
	return UnitPawn;
}

simulated function OnReceiveFocus()
{
	if (bSkipDirty)
	{
		bDirty = false;
		bSkipDirty = false;
	}
	else
	{
		MoveCamera(`HQINTERPTIME);
		MouseGuard.StartUpdate();
	}
	//Don't reset the camera during the launch sequence.
	//This case occurs, for example, when closing the "reconnect controller" dialog.
	//INS:
	if(bLaunched)
		return;

	super(UIScreen).OnReceiveFocus();
	// fix ported from WotC
	// When the screen gains focus in some rare case, NavHelp needs something inside it before it clears, otherwise the clear is ignored (for some reason)
	`HQPRES.m_kAvengerHUD.NavHelp.AddLeftHelp("");
	UpdateNavHelp();

	if(bDirty) 
	{
		UpdateData();
	}

}

simulated function OnLoseFocus()
{
	// always mark dirty unless the screen is just an alert -- this can happen with mission warning popups
	bDirty = true;
	
	super(UIScreen).OnLoseFocus();
	StoreGameStateChanges(); // need to save the state of the screen when we leave it

	`HQPRES.m_kAvengerHUD.NavHelp.ClearButtonHelp();

	MouseGuard.ClearUpdate();
	SetTimer(0.01, false, nameof(LostFocusWaitForStack), self);
}

// don't repopulate everything if it's just a mission warning, such as "allow wounded soldiers" etc.
simulated function LostFocusWaitForStack()
{
	if (`SCREENSTACK.GetCurrentScreen().IsA('UIAlert'))
		bSkipDirty = true;
}

defaultproperties
{
	INTERP_TIME=0.55
	// 1. we want a mouse guard, 2. of this class, 3. please let commands through
	bConsumeMouseEvents=true
	MouseGuardClass=class'robojumper_UIMouseGuard_SquadSelect'
	InputState=eInputState_Evaluate
	UIDisplayCam_Overview="PreM_UIDisplayCam_SquadSelect_Overview"
	iDefSlotY=1040
}