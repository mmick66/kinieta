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
    
    @IBOutlet weak var goButton: UIButton!
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }

    @IBAction func goButtonPressed(_ sender: UIButton) {
        self.square.move(["x": 250, "y": 500, "r": 30], during: 1.0).ease(Easing.easeInOut)
        
    }
    

}

