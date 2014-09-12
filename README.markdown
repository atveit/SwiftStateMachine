# SwiftStateMachine

Set of Swift classes for building and operating a state machine

The following Swift code defines a state machine based on [Wikipedia's "Turnstile" example](https://en.wikipedia.org/wiki/Finite-state_machine#Example:_a_turnstile):

    var machineDefinition = StateMachine.Definition()
    machineDefinition.processDefinitionFormats("locked -> locked (push)")
    machineDefinition.processDefinitionFormats("locked -> unlocked (coin)")
    machineDefinition.processDefinitionFormats("unlocked -> locked (push)")
    machineDefinition.processDefinitionFormats("unlocked -> unlocked (coin)")
    machineDefinition.initialState = machineDefinition.states["locked"]

You can also define the states and transitions without the domain specific language.

    // TODO: Example forthcoming (code in flux)

The definition format is a simple domain specific language of the form:

    <initial state label> -> <next state label> (<transition label>)

Labels are currently just Swift strings (you should generally just stick to non-special characters in labels for now). In the a future version of this project I intend labels to be any user definable type (most usefully: enums).

You can also combine definitions in one string by separating them with a semicolon (this could be handy when loading a state machine definition from disk).

You instantiate a state machine with a definition like so:

    var machine = StateMachine(definition:machineDefinition)

Because the definition is kept separate from the state machine itself you can have multiple state machine instances all sharing a single definition.

You can then perform transitions between states:

    machine.performTransition("push")
    machine.performTransition("coin")

Perform transition returns true if the transition was successful and false otherwise.

You can test if a transition is possible with _canPerformTransition_:

    machine.canPerformTransition("push")

You can cause the state machine to log transitions (and other events):

    machine.logger = println

You can access the states of a definition via the 'states' property:

    let unlockedState = machineDefinition.states["unlocked"]
    
And you can access the transitions of a state via the 'transitions' property

    let transition = unlockedState!.transitions["push"]
    
You can set "_action_" closures on transitions that execute when a transition is performed:

    machineDefinition.states["unlocked"]!.transitions["coin"]!.action = { t in println("#### Stile already unlocked. Coin rejected.") }
    machineDefinition.states["locked"]!.transitions["push"]!.action = { t in println("#### Stile locked. Try putting a coin in.") }

You can set "_entryAction_" closures on states that execute when the state is entered. Conversely there are also "_exitAction_" closures that execute when the state is exited:

    machineDefinition.states["unlocked"]!.entryAction = { t in println("### Clunk!") }

There are also "_transitionGuard_" closures on states that prevent transitions from occuring:

    // TODO: Example forthcoming

You can print all definitions like so:

    println(machineDefinition.definitionFormats())

Which outputs:

    locked -> locked (push);
    locked -> unlocked (coin);
    unlocked -> locked (push);
    unlocked -> unlocked (coin);

You can output a [GraphViz](http://graphviz.org) .dot file like so:

    println(machineDefinition.graphViz())

A generated dot file looks like:

    digraph {
        node [shape=circle, height=1, width=1]
        start [label="", shape=circle, style=filled, color=black, height=0.25, width=0.25]
        unlocked [label="unlocked"]
        locked [label="locked"]
        start -> locked
        unlocked -> unlocked [label="coin"]
        unlocked -> locked [label="push"]
        locked -> unlocked [label="coin"]
        locked -> locked [label="push"]
    }
    
And you can then use GraphViz (brew install graphviz) to generate an image file from the dot file:

    schwa@mouse ~> dot test.dot -Tpng > test.png

The "turnstile" definition state diagram looks like:

![test.png](test.png)

## TODO

* Unit Tests
* Both the State and Transition classes need to be "dummed" down and the logic moved into the main Definition object - perhaps as a transition table. This would allow definitions to be easily changed on the fly.
* Labels: States and transitions currently use a String as the label type. It would be great if instead of Strings the user could use any Swift type as a label - for example user defined enums. To do this the code should be rewritten to use Swift generics instead. Unfortunately Swift currently cannot use nested classes and generics.

## State Machine Definition Domain Specific Language EBNF

    letter = "A" | "B" | "C" | "D" | "E" | "F" | "G"
           | "H" | "I" | "J" | "K" | "L" | "M" | "N"
           | "O" | "P" | "Q" | "R" | "S" | "T" | "U"
           | "V" | "W" | "X" | "Y" | "Z" ;

    identifier = letter , { letter } ;

    state_label = identifier ;

    transition_label = identifier ;

    definition = state_label , "->" , state_label , "(" , transition_label, ")"

    definitions = definition { ";" , definition }
