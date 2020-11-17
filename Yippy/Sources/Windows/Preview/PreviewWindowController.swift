//
//  PreviewWindowController.swift
//  Yippy
//
//  Created by Matthew Davidson on 19/11/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxRelay

class PreviewWindowController: NSWindowController {
    
    var previewTextViewController: PreviewTextViewController!
    var previewImageViewController: PreviewImageViewController!
    var previewQLViewController: PreviewQLViewController!
    
    var disposeBag = DisposeBag()
    
    var previewItem: HistoryItem?

    var fromFrame: NSRect?
    var toFrame: NSRect?

    private static let easeOutCirc = CAMediaTimingFunction(controlPoints: 0.075, 0.82, 0.165, 1)
    
    private static func createPreviewViewController<T>() -> T where T: PreviewViewController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: T.identifier) as? T else {
            fatalError("Failed to load \(T.identifier) of type \(T.self) from the Main storyboard.")
        }
        return controller
    }
    
    static func create() -> PreviewWindowController {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.level = NSWindow.Level(NSWindow.Level.mainMenu.rawValue - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        let previewWC = PreviewWindowController(window: window)
        
        previewWC.previewTextViewController = createPreviewViewController()
        previewWC.previewImageViewController = createPreviewViewController()
        previewWC.previewQLViewController = createPreviewViewController()
        
        State.main.showsRichText.distinctUntilChanged().subscribe(onNext: previewWC.onShowsRichText).disposed(by: previewWC.disposeBag)
        
        return previewWC
    }
    
    func subscribeTo(previewItem: BehaviorRelay<HistoryItem?>) -> Disposable {
        return previewItem
            .subscribe(onNext: {
                self.previewItem = $0
                if let item = $0 {
                    self.showWindow(nil)
                    self.updateController(forItem: item)
                }
                else {
                    NSAnimationContext.beginGrouping()
                    NSAnimationContext.current.completionHandler = {
                        self.close()
                    }
                    self.animateOut()
                    self.fromFrame = nil
                    self.toFrame = nil
                    NSAnimationContext.endGrouping()
                }
            })
    }
    
    func updateController(forItem item: HistoryItem) {
        let controller = self.getViewController(forItem: item)
        self.contentViewController = controller
        animateIn(forItem: item, controller: controller)
    }
    
    func getViewController(forItem item: HistoryItem) -> PreviewViewController {
        if item.getFileUrl() != nil {
            return previewQLViewController
        }
        else if item.types.contains(.tiff) || item.types.contains(.png) {
            return previewImageViewController
        }
        else {
            return previewTextViewController
        }
    }
    
    func onShowsRichText(_ showsRichText: Bool) {
        if let item = previewItem {
            previewTextViewController.isRichText = showsRichText
            if getViewController(forItem: item) is PreviewTextViewController {
                updateController(forItem: item)
            }
        }
    }

    private func animateIn(forItem item: HistoryItem, controller: PreviewViewController) {
        if var startFrame = State.main.previewHistoryItemFrame {
            var fromAlpha: CGFloat = 0
            fromFrame = startFrame
            if let toFrame = self.toFrame {
                fromAlpha = 1
                startFrame = toFrame
            }
            let endFrame = controller.configureView(forItem: item)
            toFrame = endFrame

            animate(fromFrame: startFrame, to: endFrame, fromAlpha: fromAlpha, to: 1)
        }
    }

    private func animateOut() {
        if let startFrame = self.toFrame, let endFrame = self.fromFrame {
            animate(fromFrame: startFrame, to: endFrame, fromAlpha: 1, to: 0)
        }
    }

    private func animate(fromFrame startFrame: NSRect, to endFrame: NSRect, fromAlpha startAlpha: CGFloat, to endAlpha: CGFloat) {
        window?.setFrame(startFrame, display: false)
        window?.alphaValue = startAlpha

        // Set up scaling
        let resizeAnimation = CABasicAnimation(keyPath: "bounds.size")
        resizeAnimation.fromValue = startFrame.size
        resizeAnimation.toValue = endFrame.size
        resizeAnimation.fillMode = CAMediaTimingFillMode.forwards
        resizeAnimation.isRemovedOnCompletion = false

        let pathAnimation = CAKeyframeAnimation(keyPath: "position")
        pathAnimation.calculationMode = CAAnimationCalculationMode.paced;
        pathAnimation.fillMode = CAMediaTimingFillMode.forwards;
        pathAnimation.isRemovedOnCompletion = false

        let curvedPath = CGMutablePath()
        curvedPath.move(to: startFrame.origin)
        curvedPath.addQuadCurve(to: endFrame.origin, control: CGPoint(x: startFrame.origin.x,  y: endFrame.origin.y))
        pathAnimation.path = curvedPath

        NSAnimationContext.current.timingFunction = PreviewWindowController.easeOutCirc
        NSAnimationContext.current.duration = 0.5
        window?.animations = [
            "frameOrigin": pathAnimation,
            "frameSize": resizeAnimation
        ]
        window?.animator().setFrame(endFrame, display: true)
        window?.animator().alphaValue = endAlpha
    }
}
