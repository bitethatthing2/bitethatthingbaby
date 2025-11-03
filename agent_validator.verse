using { /Fortnite.com/Characters }
using { /UnrealEngine.com/Temporary/Diagnostics }

# ============================================================================
# AGENT VALIDATOR - Clean Agent Validity Checks
# ============================================================================
# Centralized agent validation to prevent null reference errors
# No side effects, pure validation logic
# ============================================================================

agent_validator := class:
    
    # ==================== CORE VALIDATION ====================
    
    # Check if agent is valid and active
    IsAgentValid(Agent:agent):logic=
        if (FortChar := Agent.GetFortCharacter[]):
            if (FortChar.IsActive[]):
                return true
        return false
    
    # Check if agent is valid and has character
    HasCharacter(Agent:agent):logic=
        if (FortChar := Agent.GetFortCharacter[]):
            return true
        return false
    
    # ==================== SAFE OPERATIONS ====================
    
    # Get character only if valid
    GetValidCharacter(Agent:agent):<decides>fort_character=
        if:
            FortChar := Agent.GetFortCharacter[]
            FortChar.IsActive[]
        then:
            return FortChar
        else:
            fail()
    
    # Check if two agents are both valid
    AreBothValid(Agent1:agent, Agent2:agent):logic=
        return IsAgentValid(Agent1) and IsAgentValid(Agent2)
    
    # ==================== BULK VALIDATION ====================
    
    # Filter list to only valid agents
    FilterValidAgents(Agents:[]agent):[]agent=
        var ValidAgents:[]agent = array{}
        for (Agent : Agents):
            if (IsAgentValid(Agent)):
                set ValidAgents += array{Agent}
        return ValidAgents
    
    # Count valid agents in list
    CountValidAgents(Agents:[]agent):int=
        var Count:int = 0
        for (Agent : Agents):
            if (IsAgentValid(Agent)):
                set Count += 1
        return Count
    
    # ==================== DEBUG ====================
    
    PrintValidationStatus(Agent:agent, Context:string):void=
        if (IsAgentValid(Agent)):
            Print("{Context}: Agent VALID")
        else:
            Print("{Context}: Agent INVALID")
