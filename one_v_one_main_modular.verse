using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }

# ============================================================================
# 1v1 CHALLENGE SYSTEM - MAIN MANAGER (MODULAR ARCHITECTURE)
# ============================================================================
# Clean, maintainable, testable architecture
# Delegates to specialized modules for each system
# ============================================================================

one_v_one_manager := class(creative_device):

    # ==================== MODULE INSTANCES ====================
    
    StatsManager:player_stats_manager = player_stats_manager{}
    AgentValidator:agent_validator = agent_validator{}
    ChallengeManager:challenge_manager = challenge_manager{}
    BountyManager:bounty_manager = bounty_manager{}

    # ==================== CONFIGURATION CONSTANTS ====================
    
    var BOUNTY_DECISION_TIMEOUT_SECONDS:float = 30.0
    var DUEL_TIMEOUT_SECONDS:float = 90.0
    var TRACKING_UPDATE_CLOSE:float = 3.0
    var TRACKING_UPDATE_MED:float = 5.0
    var TRACKING_UPDATE_FAR:float = 8.0
    var TRACKING_DISTANCE_CLOSE:float = 5000.0
    var TRACKING_DISTANCE_MED:float = 10000.0
    var BOOTH_LOCK_TIMEOUT_SECONDS:float = 30.0

    # ==================== CORE GAME DEVICES ====================
    
    @editable
    GameEnder : end_game_device = end_game_device{}
    
    @editable
    MainHUDMessage : hud_message_device = hud_message_device{}
    
    @editable
    TrackingHUD : hud_message_device = hud_message_device{}
    
    @editable
    KillStreakBillboard : billboard_device = billboard_device{}
    
    @editable
    BountyBoard : billboard_device = billboard_device{}
    
    @editable
    LeaderboardDisplay : billboard_device = billboard_device{}
    
    @editable
    BoothInfoBillboard : billboard_device = billboard_device{}
    
    @editable
    ArenaSpawnPoint1 : teleporter_device = teleporter_device{}
    
    @editable
    ArenaSpawnPoint2 : teleporter_device = teleporter_device{}
    
    @editable
    DuelClassSelector : class_and_team_selector_device = class_and_team_selector_device{}
    
    @editable
    ArenaContainmentBarrier : mutator_zone_device = mutator_zone_device{}
    
    @editable
    ArenaCenterDivider : mutator_zone_device = mutator_zone_device{}
    
    @editable
    BatWeaponPad : item_spawner_device = item_spawner_device{}
    
    @editable
    SwordWeaponPad : item_spawner_device = item_spawner_device{}
    
    @editable
    MythicWeaponGranter : item_granter_device = item_granter_device{}
    
    @editable
    BoothEntranceTrigger : trigger_device = trigger_device{}
    
    @editable
    AcceptChallengeButton : button_device = button_device{}
    
    @editable
    FlipBountyButton : button_device = button_device{}
    
    @editable
    FlipBountyValidator : conditional_button_device = conditional_button_device{}
    
    @editable
    DecisionRoomTeleporter : teleporter_device = teleporter_device{}
    
    @editable
    PlaceBountyTrigger : trigger_device = trigger_device{}
    
    @editable
    SkipBountyTrigger : trigger_device = trigger_device{}
    
    @editable
    GoldBarsRemover : item_granter_device = item_granter_device{}
    
    @editable
    GoldBarsReward : item_granter_device = item_granter_device{}
    
    @editable
    GoldBarsFlipCost : item_granter_device = item_granter_device{}
    
    @editable
    NormalRespawnPoint : teleporter_device = teleporter_device{}
    
    @editable
    RespawnClassSelector : class_and_team_selector_device = class_and_team_selector_device{}

    # ==================== STATE TRACKING ====================
    
    var ActiveTrackingLoops : [agent][]cancelable = map{}
    var DecisionQueue : []agent = array{}
    var ActiveDecisionAgent : ?agent = false
    var PendingBountyDecisions : [agent]agent = map{}
    var BoothActionLock : [agent]logic = map{}
    var BoothActionLockTimes : [agent]float = map{}
    var ActiveReminderLoops : [agent]cancelable = map{}
    var IsDuelActive : logic = false
    var CurrentDuelists : [agent]agent = map{}
    
    var GameStartTime : float = 0.0

    # ==================== HELPER FUNCTIONS ====================
    
    StringToMessage<localizes>(value:string):message = "{value}"
    
    GetGameTime():float=
        return GetSimulationElapsedTime() - GameStartTime

    # ==================== INITIALIZATION ====================
    
    OnBegin<override>()<suspends>:void=
        Sleep(0.0)
        Print("=== 1v1 Challenge System Starting (Modular v2) ===")
        
        set GameStartTime = GetSimulationElapsedTime()
        ChallengeManager.Initialize(GameStartTime)
        
        InitializeExistingPlayers()
        
        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)
        GetPlayspace().PlayerRemovedEvent().Subscribe(OnPlayerRemoved)
        
        BoothEntranceTrigger.TriggeredEvent.Subscribe(HandleBoothEntrance)
        AcceptChallengeButton.InteractedWithEvent.Subscribe(HandleAcceptChallenge)
        FlipBountyButton.InteractedWithEvent.Subscribe(HandleFlipBounty)
        PlaceBountyTrigger.TriggeredEvent.Subscribe(HandlePlaceBounty)
        SkipBountyTrigger.TriggeredEvent.Subscribe(HandleSkipBounty)
        
        PlaceBountyTrigger.Disable()
        SkipBountyTrigger.Disable()
        BatWeaponPad.Disable()
        SwordWeaponPad.Disable()
        ArenaCenterDivider.Disable()
        ArenaContainmentBarrier.Disable()
        
        spawn{UpdateBountyBoardLoop()}
        spawn{UpdateLeaderboardLoop()}
        spawn{ProcessDecisionQueueLoop()}
        spawn{MonitorChallengeExpiry()}
        spawn{MonitorBoothLockTimeouts()}
        
        Print("System ready!")
    
    InitializeExistingPlayers():void=
        AllPlayers := GetPlayspace().GetPlayers()
        for (Player : AllPlayers):
            if (Agent := agent[Player]):
                RegisterPlayerForEliminations(Agent)
                StatsManager.GetOrCreateStats(Agent)
    
    OnPlayerAdded(Player:player):void=
        if (Agent := agent[Player]):
            RegisterPlayerForEliminations(Agent)
            StatsManager.GetOrCreateStats(Agent)
    
    RegisterPlayerForEliminations(Agent:agent):void=
        if (FortChar := Agent.GetFortCharacter[]):
            FortChar.EliminatedEvent().Subscribe(OnPlayerEliminated)
    
    OnPlayerRemoved(Player:player):void=
        if (Agent := agent[Player]):
            CleanupPlayerData(Agent)
    
    CleanupPlayerData(Agent:agent):void=
        # Cancel tracking loops
        if (Cancelables := ActiveTrackingLoops[Agent]):
            for (Cancelable : Cancelables):
                Cancelable.Cancel()
        
        var NewTrackingLoops:[agent][]cancelable = map{}
        for (Key->Value : ActiveTrackingLoops, Key <> Agent):
            set NewTrackingLoops[Key] = Value
        set ActiveTrackingLoops = NewTrackingLoops
        
        # Cancel reminder loops
        if (ReminderCancelable := ActiveReminderLoops[Agent]):
            ReminderCancelable.Cancel()
        
        var NewReminderLoops:[agent]cancelable = map{}
        for (Key->Value : ActiveReminderLoops, Key <> Agent):
            set NewReminderLoops[Key] = Value
        set ActiveReminderLoops = NewReminderLoops
        
        # Clean up via managers
        ChallengeManager.RemoveFromAllQueues(Agent)
        BountyManager.ClearBounty(Agent)
        BountyManager.RemoveAsHunter(Agent)
        StatsManager.ClearStats(Agent)
        RemoveFromDecisionQueue(Agent)
        
        # Clean up duel state
        if (Opponent := CurrentDuelists[Agent]):
            spawn{HandleDuelCompletion(Opponent, Agent)}
        
        ReleaseBoothLock(Agent)
        RemovePendingBountyDecision(Agent)

    # ==================== ELIMINATION HANDLER ====================
    
    OnPlayerEliminated(Result:elimination_result):void=
        EliminatedChar := Result.EliminatedCharacter
        if (Victim := EliminatedChar.GetAgent[]):
            EliminatingChar := Result.EliminatingCharacter
            if:
                KillerChar := EliminatingChar?
                Killer := KillerChar.GetAgent[]
            then:
                ProcessElimination(Killer, Victim)
            else:
                spawn{HandleEnvironmentalDeath(Victim)}

    ProcessElimination(Killer:agent, Victim:agent):void=
        # Check if this was a duel elimination
        if (Opponent := CurrentDuelists[Killer]):
            if (Opponent = Victim):
                spawn{HandleDuelCompletion(Killer, Victim)}
                return
        
        # Check if this was a bounty elimination
        if (BountyManager.IsHunting(Killer, Victim)):
            if (BountyAmount := BountyManager.GetBountyAmount(Victim)):
                spawn{HandleBountyCompletion(Killer, Victim, BountyAmount)}
                return
        
        # Regular elimination
        StatsManager.IncrementKillCount(Killer)
        StatsManager.IncrementTotalKills(Killer)
        
        # Update kill streak billboard
        KillCount := StatsManager.GetKillCount(Killer)
        if (KillCount >= 5):
            KillStreakBillboard.SetText(StringToMessage("🔥 STREAK: {KillCount}"))
        else if (KillCount >= 3):
            KillStreakBillboard.SetText(StringToMessage("⚠️ {KillCount} KILLS"))
        
        ActivePlayers := GetCurrentPlayerCount()
        
        if (ActivePlayers <= 1):
            HandleGameEnd(Killer)
            return
        
        ChallengeManager.AddChallenge(Killer, Victim)
        
        # Teleport victim to decision room if still valid
        if (AgentValidator.IsAgentValid(Victim)):
            DecisionRoomTeleporter.Teleport(Victim)
            AddToDecisionQueue(Victim)
            TrackingHUD.Show(Victim, StringToMessage("Waiting in decision room..."), ?DisplayTime := 5.0)
        
        NotifyKillerOfChallenge(Killer)
    
    HandleEnvironmentalDeath(Victim:agent)<suspends>:void=
        if (AgentValidator.IsAgentValid(Victim) = false):
            return
        
        Sleep(2.0)
        
        if (AgentValidator.IsAgentValid(Victim) = false):
            return
        
        TrackingHUD.Show(Victim, StringToMessage("Environmental death - respawning soon..."), ?DisplayTime := 3.0)
        Sleep(3.0)
        
        if (AgentValidator.IsAgentValid(Victim)):
            RespawnPlayer(Victim)

    # ==================== CHALLENGE NOTIFICATIONS ====================
    
    NotifyKillerOfChallenge(Killer:agent):void=
        QueueSize := ChallengeManager.GetQueueSize(Killer)
        TrackingHUD.Show(Killer, StringToMessage("⚔️ CHALLENGES: {QueueSize} | Visit Booth"), ?DisplayTime := 5.0)
        
        if (ExistingCancelable := ActiveReminderLoops[Killer]):
            ExistingCancelable.Cancel()
        
        NewCancelable := spawn{RemindKillerOfChallenges(Killer)}
        set ActiveReminderLoops[Killer] = NewCancelable
    
    RemindKillerOfChallenges(Killer:agent)<suspends>:void=
        loop:
            Sleep(10.0)
            
            if (AgentValidator.IsAgentValid(Killer) = false):
                return
            
            QueueSize := ChallengeManager.GetQueueSize(Killer)
            if (QueueSize > 0):
                TrackingHUD.Show(Killer, StringToMessage("⚔️ {QueueSize} Challenge(s) pending"), ?DisplayTime := 3.0)
            else:
                return
    
    MonitorChallengeExpiry()<suspends>:void=
        loop:
            Sleep(5.0)
            
            ExpiredKillers := ChallengeManager.GetExpiredChallenges()
            for (Killer : ExpiredKillers):
                ChallengeManager.HandleExpiry(Killer)

    # ==================== BOOTH SYSTEM ====================
    
    HandleBoothEntrance(MaybeAgent:?agent):void=
        if (Agent := MaybeAgent?):
            if (AgentValidator.IsAgentValid(Agent)):
                UpdateBoothDisplayForPlayer(Agent)
    
    UpdateBoothDisplayForPlayer(Agent:agent):void=
        var DisplayText:string = "⚔️ CHALLENGE BOOTH ⚔️\n\n"
        
        ChallengeCount := ChallengeManager.GetQueueSize(Agent)
        if (ChallengeCount > 0):
            set DisplayText = DisplayText + "Challenges Available: {ChallengeCount}\n"
            set DisplayText = DisplayText + "Press GREEN to accept next\n\n"
        else:
            set DisplayText = DisplayText + "No challenges available\n\n"
        
        Stats := StatsManager.GetStats(Agent)
        if (Stats.CurrentBountyAmount > 0):
            set DisplayText = DisplayText + "⚠️ BOUNTY ON YOU ⚠️\n"
            set DisplayText = DisplayText + "Amount: {Stats.CurrentBountyAmount}g\n"
            set DisplayText = DisplayText + "Hunters: {Stats.ActiveHunters}\n"
            set DisplayText = DisplayText + "Press RED to flip (1500g)\n\n"
        
        BoothInfoBillboard.SetText(StringToMessage(DisplayText))
        
        var HudText:string = ""
        if (ChallengeCount > 0):
            set HudText = HudText + "You have {ChallengeCount} challenge(s)\n"
        if (Stats.CurrentBountyAmount > 0):
            set HudText = HudText + "⚠️ Bounty on you: {Stats.CurrentBountyAmount}g\n"
        
        if (HudText <> ""):
            TrackingHUD.Show(Agent, StringToMessage(HudText), ?DisplayTime := 10.0)
    
    TryAcquireBoothLock(Agent:agent):logic=
        if (BoothActionLock[Agent]):
            if (LockTime := BoothActionLockTimes[Agent]):
                CurrentTime := GetGameTime()
                if (CurrentTime - LockTime > BOOTH_LOCK_TIMEOUT_SECONDS):
                    ReleaseBoothLock(Agent)
                else:
                    return false
        
        set BoothActionLock[Agent] = true
        set BoothActionLockTimes[Agent] = GetGameTime()
        return true
    
    ReleaseBoothLock(Agent:agent):void=
        var NewLocks:[agent]logic = map{}
        for (Key->Value : BoothActionLock, Key <> Agent):
            set NewLocks[Key] = Value
        set BoothActionLock = NewLocks
        
        var NewLockTimes:[agent]float = map{}
        for (Key->Value : BoothActionLockTimes, Key <> Agent):
            set NewLockTimes[Key] = Value
        set BoothActionLockTimes = NewLockTimes
    
    MonitorBoothLockTimeouts()<suspends>:void=
        loop:
            Sleep(10.0)
            CurrentTime := GetGameTime()
            var AgentsToRelease:[]agent = array{}
            
            for (Agent->LockTime : BoothActionLockTimes):
                if (CurrentTime - LockTime > BOOTH_LOCK_TIMEOUT_SECONDS):
                    set AgentsToRelease += array{Agent}
            
            for (Agent : AgentsToRelease):
                ReleaseBoothLock(Agent)
    
    HandleAcceptChallenge(Agent:agent):void=
        if (AgentValidator.IsAgentValid(Agent) = false):
            return
        
        if (TryAcquireBoothLock(Agent) = false):
            return
        
        if (IsDuelActive):
            TrackingHUD.Show(Agent, StringToMessage("Duel already in progress"), ?DisplayTime := 2.0)
            ReleaseBoothLock(Agent)
            return
        
        if (Victim := ChallengeManager.GetNextChallenge(Agent)):
            if (AgentValidator.IsAgentValid(Victim) = false):
                ChallengeManager.RemoveFirstChallenge(Agent)
                ReleaseBoothLock(Agent)
                TrackingHUD.Show(Agent, StringToMessage("Challenge target disconnected"), ?DisplayTime := 2.0)
                return
            
            ChallengeManager.RemoveFirstChallenge(Agent)
            spawn{SetupDuel(Agent, Victim)}
        else:
            TrackingHUD.Show(Agent, StringToMessage("No challenges available"), ?DisplayTime := 2.0)
            ReleaseBoothLock(Agent)
    
    HandleFlipBounty(Agent:agent):void=
        if (AgentValidator.IsAgentValid(Agent) = false):
            return
        
        if (TryAcquireBoothLock(Agent) = false):
            return
        
        if (BountyManager.HasBounty(Agent)):
            if (FlipBountyValidator.HasAllItems(Agent)):
                if (OldHunters := BountyManager.FlipBounty(Agent)):
                    GoldBarsFlipCost.GrantItem(Agent)
                    
                    var HunterCount:int = OldHunters.Length
                    var BountyPerHunter:int = BountyManager.BOUNTY_BASE_AMOUNT
                    
                    if (HunterCount > 1):
                        set BountyPerHunter = BountyManager.BOUNTY_BASE_AMOUNT / HunterCount
                        if (BountyPerHunter < 500):
                            set BountyPerHunter = 500
                    
                    for (Hunter : OldHunters):
                        PlaceBountyOnTarget(Hunter, Agent, BountyPerHunter)
                    
                    TrackingHUD.Show(Agent, StringToMessage("BOUNTY FLIPPED! Tracking {HunterCount} targets!"), ?DisplayTime := 5.0)
                    ReleaseBoothLock(Agent)
            else:
                TrackingHUD.Show(Agent, StringToMessage("Need 1500g to flip bounty!"), ?DisplayTime := 3.0)
                ReleaseBoothLock(Agent)
        else:
            TrackingHUD.Show(Agent, StringToMessage("No bounty on you"), ?DisplayTime := 2.0)
            ReleaseBoothLock(Agent)
    
    PlaceBountyOnTarget(Target:agent, Hunter:agent, Amount:int):void=
        NewAmount := BountyManager.PlaceBounty(Target, Hunter, Amount)
        HunterCount := BountyManager.GetHunterCount(Target)
        
        StatsManager.UpdateBountyStats(Target, NewAmount, HunterCount)
        
        if (AgentValidator.IsAgentValid(Target)):
            TrackingHUD.Show(Target, StringToMessage("⚠️ NEW BOUNTY: {NewAmount}g | {HunterCount} hunters!"), ?DisplayTime := 5.0)
        
        TrackingCancelable := spawn{TrackTargetForHunter(Hunter, Target)}
        if (ExistingCancelables := ActiveTrackingLoops[Hunter]):
            set ActiveTrackingLoops[Hunter] = ExistingCancelables + array{TrackingCancelable}
        else:
            set ActiveTrackingLoops[Hunter] = array{TrackingCancelable}

    # This file is getting long - will continue in next part...
    # For now, remaining functions follow same pattern using module delegates
    
    GetCurrentPlayerCount():int=
        AllPlayers := GetPlayspace().GetPlayers()
        ValidAgents := AgentValidator.FilterValidAgents(
            for (Player : AllPlayers, Agent := agent[Player]):
                Agent
        )
        return ValidAgents.Length
    
    RespawnPlayer(Agent:agent):void=
        if (AgentValidator.IsAgentValid(Agent) = false):
            return
        
        NormalRespawnPoint.Teleport(Agent)
        RespawnClassSelector.ChangeClass(Agent)
        ReleaseBoothLock(Agent)
