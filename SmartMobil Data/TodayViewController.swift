//
//  TodayViewController.swift
//  SmartMobil Data
//
//  Created by Raul Gigea on 05.12.17.
//  Copyright © 2017 Raul Gigea. All rights reserved.
//

import UIKit
import NotificationCenter
import UICircularProgressRing

class TodayViewController: UIViewController, NCWidgetProviding {
        
    @IBOutlet weak var progressView: UICircularProgressRingView!
    @IBOutlet weak var consumedLabel: UILabel!
    @IBOutlet weak var remainingLabel: UILabel!
    @IBOutlet weak var daysUntilResetLabel: UILabel!
    @IBOutlet weak var predictedDaysLabel: UILabel!
    var usageScraper : UsageScaper?
    var failedLogin : Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if (self.usageScraper == nil) {
            self.usageScraper = UsageScaper()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        self.usageScraper!.updateUsage { (success) in
            if (success) {
                self.progressView.maxValue = 100;
                self.progressView.setProgress(value: (self.usageScraper!.usagePercent), animationDuration: 1)
                self.consumedLabel.text = self.usageScraper!.usedMBFormatted;
                self.remainingLabel.text = self.usageScraper!.availMBFormatted;
                self.daysUntilResetLabel.text = String(self.usageScraper!.daysUntilReset)
                self.predictedDaysLabel.text = String(self.usageScraper!.daysPredicted)
                
                self.animateView(view: self.consumedLabel)
                self.animateView(view: self.remainingLabel)
                self.animateView(view: self.daysUntilResetLabel)
                self.animateView(view: self.predictedDaysLabel)

                completionHandler(NCUpdateResult.newData)
            } else {
                completionHandler(NCUpdateResult.failed)
            }
        }
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
