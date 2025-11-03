using { /Fortnite.com/Devices }
using { /Fortnite.com/UI }
using { /Verse.org/Simulation }
using { /Verse.org/Colors }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/UI }
using { /Fortnite.com/AI }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }

# A Verse-authored creative device for bounty hunting gameplay
bounty_game_device := class(creative_device):

    # Editable devices for bounty placement and skipping
    @editable
    PlaceBountyTrigger:trigger_device = trigger_device{}
    
    @editable
    SkipBountyTrigger:trigger_device = trigger_device{}
    
    @editable
    BountyTargetSpawner:guard_spawner_device = guard_spawner_device{}
    
    @editable
    ShowBountyUITrigger:volume_device = volume_device{}
    
    @editable
    RemoveTriggers:[]volume_device = array{}
    
    @editable
    RemoveTeleporters:[]teleporter_device = array{}

    # UI and state management
    var BountyUI:overlay = overlay{}
    var ActiveDecisionAgent:?agent = false
    var CurrentBountyTarget:?agent = false
    var BountyActive:logic = false
    var BountiesCompleted:int = 0
    
    # Initialize the device
    OnBegin<override>()<suspends>:void =
        # Subscribe to trigger events
        PlaceBountyTrigger.TriggeredEvent.Subscribe(OnPlaceBounty)
        SkipBountyTrigger.TriggeredEvent.Subscribe(OnSkipBounty)
        
        # Subscribe to volume events for UI management
        ShowBountyUITrigger.AgentEntersEvent.Subscribe(ShowBountyUI)
        
        # Subscribe to reset triggers
        for (RemoveTrigger : RemoveTriggers):
            RemoveTrigger.AgentEntersEvent.Subscribe(ResetBountySystem)
        
        for (Teleporter : RemoveTeleporters):
            Teleporter.TeleportedEvent.Subscribe(ResetBountySystem)
        
        # Subscribe to bounty target spawner events
        BountyTargetSpawner.SpawnedEvent.Subscribe(OnBountyTargetSpawned)
        BountyTargetSpawner.EliminatedEvent.Subscribe(OnBountyTargetEliminated)
        
        # Initialize triggers as disabled
        PlaceBountyTrigger.Disable()
        SkipBountyTrigger.Disable()

    # Event handler for placing a bounty
    OnPlaceBounty(InAgent:?agent):void =
        Print("Place Bounty Triggered")
        
        if (Agent := InAgent?):
            # Set the active decision agent
            set ActiveDecisionAgent = option{Agent}
            
            # Spawn the bounty target
            if (BountyTargetSpawner.GetNumberActiveGuards() = 0):
                BountyTargetSpawner.Enable()
                BountyTargetSpawner.Spawn()
                set BountyActive = true
                
                Print("Bounty placed - Target spawned")
            
            # Disable both triggers while bounty is active
            DisableBountyTriggers()

    # Event handler for skipping a bounty
    OnSkipBounty(InAgent:?agent):void =
        Print("Skip Bounty Triggered")
        
        if (Agent := InAgent?):
            # Check if this is the agent who placed the bounty
            if (ActiveAgent := ActiveDecisionAgent?):
                if (ActiveAgent = Agent):
                    # Skip the current bounty
                    ClearCurrentBounty()
                    Print("Bounty skipped by decision agent")
                else:
                    Print("Only the decision agent can skip the bounty")

    # Show the bounty UI when agent enters the volume
    ShowBountyUI(InAgent:agent):void =
        Print("Showing Bounty UI")
        
        for:
            Player : GetPlayspace().GetPlayers()
            PlayerUI := GetPlayerUI[Player]
        do:
            PlayerUI.AddWidget(BountyUI)
        
        # Enable the bounty placement trigger
        PlaceBountyTrigger.Enable()

    # Event handler for when bounty target is spawned
    OnBountyTargetSpawned(InAgent:agent):void =
        Print("Bounty Target Spawned")
        set CurrentBountyTarget = option{InAgent}
        
        # Optional: Update UI to show active bounty
        if (FortChar := InAgent.GetFortCharacter[]):
            TargetHealth := FortChar.GetHealth()
            Print("Bounty target health: {TargetHealth}")

    # Event handler for when bounty target is eliminated
    OnBountyTargetEliminated(Result:device_ai_interaction_result):void =
        Print("Bounty Target Eliminated")
        
        if (Target := Result.Target?):
            # Award bounty completion
            set BountiesCompleted += 1
            Print("Bounties completed: {BountiesCompleted}")
            
            # Clear the current bounty
            ClearCurrentBounty()
            
            # Re-enable triggers for next bounty
            EnableBountyTriggers()

    # Disable both bounty triggers
    DisableBountyTriggers():void =
        Print("Disabling bounty triggers")
        
        # Disable place bounty trigger
        PlaceBountyTrigger.Disable()
        
        # Disable skip bounty trigger
        SkipBountyTrigger.Disable()

    # Enable both bounty triggers
    EnableBountyTriggers():void =
        Print("Enabling bounty triggers")
        
        # Only enable if no bounty is currently active
        if (BountyActive = false):
            PlaceBountyTrigger.Enable()
            SkipBountyTrigger.Enable()

    # Clear the current bounty and reset state
    ClearCurrentBounty():void =
        Print("Clearing current bounty")
        
        # Despawn any active bounty targets
        BountyTargetSpawner.Despawn()
        
        # Reset state variables
        set BountyActive = false
        set CurrentBountyTarget = false
        set ActiveDecisionAgent = false
        
        # Re-enable triggers for next bounty
        EnableBountyTriggers()

    # Full reset of the bounty system
    ResetBountySystem(InAgent:agent):void =
        Print("Resetting bounty system")
        
        # Hide UI for all players
        for:
            Player : GetPlayspace().GetPlayers()
            PlayerUI := GetPlayerUI[Player]
        do:
            PlayerUI.RemoveWidget(BountyUI)
        
        # Despawn and reset the spawner
        BountyTargetSpawner.Despawn()
        BountyTargetSpawner.Reset()
        BountyTargetSpawner.Disable()
        
        # Disable all triggers
        DisableBountyTriggers()
        
        # Reset all state
        set BountyActive = false
        set CurrentBountyTarget = false
        set ActiveDecisionAgent = false
        set BountiesCompleted = 0
        
        Print("Bounty system reset complete")
