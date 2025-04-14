// Copyright 2025 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
    

import Foundation

@objc class MUTextMessage: NSObject {
    @objc private(set) var heading: String
    @objc private(set) var message: String
    @objc private(set) var date: Date
    @objc private(set) var links: [Any]
    @objc private(set) var images: [Any]
    @objc private(set) var sentBySelf: Bool
    
    private init(heading: String, message: String, date: Date, embeddedLinks: [Any], embeddedImages: [Any], timestampDate: Date, sentBySelf: Bool) {
        self.heading = heading
        self.message = message
        self.date = date
        self.links = embeddedLinks
        self.images = embeddedImages
        self.sentBySelf = sentBySelf
    }

    @objc func numberOfAttachments() -> Int {
        return links.count + images.count
    }
    
    @objc func hasAttachments() -> Bool {
        return self.numberOfAttachments() > 0
    }

    @objc class func textMessage(heading: String, message: String, embeddedLinks: [Any], embeddedImages: [Any], timestampDate: Date, sentBySelf: Bool) -> MUTextMessage {
        return MUTextMessage(heading: heading, message: message, date: timestampDate, embeddedLinks: embeddedLinks, embeddedImages: embeddedImages, timestampDate: timestampDate, sentBySelf: sentBySelf)
    }
}
