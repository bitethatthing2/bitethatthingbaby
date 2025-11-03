using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }

# ============================================================================
# CHALLENGE MANAGER - Challenge Queue System
# ============================================================================
# Manages pending challenges between players
# Clean queue operations with timeout tracking
# ============================================================================

challenge_manager := class:
    
    var CHALLENGE_TIMEOUT_SECONDS:float = 45.0
    var GameStartTime:float = 0.0
    
    var PendingChallenges : [agent][]agent = map{}
    var ChallengeExpiryTimes : [agent][]float = map{}
    
    # ==================== INITIALIZATION ====================
    
    Initialize(StartTime:float):void=
        set GameStartTime = StartTime
    
    GetGameTime():float=
        return GetSimulationElapsedTime() - GameStartTime
    
    # ==================== QUEUE MANAGEMENT ====================
    
    AddChallenge(Killer:agent, Victim:agent):void=
        CurrentTime := GetGameTime()
        ExpiryTime := CurrentTime + CHALLENGE_TIMEOUT_SECONDS
        
        if (ExistingChallenges := PendingChallenges[Killer]):
            set PendingChallenges[Killer] = ExistingChallenges + array{Victim}
        else:
            set PendingChallenges[Killer] = array{Victim}
        
        if (ExistingTimes := ChallengeExpiryTimes[Killer]):
            set ChallengeExpiryTimes[Killer] = ExistingTimes + array{ExpiryTime}
        else:
            set ChallengeExpiryTimes[Killer] = array{ExpiryTime}
    
    GetQueueSize(Killer:agent):int=
        if (Challenges := PendingChallenges[Killer]):
            return Challenges.Length
        return 0
    
    GetNextChallenge(Killer:agent):?agent=
        if (Challenges := PendingChallenges[Killer]):
            if (Challenges.Length > 0):
                return option{Challenges[0]}
        return false
    
    RemoveFirstChallenge(Killer:agent):void=
        # Remove first challenge from array
        if (Challenges := PendingChallenges[Killer]):
            if (Challenges.Length > 1):
                var NewChallenges:[]agent = array{}
                for (Index := 1..Challenges.Length - 1):
                    if (Victim := Challenges[Index]):
                        set NewChallenges += array{Victim}
                set PendingChallenges[Killer] = NewChallenges
            else:
                # Last challenge, remove entry
                RemoveAllChallenges(Killer)
        
        # Remove first expiry time
        if (Times := ChallengeExpiryTimes[Killer]):
            if (Times.Length > 1):
                var NewTimes:[]float = array{}
                for (Index := 1..Times.Length - 1):
                    if (Time := Times[Index]):
                        set NewTimes += array{Time}
                set ChallengeExpiryTimes[Killer] = NewTimes
            else:
                RemoveAllChallengeTimes(Killer)
    
    RemoveAllChallenges(Killer:agent):void=
        var NewChallenges:[agent][]agent = map{}
        for (Key->Value : PendingChallenges, Key <> Killer):
            set NewChallenges[Key] = Value
        set PendingChallenges = NewChallenges
    
    RemoveAllChallengeTimes(Killer:agent):void=
        var NewTimes:[agent][]float = map{}
        for (Key->Value : ChallengeExpiryTimes, Key <> Killer):
            set NewTimes[Key] = Value
        set ChallengeExpiryTimes = NewTimes
    
    # Remove agent from all challenge queues (as victim)
    RemoveFromAllQueues(Agent:agent):void=
        RemoveAllChallenges(Agent)
        RemoveAllChallengeTimes(Agent)
        
        var NewPendingChallenges:[agent][]agent = map{}
        for (Killer->Victims : PendingChallenges):
            var NewVictims:[]agent = array{}
            for (Victim : Victims):
                if (Victim <> Agent):
                    set NewVictims += array{Victim}
            
            if (NewVictims.Length > 0):
                set NewPendingChallenges[Killer] = NewVictims
        set PendingChallenges = NewPendingChallenges
    
    # ==================== EXPIRY CHECKING ====================
    
    GetExpiredChallenges():[]agent=
        var ExpiredKillers:[]agent = array{}
        CurrentTime := GetGameTime()
        
        for (Killer->Times : ChallengeExpiryTimes):
            if (Times.Length > 0):
                if (FirstExpiry := Times[0]):
                    if (CurrentTime >= FirstExpiry):
                        set ExpiredKillers += array{Killer}
        
        return ExpiredKillers
    
    HandleExpiry(Killer:agent):void=
        RemoveFirstChallenge(Killer)
    
    # ==================== UTILITY ====================
    
    HasChallenges(Killer:agent):logic=
        return GetQueueSize(Killer) > 0
    
    GetAllPendingKillers():[]agent=
        var Killers:[]agent = array{}
        for (Killer->Challenges : PendingChallenges):
            if (Challenges.Length > 0):
                set Killers += array{Killer}
        return Killers
    
    ClearAll():void=
        set PendingChallenges = map{}
        set ChallengeExpiryTimes = map{}
