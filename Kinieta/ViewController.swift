//
//  ViewController.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

let color1 = UIColor(red:1.00, green:0.44, blue:0.75, alpha:1.00)
let color2 = UIColor(red:0.00, green:1.00, blue:1.00, alpha:1.00)

class ViewController: UIViewController {

    @IBOutlet var square: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Defaults.ColorInterpolation.Method = .RGB_HLC_Assisted
        
        self.square.backgroundColor = color1
        self.square.layer.cornerRadius = 6.0
    }
    
    @IBOutlet weak var goButton: UIButton!
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @IBAction func goButtonPressed(_ sender: UIButton) {
        

        self.square.move(to: ["x": 200, "y": 100, "bg": color2], during: 3.0).wait(for: 4.0).complete {
            self.square.backgroundColor = color1
        }
        
        
    }
    

}


