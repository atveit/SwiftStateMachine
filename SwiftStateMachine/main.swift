//
//  main.swift
//  SwiftStateMachine
//
//  Created by Jonathan Wight on 9/8/14.
//  Copyright (c) 2014 schwa. All rights reserved.
//

import Foundation

import SwiftStateMachine

// MARK: Setup

// TODO: Is this the best way to handle namespace aliasing?
typealias StateMachine = SwiftStateMachine.StateMachine

var machineDefinition = StateMachine.Definition()

machineDefinition.processDefinitionFormats("locked -> locked (push)")
machineDefinition.processDefinitionFormats("locked -> unlocked (coin)")
machineDefinition.processDefinitionFormats("unlocked -> locked (push)")
machineDefinition.processDefinitionFormats("unlocked -> unlocked (coin)")
machineDefinition.initialState = machineDefinition.states["locked"]

machineDefinition.states["unlocked"]!.transitions["coin"]!.action = { t in println("#### Stile already unlocked. Coin rejected.") }
machineDefinition.states["locked"]!.transitions["push"]!.action = { t in println("#### Stile locked. Try putting a coin in.") }

machineDefinition.states["unlocked"]!.entryAction = { t in println("### Clunk!") }

//println(machineDefinition.definitionFormats())
//println(machineDefinition.graphViz())

// MARK: Testing

var machine = SwiftStateMachine.StateMachine(definition:machineDefinition)
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

// #############################################################################

//typealias Column = [StateMachine.TransitionLabel:StateMachine.StateLabel]
//typealias Table = [StateMachine.StateLabel:Column]
//
//var table = Table()
//var allTransitionLabels:[StateMachine.TransitionLabel] = []
//
//for state in machineDefinition.states.values {
//    table[state.label] = Column()
//    for transition in state.transitions.values {
//        if contains(allTransitionLabels, transition.label) == false {
//            allTransitionLabels.append(transition.label)
//        }
//        table[state.label]![transition.label] = transition.nextState.label
//    }
//}
//
//print("\t")
//println(" | ".join(machineDefinition.states.keys))
//for transitionLabel in allTransitionLabels {
//    print("\(transitionLabel): ")
//
//    let row = machineDefinition.states.keys.map {
//        (stateLabel:StateMachine.StateLabel) -> String in
//        if let newStateLabel = table[stateLabel]?[transitionLabel] {
//            return newStateLabel
//        }
//        else {
//            return "..."
//        }
//    }
//
//    println(" | ".join(row))
//}

// #############################################################################
