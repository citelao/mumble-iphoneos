// Copyright 2025 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
    

import Foundation
import UIKit

@objc class MUImage: NSObject {
    @objc @MainActor class func tableViewCellImageFromImage(_ srcImage: UIImage) -> UIImage {
        let scale = UIScreen.main.scale
        let scaledWidth = srcImage.size.width * (44/srcImage.size.height)
        let rect = CGRect(x: 0, y: 0, width: scaledWidth, height: 44)
        
        // Create the rounded-rect mask
        UIGraphicsBeginImageContextWithOptions(rect.size, false, scale)
        var ctx = UIGraphicsGetCurrentContext()!
        let radius = 10.0
        
        ctx.beginPath()
        ctx.move(to: CGPoint(x: rect.origin.x,
                             y: rect.origin.y + radius))
        ctx.addLine(to: CGPoint(x: rect.origin.x,
                                y: rect.origin.y + rect.height - radius))
        ctx.addArc(center: CGPoint(x: rect.origin.x + radius,
                                   y: rect.origin.y + rect.size.height - radius),
                   radius: radius, startAngle: .pi, endAngle: .pi / 2, clockwise: true)
        ctx.addLine(to: CGPoint(x: rect.origin.x + rect.size.width,
                                y: rect.origin.y + rect.size.height))
        ctx.addLine(to: CGPoint(x: rect.origin.x + rect.size.width,
                                y: rect.origin.y))
        ctx.addLine(to: CGPoint(x: rect.origin.x + radius,
                                y: rect.origin.y))
        ctx.addArc(center: CGPoint(x: rect.origin.x + radius,
                                   y: rect.origin.y + radius),
                   radius: radius, startAngle: -.pi / 2, endAngle: .pi, clockwise: true)
        ctx.closePath()
        UIColor.black.set()
        ctx.fillPath()
        let alphaMask = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // Draw the image
        UIGraphicsBeginImageContextWithOptions(rect.size, false, scale)
        ctx = UIGraphicsGetCurrentContext()!
        ctx.clip(to: rect, mask: alphaMask.cgImage!)
        srcImage.draw(in: rect)
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    @objc @MainActor class func imageNamed(_ imageName: String) -> UIImage {
        let scale = UIScreen.main.scale
        let height = UIScreen.main.bounds.height
        // For now, we require all -568h images to also be @2x.
        if height == 568 && scale == 2 {
            let expectedFn = String(format: "%@-568h", imageName)
            let attemptedImage = UIImage(named: expectedFn)
            
            if attemptedImage != nil {
                return attemptedImage!
            }
        }
        return UIImage(named: imageName)!
    }
    
    // clearColorImage returns a 1x1 clearColor image
    // that can be used as a transparent background image
    // for UIKit APIs that force you to provide UIImages.
    @objc class func clearColorImage() -> UIImage {
        let fillRect = CGRect(origin: .zero, size: CGSize(width: 1, height: 1))
        
        UIGraphicsBeginImageContext(fillRect.size)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor(UIColor.clear.cgColor)
        ctx.fill(fillRect)
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}
