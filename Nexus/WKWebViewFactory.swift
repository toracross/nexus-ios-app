//
//  WKWebViewFactory.swift
//  Nexus
//
//  Created by Jade Mulholland on 23/02/2016.
//  Copyright © 2016 Nexus Social Network Pty Ptd. All rights reserved.
//

import Foundation
import WebKit

class WKWebViewFactory {
    var webView = WKWebView()
    
    static var sharedInstance = WKWebViewFactory()
}