# SwiftStateMachine

Set of Swift classes for building and operating a state machine

You define a state machine like so:

    var machineDefinition = StateMachine.Definition()
    machineDefinition.processDefinitionFormats("locked -> locked (push)")
    machineDefinition.processDefinitionFormats("locked -> unlocked (coin)")
    machineDefinition.processDefinitionFormats("unlocked -> locked (push)")
    machineDefinition.processDefinitionFormats("unlocked -> unlocked (coin)")
    machineDefinition.initialState = machineDefinition.states["locked"]

The definition format is a simple domain specific language of the form:

    <initial state label> -> <next state label> (<transition label>)

You can combine definitions in one string by separating them with the a semicolon

You instantiate a state machine with a definition like so:

    var machine = StateMachine(definition:machineDefinition)

You can then perform transitions between states:

    machine.performTransition("push")
    machine.performTransition("coin")

You can cause the state machine to log transitions (and other events):

    machine.logger = println

You can print all definitions like so:

    println(machineDefinition.definitionFormats())

And this outputs:

    locked -> locked (push);
    locked -> unlocked (coin);
    unlocked -> locked (push);
    unlocked -> unlocked (coin);

You can output a GraphViz .dot file as like so:

    println(machineDefinition.graphViz())

The dot file looks like:

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
    
And you can use GraphViz (brew install graphviz) to generate an image from the dot file:

    schwa@mouse ~> dot test.dot -Tpng > test.png

The "turnstile" definition looks like:

![test.png](test.png)

