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
        self.square.layer.cornerRadius = 6.0
    }
    
    @IBOutlet weak var goButton: UIButton!
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @IBAction func goButtonPressed(_ sender: UIButton) {
        
        self.square.move(to: ["x": 74, "y": 74])
        
        
        self.square.move(to: ["x": 374], during: 1.0).easeInOut(.Cubic)
            .move(to: ["a": 0], during: 0.2).delay(for: 0.8).easeOut()
            .parallel()
        
    }
    

}


