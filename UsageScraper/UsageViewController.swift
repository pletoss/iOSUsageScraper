//
//  ViewController.swift
//  UsageScraper
//
//  Created by Raul Gigea on 04.12.17.
//  Copyright © 2017 Raul Gigea. All rights reserved.
//

import UIKit
import Alamofire
import SwiftSoup
import UICircularProgressRing

class UsageViewController: UIViewController {
    @IBOutlet weak var usedLabel: UILabel!
    @IBOutlet weak var availLabel: UILabel!
    @IBOutlet weak var predictedDays: UILabel!
    @IBOutlet weak var daysUntilReset: UILabel!
    @IBOutlet weak var progressView: UICircularProgressRingView!
    
    var usageScraper : UsageScaper?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.usageScraper = UsageScraper.UsageScaper(onChange: {
            self.progressView.maxValue = 100;
            self.progressView.setProgress(value: (self.usageScraper!.usagePercent), animationDuration: 1)
            self.usedLabel.text = self.usageScraper!.usedMBFormatted;
            self.availLabel.text = self.usageScraper!.availMBFormatted;
            self.daysUntilReset.text = String(self.usageScraper!.daysUntilReset)
            self.predictedDays.text = String(self.usageScraper!.daysPredicted)
            
            self.animateView(view: self.daysUntilReset)
            self.animateView(view: self.predictedDays)
            self.animateView(view: self.usedLabel)
            self.animateView(view: self.availLabel)
        }, onLoginFail: {
            self.showLoginFailedAlert()
        })
    }
    
    func showLoginFailedAlert() {
        let alert = UIAlertController(title: "Login Failed", message: "Failure logging in", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func animateView(view: UIView) {
        
        view.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        
        UIView.animate(withDuration: 2.0,
                       delay: 0,
                       usingSpringWithDamping: CGFloat(0.20),
                       initialSpringVelocity: CGFloat(6.0),
                       options: UIViewAnimationOptions.allowUserInteraction,
                       animations: {
                        view.transform = CGAffineTransform.identity
        },
                       completion: { Void in()  }
        )
    }

}

