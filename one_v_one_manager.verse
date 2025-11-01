using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

# A Verse-authored creative device that can be placed in a level
one_v_one_manager := class(creative_device):

    # --- DEVICE & VARIABLE DECLARATIONS ---
    @editable
    EliminationTracker : elimination_manager_device = elimination_manager_device{}
    
    @editable
    GameEnder : end_game_device = end_game_device{}
    
    @editable
    TeleporterToArena : teleporter_device = teleporter_device{}
    
    @editable
    DuelClassSelector : class_and_team_selector_device = class_and_team_selector_device{}
    
    @editable
    BatButton : button_device = button_device{}
    
    @editable
    SwordButton : button_device = button_device{}
    
    @editable
    BatGranter : item_granter_device = item_granter_device{}
    
    @editable
    SwordGranter : item_granter_device = item_granter_device{}
    
    @editable
    MythicWeaponGranter : item_granter_device = item_granter_device{}
    
    @editable
    ChampionBillboard : billboard_device = billboard_device{}
    
    @editable
    NotificationDevice : hud_message_device = hud_message_device{}
    
    # FOR KILLER: View and respond to challenges
    @editable
    ViewChallengesButton : button_device = button_device{}
    
    @editable
    AcceptChallengeButton : button_device = button_device{}
    
    @editable
    DeclineChallengeButton : button_device = button_device{}
    
    @editable
    CloseMenuButton : button_device = button_device{}
    
    # FOR ELIMINATED PLAYER: Place bounty (only if challenge declined/ignored)
    @editable
    PlaceBountyButton : button_device = button_device{}
    
    @editable
    SkipBountyButton : button_device = button_device{}
    
    # Gold bar devices
    @editable
    GoldBarsRemover : item_granter_device = item_granter_device{}
    
    @editable
    GoldBarsReward : item_granter_device = item_granter_device{}

    var PendingChallenges : [agent]agent = map{}
    var BountyTargets : []agent = array{}
    var MenuOpenFor : ?agent = false
    var IsDuelActive : logic = false
    var KillCounts : [agent]int = map{}
    var ActiveDuelists : []agent = array{}
    var AwaitingBountyDecision : [agent]agent = map{}

    OnBegin<override>()<suspends>:void=
    {
        EliminationTracker.EliminatedEvent().Subscribe(HandleElimination)
        
        spawn{ListenForBatButton()}
        spawn{ListenForSwordButton()}
        spawn{ListenForViewChallenges()}
        spawn{ListenForAcceptChallenge()}
        spawn{ListenForDeclineChallenge()}
        spawn{ListenForCloseMenu()}
        spawn{ListenForPlaceBounty()}
        spawn{ListenForSkipBounty()}
        
        BatButton.Disable()
        SwordButton.Disable()
        ViewChallengesButton.Enable()
        AcceptChallengeButton.Disable()
        DeclineChallengeButton.Disable()
        CloseMenuButton.Disable()
        PlaceBountyButton.Disable()
        SkipBountyButton.Disable()
    }
    
    ListenForBatButton()<suspends>:void=
    {
        loop:
            BatButton.InteractedWithEvent.Await()
            if (Agent := BatButton.GetInteractingAgent[]):
                HandleBatChoice(Agent)
    }
    
    ListenForSwordButton()<suspends>:void=
    {
        loop:
            SwordButton.InteractedWithEvent.Await()
            if (Agent := SwordButton.GetInteractingAgent[]):
                HandleSwordChoice(Agent)
    }
    
    ListenForViewChallenges()<suspends>:void=
    {
        loop:
            ViewChallengesButton.InteractedWithEvent.Await()
            if (Agent := ViewChallengesButton.GetInteractingAgent[]):
                OpenChallengeMenu(Agent)
    }
    
    ListenForAcceptChallenge()<suspends>:void=
    {
        loop:
            AcceptChallengeButton.InteractedWithEvent.Await()
            if (Agent := AcceptChallengeButton.GetInteractingAgent[]):
                HandleAcceptChallenge(Agent)
    }
    
    ListenForDeclineChallenge()<suspends>:void=
    {
        loop:
            DeclineChallengeButton.InteractedWithEvent.Await()
            if (Agent := DeclineChallengeButton.GetInteractingAgent[]):
                HandleDeclineChallenge(Agent)
    }
    
    ListenForCloseMenu()<suspends>:void=
    {
        loop:
            CloseMenuButton.InteractedWithEvent.Await()
            if (Agent := CloseMenuButton.GetInteractingAgent[]):
                CloseChallengeMenu(Agent)
    }
    
    ListenForPlaceBounty()<suspends>:void=
    {
        loop:
            PlaceBountyButton.InteractedWithEvent.Await()
            if (Agent := PlaceBountyButton.GetInteractingAgent[]):
                HandlePlaceBounty(Agent)
    }
    
    ListenForSkipBounty()<suspends>:void=
    {
        loop:
            SkipBountyButton.InteractedWithEvent.Await()
            if (Agent := SkipBountyButton.GetInteractingAgent[]):
                HandleSkipBounty(Agent)
    }

    GetCurrentPlayerCount<public>()<transacts>:int=
    {
        AllPlayers := GetPlayspace().GetPlayers()
        var ActiveCount:int = 0
        
        for (Player : AllPlayers):
            if (PlayerAgent := agent[Player]):
                if (FortChar := PlayerAgent.GetFortCharacter[]):
                    if (FortChar.IsActive[]):
                        set ActiveCount += 1
        
        return ActiveCount
    }
    
    GetKillCount(Agent:agent):int=
    {
        if (Count := KillCounts[Agent]):
            return Count
        return 0
    }
    
    IncrementKillCount(Agent:agent):void=
    {
        CurrentCount := GetKillCount(Agent)
        if (set KillCounts[Agent] = CurrentCount + 1) {}
        
        NewCount := GetKillCount(Agent)
        Print("Kill count: {NewCount}")
        
        if (NewCount >= 5):
            ChampionBillboard.SetText("MOST WANTED: {NewCount} KILLS")
        else if (NewCount >= 3):
            ChampionBillboard.SetText("WANTED: {NewCount} KILLS")
    }
    
    HasPendingChallenge(Killer:agent):logic=
    {
        if (Challenger := PendingChallenges[Killer]):
            return true
        return false
    }
    
    IsInDuel(Agent:agent):logic=
    {
        for (Duelist : ActiveDuelists):
            if (Duelist = Agent):
                return true
        return false
    }
    
    HasActiveBounty(Target:agent):logic=
    {
        for (BountyTarget : BountyTargets):
            if (BountyTarget = Target):
                return true
        return false
    }

    HandleElimination(Result:elimination_result):void=
    {
        # Get agents from the elimination result
        EliminatingChar := Result.EliminatingCharacter
        EliminatedChar := Result.EliminatedCharacter
        
        if (InstigatorAgent := EliminatingChar.GetAgent[]):
            if (EliminatedAgent := EliminatedChar.GetAgent[]):
                
                # Check if bounty was completed
                if (HasActiveBounty(EliminatedAgent) = true):
                    Print("BOUNTY COMPLETED!")
                    GoldBarsReward.GrantItem(InstigatorAgent)
                    RemoveBounty(EliminatedAgent)
                    
                    NotificationDevice.SetText("BOUNTY COLLECTED: 1000 GOLD!")
                    NotificationDevice.Show()
                    spawn:
                        HideNotificationAfterDelay(3.0)
                
                IncrementKillCount(InstigatorAgent)
                
                # Check if this is a duel elimination
                IsInstigatorInDuel := IsInDuel(InstigatorAgent)
                IsEliminatedInDuel := IsInDuel(EliminatedAgent)
                
                if (IsInstigatorInDuel? and IsEliminatedInDuel?):
                    Print("Duel elimination")
                    return
                
                ActivePlayers := GetCurrentPlayerCount()
                Print("Active players: {ActivePlayers}")
                
                if (ActivePlayers <= 1):
                    Print("GAME OVER!")
                    GameEnder.Activate(InstigatorAgent)
                    return
                
                if (ActivePlayers <= 2):
                    if (IsDuelActive? = false):
                        Print("Final elimination!")
                        GameEnder.Activate(InstigatorAgent)
                        return
                
                if (IsDuelActive?):
                    return
                
                # Issue duel challenge to killer
                Print("Issuing duel challenge to killer")
                IssueDuelChallenge(EliminatedAgent, InstigatorAgent)
    }
    
    IssueDuelChallenge(Challenger:agent, Killer:agent):void=
    {
        if (set PendingChallenges[Killer] = Challenger) {}
        
        NotificationDevice.SetText("DUEL CHALLENGE! CHECK MENU - 30 SEC")
        NotificationDevice.Show()
        spawn:
            HideNotificationAfterDelay(2.0)
        
        Print("Challenge issued - killer has 30 seconds")
        
        spawn:
            MonitorChallengeTimeout(Challenger, Killer, 30.0)
    }
    
    MonitorChallengeTimeout(Challenger:agent, Killer:agent, Timeout:float)<suspends>:void=
    {
        Sleep(Timeout)
        
        if (PendingChallenger := PendingChallenges[Killer]):
            if (PendingChallenger = Challenger):
                Print("Challenge TIMEOUT - offering bounty")
                
                RemoveChallenge(Killer)
                
                spawn:
                    OfferBountyToEliminatedPlayer(Challenger, Killer)
    }
    
    RemoveChallenge(Killer:agent):void=
    {
        var NewChallenges:[agent]agent = map{}
        for (Key->Value : PendingChallenges):
            if (Key <> Killer):
                if (set NewChallenges[Key] = Value) {}
        set PendingChallenges = NewChallenges
    }
    
    HideNotificationAfterDelay(Delay:float)<suspends>:void=
    {
        Sleep(Delay)
        NotificationDevice.Hide()
    }
    
    OpenChallengeMenu(Agent:agent):void=
    {
        HasChallenge := HasPendingChallenge(Agent)
        
        if (HasChallenge? = false):
            Print("No pending challenges")
            NotificationDevice.SetText("NO CHALLENGES")
            NotificationDevice.Show()
            spawn:
                HideNotificationAfterDelay(1.5)
            return
        
        if (IsDuelActive?):
            Print("Duel already active")
            return
        
        Print("Opening challenge menu")
        set MenuOpenFor = option{Agent}
        
        NotificationDevice.SetText("DUEL CHALLENGE | ACCEPT or DECLINE")
        NotificationDevice.Show()
        
        AcceptChallengeButton.Enable()
        DeclineChallengeButton.Enable()
        CloseMenuButton.Enable()
        
        spawn:
            AutoCloseMenu(Agent, 5.0)
    }
    
    AutoCloseMenu(Agent:agent, Timeout:float)<suspends>:void=
    {
        Sleep(Timeout)
        
        if (MenuAgent := MenuOpenFor?):
            if (MenuAgent = Agent):
                CloseChallengeMenu(Agent)
    }
    
    CloseChallengeMenu(Agent:agent):void=
    {
        if (MenuAgent := MenuOpenFor?):
            if (MenuAgent = Agent):
                Print("Closing menu")
                set MenuOpenFor = false
                
                AcceptChallengeButton.Disable()
                DeclineChallengeButton.Disable()
                CloseMenuButton.Disable()
                NotificationDevice.Hide()
    }
    
    HandleAcceptChallenge(Agent:agent):void=
    {
        if (MenuAgent := MenuOpenFor?):
            if (Agent <> MenuAgent):
                return
        
        if (Challenger := PendingChallenges[Agent]):
            Print("CHALLENGE ACCEPTED!")
            
            CloseChallengeMenu(Agent)
            RemoveChallenge(Agent)
            
            spawn:
                SetupDuel(Challenger, Agent)
    }
    
    HandleDeclineChallenge(Agent:agent):void=
    {
        if (MenuAgent := MenuOpenFor?):
            if (Agent <> MenuAgent):
                return
        
        if (Challenger := PendingChallenges[Agent]):
            Print("Challenge DECLINED - offering bounty")
            
            CloseChallengeMenu(Agent)
            RemoveChallenge(Agent)
            
            spawn:
                OfferBountyToEliminatedPlayer(Challenger, Agent)
    }
    
    OfferBountyToEliminatedPlayer(EliminatedAgent:agent, KillerAgent:agent)<suspends>:void=
    {
        if (set AwaitingBountyDecision[EliminatedAgent] = KillerAgent) {}
        
        PlaceBountyButton.Enable()
        SkipBountyButton.Enable()
        
        NotificationDevice.SetText("PLACE 1000 GOLD BOUNTY? 30 SEC")
        NotificationDevice.Show()
        
        Print("Eliminated player has 30 seconds to place bounty")
        
        Sleep(30.0)
        
        if (TargetAgent := AwaitingBountyDecision[EliminatedAgent]):
            if (TargetAgent = KillerAgent):
                Print("Bounty decision timed out")
                HandleSkipBounty(EliminatedAgent)
    }
    
    HandlePlaceBounty(Agent:agent):void=
    {
        if (KillerAgent := AwaitingBountyDecision[Agent]):
            Print("BOUNTY PLACED!")
            
            GoldBarsRemover.GrantItem(Agent)
            
            set BountyTargets += array{KillerAgent}
            
            NotificationDevice.SetText("1000 GOLD BOUNTY ACTIVE!")
            NotificationDevice.Show()
            spawn:
                HideNotificationAfterDelay(3.0)
            
            Print("Bounty active - anyone can collect")
            
            RemoveBountyDecision(Agent)
            PlaceBountyButton.Disable()
            SkipBountyButton.Disable()
    }
    
    HandleSkipBounty(Agent:agent):void=
    {
        if (KillerAgent := AwaitingBountyDecision[Agent]):
            Print("Bounty skipped")
            
            RemoveBountyDecision(Agent)
            PlaceBountyButton.Disable()
            SkipBountyButton.Disable()
            NotificationDevice.Hide()
    }
    
    RemoveBountyDecision(EliminatedAgent:agent):void=
    {
        var NewDecisions:[agent]agent = map{}
        for (Key->Value : AwaitingBountyDecision):
            if (Key <> EliminatedAgent):
                if (set NewDecisions[Key] = Value) {}
        set AwaitingBountyDecision = NewDecisions
    }
    
    RemoveBounty(Target:agent):void=
    {
        var NewBounties:[]agent = array{}
        for (BountyTarget : BountyTargets):
            if (BountyTarget <> Target):
                set NewBounties += array{BountyTarget}
        set BountyTargets = NewBounties
    }

    SetupDuel(Challenger:agent, Target:agent)<suspends>:void=
    {
        Print("DUEL STARTING!")
        
        set IsDuelActive = true
        set ActiveDuelists = array{Challenger, Target}
        
        DuelClassSelector.ChangeClass(Challenger)
        DuelClassSelector.ChangeClass(Target)
        
        TeleporterToArena.Teleport(Challenger)
        TeleporterToArena.Teleport(Target)
        
        BatButton.Enable()
        SwordButton.Enable()
        
        NotificationDevice.SetText("DUEL! CHOOSE WEAPON!")
        NotificationDevice.Show()
        
        spawn:
            MonitorDuel(Challenger, Target)
    }
    
    MonitorDuel(Player1:agent, Player2:agent)<suspends>:void=
    {
        Print("Monitoring duel...")
        
        loop:
            Sleep(0.5)
            
            var Player1Alive:logic = false
            var Player2Alive:logic = false
            
            if (P1Char := Player1.GetFortCharacter[]):
                if (P1Char.IsActive[]):
                    set Player1Alive = true
            
            if (P2Char := Player2.GetFortCharacter[]):
                if (P2Char.IsActive[]):
                    set Player2Alive = true
            
            if (Player1Alive? and Player2Alive? = false):
                ResolveDuel(Player1, Player2)
                break
            else if (Player2Alive? and Player1Alive? = false):
                ResolveDuel(Player2, Player1)
                break
            else if (Player1Alive? = false and Player2Alive? = false):
                ResolveDuel(Player1, Player2)
                break
    }
    
    HandleBatChoice(Agent:agent):void=
    {
        if (IsDuelActive?):
            IsDuelist := IsInDuel(Agent)
            if (IsDuelist?):
                BatGranter.GrantItem(Agent)
                Print("BAT SELECTED")
    }
        
    HandleSwordChoice(Agent:agent):void=
    {
        if (IsDuelActive?):
            IsDuelist := IsInDuel(Agent)
            if (IsDuelist?):
                SwordGranter.GrantItem(Agent)
                Print("SWORD SELECTED")
    }
    
    ResolveDuel(Winner:agent, Loser:agent)<suspends>:void=
    {
        Print("DUEL COMPLETE!")
        
        MythicWeaponGranter.GrantItem(Winner)
        
        ChampionBillboard.SetText("DUEL CHAMPION!")
        
        NotificationDevice.SetText("MYTHIC AWARDED!")
        NotificationDevice.Show()
        spawn:
            HideNotificationAfterDelay(3.0)
        
        set IsDuelActive = false
        set ActiveDuelists = array{}
        
        BatButton.Disable()
        SwordButton.Disable()
        
        Sleep(1.0)
        if (GetCurrentPlayerCount() <= 1):
            GameEnder.Activate(Winner)
    }
