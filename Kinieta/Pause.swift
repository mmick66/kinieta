//
//  Pause.swift
//  Kinieta
//
//  Created by Michael Michailidis on 10/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Pause: Action {
    
    init(_ view: UIView, for duration: TimeInterval) {
        super.init(view)
        self.setTimeframe(for: duration)
    }
    
}
