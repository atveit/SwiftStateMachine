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

    public enum Error: ErrorType {
        case CannotPerformTransition
        case NoTransition
        case InvalidRule
    }

    public typealias StateLabel = String
    public typealias TransitionLabel = String
    public typealias Action = State -> Void
    public typealias TransitionGate = State -> Bool
    public typealias Logger = AnyObject -> Void

    /**
     A State Machine definition.

     Generally you create a definition, add states and transitions to it and then use the defintion to create the state machine.
     */
    public class Definition {

        public private (set) var states: [StateLabel: State] = [:]

        /**
            Initial state, if you do not define an initial state the first state added to the definition is assumed to be the initial.
        */
        public var initialState: State!

        public init(states: [StateLabel: State] = [:], initialState: State! = nil) {
            self.states = states
            self.initialState = initialState
        }

        public func addState(state: State) {
            if initialState == nil {
                initialState = state
            }
            states[state.label] = state
        }

//        public func addTransition(transition: Transition, from: State) {
//            transitions[StateTransitionKey(from.label, transition.label)] = transition
//        }

        /**
         Create or fetch a State object with label.

         - parameter label: Label of state to create/find

         - returns: If a State with label already exists this returns that state. Otherwise a new State object is created.
         */
        public func stateForLabel(label: StateLabel) -> State {
            if let state = states[label] {
                return state
            }
            else {
                let state = State(label: label)
                addState(state)
                return state
            }
        }
    }

    public class State {
        public let label: StateLabel
        public private (set) var transitions: [TransitionLabel: Transition] = [:]
        public var entryAction: Action?
        public var exitAction: Action?

        public init(label: StateLabel, transitions: [Transition] = []) {
            self.label = label
            for transition in transitions {
                addTransition(transition)
            }
        }

        public func addTransition(transition: Transition) {
            transition.state = self
            transitions[transition.label] = transition
        }
    }

    public class Transition {
        public let label: TransitionLabel
        public private (set) weak var state: State!
        public let nextState: State!
        public var gate: TransitionGate?
        public var action: Action?

        public init(label: TransitionLabel, nextState: State) {
            self.label = label
            self.nextState = nextState
        }
    }

    public let definition: Definition
    public private (set) var currentState: State

    /// Set this to a func or closure that accepts AnyObject (e.g. println)
    public var logger: Logger?

    public init(definition: Definition) {
        self.definition = definition
        self.currentState = self.definition.initialState
    }

    public func canPerformTransition(transition: Transition) -> Bool {
        if let transition = currentState.transitions[transition.label] {
            if let gate = transition.gate {
                return gate(currentState)
            } else {
                return true
            }
        }
        return false
    }

    public func canPerformTransition(transitionLabel: TransitionLabel) throws -> Bool {
        guard let transition = currentState.transitions[transitionLabel] else {
            throw Error.NoTransition
        }

        if let gate = transition.gate {
            return gate(currentState)
        } else {
            return true
        }
    }

    public func performTransition(transitionLabel: TransitionLabel) throws {
        guard let transition = currentState.transitions[transitionLabel] else {
            throw Error.NoTransition
        }

        guard canPerformTransition(transition) == true else {
            throw Error.CannotPerformTransition
        }

        if let action = currentState.exitAction {
            action(currentState)
        }

        let newState = transition.nextState
        log("\(transition.description): from \(currentState.description) to new \(newState.description)")

        currentState = newState
        if let action = currentState.entryAction {
            action(currentState)
        }

        if let action = transition.action {
            action(currentState)
        }
    }

    internal func log(@autoclosure closure: () -> AnyObject) {
        if let logger = logger {
            let o: AnyObject = closure()
            logger(o)
        }
    }
}

public func += (lhs: StateMachine.Definition, rhs: StateMachine.State) {
    lhs.addState(rhs)
}

extension StateMachine.State: CustomStringConvertible {
    public var description: String {
        return "State(\(label))"
    }
}

extension StateMachine.Transition: CustomStringConvertible {
    public var description: String {
        return "Transition(\(label))"
    }
}

// MARK: Visual Format

public extension StateMachine.Definition {
	/**
	 Take a string that contains one or more definitions in visual format,
	 and import them sequentially into this definition.

	 Note: Ignores commented out lines, and ignores blank lines.
	 This allows you to read a StateMachine definition from a file.

	 - see: README.markdown for a full EBNF grammar.
	 */
    func processDefinitionFormats(string: String) throws {
		let definitionsList = string
			.stringByReplacingOccurrencesOfString("#", withString: "\n#") // Allow comments to be on the same line as a definition
			.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
			.filter { (line) -> Bool in
				// Remove all commented-out lines & whitespace only lines
				return !(line.hasPrefix("#") || line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).characters.isEmpty)
			}
			.joinWithSeparator("") // Into a flat string of definitions, allowing definitions to span multiple lines
			.componentsSeparatedByString(";") // Split into potential definitions
			.filter { $0.characters.isEmpty == false } // Ditch empty lines (allows last definition to end with ';')

		var successfulCount = 0
        for string in definitionsList {
			let identifier = "([a-z0-9_.\\-]+)"
            let expression = try? NSRegularExpression(pattern: "\(identifier) -> \(identifier) \\(\(identifier)\\)", options: .CaseInsensitive)
            let searchRange = NSRange(location: 0, length: (string as NSString).length)
            guard let match = expression?.firstMatchInString(string, options: NSMatchingOptions(), range: searchRange) else {
				print("Error: InvalidRule. Definition found was `\(expression)` Halted parsing after \(successfulCount) valid rules.")
                throw StateMachine.Error.InvalidRule
            }

            let stateLabel = (string as NSString).substringWithRange(match.rangeAtIndex(1))
            let nextStateLabel = (string as NSString).substringWithRange(match.rangeAtIndex(2))
            let transitionLabel = (string as NSString).substringWithRange(match.rangeAtIndex(3))

            let state = stateForLabel(stateLabel)
            let nextState = stateForLabel(nextStateLabel)
            let transition = StateMachine.Transition(label: transitionLabel, nextState: nextState)

            state.addTransition(transition)
			successfulCount = successfulCount + 1
        }
    }


    func definitionFormats() -> String {
        var lines: [String] = []
        for state in states.values {
            for transition in state.transitions.values {
                lines.append("\(state.label) -> \(transition.nextState.label) (\(transition.label));")
            }
        }
        lines.sortInPlace(<)
        return lines.joinWithSeparator("\n")
    }
}

// MARK: Equatable

// Note: this only tests if the Definitions are structurally the same.
// It does not test the gating logic is bound to the same block, for example.

extension StateMachine.Definition : Equatable {
}

public func == (lhs: StateMachine.Definition, rhs: StateMachine.Definition) -> Bool {
	return lhs.initialState.label == rhs.initialState.label && lhs.states == rhs.states
}

extension StateMachine.State : Equatable {
}

public func == (lhs: StateMachine.State, rhs: StateMachine.State) -> Bool {
	return lhs.label == rhs.label && lhs.transitions == rhs.transitions
}

extension StateMachine.Transition : Equatable {
}

public func == (lhs: StateMachine.Transition, rhs: StateMachine.Transition) -> Bool {
	return lhs.label == rhs.label
		// Test the labels for equality, because we don't want to infinitely recurse testing transitions!
		&& lhs.state.label == rhs.state.label && lhs.nextState.label == rhs.nextState.label
}

// MARK: Export

public extension StateMachine.Definition {

    func graphViz() -> String {
        var dot = "digraph {\n"

        dot += "\tnode [shape=circle, height=1, width=1]\n"

        dot += "\tstart [label=\"\", shape=circle, style=filled, color=black, height=0.25, width=0.25]\n"

        for state in states.values {
            dot += "\t\"\(state.label)\" [label=\"\(state.label)\"]\n"
        }

        dot += "\tstart -> \"\(initialState.label)\"\n"

        for state in states.values {
            for transition in state.transitions.values {
                dot += "\t\"\(state.label)\" -> \"\(transition.nextState.label)\" [label=\"\(transition.label)\"]\n"
            }
        }

        dot += "}\n"
        return dot
    }
}
