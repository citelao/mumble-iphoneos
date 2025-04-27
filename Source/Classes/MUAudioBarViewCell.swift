// Copyright 2025 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
    

import Foundation
import UIKit

@objc class MUAudioBarViewCell : UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        let audioBarView = MUAudioBarView(frame: self.bounds)
        audioBarView.setBelow(0.4)
        audioBarView.setAbove(0.6)
        
        self.backgroundView = audioBarView
        
        // Round the corners on anything but iOS 7 and greater
        if #available(iOS 7, *) {
            self.backgroundView!.layer.masksToBounds = false
            self.backgroundView!.layer.cornerRadius = 0
        } else {
            self.backgroundView!.layer.masksToBounds = true
            self.backgroundView!.layer.cornerRadius = 8
        }
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
