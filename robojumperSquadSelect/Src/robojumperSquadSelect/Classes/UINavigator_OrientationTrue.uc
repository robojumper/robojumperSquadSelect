// there is an issue in UINavigator that causes cascaded lists with different orientations to not work properly
class UINavigator_OrientationTrue extends UINavigator;

var bool bAllowCyclingOnRepeat;

// this currently only handles commands downwards
// TODO: evaluate upwards handling
// by not passing enough upwards, we may lock ourselves
// probably use ALL parents (iteratively) and check if their navigation style matches

public function bool Next(optional bool ReturningFromChild = false, optional bool bNewFocus = false, optional bool IsRepeat = false)
{
	local bool HandledByChild; 
	local bool HandledByOwner;
	local int PrevSelectedIndex;
	local UIPanel NavigableControl;
	local UIPanel SelectedControl;
	local int ChildIndex;

	if(Size == 0)
		return false;
	ChildIndex = -1;

	// If our Control was unfocused, then we need to force the direction that we are entering from,
	// because we're in Next() so we know what the selection will need to be. 
	if( !OwnerControl.IsSelectedNavigation() )
		SelectedIndex = -1;

	// See if children of our NavigableControls want to control handle this command,
	// but only if this request hasn't come cascading upwards from a child already. 
	if(!ReturningFromChild)
	{
		SelectedControl = GetSelected();

		if(SelectedControl != none && SelectedControl.Navigator.HorizontalNavigation == HorizontalNavigation)
		{
			HandledByChild = SelectedControl.Navigator.Next(,, IsRepeat);
		}
		else
		{
			foreach NavigableControls(NavigableControl)
			{
				// robojumper: FXS, you forgot this here
				ChildIndex++;
				if(NavigableControl.Navigator.HorizontalNavigation == HorizontalNavigation && NavigableControl.Navigator.Next(,, IsRepeat))
				{
					HandledByChild = true;
					break;
				}
			}
		}
	}

	if(HandledByChild)
	{
		if(SelectedIndex < 0)
		{
			SelectedIndex = ChildIndex;
			SelectedControl = GetSelected();
			if(SelectedControl != none)
				SelectedControl.OnReceiveFocus();
		}
		return true;
	}
	else
	{
		ChildIndex = -1;
		//Do we need to LoopSelection? 
		PrevSelectedIndex = SelectedIndex++;
		if(SelectedIndex >= Size)
		{
			if(LoopSelection || (LoopOnReceiveFocus && bNewFocus))
			{
				//no loop when holding down
				if (IsRepeat && !bAllowCyclingOnRepeat && !bNewFocus) //Added !bNewFocus condition - BET 2016-04-14
				{
					SelectedIndex--;
					return true;
				}
				SelectedIndex = 0;
			}
			else
			{
				// We've hit an end cap of our local Control's items, so we need to report upwards to go to the next item if possible. 
				if( OwnerControl.ParentPanel != none )
					HandledByOwner = OwnerControl.ParentPanel.Navigator.Next(true,, IsRepeat);

				// Set to out of range endcap values, so we can see which way we left this object for debugging purposes. 
				if( HandledByOwner )
					SelectedIndex = Size;
				else
					SelectedIndex--;
			}
		}
		if(ReturningFromChild && size == 1 && OwnerControl.ParentPanel.Navigator.Size == 1)
		{
			return true;
		}

		// Always lose focus on the previously selected element, in case the Control UIPanel is losing focus 
		if( IsValid(PrevSelectedIndex) && SelectedIndex != PrevSelectedIndex && NavigableControls[PrevSelectedIndex].bIsFocused)
			NavigableControls[PrevSelectedIndex].OnLoseFocus();

		if(SelectedIndex != PrevSelectedIndex)
		{
			// Pass down recursively to any children for notification
			// ORDER MATTERS: must call Next() before OnReceiveFocus() to successfully see which way we are entering 
			// a previously unfocused object and set the correct SelectedIndex accordingly. 
			SelectedControl = GetSelected();
			if(SelectedControl != none)
			{
				//TODO: BSTEINER: evaluate 
				//<workshop> Unbreak the navigator SCI 2015/11/16
				//WAS:
				//if (SelectedControl.Navigator.OwnerControl == none ||
				//	SelectedControl.Navigator.OwnerControl.ParentPanel == none ||
				//	SelectedControl.Navigator.OwnerControl.ParentPanel.Navigator != SelectedControl.Navigator)
				//{
				//	SelectedControl.Navigator.Next(ReturningFromChild, true);
				//	SelectedControl.OnReceiveFocus();
				//}
				// robojumper: WTF?
				//SelectedControl.Navigator.Next(ReturningFromChild, true, IsRepeat);
				SelectedControl.OnReceiveFocus();
				//</workshop>
			}

			if(OnSelectedIndexChanged != none)
				OnSelectedIndexChanged(SelectedIndex);
			return true;
		}
	}

	// If we went in to an area where the Control handled our upward-cascade request, then report successful handling internally. 
	return HandledByOwner;
}

// FALSE means we've lost focus.
// TRUE means we've handled this internally.
public function bool Prev( optional bool ReturningFromChild = false, optional bool bNewFocus = false, optional bool IsRepeat = false)
{
	local bool HandledByChild; 
	local bool HandledByOwner;
	local int PrevSelectedIndex;
	local UIPanel NavigableControl;
	local UIPanel SelectedControl;
	local int ChildIndex;

	if(Size == 0)
		return false;
	ChildIndex = -1;

	// If our Control was unfocused, then we need to force the direction that we are entering from, 
	// because we're in Prev() so we know what the selection will need to be. 
	if( !OwnerControl.IsSelectedNavigation() )
		SelectedIndex = Size;

	// See if children of our NavigableControls want to control handle this command,
	// but only if this request hasn't come cascading upwards from a child already. 
	if(!ReturningFromChild)
	{
		SelectedControl = GetSelected();
		if(SelectedControl != none && SelectedControl.Navigator.HorizontalNavigation == HorizontalNavigation)
		{
			HandledByChild = SelectedControl.Navigator.Prev(,, IsRepeat);
		}
		else
		{
			foreach NavigableControls(NavigableControl)
			{
				ChildIndex++;
				if(NavigableControl.Navigator.HorizontalNavigation == HorizontalNavigation && NavigableControl.Navigator.Prev(,, IsRepeat))
				{
					HandledByChild = true;
					break;
				}
			}
		}
	}

	if(HandledByChild)
	{
		if(SelectedIndex < 0)
		{
			SelectedIndex = ChildIndex;
			SelectedControl = GetSelected();
			if(SelectedControl != none)
				SelectedControl.OnReceiveFocus();
		}
		return true;
	}
	else
	{
		ChildIndex = -1;
		//Do we need to LoopSelection? 
		PrevSelectedIndex = SelectedIndex--;
		if(SelectedIndex < 0)
		{
			if(LoopSelection || (LoopOnReceiveFocus && bNewFocus))
			{
				//no loop when holding down
				if (IsRepeat && !bAllowCyclingOnRepeat && !bNewFocus) //Added !bNewFocus condition - BET 2016-04-14
				{
					SelectedIndex++;
					return true;
				}
				SelectedIndex = Size - 1;
			}
			else
			{
				// We've hit an end cap of our local Control's items, so we need to report upwards to go to the next item if possible. 
				if( OwnerControl.ParentPanel != none )
					HandledByOwner = OwnerControl.ParentPanel.Navigator.Prev(true,, IsRepeat);

				// Set to out of range endcap values, so we can see which way we left this object for debugging purposes. 
				if( HandledByOwner )
					SelectedIndex = -1; 
				else
					SelectedIndex++;
			}
		}
		if(ReturningFromChild && size == 1 && OwnerControl.ParentPanel.Navigator.Size == 1)
		{
			return true;
		}

		// Always lose focus on the previously selected element, in case the Control UIPanel is losing focus 
		if( IsValid(PrevSelectedIndex) && SelectedIndex != PrevSelectedIndex && NavigableControls[PrevSelectedIndex].bIsFocused )
			GetControl(PrevSelectedIndex).OnLoseFocus();

		if(SelectedIndex != PrevSelectedIndex)
		{
			// Pass down recursively to any children for notification
			// ORDER MATTERS: must call Prev() before OnReceiveFocus() to successfully see which way we are entering 
			// a previously unfocused object and set the correct SelectedIndex accordingly. 
			SelectedControl = GetSelected();
			if(SelectedControl != none)
			{
				// TODO: bsteiner evaluate 
				//<workshop> Unbreak the navigator SCI 2015/11/16
				//WAS:
				//if (SelectedControl.Navigator.OwnerControl == none ||
				//	SelectedControl.Navigator.OwnerControl.ParentPanel == none ||
				//	SelectedControl.Navigator.OwnerControl.ParentPanel.Navigator != SelectedControl.Navigator)
				//{
				//	SelectedControl.Navigator.Prev(ReturningFromChild, true);
				//	SelectedControl.OnReceiveFocus();
				//}
				// robojumper: WTF?
				//SelectedControl.Navigator.Prev(ReturningFromChild, true, IsRepeat);
				SelectedControl.OnReceiveFocus();
				//</workshop>
			}

			if(OnSelectedIndexChanged != none)
				OnSelectedIndexChanged(SelectedIndex);

			return true;
		}
	}

	// If we went in to an area where the Control handled our upward-cascade request, then report successful handling internally.
	return HandledByOwner;
}
