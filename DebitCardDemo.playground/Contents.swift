//: Playground - noun: a place where people can play

import Foundation
import SwiftStateMachine

/**
 This Demo statemachine is meant to implement the logic of an automated ticket machine for entering a tourist attraction.
 */

enum States: String {
	case WaitingForCard = "waiting"
	case WaitingForPin = "wait_for_pin"
	case CheckingBalance = "checking"
	case Pending = "pending"
	case Rejected = "rejected"
	case Purchased = "purchased"
}
enum Actions {
	case CancelEject(DebitCard?)
	case InsertCard(DebitCard)
	case InputPin((DebitCard, pin: String))
	case AddTicket(DebitCard)
	case RemoveTicket(DebitCard)
	case ConfirmPurchase(DebitCard)

	var transitionLabel: String {
		get {
			switch self {
			case .CancelEject(_):
				return "cancel_eject"
			case .InsertCard(_):
				return "insert_card"
			case .InputPin(_):
				return "input_pin"
			case .AddTicket(_):
				return "add_ticket"
			case .RemoveTicket(_):
				return "remove_ticket"
			case .ConfirmPurchase(_):
				return "confirm_purchase"
			}
		}
	}
}
protocol KioskTransactionProtocol: TransitionContext {
	var transitionLabel: String { get }
	var card: DebitCard { get } // Card must be present during transactions
	var cardPin: String? { get }
}
struct KioskTransaction: KioskTransactionProtocol {
	var transitionLabel: String
	var card: DebitCard
	var cardPin: String?
	init(label: String, _ debitCard: DebitCard, _ pin: String? = nil) {
		transitionLabel = label
		card = debitCard
		cardPin = pin
	}
}
extension StateMachine {
	func performTransition(action: Actions) throws {
		switch action {
		case .CancelEject(let card):
			if let card = card {
				try self.performTransition(KioskTransaction(label: action.transitionLabel, card))
			} else {
				try self.performTransition(action.transitionLabel)
			}
		case .InsertCard(let card):
			try self.performTransition(KioskTransaction(label: action.transitionLabel, card))
		case .InputPin(let cardPinPair):
			try self.performTransition(KioskTransaction(label: action.transitionLabel, cardPinPair.0, cardPinPair.1))
		case .AddTicket(let card):
			try self.performTransition(KioskTransaction(label: action.transitionLabel, card))
		case .RemoveTicket(let card):
			try self.performTransition(KioskTransaction(label: action.transitionLabel, card))
		case .ConfirmPurchase(let card):
			try self.performTransition(KioskTransaction(label: action.transitionLabel, card))
		}
	}
}
enum InternalEvents {
	case InsufficientFunds
	case Preapprove
	case PrinterSpooled

	var transitionLabel: String {
		get {
			switch self {
			case .InsufficientFunds:
				return "insufficient_funds"
			case .Preapprove:
				return "preapprove"
			case .PrinterSpooled:
				return "print_spooled"
			}
		}
	}
}
class DebitCard {
	let cardType: String
	let pinCode: String
	var availableBalance: Float
	var reservedBalance: Float

	init(type: String, code: String, _ balance: Float, _ reserved: Float) {
		cardType = type
		pinCode = code
		availableBalance = balance
		reservedBalance = reserved
	}
	static let DummyCard = DebitCard(type: "NOT_A_CARD", code: "", 0, 0)
}
struct MachineStatus {
	let ticketPrice: Float = 4.50
	let maxTicketsPerTransaction: Int = 5

	var currentTransactionId: Int
	var currentTicketCount: Int
	var curTotal: Float {
		get {
			return self.priceForTickets(Float(currentTicketCount))
		}
	}
	func priceForTickets(count: Float) -> Float {
		return count * ticketPrice
	}

	init() {
		currentTicketCount = 0
		currentTransactionId = 0
	}
}
var status = MachineStatus()

var machineDefinitionStr = try! NSString(
	contentsOfFile: NSBundle.mainBundle().pathForResource("kiosk", ofType: "definition")!,
	encoding:NSUTF8StringEncoding) as String

var machineDefinition = StateMachine.Definition()
try! machineDefinition.processDefinitionFormats(machineDefinitionStr)

print(machineDefinition.graphViz())
//: # This Machine's State Diagram looks like:
NSImage(byReferencingFile: NSBundle.mainBundle().pathForResource("kiosk", ofType: "png")!)!

let kiosk = StateMachine(definition: machineDefinition)

machineDefinition.initialState.exitAction = {_, _ in print("Display: System Ready")}
machineDefinition.states[States.WaitingForCard.rawValue]!.entryAction = {_, _ in
	print("Display: ----------------------------------------")
	print("Display: Ticket price is $\(status.ticketPrice)")
	print("Display: Please insert your card to begin")
}
machineDefinition.states[States.WaitingForPin.rawValue]!.entryAction = {_, _ in
	print("Display: ----------------------------------------")
	print("Display: Card inserted, please enter your pin")
}
machineDefinition.states[States.CheckingBalance.rawValue]!.entryAction = {_, transaction in
	print("Display: ----------------------------------------")
	print("Display: Checking for sufficient funds")

	guard let transaction: KioskTransactionProtocol = transaction as? KioskTransactionProtocol else {
		print("Display: System Error. Invalid Transaction")
		abort()
	}

	guard transaction.card.availableBalance >= status.curTotal else {
		// Hard reject
		try! kiosk.performTransition(InternalEvents.InsufficientFunds.transitionLabel)
		return
	}

	// Reserve the funds
	transaction.card.reservedBalance += status.curTotal
	transaction.card.availableBalance -= status.curTotal

	try! kiosk.performTransition(InternalEvents.Preapprove.transitionLabel)
}
machineDefinition.states[States.Pending.rawValue]!.entryAction = {_, _ in
	print("Display: ----------------------------------------")
	print("Display: Currently purchasing \(status.currentTicketCount) ticket(s).")
	print("Display: Total: $\(status.curTotal)")
}
machineDefinition.states[States.Purchased.rawValue]!.entryAction = {_, _ in
	print("Display: ----------------------------------------")
	print("Display: Purchase Complete! Printing Receipt…")
}
machineDefinition.states[States.Purchased.rawValue]!.exitAction = {_, _ in
	print("Printer: Transaction \(status.currentTransactionId)")
	print("Printer: \(status.currentTicketCount) Ticket(s)")
	print("Printer: Total: $\(status.curTotal)")
}
machineDefinition.states[States.Rejected.rawValue]!.entryAction = {_, _ in
	print("Display: Insufficient Funds on this Card. Please use a different card…")
	print("Display: ----------------------------------------")

	// We didn't mutate a card here, so give nil to the cancel line so we don't give people money ;)
	try! kiosk.performTransition(Actions.CancelEject(nil))
}
// Verify if you're allowed to perform these transitions
machineDefinition.states[States.WaitingForCard.rawValue]!.transitions[Actions.InsertCard(DebitCard.DummyCard).transitionLabel]?.gate = {_, transaction in
	guard let transaction: KioskTransactionProtocol = transaction as? KioskTransactionProtocol else {
		print("Display: System Error. Invalid Transaction")
		return false
	}
	guard transaction.card.cardType == "VISA" else {
		print("Display: Unsupported Card Type. This Kiosk only supports VISA.")
		print("Display: Nobody supports \(transaction.card.cardType), please enter a supported card!")
		print("Ejector: CARD_EJECTED")
		return false
	}
	guard transaction.card.pinCode.characters.count == 4 else {
		print("Display: Unable to read card, corrupted pin code?")
		print("Display: Please try again.")
		print("Ejector: CARD_EJECTED")
		return false
	}
	return true
}
machineDefinition.states[States.WaitingForPin.rawValue]!.transitions[Actions.InputPin((DebitCard.DummyCard,"")).transitionLabel]?.gate = {_, transaction in
	guard let transaction: KioskTransactionProtocol = transaction as? KioskTransactionProtocol else {
		print("Display: System Error. Invalid Transaction")
		return false
	}
	guard let pinGuess = transaction.cardPin else {
		print("Display: Missing Pin. Please try again!")
		return false
	}
	guard transaction.card.pinCode == pinGuess else {
		print("Display: Invalid Pin. Please try again!")
		return false
	}
	print("Display: Pin Accepted.")
	return true
}
machineDefinition.states[States.WaitingForPin.rawValue]!.exitAction = {_, transaction in
	// When we exit waiting for pin, this is the real start of messing with money. Reset our settings
	status.currentTicketCount = 1
	status.currentTransactionId += 1
}
machineDefinition.states[States.Pending.rawValue]!.transitions[Actions.AddTicket(DebitCard.DummyCard).transitionLabel]?.gate = {_, transaction in
	guard let transaction: KioskTransactionProtocol = transaction as? KioskTransactionProtocol else {
		print("Display: System Error. Invalid Transaction")
		return false
	}
	guard status.currentTicketCount < status.maxTicketsPerTransaction else {
		print("Display: Maximum Tickets per Customer is \(status.maxTicketsPerTransaction)")
		return false
	}
	guard transaction.card.availableBalance >= status.ticketPrice else {
		print("Display: Not enough funds to add another ticket.")
		// Soft-fail (don't reject the card)
		return false
	}
	// Restore the money before going back to reserve the funds
	transaction.card.availableBalance += status.curTotal
	transaction.card.reservedBalance -= status.curTotal
	status.currentTicketCount += 1
	return true
}
machineDefinition.states[States.Pending.rawValue]!.transitions[Actions.RemoveTicket(DebitCard.DummyCard).transitionLabel]?.gate = {_, transaction in
	guard let transaction: KioskTransactionProtocol = transaction as? KioskTransactionProtocol else {
		print("Display: System Error. Invalid Transaction")
		return false
	}
	guard status.currentTicketCount > 1 else {
		print("Display: Purchasing 1 Ticket")
		return false
	}
	status.currentTicketCount -= 1
	transaction.card.availableBalance += status.ticketPrice
	transaction.card.reservedBalance -= status.ticketPrice
	return true
}
// Auto advance out of transient state
machineDefinition.states[States.Pending.rawValue]!.transitions[Actions.ConfirmPurchase(DebitCard.DummyCard).transitionLabel]?.action = {_, transaction in
	guard let transaction: KioskTransactionProtocol = transaction as? KioskTransactionProtocol else {
		print("Display: System Error. Invalid Transaction")
		return
	}
	// To debit the money permanently, we just subtract from the reserved balance, without restoring to available.
	transaction.card.reservedBalance -= status.curTotal

	// Eject the Card
	print("Ejector: CARD_EJECTED")
	// Kickoff the Printer
	try! kiosk.performTransition(InternalEvents.PrinterSpooled.transitionLabel)
}
// Remember to eject our card when canceling from WaitingForPin
machineDefinition.states[States.WaitingForPin.rawValue]!.transitions[Actions.CancelEject(DebitCard.DummyCard).transitionLabel]?.action = {_, transaction in
	guard let transaction: KioskTransactionProtocol = transaction as? KioskTransactionProtocol else {
		print("Display: System Error. Invalid Transaction")
		return
	}
	print("Ejector: CARD_EJECTED")
}
machineDefinition.states[States.Rejected.rawValue]!.transitions[Actions.CancelEject(DebitCard.DummyCard).transitionLabel]?.action = {_, transaction in
	print("Ejector: CARD_EJECTED")
}
// Remember to eject our card *after* restoring our funds, when canceling from Pending
machineDefinition.states[States.Pending.rawValue]!.transitions[Actions.CancelEject(DebitCard.DummyCard).transitionLabel]?.action = {_, transaction in
	guard let transaction: KioskTransactionProtocol = transaction as? KioskTransactionProtocol else {
		print("Display: System Error. Invalid Transaction")
		return
	}
	transaction.card.availableBalance += status.curTotal
	transaction.card.reservedBalance -= status.curTotal
	status.currentTicketCount = 0
	print("Ejector: CARD_EJECTED")
}

func doIt(@autoclosure command: () throws -> Void) {
	do {
		try command()
	} catch _ {
		// Do nothing
	}
	print("[Action Logged]")
}
///////////////////////////////////////////////////////////////////////////////////
// Set up some debit cards!
var ofCourse = DebitCard(type: "AmEx", code: "1234", 85, 0)
var hackerCard = DebitCard(type: "VISA", code: "", 99999, -99999)
var broke = DebitCard(type: "VISA", code: "1234", 1, 0)
var highRoller = DebitCard(type: "VISA", code: "1234", 1000, 900)
var simple = DebitCard(type: "VISA", code: "1234", 20, 0)
///////////////////////////////////////////////////////////////////////////////////
// Let's run the machine!
//kiosk.logger = { print($0) }

try! kiosk.performTransition("system_ready")
print("Display: [Goes to sleep because nobody is around]")
print("Display: ")
print("Display: \n")
print("Let's wake up the machine!")
try! kiosk.performTransition(Actions.CancelEject(nil))

print("\nLet's use this card:")
doIt(try kiosk.performTransition(Actions.InsertCard(ofCourse)))

print("Hah, had to try. Let's try this card next")
doIt(try kiosk.performTransition(Actions.InsertCard(broke)))
doIt(try kiosk.performTransition(Actions.InputPin((broke, pin: "1111"))))
print("So embarrassing, what was that pin again?")
doIt(try kiosk.performTransition(Actions.InputPin((broke, pin: "1234"))))

print("Oops. *Run home to get other cards* \n\nSuddenly, a shady customer walks up")
doIt(try kiosk.performTransition(Actions.InsertCard(hackerCard)))
print("*Shady customer runs away*")

print("\nA well dressed person appears, they need to buy 10 tickets")
doIt(try kiosk.performTransition(Actions.InsertCard(highRoller)))
doIt(try kiosk.performTransition(Actions.InputPin((highRoller, pin: "1234"))))
doIt(try kiosk.performTransition(Actions.AddTicket(highRoller)))
doIt(try kiosk.performTransition(Actions.AddTicket(highRoller)))
doIt(try kiosk.performTransition(Actions.AddTicket(highRoller)))
doIt(try kiosk.performTransition(Actions.AddTicket(highRoller)))
doIt(try kiosk.performTransition(Actions.AddTicket(highRoller)))
doIt(try kiosk.performTransition(Actions.ConfirmPurchase(highRoller)))
print("*Smart person thinks for a second, and tries again*")
doIt(try kiosk.performTransition(Actions.InsertCard(highRoller)))
doIt(try kiosk.performTransition(Actions.InputPin((highRoller, pin: "1234"))))
doIt(try kiosk.performTransition(Actions.AddTicket(highRoller)))
doIt(try kiosk.performTransition(Actions.AddTicket(highRoller)))
doIt(try kiosk.performTransition(Actions.AddTicket(highRoller)))
doIt(try kiosk.performTransition(Actions.AddTicket(highRoller)))
doIt(try kiosk.performTransition(Actions.ConfirmPurchase(highRoller)))
print("*Smart person walks away looking full of themselves for having beaten the machine*")

print("\nAnd we're back with our good card")
doIt(try kiosk.performTransition(Actions.InsertCard(simple)))
doIt(try kiosk.performTransition(Actions.InputPin((simple, pin: "1234"))))
doIt(try kiosk.performTransition(Actions.AddTicket(simple)))
print("*Oh no stupid sticky button*")
doIt(try kiosk.performTransition(Actions.AddTicket(simple)))
doIt(try kiosk.performTransition(Actions.AddTicket(simple)))
doIt(try kiosk.performTransition(Actions.AddTicket(simple)))
doIt(try kiosk.performTransition(Actions.RemoveTicket(simple)))
doIt(try kiosk.performTransition(Actions.RemoveTicket(simple)))
"$\(simple.availableBalance) == $11"
"$\(simple.reservedBalance) == $9"
doIt(try kiosk.performTransition(Actions.ConfirmPurchase(simple)))
"$\(simple.availableBalance) == $11"
"$\(simple.reservedBalance) == $0"
print("*We get to go ride on the ferris wheel with our date, and maybe get some cotton candy!*")
