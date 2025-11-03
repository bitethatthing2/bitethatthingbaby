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

# Advanced bounty game device with v38.00 features
# Includes: Dynamic UI with Verse Fields, Cooldown tracking, Material blocks
advanced_bounty_game_device := class(creative_device):

    # ===== EDITABLE DEVICES =====
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
    
    @editable
    BountyRewardDevice:item_granter_device = item_granter_device{}

    # ===== UI COMPONENTS =====
    var BountyUI:overlay = overlay{}
    var BountyStatusText:text_block = text_block:
        DefaultTextColor := NamedColors.White
        DefaultShadowColor := color{R:=0.0, G:=0.0, B:=0.0}
        DefaultShadowOffset := option{vector2{X:=3.0, Y:=2.0}}
    
    var BountyCountText:text_block = text_block:
        DefaultTextColor := NamedColors.Yellow
        DefaultShadowColor := color{R:=0.0, G:=0.0, B:=0.0}
        DefaultShadowOffset := option{vector2{X:=3.0, Y:=2.0}}

    # ===== STATE VARIABLES =====
    var ActiveDecisionAgent:?agent = false
    var CurrentBountyTarget:?agent = false
    var BountyActive:logic = false
    var BountiesCompleted:int = 0
    var BountyTargetHealth:float = 100.0
    var PlaceBountyCooldown:float = 0.0
    var SkipBountyCooldown:float = 0.0
    
    # Cooldown durations (in seconds)
    PlaceBountyCooldownDuration:float = 5.0
    SkipBountyCooldownDuration:float = 10.0

    # ===== INITIALIZATION =====
    OnBegin<override>()<suspends>:void =
        Print("Initializing Advanced Bounty Game Device")
        
        # Subscribe to trigger events with cooldown management
        PlaceBountyTrigger.TriggeredEvent.Subscribe(OnPlaceBountyAttempt)
        SkipBountyTrigger.TriggeredEvent.Subscribe(OnSkipBountyAttempt)
        
        # Subscribe to volume events for UI management
        ShowBountyUITrigger.AgentEntersEvent.Subscribe(ShowBountyUI)
        
        # Subscribe to reset triggers
        for (RemoveTrigger : RemoveTriggers):
            RemoveTrigger.AgentEntersEvent.Subscribe(ResetBountySystem)
        
        for (Teleporter : RemoveTeleporters):
            Teleporter.TeleportedEvent.Subscribe(ResetBountySystem)
        
        # Subscribe to bounty target spawner events
        BountyTargetSpawner.SpawnedEvent.Subscribe(OnBountyTargetSpawned)
        BountyTargetSpawner.DamagedEvent.Subscribe(OnBountyTargetDamaged)
        BountyTargetSpawner.EliminatedEvent.Subscribe(OnBountyTargetEliminated)
        BountyTargetSpawner.AlertedEvent.Subscribe(OnBountyTargetAlerted)
        BountyTargetSpawner.UnawareEvent.Subscribe(OnBountyTargetUnaware)
        
        # Initialize triggers as disabled
        PlaceBountyTrigger.Disable()
        SkipBountyTrigger.Disable()
        
        # Start cooldown tracking
        spawn{TrackCooldowns()}
        
        Print("Advanced Bounty Game Device initialized")

    # ===== TRIGGER EVENT HANDLERS =====
    OnPlaceBountyAttempt(InAgent:?agent):void =
        Print("Place Bounty Attempt")
        
        if (Agent := InAgent?):
            # Check if cooldown has expired
            if (PlaceBountyCooldown > 0.0):
                Print("Place Bounty on cooldown: {PlaceBountyCooldown}s remaining")
                # Could display cooldown message to player here
                return
            
            # Process the bounty placement
            OnPlaceBounty(Agent)

    OnSkipBountyAttempt(InAgent:?agent):void =
        Print("Skip Bounty Attempt")
        
        if (Agent := InAgent?):
            # Check if cooldown has expired
            if (SkipBountyCooldown > 0.0):
                Print("Skip Bounty on cooldown: {SkipBountyCooldown}s remaining")
                return
            
            # Process the bounty skip
            OnSkipBounty(Agent)

    # Place a new bounty
    OnPlaceBounty(Agent:agent):void =
        Print("Place Bounty Triggered by agent")
        
        # Set the active decision agent
        set ActiveDecisionAgent = option{Agent}
        
        # Spawn the bounty target
        if (BountyTargetSpawner.GetNumberActiveGuards() = 0):
            BountyTargetSpawner.Enable()
            BountyTargetSpawner.Spawn()
            set BountyActive = true
            
            # Start cooldown for placing bounty
            set PlaceBountyCooldown = PlaceBountyCooldownDuration
            
            # Update UI
            UpdateBountyStatusUI("Active")
            
            Print("Bounty placed - Target spawned")
        
        # Disable both triggers while bounty is active
        DisableBountyTriggers()

    # Skip the current bounty
    OnSkipBounty(Agent:agent):void =
        Print("Skip Bounty Triggered")
        
        # Check if this is the agent who placed the bounty
        if (ActiveAgent := ActiveDecisionAgent?):
            if (ActiveAgent = Agent):
                # Start cooldown for skipping
                set SkipBountyCooldown = SkipBountyCooldownDuration
                
                # Skip the current bounty
                ClearCurrentBounty()
                
                # Update UI
                UpdateBountyStatusUI("Skipped")
                
                Print("Bounty skipped by decision agent")
            else:
                Print("Only the decision agent can skip the bounty")

    # ===== BOUNTY TARGET EVENT HANDLERS =====
    OnBountyTargetSpawned(InAgent:agent):void =
        Print("Bounty Target Spawned")
        set CurrentBountyTarget = option{InAgent}
        
        # Get initial health
        if (FortChar := InAgent.GetFortCharacter[]):
            set BountyTargetHealth = FortChar.GetHealth()
            Print("Bounty target spawned with health: {BountyTargetHealth}")
            
            # Update UI with target info
            UpdateBountyHealthUI(BountyTargetHealth, BountyTargetHealth)

    OnBountyTargetDamaged(Result:device_ai_interaction_result):void =
        Print("Bounty Target Damaged")
        
        if (Target := Result.Target?):
            if (FortChar := Target.GetFortCharacter[]):
                CurrentHealth := FortChar.GetHealth()
                Print("Bounty target health: {CurrentHealth}/{BountyTargetHealth}")
                
                # Update UI with current health
                UpdateBountyHealthUI(CurrentHealth, BountyTargetHealth)

    OnBountyTargetEliminated(Result:device_ai_interaction_result):void =
        Print("Bounty Target Eliminated")
        
        if (Target := Result.Target?):
            # Award bounty completion
            set BountiesCompleted += 1
            Print("Bounties completed: {BountiesCompleted}")
            
            # Grant reward to the decision agent if applicable
            if (ActiveAgent := ActiveDecisionAgent?):
                BountyRewardDevice.GrantItem(ActiveAgent)
                Print("Reward granted to decision agent")
            
            # Update UI
            UpdateBountyStatusUI("Completed")
            UpdateBountyCountUI(BountiesCompleted)
            
            # Clear the current bounty
            ClearCurrentBounty()
            
            # Re-enable triggers for next bounty after a delay
            spawn{DelayedEnableTriggers(2.0)}

    OnBountyTargetAlerted(Result:device_ai_interaction_result):void =
        Print("Bounty Target Alerted")
        UpdateBountyStatusUI("Target Alerted")

    OnBountyTargetUnaware(InAgent:agent):void =
        Print("Bounty Target Unaware")
        UpdateBountyStatusUI("Target Unaware")

    # ===== UI MANAGEMENT =====
    ShowBountyUI(InAgent:agent):void =
        Print("Showing Bounty UI")
        
        # Create the bounty UI overlay
        CreateBountyUIElements()
        
        # Show UI to all players
        for:
            Player : GetPlayspace().GetPlayers()
            PlayerUI := GetPlayerUI[Player]
        do:
            PlayerUI.AddWidget(BountyUI)
        
        # Enable the bounty placement trigger
        PlaceBountyTrigger.Enable()
        
        # Initialize UI text
        UpdateBountyStatusUI("Ready")
        UpdateBountyCountUI(BountiesCompleted)

    CreateBountyUIElements():void =
        # Create the main UI structure
        BountyOverlay := overlay:
            Slots := array:
                # Top-right corner for bounty status
                overlay_slot:
                    VerticalAlignment := vertical_alignment.Top
                    HorizontalAlignment := horizontal_alignment.Right
                    Padding := margin{Left:=0.0, Top:=50.0, Right:=50.0, Bottom:=0.0}
                    Widget := stack_box:
                        Orientation := orientation.Vertical
                        Slots := array:
                            stack_box_slot:
                                Widget := BountyStatusText
                                Padding := margin{Left:=0.0, Top:=0.0, Right:=0.0, Bottom:=10.0}
                            stack_box_slot:
                                Widget := BountyCountText
                                Padding := margin{Left:=0.0, Top:=0.0, Right:=0.0, Bottom:=0.0}
        
        set BountyUI = BountyOverlay

    UpdateBountyStatusUI<localizes>(Status:string):void =
        StatusMessage:message = "Bounty: {Status}"
        BountyStatusText.SetText(StatusMessage)

    UpdateBountyCountUI<localizes>(Count:int):void =
        CountMessage:message = "Completed: {Count}"
        BountyCountText.SetText(CountMessage)

    UpdateBountyHealthUI<localizes>(CurrentHealth:float, MaxHealth:float):void =
        # Calculate health percentage
        HealthPercent:float = (CurrentHealth / MaxHealth) * 100.0
        HealthMessage:message = "Target: {Floor(HealthPercent)}%"
        BountyStatusText.SetText(HealthMessage)

    # ===== TRIGGER CONTROL =====
    DisableBountyTriggers():void =
        Print("Disabling bounty triggers")
        PlaceBountyTrigger.Disable()
        SkipBountyTrigger.Disable()

    EnableBountyTriggers():void =
        Print("Enabling bounty triggers")
        
        # Only enable if no bounty is currently active
        if (BountyActive = false):
            PlaceBountyTrigger.Enable()
            SkipBountyTrigger.Enable()

    DelayedEnableTriggers(DelaySeconds:float)<suspends>:void =
        Sleep(DelaySeconds)
        EnableBountyTriggers()

    # ===== BOUNTY STATE MANAGEMENT =====
    ClearCurrentBounty():void =
        Print("Clearing current bounty")
        
        # Despawn any active bounty targets
        BountyTargetSpawner.Despawn()
        
        # Reset state variables
        set BountyActive = false
        set CurrentBountyTarget = false
        set ActiveDecisionAgent = false
        set BountyTargetHealth = 100.0
        
        # Re-enable triggers for next bounty
        EnableBountyTriggers()

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
        set BountyTargetHealth = 100.0
        set PlaceBountyCooldown = 0.0
        set SkipBountyCooldown = 0.0
        
        Print("Bounty system reset complete")

    # ===== COOLDOWN TRACKING =====
    TrackCooldowns()<suspends>:void =
        loop:
            # Decrease place bounty cooldown
            if (PlaceBountyCooldown > 0.0):
                set PlaceBountyCooldown = Max(0.0, PlaceBountyCooldown - 0.1)
            
            # Decrease skip bounty cooldown
            if (SkipBountyCooldown > 0.0):
                set SkipBountyCooldown = Max(0.0, SkipBountyCooldown - 0.1)
            
            # Sleep for 100ms
            Sleep(0.1)
