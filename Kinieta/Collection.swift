//
//  Collection.swift
//  Kinieta
//
//  Created by Michael Michailidis on 11/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Collection: Action {
    
    let actions: [ActionType]
    let view: UIView
    
    init(_ view: UIView, actions: [ActionType], complete: Block?) {
        
        self.actions    = actions
        self.view       = view
        
        super.init()
        
        self.onComplete = complete
        
    }
    
}
