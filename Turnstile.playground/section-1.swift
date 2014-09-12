// Playground - noun: a place where people can play

import Foundation

// MARK: Setup

// This this isn't working - compile the framework first!
import SwiftStateMachine

var machineDefinition = StateMachine.Definition()

machineDefinition.processDefinitionFormats("locked -> locked (push)")
machineDefinition.processDefinitionFormats("locked -> unlocked (coin)")
machineDefinition.processDefinitionFormats("unlocked -> locked (push)")
machineDefinition.processDefinitionFormats("unlocked -> unlocked (coin)")
machineDefinition.initialState = machineDefinition.states["locked"]

machineDefinition.states["unlocked"]!.transitions["coin"]!.action = { t in println("#### Stile already unlocked. Coin rejected.") }
machineDefinition.states["locked"]!.transitions["push"]!.action = { t in println("#### Stile locked. Try putting a coin in.") }

machineDefinition.states["unlocked"]!.entryAction = { t in println("### Clunk!") }

println(machineDefinition.definitionFormats())
println(machineDefinition.graphViz())

// MARK: Testing

var machine = StateMachine(definition:machineDefinition)
machine.logger = println

println(machine.state)
machine.performTransition("push")
println(machine.state)
machine.performTransition("coin")
println(machine.state)
machine.performTransition("push")
println(machine.state)
machine.performTransition("coin")
println(machine.state)
machine.performTransition("coin")
println(machine.state)
machine.performTransition("coin")
println(machine.state)

