//
//  SwiftStateMachine.swift
//  SwiftStateMachine
//
//  Created by Jonathan Wight on 9/8/14.
//  Copyright (c) 2014 schwa. All rights reserved.
//

import Foundation

// MARK: Machine


public class StateMachine {

    public typealias StateLabel = String
    public typealias TransitionLabel = String
    public typealias Action = (state:State) -> (Void)
    public typealias TransitionGuard = (state:State) -> (Bool)
    public typealias Logger = (AnyObject) -> Void

    /**
     A State Machine definition.
     
     Generally you create a definition, add states and transitions to it and then use the defintion to create the state machine.
     */
    public class Definition {
//        typealias StateTransitionKey = HashablePair <StateLabel,TransitionLabel>
    
        public var states : [StateLabel:State] = [:]
        public var initialState : State!
//        internal var transitions : [StateTransitionKey:Transition] = [:]

        public init() {
        }

        public func addState(state:State) {
            self.states[state.label] = state
        }

//        public func addTransition(transition:Transition, from:State) {
//            self.transitions[StateTransitionKey(from.label, transition.label)] = transition
//        }
        
        /**
         Create or fetch a State object with label.

         :param: label Label of state to create/find

         :returns: If a State with label already exists this returns that state. Otherwise a new State object is created.
         */
        public func stateForLabel(label:StateLabel) -> State {
            if let state = states[label] {
                return state
            }
            else {
                let state = State(label:label)
                self.addState(state)
                return state
            }
        }
    }

    public class State {
        public let label:StateLabel
        public var transitions:[TransitionLabel:Transition] = [:]
        public var entryAction:Action?
        public var exitAction:Action?

        public init(label:StateLabel) {
            self.label = label
        }

        public convenience init(label:StateLabel, transitions:[Transition]) {
            self.init(label:label)
            for t:Transition in transitions {
                t.state = self
                self.transitions[t.label] = t
            }
        }

        public func addTransition(transition:Transition) {
            self.transitions[transition.label] = transition
        }
    }

    public class Transition {
        public var label:TransitionLabel
        public weak var state:State!
        public var nextState:State!
        public var guard:TransitionGuard?
        public var action:Action?

        public init(label:TransitionLabel, nextState:State) {
            self.label = label
            self.nextState = nextState
        }
    }

    public let definition : Definition
    public var state : State

    /// Set this to a func or closure that accepts AnyObject (e.g. println)
    public var logger : Logger?

    internal func log(closure: @autoclosure () -> AnyObject) {
        if let logger = logger {
            let o:AnyObject = closure()
            logger(o)
        }
    }

    public init(definition:Definition) {
        self.definition = definition
        self.state = self.definition.initialState
    }

    public func canPerformTransition(transitionLabel:TransitionLabel) -> Bool {
        if let transition = self.state.transitions[transitionLabel] {
            if let guard = transition.guard {
                if guard(state:self.state) == true {
                    return true
                }
            }
        }
        return false
    }

    public func performTransition(transitionLabel:TransitionLabel) -> Bool {
        if let transition = self.state.transitions[transitionLabel] {
            if let guard = transition.guard {
                if guard(state:self.state) == false {
                    self.log("Transition guard prevented transition")
                    return false
                }
            }

            if let action = self.state.exitAction {
                action(state:self.state)
            }
            let newState = transition.nextState
            self.log("\(transition.description): from \(state.description) to new \(newState.description)")

            self.state = newState
            if let action = self.state.entryAction {
                action(state:self.state)
            }

            if let action = transition.action {
                action(state:self.state)
            }

            return true
        } else {
            self.log("Cannot find transition called \(transitionLabel)")
            return false
        }
    }
}

public func += (lhs:StateMachine.Definition, rhs:StateMachine.State) {
    lhs.addState(rhs)
}

extension StateMachine.State: Printable {
    public var description: String { get { return "State(\(label))" } }
}

extension StateMachine.Transition: Printable {
    public var description: String { get { return "Transition(\(label))" } }
}

// MARK: Visual Format

public extension StateMachine.Definition {

    func processDefinitionFormats(string:String) -> Bool {
        for string in string.componentsSeparatedByString(",") {
            let expression = NSRegularExpression(pattern:"([a-z]+) -> ([a-z]+) \\(([a-z]+)\\)", options:.CaseInsensitive, error:nil)
            let match = expression.firstMatchInString(string, options:NSMatchingOptions(), range:NSMakeRange(0, string._bridgeToObjectiveC().length))
            if let match = match {
                let stateLabel = string._bridgeToObjectiveC().substringWithRange(match.rangeAtIndex(1))
                let nextStateLabel = string._bridgeToObjectiveC().substringWithRange(match.rangeAtIndex(2))
                let transitionLabel = string._bridgeToObjectiveC().substringWithRange(match.rangeAtIndex(3))

                let state = self.stateForLabel(stateLabel)
                let nextState = self.stateForLabel(nextStateLabel)
                let transition = StateMachine.Transition(label:transitionLabel, nextState:nextState)

                state.addTransition(transition)
            }
        }
        return false
    }

    func definitionFormats() -> String {
        var lines:[String] = []
        for state in self.states.values {
            for transition in state.transitions.values {
                lines.append("\(state.label) -> \(transition.nextState.label) (\(transition.label))")
            }
        }
        lines.sort(<)
        return "\n".join(lines)
    }
}

// MARK: Export

public extension StateMachine.Definition {

    func graphViz() -> String {
        var dot = "digraph {\n"

        dot += "\tnode [shape=circle, height=1, width=1]\n"

        dot += "\tstart [label=\"\", shape=circle, style=filled, color=black, height=0.25, width=0.25]\n"

        for state in self.states.values {
            dot += "\t\(state.label) [label=\"\(state.label)\"]\n"
        }

        dot += "\tstart -> \(self.initialState.label)\n"


        for state in self.states.values {
            for transition in state.transitions.values {
                dot += "\t\(state.label) -> \(transition.nextState.label) [label=\"\(transition.label)\"]\n"
            }
        }

        dot += "}\n"
        return dot
    }
}


// Playground - noun: a place where people can play

struct HashablePair <T1:Hashable, T2:Hashable> : Hashable {
    let v1:T1
    let v2:T2
    var hashValue: Int { get { return v1.hashValue ^ v2.hashValue } }
    init(_ v1:T1, _ v2:T2) {
        self.v1 = v1
        self.v2 = v2
    }
}

func == <T1, T2> (lhs:HashablePair <T1, T2>, rhs:HashablePair <T1, T2>) -> Bool {
    return lhs.hashValue == rhs.hashValue
    }


// All this because (Hashable, Hashable) isn't itself Hashable