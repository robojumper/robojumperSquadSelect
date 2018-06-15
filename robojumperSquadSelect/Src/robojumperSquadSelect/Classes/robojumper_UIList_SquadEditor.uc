// use a dedicated panel
// UIList is too integrated -- scrollbars, navigators, offsets, etc pp.
// this is very rudimentary. No removal, encapsulated container without delegates, ...
class robojumper_UIList_SquadEditor extends UIPanel;

var protected UIPanel ItemContainer;
var protected UIMask TheMask;

var protectedwrite int iSelectedIndex;
var protectedwrite int runningX;
var protectedwrite int totalWidth; 
var protectedwrite int ItemPadding;

var protected class<UIPanel> ListItemClass;

var protected int prevIdx;

var protected int maxWidth;
var protected int maxChildren;

var protected bool bDisAllowInfiniteScrolling;

delegate float GetScrollDelegate();
delegate float GetScrollGoalDelegate();
delegate ScrollCallback(float fScroll);

simulated function robojumper_UIList_SquadEditor InitSquadList(name InitName, int initX, int initY, int numChildren, int displayedChildren, class<UIPanel> ItemClass, int iItemPadding)
{
	local int theWidth, i;
	
	InitPanel(InitName);

	bDisAllowInfiniteScrolling = class'robojumper_SquadSelectConfig'.static.DisAllowInfiniteScrolling();
	
	ItemPadding = iItemPadding;
	SetPosition(initX, initY);
	ListItemClass = ItemClass;
	maxChildren = displayedChildren;
	theWidth = (displayedChildren * (ListItemClass.default.width + ItemPadding)) - ItemPadding;
	totalWidth = (numChildren * (ListItemClass.default.width + ItemPadding));
	SetSize(theWidth, 2000);
	

	ItemContainer = Spawn(class'UIPanel', self);
	ItemContainer.bCascadeFocus = false;
	ItemContainer.bIsNavigable = false;
	ItemContainer.InitPanel('ListItemContainer');
	
	//Navigator = ItemContainer.Navigator.InitNavigator(self); // set owner to be self;
	Navigator = new(ItemContainer) class'UINavigator_OrientationTrue' (ItemContainer.Navigator);
	ItemContainer.Navigator = Navigator;
	UINavigator_OrientationTrue(Navigator).bAllowCyclingOnRepeat = true;
	Navigator.InitNavigator(self);
	Navigator.RemoveControl(ItemContainer); // remove container
	Navigator.HorizontalNavigation = true;
	Navigator.LoopSelection = true; //!class'robojumper_SquadSelectConfig'.static.DisAllowInfiniteScrolling(); causes navigation issues
	Navigator.OnSelectedIndexChanged = NavigatorSelectionChanged;

	runningX = 0;
	for (i = 0; i < NumChildren; i++)
	{
		Spawn(ListItemClass, ItemContainer).InitPanel().SetX(runningX);
		runningX += ListItemClass.default.width + ItemPadding;
	}

	TheMask = Spawn(class'UIMask', self).InitMask('ListMask');
	TheMask.SetMask(ItemContainer);
	TheMask.SetSize(Width, Height);
	TheMask.SetY(-1000);
	// without this, we somehow enter the navigation cycle without using our navigator at all
	Navigator.SelectFirstAvailable();
	return self;

}



// fScroll is a real number where 1 means "one child item"
// since we know what we use it for, it should be fine (tm)
simulated function UpdateScroll()
{
	local int ContainerX;
	local float fScroll;

	fScroll = GetScrollDelegate();
	LoopScroll(fScroll);

	ContainerX = fScroll * (ListItemClass.default.width + ItemPadding);
	// now that just moves stuff out of here
	ItemContainer.SetX(ContainerX);
	ReorganizeListItems();
	
}

simulated function ReorganizeListItems()
{
	local int localRunningX, i, step;
	
	localRunningX = 0;

	step = (ItemPadding + ListItemClass.default.width);
	i = 0;
	// fill right
	while (localRunningX < Width - ItemContainer.X && i < GetNumItems())
	{
		GetItem(i).SetX(localRunningX);
		localRunningX += step;
		i++;
	}
	// fill left
	while (i < GetNumItems())
	{
		GetItem(i).SetX((i - GetNumItems()) * step);
		i++;
	}
}

simulated function SetSelectedItem(UIPanel item)
{
	if (Navigator.GetSelected() != item)
	{
		Navigator.GetSelected().OnLoseFocus();
		Navigator.SetSelected(item);
	}
}

simulated function NavigatorSelectionChanged(int idx)
{
	local float scroll, leftDist, rightDist;
	local bool bNavigatedRight; // false = left, true = right
	local int iHelpIdx;

	if (prevIdx == idx || GetNumItems() <= maxChildren) return;

	iHelpIdx = idx;
	if (Abs(idx + GetNumItems() - prevIdx) < Abs(idx - prevIdx)) iHelpIdx += GetNumItems();
	if (Abs(idx - GetNumItems() - prevIdx) < Abs(idx - prevIdx)) iHelpIdx -= GetNumItems();
	bNavigatedRight = iHelpIdx - prevIdx > 0;
	prevIdx = idx;

	scroll = GetScrollGoalDelegate();
	LoopScroll(scroll);
	
	// rightDist is the amount of scroll to apply to the right in order to get idx to show
	rightDist = idx + scroll - (maxChildren - 1);
	if (rightDist > GetNumItems()) rightDist -= GetNumItems();
	// leftDist is the amount of scroll to apply to the left in order to get idx to show
	leftDist = GetNumItems() - idx - scroll;
	if (leftDist <= -maxChildren) leftDist += GetNumItems();

	if (rightDist < 0 || leftDist < 0) return;

	// use the path that won't make us go over the scrolling limit
	if (bDisAllowInfiniteScrolling)
	{
		if (scroll - rightDist >= 0)
		{
			ScrollCallback(-rightDist);
		}
		else
		{
			// assert(scroll + leftDist < 6 - maxChildren);
			ScrollCallback(leftDist);
		}
	}
	else
	{
		// use the shortest path, or, if both are the same, use the one we scrolled into
		if (Abs(leftDist - rightDist) < 1)
		{
			ScrollCallback(bNavigatedRight ? -rightDist : leftDist);
		}
		else if (leftDist < rightDist)
		{
			ScrollCallback(leftDist);
		}
		else
		{
			ScrollCallback(-rightDist);
		}	
	}
}

simulated function LoopScroll(out float fScr)
{
	local int iMax;
	iMax = Max(maxChildren, GetNumItems());
	while (fScr < 0)
		fScr += iMax;
	while (fScr >= iMax)
		fScr -= iMax;
}

simulated function UIPanel GetItem(int i)
{
	return ((i < 0 || i >= ItemContainer.ChildPanels.Length) ? none : ItemContainer.ChildPanels[i]);
}

simulated function int GetNumItems()
{
	return ItemContainer.ChildPanels.Length;
}

simulated function int GetItemCount()
{
	return GetNumItems();
}
/*
// bsg-jrebar (5/16/17): Gain/Remove focus for first selected item on UI
simulated function SelectFirstListItem()
{
	local UISquadSelect_ListItem ListItem, PrevListItem;
	local int Index;
	local bool bFoundIndex;

	// bsg-jrebar (5/30/17): Adding SelectFirst to select the old previously selected item slot or the actual first item in the list
	PrevListItem = UISquadSelect_ListItem(Navigator.GetSelected());

	if (PrevListItem != none)
	{
		PrevListItem.OnLoseFocus();
	}
	
	bFoundIndex = false;
	ListItem = UISquadSelect_ListItem(Navigator.GetSelected());
	if(ListItem != none)
	{
		bFoundIndex = true;
		Index = iSelectedIndex;
	}
	else
	{
	for (Index = 0; Index < GetNumItems(); Index++)
	{
		ListItem = UISquadSelect_ListItem(GetItem(Index));
		if (ListItem != none && !ListItem.bDisabled && ListItem.HasUnit())
		{
			bFoundIndex = true;
			break;
		}
	}

	if (!bFoundIndex)
	{
		for (Index = 0; Index < GetNumItems(); Index++)
		{
			ListItem = UISquadSelect_ListItem(GetItem(Index));
			if (ListItem != none && !ListItem.bDisabled)
			{
				break;
			}
		}
	}
	}
	// bsg-jrebar (5/30/17): end

	ListItem.OnReceiveFocus();
//	ListItem.SetNavigatorFocus();

	iSelectedIndex = Index;
}
// bsg-jrebar (5/16/17): end
*/

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	bHandled = true;
		
	switch (cmd)
	{
		default:
			bHandled = false;
			break;
	}
	return bHandled || Navigator.OnUnrealCommand(cmd, arg);

}