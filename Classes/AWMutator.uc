/*
 *
 *	AWMutator, replaces the welder with one that can repair armor
 *
 *	Copyright 2017 Kavoh, HickDead
 */

class AWMutator extends KFMutator
;



var private const class<KFWeapon> NewWelder;


private final function ReplaceWelder(Pawn P)
{
    local KFInventoryManager KFIM;
    local KFWeapon OldWelder;
    
    KFIM = KFInventoryManager(KFPawn(P).InvManager);
    
    if (KFIM != none)
    {
        KFIM.GetWeaponFromClass(OldWelder, 'KFWeap_Welder');
        
        if (OldWelder != none)
            KFIM.ServerRemoveFromInventory(OldWelder);
        
        if (NewWelder != none)
        {
            KFIM.CreateInventory(NewWelder /*, false*/);
            `log( "=== ArmorWelder === Replaced welder");
	}

    }
}

function ModifyPlayer(Pawn P)
{
    Super.ModifyPlayer(P);
    
    if (P != none)
        ReplaceWelder(P);
}


defaultproperties
{
    NewWelder=Class'ArmorWelder.KFWeap_ArmorWelder'
}

