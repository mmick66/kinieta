//
//  ViewController.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

let start = UIColor(red:1.00, green:0.44, blue:0.75, alpha:1.00)
let targt = UIColor(red:0.00, green:1.00, blue:1.00, alpha:1.00)

class ViewController: UIViewController {

    @IBOutlet var square: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.square.layer.cornerRadius = 6.0
        self.square.backgroundColor = start
    }
    
    @IBOutlet weak var goButton: UIButton!
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @IBAction func goButtonPressed(_ sender: UIButton) {
        
        self.square.move(to: ["bg": targt], during: 3.0).wait(for: 2.0).complete {
            self.square.backgroundColor = start
        }
        
        
    }
    

}


