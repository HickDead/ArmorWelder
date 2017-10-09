//=============================================================================
// KFWeapDef_ArmorWelder
//=============================================================================
// A lightweight container for basic weapon properties that can be safely
// accessed without a weapon actor (UI, remote clients). 
//=============================================================================
// Killing Floor 2
// Copyright (C) 2015 Tripwire Interactive LLC
// Copyright (C) 2017 HickDead
//=============================================================================
class KFWeapDef_ArmorWelder extends KFWeaponDefinition
	abstract;

DefaultProperties
{
	WeaponClassPath="ArmorWelder.KFWeap_ArmorWelder"

	BuyPrice=1700
	AmmoPricePerMag=100
	ImagePath="ui_weaponselect_tex.UI_WeaponSelect_Welder"
}
