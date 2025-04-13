// Copyright 2025 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
    

import Foundation
import UIKit

@objc class MUUserStateAcessoryView: NSObject {
    @MainActor @objc class func viewFor(user: MKUser) -> UIView {
        let iconHeight = 24.0
        let iconWidth = 28.0
        let iconSize = CGSize(width: iconWidth, height: iconHeight)
        
        var states: [String] = []
        if user.isAuthenticated() {
            states.append("authenticated")
        }
        if user.isSelfDeafened() {
            states.append("deafened_self")
        }
        if user.isSelfMuted() {
            states.append("muted_self")
        }
        if user.isMuted() {
            states.append("muted_server")
        }
        if user.isDeafened() {
            states.append("deafened_server")
        }
        if user.isLocalMuted() {
            states.append("muted_local")
        }
        if user.isSuppressed() {
            states.append("muted_suppressed")
        }
        if user.isPrioritySpeaker() {
            states.append("priorityspeaker")
        }
        
        var widthOffset = Double(states.count) * iconSize.width
        let stateView = UIView.init(frame: CGRect(origin: CGPoint.zero, size: iconSize))
        
        for imageName in states {
            let img = UIImage.init(named: imageName)!
            let imgView = UIImageView.init(image: img)
            let ypos = (iconSize.height - img.size.height) / 2.0
            let xpos = (iconSize.width - img.size.width) / 2.0
            widthOffset -= iconWidth - xpos
            
            imgView.frame = CGRect(
                origin: CGPoint(x: ceil(widthOffset), y: ceil(ypos)),
                size: img.size
            )
            stateView.addSubview(imgView)
        }
        
        return stateView
    }
}
