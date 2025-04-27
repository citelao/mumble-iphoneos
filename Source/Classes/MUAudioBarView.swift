// Copyright 2025 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
    

import Foundation
import UIKit

@objc class MUAudioBarView : UIView {
    private var below: Float
    @objc func setBelow(_ below: Float) {
        self.below = below
    }
    
    private var above: Float
    @objc func setAbove(_ above: Float) {
        self.above = above
    }
    
    private var min: Float
    private var max: Float
    private var value: Float
    private var timer: Timer?
    
    override init(frame: CGRect) {
        value = 0.5
        min = 0
        max = 1
        
        below = 0
        above = 0
        
        super.init(frame: frame)
        
        timer = Timer(timeInterval: TimeInterval(floatLiteral: 1/60), target: self, selector: #selector(tickTock), userInfo: nil, repeats: true)
        
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        //TODO: timer?.invalidate()
        //timer!.invalidate()
    }
    
    override func draw(_ rect: CGRect) {
        let bounds = self.bounds;
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.clear(bounds)
        
        self.below = UserDefaults.standard.float(forKey: "AudioVADBelow")
        self.above = UserDefaults.standard.float(forKey: "AudioVADAbove")
        
        let scale = Float(bounds.width) / (max - min);
        let below = Int((self.below-min)*scale);
        let above = Int((self.above-min)*scale);
        let value = Int((self.value-min)*scale);
        
        let redA = MUColor.badPingColor().withAlphaComponent(0.6).cgColor
        let redO = MUColor.badPingColor().cgColor
        let yellowA = MUColor.mediumPingColor().withAlphaComponent(0.6).cgColor
        let yellowO = MUColor.mediumPingColor().cgColor
        let greenA = MUColor.goodPingColor().withAlphaComponent(0.6).cgColor
        let greenO = MUColor.mediumPingColor().cgColor
        
        if self.above < self.below {
            ctx.setFillColor(redA)
            ctx.fill(bounds)
            return
        }
        
        var redBounds = CGRect(x: bounds.origin.x, y: 0, width: CGFloat(below), height: bounds.height);
        ctx.setFillColor(redA);
        ctx.fill(redBounds);

        var x = redBounds.width
        let yellowBounds = CGRectMake(x, 0, CGFloat(above)-x, bounds.height)
        ctx.setFillColor(yellowA)
        ctx.fill(yellowBounds)

        x = yellowBounds.origin.x+yellowBounds.width
        var greenBounds = CGRectMake(x, 0, bounds.width-x, bounds.height)
        ctx.setFillColor(greenA)
        ctx.fill(greenBounds)

        if (value > below) {
            ctx.setFillColor(redO)
            ctx.fill(redBounds)
        } else {
            redBounds = CGRectMake(bounds.origin.x, 0, CGFloat(value), bounds.height)
            ctx.setFillColor(redO)
            ctx.fill(redBounds)
        }
        if (value > above) {
            ctx.setFillColor(yellowO)
            ctx.fill(yellowBounds)

            greenBounds = CGRectMake(x, 0, CGFloat(value)-x, bounds.height)
            ctx.setFillColor(greenO)
            ctx.fill(greenBounds)
        } else if (value > below && value <= above) {
            x = redBounds.size.width
            let yellowBounds = CGRect(x: x, y: 0, width: CGFloat(value)-x, height: bounds.height)
            ctx.setFillColor(yellowO)
            ctx.fill(yellowBounds)
        }
    }
    
    @objc func tickTock() {
        let audio = MKAudio.shared()!
        
        var kind = UserDefaults.standard.string(forKey: "AudioVADKind")
        if !UserDefaults.standard.bool(forKey: "AudioPreprocessor") {
            kind = "amplitude"
        }
        
        if kind == "snr" {
            value = audio.speechProbablity()
        } else {
            value = (audio.peakCleanMic() + 96) / 96
        }
        
        self.setNeedsDisplay()
    }
}
