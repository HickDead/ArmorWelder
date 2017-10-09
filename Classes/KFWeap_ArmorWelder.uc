//=============================================================================
// KFWeap_ArmorWelder
//=============================================================================
// Weapon class used for the welder
//=============================================================================
// Killing Floor 2
// Copyright (C) 2015 Tripwire Interactive LLC, Andrew "Strago" Ladenberger
// Copyright (C) 2017 HickDead
//=============================================================================
class KFWeap_ArmorWelder extends KFWeap_Welder
	hidedropdown;

/** Reference to the actor we're pointing at */
var Actor WeldTargetActor;


/** Turn on the UI screen when we equip the healer */
simulated function AttachWeaponTo( SkeletalMeshComponent MeshCpnt, optional Name SocketName )
{
	super.AttachWeaponTo( MeshCpnt, SocketName );

	if( Instigator != none && Instigator.IsLocallyControlled() )
	{
		// Create the screen's UI piece
		if (ScreenUI == none)
		{
			ScreenUI = new( self ) ScreenUIClass;
			ScreenUI.Init();
			ScreenUI.Start(true);
		}

		if ( ScreenUI != none)
		{
			ScreenUI.SetPause(false);
			ScreenUI.SetCharge( AmmoCount[0] );
			ScreenUI.SetIntegrity( 255 );
		}
	}
}

/** Only update the screen screen if we have the welder equipped and it's screen values have changed */
simulated function UpdateScreenUI()
{
	local float WeldPercentageFloat;
	local byte WeldPercentage;
	local KFDoorActor DoorTarget;
	local KFPawn_Human HumanTarget;

	if ( Instigator != none && Instigator.IsLocallyControlled() && Instigator.Weapon == self )
	{
		if ( ScreenUI != none )
		{
			// Check if our current ammo reading has changed
			if ( ScreenUI.CurrentCharge != AmmoCount[0] )
			{
				ScreenUI.SetCharge( AmmoCount[0] );
			}

			DoorTarget=KFDoorActor(WeldTargetActor);
			HumanTarget=KFPawn_Human(WeldTargetActor);

			if ( DoorTarget != none )
			{
				// Address rounding errors in UI
				WeldPercentageFloat = ( float(DoorTarget.WeldIntegrity) / float(DoorTarget.MaxWeldIntegrity) ) * 100.f;
				if( WeldPercentageFloat < 1.f && WeldPercentageFloat > 0.f )
				{
					WeldPercentageFloat = 1.f;
				}
				else if( WeldPercentageFloat > 99.f && WeldPercentageFloat < 100.f )
				{
					WeldPercentageFloat = 99.f;
				}

				WeldPercentage = byte( WeldPercentageFloat );
				// Check if our weld integrity has changed
				if ( WeldPercentage != ScreenUI.IntegrityPercentage )
				{
					ScreenUI.SetIntegrity( WeldPercentage );
				}
			}
			else if ( HumanTarget != none )
			{
				// Address rounding errors in UI
				WeldPercentageFloat = ( float(HumanTarget.Armor) / float(HumanTarget.MaxArmor) ) * 100.f;
				if( WeldPercentageFloat < 1.f && WeldPercentageFloat > 0.f )
				{
					WeldPercentageFloat = 1.f;
				}
				else if( WeldPercentageFloat > 99.f && WeldPercentageFloat < 100.f )
				{
					WeldPercentageFloat = 99.f;
				}


				WeldPercentage = byte( WeldPercentageFloat );
				// Check if our weld integrity has changed
				if ( WeldPercentage != ScreenUI.IntegrityPercentage )
				{
					ScreenUI.SetIntegrity( WeldPercentage );
				}
			}

			// Remove our weld value
			else if ( ScreenUI.IntegrityPercentage != 255 )
			{
				ScreenUI.SetIntegrity( 255 );
			}
		}
	}
}

/*********************************************************************************************
 * @name Ammunition
 *********************************************************************************************/

simulated function bool HasAmmo( byte FireModeNum, optional int Amount )
{
	if ( FireModeNum == DEFAULT_FIREMODE || FireModeNum == ALTFIRE_FIREMODE )
	{
		if ( AmmoCount[0] >= AmmoCost[FireModeNum])
		{
			// Requires a valid WeldTarget (see ServerSetWeldTarget)
			return ( WeldTargetActor != None && CanWeldTarget(FireModeNum) );
		}
		return false;
	}

	return Super.HasAmmo(FireModeNum, Amount);
}

/*********************************************************************************************
 @name Firing / Projectile
********************************************************************************************* */

/**
 * @see Weapon::StartFire
 */
simulated function StartFire(byte FireModeNum)
{
	// Notify server of the weld target we plan to use
	if ( FireModeNum == DEFAULT_FIREMODE || FireModeNum == ALTFIRE_FIREMODE )
	{
		if ( Role < ROLE_Authority )
		{
			ServerSetWeldTarget(WeldTargetActor, false);
		}
	}

	Super.StartFire(FireModeNum);
}

/**
 * If the weapon isn't an instant hit, or a simple projectile, it should use the type EWFT_Custom.  In those cases
 * this function will be called.  It should be subclassed by the custom weapon.
 */
simulated function CustomFire()
{
	local float CurrentFastenRate, CurrentUnfastenRate;
	local KFDoorActor DoorTarget;
	local KFPawn_Human HumanTarget;

	WeldTargetActor = TraceWeldActors();
	DoorTarget=KFDoorActor(WeldTargetActor);
	HumanTarget=KFPawn_Human(WeldTargetActor);

	// Fasten/Unfasten the door
	if ( Role == ROLE_Authority )
	{
		if ( DoorTarget != None )
		{
			CurrentFastenRate = FastenRate;
			CurrentUnfastenRate = UnFastenRate;

			GetPerk().ModifyWeldingRate(CurrentFastenRate, CurrentUnfastenRate);
			SetTimer(AmmoRechargeRate, true, nameof(RechargeAmmo));

			if ( DoorTarget.bIsDestroyed )
			{
				DoorTarget.RepairDoor(RepairRate, KFPawn(Instigator));
			}
			else if ( CurrentFireMode == DEFAULT_FIREMODE )
			{
				DoorTarget.FastenDoor(CurrentFastenRate, KFPawn(Instigator));
			}
			else
			{
				DoorTarget.FastenDoor(CurrentUnfastenRate, KFPawn(Instigator));
			}
		}
		else if ( HumanTarget != None )
		{
			CurrentFastenRate = FastenRate;
			CurrentUnfastenRate = UnFastenRate;

			GetPerk().ModifyWeldingRate(CurrentFastenRate, CurrentUnfastenRate);
			SetTimer(AmmoRechargeRate, true, nameof(RechargeAmmo));

			if ( HumanTarget.Armor > 0.0 )
			{
				if ( CurrentFireMode == DEFAULT_FIREMODE )
				{
					HumanTarget.Armor++;
				}
				else
				{
					HumanTarget.Armor--;
				}
			}
		}
	}

	// On the local player check to see if we should stop firing
	// It makes sense to do this in ShouldRefire(), but there is no guarantee
	// that it will sync on server/client.  So, use StopFire() instead.
	if ( Instigator.IsLocallyControlled() )
	{
		if ( WeldTargetActor == none || !CanWeldTarget() )
		{
			// TargetActor is no longer valid
			StopFire(CurrentFireMode);
		}
	}
}

simulated function bool CanWeldTarget( optional int FireModeNum=CurrentFireMode )
{
	local KFPerk WelderPerk;
	local KFDoorActor DoorTarget;
	local KFPawn_Human HumanTarget;

	WelderPerk = GetPerk();
	DoorTarget=KFDoorActor(WeldTargetActor);
	HumanTarget=KFPawn_Human(WeldTargetActor);

	if ( DoorTarget != None )
	{

		if ( FireModeNum == DEFAULT_FIREMODE &&
			 DoorTarget.WeldIntegrity >= DoorTarget.MaxWeldIntegrity )
		{
			if( WelderPerk != none && WelderPerk.CanExplosiveWeld() )
			{
				return DoorTarget.DemoWeld < DoorTarget.default.DemoWeldRequired;
			}

			return false;
		}
		else if ( FireModeNum == ALTFIRE_FIREMODE &&
				DoorTarget.WeldIntegrity <= 0 )
		{
			return false;
		}

	}
	else if ( HumanTarget != None )
	{
		if ( FireModeNum == DEFAULT_FIREMODE && HumanTarget.Armor >= HumanTarget.MaxArmor )
		{
			return false;
		}
		else if ( FireModeNum == ALTFIRE_FIREMODE && HumanTarget.Armor <= 0 )
		{
			return false;
		}
	}


	return true;
}

/** If we recieve a valid target after the fire key was already pressed down */
simulated function CheckDelayedStartFire()
{
	local bool bNotifyServer;

	if ( WeldTargetActor != None )
	{
		if( PendingFire(DEFAULT_FIREMODE) )
		{
			BeginFire(DEFAULT_FIREMODE);
			bNotifyServer = true;
		}
		else if( PendingFire(ALTFIRE_FIREMODE) )
		{
			BeginFire(ALTFIRE_FIREMODE);
			bNotifyServer = true;
		}

		if ( bNotifyServer && Role < ROLE_Authority )
		{
			ServerSetWeldTarget(WeldTargetActor, true);
		}
	}
}

/*********************************************************************************************
 @name WeldTargetActor
********************************************************************************************* */

/**
 * Find actors within welding range
 * Network: Local Player
 */
simulated function bool TickWeldTarget()
{
	local Actor PreviousTarget;

	// prevent state from changing too often (also a optimization)
	if ( `TimeSince(LastTraceHitTime) < 0.2f )
	{
		return false;
	}

	PreviousTarget = WeldTargetActor;
	WeldTargetActor = TraceWeldActors();

	// refresh idle anim if Target has changed
	if ( PreviousTarget != WeldTargetActor )
	{
		return PlayIdleReadyTransition(PreviousTarget);
	}

	return false;
}

/** Network: All */
simulated function Actor TraceWeldActors()
{
	local KFDoorActor Door;
	local KFPawn_Human Player;
	local vector HitLoc, HitNorm, StartTrace, EndTrace, AdjustedAim;

	// define range to use for CalcWeaponFire()
	StartTrace = Instigator.GetWeaponStartTraceLocation();
	AdjustedAim = vector(GetAdjustedAim(StartTrace));
	EndTrace = StartTrace + AdjustedAim * WeldingRange;

	// Give the welder extra range when it has a WeldTarget to avoid the ready animation 
	// activating / deactivating on actor that is is currently being damaged 
	if( WeldTargetActor != none )
	{
		EndTrace += AdjustedAim * ExtraWeldingRange;
	}

	// find door actor
	foreach GetTraceOwner().TraceActors(class'KFDoorActor', Door, HitLoc, HitNorm, StartTrace, EndTrace)
	{
		if ( !Door.bIsDestroyed )
		{
			LastTraceHitTime = WorldInfo.TimeSeconds;
			return Door;
		}
	}

	// find player actor
	foreach GetTraceOwner().TraceActors(class'KFPawn_Human', Player, HitLoc, HitNorm, StartTrace, EndTrace)
	{
		if( Player.Health > 0 && Player.Armor < Player.MaxArmor )
		{
			LastTraceHitTime = WorldInfo.TimeSeconds;
			return Player;
		}
	}

	return FindRepairableDoor();
}

/** Notify server of new WeldTarget for 'HasAmmo' */
reliable server private function ServerSetWeldTarget(Actor NewTarget, bool bDelayedStart)
{
	WeldTargetActor = NewTarget;

	if ( bDelayedStart )
	{
		CheckDelayedStartFire();
	}
}

/** Play a transition animation between idle ready states */
simulated function bool PlayIdleReadyTransition(Actor PreviousTarget)
{
	local name AnimName;
	local float Duration;

	if( WeldTargetActor != None )
	{
		AnimName = WeldOpenAnim;
		// set timer to begin firing if PendingFire is already set
		if ( PreviousTarget == None )
		{
			Duration = MySkelMesh.GetAnimLength(AnimName);
			SetTimer(FMax(Duration - 0.2f, 0.01f), false, nameof(CheckDelayedStartFire));
		}
	}
	else if( PreviousTarget != None )
	{
		AnimName = WeldCloseAnim;
	}

	if ( AnimName != '' )
	{
		PlayAnimation(AnimName);
		return true;
	}

	return false;
}

/*********************************************************************************************
 * state Inactive
 * This state is the default state.  It needs to make sure Zooming is reset when entering/leaving
 *********************************************************************************************/

auto state Inactive
{
	simulated function BeginState(name PreviousStateName)
	{
		Super.BeginState(PreviousStateName);
		WeldTargetActor = none;
	}
}

/*********************************************************************************************
 * State Active
 * A Weapon this is being held by a pawn should be in the active state.  In this state,
 * a weapon should loop any number of idle animations, as well as check the PendingFire flags
 * to see if a shot has been fired.
 *********************************************************************************************/

simulated state Active
{
	/** Event called when weapon enters this state */
	simulated event BeginState(Name PreviousStateName)
	{
		Super.BeginState(PreviousStateName);
	}

	simulated event Tick(float DeltaTime)
	{
		// Caution - Super will skip our global, but global will skip super's state function!
		Global.Tick(DeltaTime);

		if ( Instigator != none && Instigator.IsLocallyControlled() )
		{
			// local player - find nearbydoors
			TickWeldTarget();	// will trace each call, but it's decently fast (zero-extent)
			UpdateScreenUI();

			if ( !bAutoUnequip )
			{
				TickAutoUnequip();
			}
		}
	}

	simulated event OnAnimEnd(AnimNodeSequence SeqNode, float PlayedTime, float ExcessTime)
	{
		local bool bPlayingAnim;

		if ( Instigator != none && Instigator.IsLocallyControlled() )
		{
			// Update target immediately and enable tick (first time)
			bPlayingAnim = TickWeldTarget();

			// if animation didn't play in UpdateWeldTarget, play idle normally
			if ( !bPlayingAnim )
			{
				PlayIdleAnim();
			}
		}
	}

	simulated function PlayIdleAnim()
	{
		local int IdleIndex;

		if ( Instigator != none && Instigator.IsLocallyControlled() )
		{
			if( WeldTargetActor != None )
			{
				PlayAnimation(IdleWeldAnim, 0.0, true, 0.2);
			}
			else
			{
				IdleIndex = Rand(IdleAnims.Length);
				PlayAnimation(IdleAnims[IdleIndex], 0.0, true, 0.2);
			}
		}
	}
}

defaultproperties
{
	InventoryGroup=IG_None
	bCanThrow=false
	bDropOnDeath=false
	bAutoUnequip=true

	PlayerViewOffset=(X=20.0,Y=10,Z=-10)

	FireTweenTime=0.2f
	WeldingRange=100.f
	ExtraWeldingRange=10
	FastenRate=68.f
	UnFastenRate=-110.f
	RepairRate=0.03f  //0.05f
	IdleWeldAnim=Idle_Weld
	WeldOpenAnim=Weld_On
	WeldCloseAnim=Weld_Off

	// Aim Assist
	AimCorrectionSize=0.f
	bTargetAdhesionEnabled=false
	
	// Ammo
	MagazineCapacity[0]=100
	SpareAmmoCapacity[0]=0
	bInfiniteSpareAmmo=true
	AmmoRechargeRate=0.08f
	bAllowClientAmmoTracking=false

	// Grouping
	GroupPriority=5
	WeaponSelectTexture=Texture2D'ui_weaponselect_tex.UI_WeaponSelect_Welder'

	// Weld
	FireModeIconPaths(DEFAULT_FIREMODE)=Texture2D'ui_firemodes_tex.UI_FireModeSelect_Electricity'
	FiringStatesArray(DEFAULT_FIREMODE)=WeaponWelding
	WeaponFireTypes(DEFAULT_FIREMODE)=EWFT_Custom
	FireInterval(DEFAULT_FIREMODE)=+0.2
	AmmoCost(DEFAULT_FIREMODE)=7

	// Un-Weld
	FireModeIconPaths(ALTFIRE_FIREMODE)=Texture2D'ui_firemodes_tex.UI_FireModeSelect_Electricity'
	FiringStatesArray(ALTFIRE_FIREMODE)=WeaponWelding
	WeaponFireTypes(ALTFIRE_FIREMODE)=EWFT_Custom
	FireInterval(ALTFIRE_FIREMODE)=+0.2
	AmmoCost(ALTFIRE_FIREMODE)=7

	// Fire Effects
	MuzzleFlashTemplate=KFMuzzleFlash'WEP_Welder_ARCH.Wep_Welder_MuzzleFlash'
	WeaponFireSnd(DEFAULT_FIREMODE)=(DefaultCue=AkEvent'WW_WEP_SA_Welder.Play_WEP_SA_Welder_Fire_Loop_M', FirstPersonCue=AkEvent'WW_WEP_SA_Welder.Play_WEP_SA_Welder_Fire_Loop_S')
	WeaponFireSnd(ALTFIRE_FIREMODE)=(DefaultCue=AkEvent'WW_WEP_SA_Welder.Play_WEP_SA_Welder_Fire_Loop_M', FirstPersonCue=AkEvent'WW_WEP_SA_Welder.Play_WEP_SA_Welder_Fire_Loop_S')

	// BASH_FIREMODE
	InstantHitDamageTypes(BASH_FIREMODE)=class'KFDT_Bludgeon_Welder'
	InstantHitDamage(BASH_FIREMODE)=20

	// Advanced (High RPM) Fire Effects
	bLoopingFireAnim(DEFAULT_FIREMODE)=true
	bLoopingFireAnim(ALTFIRE_FIREMODE)=true
	bLoopingFireSnd(DEFAULT_FIREMODE)=true
	bLoopingFireSnd(ALTFIRE_FIREMODE)=true
	WeaponFireLoopEndSnd(DEFAULT_FIREMODE)=(DefaultCue=AkEvent'WW_WEP_SA_Welder.Stop_WEP_SA_Welder_Fire_Loop_M', FirstPersonCue=AkEvent'WW_WEP_SA_Welder.Stop_WEP_SA_Welder_Fire_Loop_S')

	Begin Object Name=FirstPersonMesh
		SkeletalMesh=SkeletalMesh'WEP_1P_Welder_MESH.Wep_1stP_Welder_Rig'
		AnimSets(0)=AnimSet'WEP_1P_Welder_ANIM.Wep_1st_Welder_Anim'
	End Object

	ScreenUIClass=class'KFGFxWorld_WelderScreen'

	AttachmentArchetype=KFWeaponAttachment'WEP_Welder_ARCH.Welder_3P'

	AssociatedPerkClasses(0)=none
}
