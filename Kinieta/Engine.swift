//
//  Engine.swift
//  Kinieta
//
//  Created by Michael Michailidis on 06/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Engine {
    
    struct Frame {
        var timestamp: Double
        var duration: Double
        init(_ timestamp: Double, _ duration:Double) {
            self.timestamp  = timestamp
            self.duration   = duration
        }
    }
    
    class DisplayLink {
        private var displayLink: CADisplayLink?
    
        func pause() {
            displayLink?.isPaused = true
        }
        
        func resume() {
            displayLink?.isPaused = false
        }
        
        var onUpdate:((Engine.Frame) -> Void)?
        func start(onUpdate: ((Engine.Frame) -> Void)? = nil) {
            guard displayLink == nil else {
                return
            }
            self.onUpdate = onUpdate
            displayLink = CADisplayLink(target: self, selector: #selector(DisplayLink.update(_:)))
            displayLink?.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        }
        func stop() {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
        
        @objc func update(_ displayLink: CADisplayLink) {
            let frame = Engine.Frame(displayLink.timestamp, displayLink.duration)
            self.onUpdate?(frame)
        }
    }
    
    static let shared = Engine()
    
    let displayLink = Engine.DisplayLink()
    
    private var sequences: [Sequence] = []
    
    func add(sequence: Sequence) {
        
        sequences.append(sequence)
        displayLink.start() { frame in
            self.update(with: frame)
        }
    }
    
    func remove(sequence: Sequence) {
        guard let index = sequences.index(where: { $0 === sequence }) else {
            return
        }
        sequences.remove(at: index)
        if sequences.count == 0 {
            displayLink.stop()
        }
    }
    
    private func update(with frame: Engine.Frame) {
     
        for sequence in sequences {
            switch sequence.update(frame) {
            case .Running:  continue
            case .Finished: self.remove(sequence: sequence)
            }
        }
    }
    
    deinit {
        displayLink.stop()
    }
    
}



