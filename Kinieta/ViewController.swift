//
//  ViewController.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet var square: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.square.layer.cornerRadius = 4.0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.square.move(["x": 330])
    }




}

