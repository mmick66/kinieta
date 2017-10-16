//
//  ViewController.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var square2: UIView!
    @IBOutlet var square: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.square.layer.cornerRadius = 6.0
        self.square2.layer.cornerRadius = 6.0
    }
    
    @IBOutlet weak var goButton: UIButton!
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @IBAction func goButtonPressed(_ sender: UIButton) {
        let target = UIColor(red:0.45, green:0.18, blue:0.18, alpha:1.00)
        self.square
            .move(to: ["x": 374], during: 1.0).easeInOut(.Cubic)
            .move(to: ["bg": target], during: 0.3).easeOut()
            .move(to: ["bg": target], during: 0.3).easeOut()
            .parallel()
        
        
    }
    

}


