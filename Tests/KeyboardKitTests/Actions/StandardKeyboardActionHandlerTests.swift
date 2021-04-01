//
//  StandardKeyboardActionHandlerTests.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2019-05-06.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import MockingKit
import KeyboardKit
import UIKit

class StandardKeyboardActionHandlerTests: QuickSpec {
    
    var mock: Mock!
    func autocompleteAction() { mock.call(autocompleteActionRef, args: ()) }
    func changeKeyboardTypeAction(_ type: KeyboardType) { mock.call(changeKeyboardTypeActionRef, args: (type))  }
    lazy var autocompleteActionRef = MockReference(autocompleteAction)
    lazy var changeKeyboardTypeActionRef = MockReference(changeKeyboardTypeAction)

    override func spec() {
        
        var handler: TestClass!
        var feedbackHandler: MockKeyboardFeedbackHandler!
        var inputViewController: MockKeyboardInputViewController!
        var proxy: MockTextDocumentProxy!
        var spaceDragHandler: MockDragGestureHandler!
        
        beforeEach {
            self.mock = Mock()
            feedbackHandler = MockKeyboardFeedbackHandler()
            inputViewController = MockKeyboardInputViewController()
            proxy = MockTextDocumentProxy()
            inputViewController.keyboardContext.textDocumentProxy = proxy
            spaceDragHandler = MockDragGestureHandler()
            handler = TestClass(
                keyboardContext: inputViewController.keyboardContext,
                keyboardBehavior: inputViewController.keyboardBehavior,
                keyboardFeedbackHandler: feedbackHandler,
                autocompleteContext: inputViewController.autocompleteContext,
                autocompleteAction: self.autocompleteAction,
                changeKeyboardTypeAction: self.changeKeyboardTypeAction,
                spaceDragGestureHandler: spaceDragHandler)
        }


        // MARK: - KeyboardActionHandler

        describe("can handle gesture on action") {

            it("can handle any action that isn't nil") {
                expect(handler.canHandle(.tap, on: .backspace, sender: nil)).to(beTrue())
                expect(handler.canHandle(.doubleTap, on: .backspace, sender: nil)).to(beFalse())
            }
        }
        
        describe("handling gesture on action") {
            
            it("tap triggers a bunch of actions") {
                handler.handle(.tap, on: .character("a"))
                expect(self.mock.hasCalled(self.autocompleteActionRef)).to(beTrue())
                expect(handler.hasCalled(handler.tryChangeKeyboardTypeRef)).to(beTrue())
                expect(handler.hasCalled(handler.tryEndSentenceRef)).to(beTrue())
                expect(handler.hasCalled(handler.tryRegisterEmojiRef)).to(beTrue())
                expect(feedbackHandler.hasCalled(feedbackHandler.triggerFeedbackWithActionProviderRef)).to(beTrue())
            }
        }
        
        describe("handling drag on action") {
            
            it("uses space drag handler for space") {
                handler.handleDrag(on: .space, from: .init(x: 1, y: 2), to: .init(x: 3, y: 4))
                let calls = spaceDragHandler.calls(to: spaceDragHandler.handleDragGestureRef)
                expect(calls.count).to(equal(1))
                expect(calls[0].arguments.0).to(equal(.init(x: 1, y: 2)))
                expect(calls[0].arguments.1).to(equal(.init(x: 3, y: 4)))
            }
            
            it("doesn't do anything for other actions") {
                let actions = KeyboardAction.testActions.filter { $0 != .space }
                actions.forEach {
                    handler.handleDrag(on: $0, from: .zero, to: .zero)
                }
                expect(spaceDragHandler.hasCalled(spaceDragHandler.handleDragGestureRef)).to(beFalse())
            }
        }


        // MARK: - Actions

        context("action for gesture on action") {

            let actions = KeyboardAction.testActions

            describe("double tap action") {

                it("is nil for all actions with standard action") {
                    actions.forEach {
                        let action = handler.action(for: .doubleTap, on: $0)
                        expect(action == nil).to(equal($0.standardDoubleTapAction == nil))
                    }
                }
            }

            describe("long press action") {

                it("is not nil for actions with standard action") {
                    actions.forEach {
                        let action = handler.action(for: .longPress, on: $0)
                        expect(action == nil).to(equal($0.standardLongPressAction == nil))
                    }
                }
            }

            describe("tap action") {

                it("is not nil for actions with standard action") {
                    actions.forEach {
                        let action = handler.action(for: .tap, on: $0)
                        expect(action == nil).to(equal($0.standardTapAction == nil))
                    }
                }
            }

            describe("repeat action") {

                it("is not nil for actions with standard action") {
                    actions.forEach {
                        let action = handler.action(for: .repeatPress, on: $0)
                        expect(action == nil).to(equal($0.standardRepeatAction == nil))
                    }
                }
            }
        }


        // MARK: - Action Handling

        describe("trying to end sentence after gesture on action") {

            it("does not end sentence if behavior says no") {
                proxy.documentContextBeforeInput = ""
                handler.tryEndSentence(after: .tap, on: .character("a"))
                expect(handler.hasCalled(handler.handleRef)).to(beFalse())
            }

            it("ends sentence with behavior action if behavior says yes") {
                proxy.documentContextBeforeInput = "foo  "
                handler.tryEndSentence(after: .tap, on: .space)
                expect(proxy.hasCalled(proxy.deleteBackwardRef, numberOfTimes: 2)).to(beTrue())
                expect(proxy.hasCalled(proxy.insertTextRef, numberOfTimes: 1)).to(beTrue())
            }
        }

        describe("trying to change keyboard type after gesture on action") {

            it("does not change type if new type is same as current") {
                inputViewController.keyboardContext.keyboardType = .alphabetic(.lowercased)
                handler.tryChangeKeyboardType(after: .tap, on: .character("a"))
                expect(inputViewController.hasCalled(inputViewController.changeKeyboardTypeRef)).to(beFalse())
            }

            it("changes type if new type is different from current") {
                inputViewController.keyboardContext.keyboardType = .alphabetic(.uppercased)
                handler.tryChangeKeyboardType(after: .tap, on: .character("a"))
                let inv = self.mock.calls(to: self.changeKeyboardTypeActionRef)
                expect(inv.count).to(equal(1))
                expect(inv[0].arguments).to(equal(.alphabetic(.lowercased)))
            }
        }

        describe("trying to register emoji after gesture on action") {

            var mockProvider: MockFrequentEmojiProvider!

            beforeEach {
                mockProvider = MockFrequentEmojiProvider()
                EmojiCategory.frequentEmojiProvider = mockProvider
            }

            it("aborts if gesture is not tap") {
                handler.tryRegisterEmoji(after: .doubleTap, on: .emoji(Emoji("a")))
                expect(mockProvider.hasCalled(mockProvider.registerEmojiRef)).to(beFalse())
            }

            it("aborts if action is not emoji") {
                handler.tryRegisterEmoji(after: .tap, on: .space)
                expect(mockProvider.hasCalled(mockProvider.registerEmojiRef)).to(beFalse())
            }

            it("registers tapped emoji to emoji category provider") {
                handler.tryRegisterEmoji(after: .tap, on: .emoji(Emoji("a")))
                expect(mockProvider.hasCalled(mockProvider.registerEmojiRef)).to(beTrue())
            }
        }
    }
}


private class TestClass: StandardKeyboardActionHandler, Mockable {

    var mock = Mock()

    lazy var handleRef = MockReference(handle as (KeyboardGesture, KeyboardAction) -> Void)
    lazy var tryChangeKeyboardTypeRef = MockReference(tryChangeKeyboardType)
    lazy var tryEndSentenceRef = MockReference(tryEndSentence)
    lazy var tryRegisterEmojiRef = MockReference(tryRegisterEmoji)

    override func handle(_ gesture: KeyboardGesture, on action: KeyboardAction) {
        super.handle(gesture, on: action)
        call(handleRef, args: (gesture, action))
    }
    
    override func tryChangeKeyboardType(after gesture: KeyboardGesture, on action: KeyboardAction) {
        super.tryChangeKeyboardType(after: gesture, on: action)
        call(tryChangeKeyboardTypeRef, args: (gesture, action))
    }

    override func tryEndSentence(after gesture: KeyboardGesture, on action: KeyboardAction) {
        super.tryEndSentence(after: gesture, on: action)
        call(tryEndSentenceRef, args: (gesture, action))
    }

    override func tryRegisterEmoji(after gesture: KeyboardGesture, on action: KeyboardAction) {
        super.tryRegisterEmoji(after: gesture, on: action)
        call(tryRegisterEmojiRef, args: (gesture, action))
    }
}
