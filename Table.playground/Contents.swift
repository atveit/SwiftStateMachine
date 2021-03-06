import Foundation

// MARK: Setup

// If this isn't working - compile the framework first!
import SwiftStateMachine

var machineDefinition = StateMachine.Definition()

try! machineDefinition.processDefinitionFormats("locked -> locked (push)")
try! machineDefinition.processDefinitionFormats("locked -> unlocked (coin)")
try! machineDefinition.processDefinitionFormats("unlocked -> locked (push)")
try! machineDefinition.processDefinitionFormats("unlocked -> unlocked (coin)")

// Demonstrate another way of expressing the above state machine (useful for reading from a file)
var stateMachineAsSingleString =
	"# Coin machine\n" + // Commented line
	"locked -> locked (push);" +
	"locked -> unlocked (coin); # trailing comment\n" +
	"\n" +	// Blank line
	"unlocked -> locked (push);\n" +
	"unlocked -> unlocked (coin);"

// Try to create an identical definition from a single multi-line string
var multiDefinition = StateMachine.Definition()
try! multiDefinition.processDefinitionFormats(stateMachineAsSingleString)
// Assert they're equivalent
assert(machineDefinition == multiDefinition)

machineDefinition.states["unlocked"]!.transitions["coin"]!.action = { label in print("#### Stile already unlocked. Coin rejected.") }
machineDefinition.states["locked"]!.transitions["push"]!.action = { label in print("#### Stile locked. Try putting a coin in.") }

machineDefinition.states["unlocked"]!.entryAction = { label in print("### Clunk!") }

var str = "Hello, playground"

typealias Column = [StateMachine.TransitionLabel: StateMachine.StateLabel]
typealias Table = [StateMachine.StateLabel: Column]

var table = Table()
var allTransitionLabels: [StateMachine.TransitionLabel] = []

for state in machineDefinition.states.values {
    table[state.label] = Column()
    for transition in state.transitions.values {
        if allTransitionLabels.contains(transition.label) == false {
            allTransitionLabels.append(transition.label)
        }
        table[state.label]![transition.label] = transition.nextState.label
    }
}

print(machineDefinition.states.keys.joinWithSeparator(" | "))
for transitionLabel in allTransitionLabels {
    print("\(transitionLabel): ")

    let row = machineDefinition.states.keys.map {
        (stateLabel: StateMachine.StateLabel) -> String in
        if let newStateLabel = table[stateLabel]?[transitionLabel] {
            return newStateLabel
        }
        else {
            return "..."
        }
    }

    print(row.joinWithSeparator(" | "))
}
