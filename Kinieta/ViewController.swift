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
        
        
        let myBezier = Bezier(0.16, 0.73, 0.89, 0.24)
        self.square.move(to: ["x": 374], during: 1.0).easeInOut(.Custom(myBezier)).wait(for: 1.0).complete {
            self.square.move(to: ["x": 74, "y": 74])
        }
        
    }
    

}


