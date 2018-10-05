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
var protected int visibleChildren;

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
	visibleChildren = displayedChildren;
	theWidth = (displayedChildren * (ListItemClass.default.width + ItemPadding)) - ItemPadding;
	totalWidth = (numChildren * (ListItemClass.default.width + ItemPadding));
	SetSize(theWidth, 2000);
	

	ItemContainer = Spawn(class'UIPanel', self);
	ItemContainer.bCascadeFocus = false;
	ItemContainer.bIsNavigable = false;
	ItemContainer.InitPanel('ListItemContainer');
	
	Navigator = ItemContainer.Navigator.InitNavigator(self); // set owner to be self;
	Navigator.RemoveControl(ItemContainer); // remove container
	Navigator.LoopSelection = true; //!class'robojumper_SquadSelectConfig'.static.DisAllowInfiniteScrolling(); causes navigation issues
	Navigator.OnlyUsesNavTargets = true;
	//Navigator.OnSelectedIndexChanged = NavigatorSelectionChanged;

	runningX = 0;
	for (i = 0; i < NumChildren; i++)
	{
		Spawn(ListItemClass, ItemContainer).InitPanel().SetX(runningX);
		runningX += ListItemClass.default.width + ItemPadding;
	}

	for (i = 0; i < NumChildren; i++)
	{
		if (i == 0)
		{
			GetItem(NumChildren - 1).Navigator.AddHorizontalNavTarget(GetItem(i));
		}
		else
		{
			GetItem(i - 1).Navigator.AddHorizontalNavTarget(GetItem(i));
		}
	}

	TheMask = Spawn(class'UIMask', self).InitMask('ListMask');
	TheMask.SetMask(ItemContainer);
	TheMask.SetSize(Width, Height);
	TheMask.SetY(-1000);
	if (`ISCONTROLLERACTIVE)
	{
		// without this, we somehow enter the navigation cycle without using our navigator at all
		Navigator.SelectFirstAvailable();
	}
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

	ContainerX = -fScroll * (ListItemClass.default.width + ItemPadding);
	// now that just moves stuff out of here
	ItemContainer.SetX(ContainerX);
	ReorganizeListItems();
	
}

simulated function ReorganizeListItems()
{
	local int i, step;
	local int numItems;

	numItems = GetNumItems();
	step = (ItemPadding + ListItemClass.default.width);
	for (i = 0; i < numItems; i++)
	{
		if ((i + 1) * step < -ItemContainer.X)
		{
			GetItem(i).SetX((i + numItems) * step);
		}
		else
		{
			GetItem(i).SetX(i * step);
		}
	}
}

simulated function NavigatorSelectionChangedPanel(UIPanel panel)
{
	NavigatorSelectionChanged(ItemContainer.GetChildIndex(panel));
}

simulated function NavigatorSelectionChanged(int idx)
{
	local float scroll, leftDist, rightDist;
	local bool bNavigatedRight; // false = left, true = right
	local int iHelpIdx;

	if (prevIdx == idx || GetNumItems() <= visibleChildren) return;

	iHelpIdx = idx;
	if (Abs(idx + GetNumItems() - prevIdx) < Abs(idx - prevIdx)) iHelpIdx += GetNumItems();
	if (Abs(idx - GetNumItems() - prevIdx) < Abs(idx - prevIdx)) iHelpIdx -= GetNumItems();
	bNavigatedRight = iHelpIdx - prevIdx > 0;
	prevIdx = idx;

	scroll = GetScrollGoalDelegate();
	LoopScroll(scroll);
	
	// rightDist is the amount of scroll to apply to the right in order to get idx to show
	rightDist = idx - scroll - (visibleChildren - 1);
	if (rightDist <= -visibleChildren) rightDist += GetNumItems();
	// leftDist is the amount of scroll to apply to the left in order to get idx to show
	leftDist = GetNumItems() - idx + scroll;
	if (leftDist >= GetNumItems()) leftDist -= GetNumItems();

	if (rightDist < 0 || leftDist < 0) return;

	// use the path that won't make us go over the scrolling limit
	if (bDisAllowInfiniteScrolling)
	{
		if (scroll - leftDist >= 0)
		{
			ScrollCallback(-leftDist);
		}
		else
		{
			ScrollCallback(rightDist);
		}
	}
	else
	{
		// use the shortest path, or, if both are the same, use the one we scrolled into
		if (Abs(leftDist - rightDist) < 1)
		{
			ScrollCallback(bNavigatedRight ? rightDist : -leftDist);
		}
		else if (leftDist < rightDist)
		{
			ScrollCallback(-leftDist);
		}
		else
		{
			ScrollCallback(rightDist);
		}	
	}
}

simulated function LoopScroll(out float fScr)
{
	local int iMax;
	iMax = GetNumItems();
	if (iMax > visibleChildren)
	{
		while (fScr < 0)
			fScr += iMax;
		while (fScr >= iMax)
			fScr -= iMax;
	}
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
