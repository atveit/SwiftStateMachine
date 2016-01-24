// Playground - noun: a place where people can play

import Foundation

// MARK: Setup

// If this isn't working - compile the framework first!
import SwiftStateMachine

var machineDefinition = StateMachine.Definition()

try! machineDefinition.processDefinitionFormats("locked -> locked (push)")
try! machineDefinition.processDefinitionFormats("locked -> unlocked (coin)")
try! machineDefinition.processDefinitionFormats("unlocked -> locked (push)")
try! machineDefinition.processDefinitionFormats("unlocked -> unlocked (coin)")
machineDefinition.initialState = machineDefinition.states["locked"]

machineDefinition.states["unlocked"]!.transitions["coin"]!.action = { t in print("#### Stile already unlocked. Coin rejected.") }
machineDefinition.states["locked"]!.transitions["push"]!.action = { t in print("#### Stile locked. Try putting a coin in.") }

machineDefinition.states["unlocked"]!.entryAction = { t in print("### Clunk!") }

print(machineDefinition.definitionFormats())
print(machineDefinition.graphViz())

// MARK: Testing

var machine = StateMachine(definition:machineDefinition)
machine.logger = { print($0) }

print(machine.currentState)
try! machine.performTransition("push")
print(machine.currentState)
try! machine.performTransition("coin")
print(machine.currentState)
try! machine.performTransition("push")
print(machine.currentState)
try! machine.performTransition("coin")
print(machine.currentState)
try! machine.performTransition("coin")
print(machine.currentState)
try! machine.performTransition("coin")
print(machine.currentState)



