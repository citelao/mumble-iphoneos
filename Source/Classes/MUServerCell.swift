// Copyright 2025 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import UIKit

//import MumbleKit

class MUServerCell: UITableViewCell, @preconcurrency MKServerPingerDelegate {
    var displayname: String?
    var hostname: String?
    var port: String?
    var username: String?
    var pinger: MKServerPinger?
    
    @objc class func reuseIdentifier() -> String {
        return "ServerCell"
    }
    
    init() {
        super.init(style: .subtitle, reuseIdentifier: MUServerCell.reuseIdentifier())
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @objc(populateFromDisplayName:hostName:port:)
    func populate(displayName: String, hostName: String, port: String) {
        self.displayname = displayName
        
        self.port = port
        
        self.pinger = nil
        
        if hostName.count > 0 {
            self.hostname = hostName
            pinger = MKServerPinger.init(hostname: self.hostname!, port: self.port!)
            pinger!.setDelegate(self)
        } else {
            self.hostname = NSLocalizedString("(No Server)", comment: "")
        }
        
        self.textLabel?.text = self.displayname
        self.detailTextLabel?.text = "\(self.hostname!):\(self.port!)"
        self.imageView?.image = self.drawPingImage(withPing: 999, userCount: 0, isFull: false)
    }
    
    @objc(populateFromFavouriteServer:)
    func populate(favouriteServer favServ: MUFavouriteServer) {
        displayname = favServ.displayName
        
        hostname = favServ.hostName
        
        port = String(favServ.port)
        
        if (favServ.userName.count > 0) {
            username = favServ.userName
        } else {
            username = UserDefaults.standard.string(forKey: "DefaultUserName")
        }
        
        pinger = nil
        if hostname != nil && hostname!.count > 0 {
            pinger = MKServerPinger.init(hostname: hostname!, port: port!)
            pinger!.setDelegate(self)
        } else {
            hostname = NSLocalizedString("(No Server)", comment: "")
        }
        
        self.textLabel?.text = displayname
        self.detailTextLabel?.text = String(format: NSLocalizedString("%@ on %@:%@", comment: "username on hostname:port"), self.username!, self.hostname!, self.port!)
        self.imageView?.image = self.drawPingImage(withPing: 999, userCount: 0, isFull: false)
    }
    
    private func drawPingImage(withPing pingMs: UInt, userCount: UInt, isFull: Bool) -> UIImage {
        let pingColor: UIColor = if pingMs <= 125 {
            MUColor.goodPingColor()
        } else if pingMs > 125 && pingMs <= 250 {
            MUColor.mediumPingColor()
        } else if pingMs > 250 {
            MUColor.badPingColor()
        } else {
            MUColor.badPingColor()
        }
        
        var pingStr = "\(pingMs)\nms"
        if pingMs >= 999 {
            pingStr = "∞\nms"
        }
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 66.0, height: 32.0), false, UIScreen.main.scale)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor(pingColor.cgColor)
        
        ctx.fill(CGRect(x: 0, y: 0, width: 32.0, height: 32.0))
        
        ctx.setTextDrawingMode(.fill)
        ctx.setFillColor(UIColor.white.cgColor)
        
        var paragraphStyle = NSMutableParagraphStyle();
        paragraphStyle.lineBreakMode = .byTruncatingTail;
        paragraphStyle.alignment = .center;
        
        pingStr.draw(in: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0),
                     withAttributes: [
            .font : UIFont.boldSystemFont(ofSize: 12),
            .paragraphStyle : paragraphStyle,
            .foregroundColor : UIColor.white
        ])
        
        if (!isFull) {
            // Non-full servers get the mild iOS blue color
            ctx.setFillColor(MUColor.userCount().cgColor)
        } else {
            // Mark full servers with the same red as we use for
            // 'bad' pings...
            ctx.setFillColor(MUColor.badPingColor().cgColor)
        }
        ctx.fill(CGRect(x: 34.0, y: 0, width: 32.0, height: 32.0))
        
        ctx.setTextDrawingMode(.fill)
        ctx.setFillColor(UIColor.white.cgColor)
        let usersStr = String(format: NSLocalizedString("%lu\nppl", comment: "user count"), userCount)
        
        paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        usersStr.draw(in: CGRect(x: 34.0, y: 0.0, width: 32.0, height: 32.0), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.white
        ])
        
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return img;
    }
    
    func serverPingerResult(_ result: UnsafeMutablePointer<MKServerPingerResult>) {
        let res = result.pointee
        let pingValue = UInt(res.ping * 1000.0)
        let userCount = UInt(res.cur_users)
        let isFull = res.cur_users == res.max_users
        
        self.imageView?.image = self.drawPingImage(withPing: pingValue, userCount: userCount, isFull: isFull)
    }
}
