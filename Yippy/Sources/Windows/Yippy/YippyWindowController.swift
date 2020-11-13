//
//  YippyWindowController.swift
//  Yippy
//
//  Created by Matthew Davidson on 25/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxRelay

class YippyWindowController: NSWindowController {

    var inFrame: NSRect?
    var outFrame: NSRect?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.level = NSWindow.Level(NSWindow.Level.mainMenu.rawValue - 2)
        window?.setAccessibilityIdentifier(Accessibility.identifiers.yippyWindow)
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    static func createYippyWindowController() -> YippyWindowController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "YippyWindowController")
        guard let windowController = storyboard.instantiateController(withIdentifier: identifier) as? YippyWindowController else {
            fatalError("Failed to load YippyWindowController of type YippyWindowController from the Main storyboard.")
        }
        
        return windowController
    }
    
    func subscribeTo(toggle: BehaviorRelay<Bool>) -> Disposable {
        return toggle
            .subscribe(onNext: {
                [] in
                if !$0 {
                    NSAnimationContext.beginGrouping()
                    NSAnimationContext.current.completionHandler = {
                        self.close()
                    }
                    self.animateWindowOut()
                    NSAnimationContext.endGrouping()
                }
                else {
                    self.showWindow(nil)
                    self.animateWindowIn()
                }
            })
    }
    
    func subscribeFrameTo(position: Observable<PanelPosition>, screen: Observable<NSScreen>) -> Disposable {
        Observable.combineLatest(position, screen).subscribe(onNext: {
            (position, screen) in
            self.inFrame = nil
            self.outFrame = nil
            self.window?.setFrame(position.getFrame(forScreen: screen), display: true)
        })
    }

    private func animateWindowIn() {
           guard let window = self.window else { return }
           var toFrame: NSRect
           if let inFrame = self.inFrame {
               toFrame = inFrame
           } else {
               toFrame = window.frame
               self.inFrame = toFrame
           }

           var fromFrame: NSRect
           if let outFrame = self.outFrame {
               fromFrame = outFrame
           } else {
               let translation = getTranslation(for: toFrame)
               fromFrame = toFrame.applying(translation)
               self.outFrame = fromFrame
           }

           window.setFrame(fromFrame, display: false)
           window.alphaValue = 0
           window.animator().setFrame(toFrame, display: true, animate: true)
           window.animator().alphaValue = 1
       }

       private func getTranslation(for frame: NSRect) -> CGAffineTransform {
           switch State.main.panelPosition.value {
           case .right:
               return CGAffineTransform(translationX: frame.size.width, y: 0)
           case .left:
               return CGAffineTransform(translationX: -frame.size.width, y: 0)
           case .top:
               return CGAffineTransform(translationX: 0, y: frame.size.height)
           case .bottom:
               return CGAffineTransform(translationX: 0, y: -frame.size.height)
           default:
               return CGAffineTransform(translationX: 0, y: 0)
           }
       }

       private func animateWindowOut() {
           guard let window = self.window,
                 let outFrame = self.outFrame,
                 let inFrame = self.inFrame else { return }
           window.setFrame(inFrame, display: false)
           window.alphaValue = 1
           window.animator().setFrame(outFrame, display: true, animate: true)
           window.animator().alphaValue = 0
       }
}
