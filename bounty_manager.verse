using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }

# ============================================================================
# BOUNTY MANAGER - Bounty System
# ============================================================================
# Manages bounties, hunters, and tracking
# Clean separation of bounty logic
# ============================================================================

bounty_manager := class:
    
    var BOUNTY_BASE_AMOUNT:int = 1000
    var BOUNTY_FLIP_COST:int = 1500
    var MAX_BOUNTY_PER_TARGET:int = 10000
    
    var BountyTargets : [agent]int = map{}
    var BountyHunters : [agent][]agent = map{}
    
    # ==================== BOUNTY PLACEMENT ====================
    
    PlaceBounty(Target:agent, Hunter:agent, Amount:int):int=
        var CurrentBounty:int = 0
        if (Existing := BountyTargets[Target]):
            set CurrentBounty = Existing
        
        var NewAmount:int = CurrentBounty + Amount
        if (NewAmount > MAX_BOUNTY_PER_TARGET):
            set NewAmount = MAX_BOUNTY_PER_TARGET
        
        set BountyTargets[Target] = NewAmount
        AddHunter(Target, Hunter)
        
        return NewAmount
    
    GetBountyAmount(Target:agent):?int=
        if (Amount := BountyTargets[Target]):
            return option{Amount}
        return false
    
    HasBounty(Target:agent):logic=
        if (Amount := BountyTargets[Target]):
            return Amount > 0
        return false
    
    ClearBounty(Target:agent):void=
        var NewBounties:[agent]int = map{}
        for (Key->Value : BountyTargets, Key <> Target):
            set NewBounties[Key] = Value
        set BountyTargets = NewBounties
        
        var NewHunters:[agent][]agent = map{}
        for (Key->Value : BountyHunters, Key <> Target):
            set NewHunters[Key] = Value
        set BountyHunters = NewHunters
    
    # ==================== HUNTER MANAGEMENT ====================
    
    AddHunter(Target:agent, Hunter:agent):void=
        var CurrentHunters:[]agent = array{}
        if (Existing := BountyHunters[Target]):
            set CurrentHunters = Existing
        
        set CurrentHunters += array{Hunter}
        set BountyHunters[Target] = CurrentHunters
    
    RemoveHunter(Target:agent, Hunter:agent):void=
        if (CurrentHunters := BountyHunters[Target]):
            var NewHunters:[]agent = array{}
            for (H : CurrentHunters):
                if (H <> Hunter):
                    set NewHunters += array{H}
            
            if (NewHunters.Length > 0):
                set BountyHunters[Target] = NewHunters
            else:
                var CleanHunters:[agent][]agent = map{}
                for (Key->Value : BountyHunters, Key <> Target):
                    set CleanHunters[Key] = Value
                set BountyHunters = CleanHunters
    
    RemoveAsHunter(Hunter:agent):void=
        var NewBountyHunters:[agent][]agent = map{}
        for (Target->Hunters : BountyHunters):
            var NewHunters:[]agent = array{}
            for (H : Hunters):
                if (H <> Hunter):
                    set NewHunters += array{H}
            if (NewHunters.Length > 0):
                set NewBountyHunters[Target] = NewHunters
        set BountyHunters = NewBountyHunters
    
    GetHunters(Target:agent):?[]agent=
        if (Hunters := BountyHunters[Target]):
            return option{Hunters}
        return false
    
    GetHunterCount(Target:agent):int=
        if (Hunters := BountyHunters[Target]):
            return Hunters.Length
        return 0
    
    IsHunting(Hunter:agent, Target:agent):logic=
        if (Hunters := BountyHunters[Target]):
            for (H : Hunters):
                if (H = Hunter):
                    return true
        return false
    
    # ==================== BOUNTY FLIPPING ====================
    
    FlipBounty(Target:agent):?[]agent=
        if (Hunters := BountyHunters[Target]):
            ClearBounty(Target)
            return option{Hunters}
        return false
    
    # ==================== UTILITY ====================
    
    GetAllBountyTargets():[]agent=
        var Targets:[]agent = array{}
        for (Target->Amount : BountyTargets):
            if (Amount > 0):
                set Targets += array{Target}
        return Targets
    
    GetHighestBounty():int=
        var Highest:int = 0
        for (Target->Amount : BountyTargets):
            if (Amount > Highest):
                set Highest = Amount
        return Highest
    
    GetActiveBountyCount():int=
        var Count:int = 0
        for (Target->Amount : BountyTargets):
            if (Amount > 0):
                set Count += 1
        return Count
    
    ClearAll():void=
        set BountyTargets = map{}
        set BountyHunters = map{}
