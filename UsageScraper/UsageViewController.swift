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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(notification:)),
            name: NSNotification.Name.UIApplicationDidBecomeActive,
            object: nil)
    }
    
    @objc func applicationDidBecomeActive(notification: NSNotification) {
        self.updateUsage();
    }

    func tryScrapeUsage(callback: ((Bool) -> Void)? = nil) -> Void {
        let datausage_url="https://service.smartmobil.de/mytariff/invoice/showGprsDataUsage"
        Alamofire.request(datausage_url).responseString { response in
            if let html = response.result.value {
                let success = self.parseUsage(html: html)
                if (callback != nil) {
                    callback?(success)
                }
            } else {
                if (callback != nil) {
                    callback?(false)
                }
            }
        }
    }
    
    func hasCredentials() -> Bool {
        let defaults = UserDefaults.standard

        return defaults.string(forKey: "smartmobil_username") != nil &&
                defaults.string(forKey: "smartmobil_password") != nil;
    }

    func credentialsChanged() -> Bool {
        let defaults = UserDefaults.standard
        return  (defaults.string(forKey: "last_login_user") != defaults.string(forKey: "smartmobil_username")) ||
                (defaults.string(forKey: "last_login_pw") != defaults.string(forKey: "smartmobil_password"))
    }

    func showLoginFailedAlert() {
        let alert = UIAlertController(title: "Login Failed", message: "Failure logging in", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func updateUsage() {
        
        if (!self.hasCredentials())
        {
            return;
        }

        let defaults = UserDefaults.standard

        if (self.credentialsChanged()) {
            self.login(user: defaults.string(forKey: "smartmobil_username")!,
                       password: defaults.string(forKey: "smartmobil_password")!,
                       callback: { success in
                        if success {
                            self.tryScrapeUsage()
                        } else {
                            self.showLoginFailedAlert()
                        }
            })
        } else {
            self.tryScrapeUsage(callback: { success in
                if (!success) {
                    self.login(user: defaults.string(forKey: "smartmobil_username")!,
                          password: defaults.string(forKey: "smartmobil_password")!,
                          callback: { success in
                            if success {
                                self.tryScrapeUsage()
                            } else {
                                self.showLoginFailedAlert()
                            }
                    })

                }
            })
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func login(user: String, password: String, callback: @escaping (Bool) -> Void) {
        let login_url = "https://service.smartmobil.de/"
        let submit_url = "https://service.smartmobil.de/public/login_check"
        
        Alamofire.request(login_url).responseString { response in
            print("\(response.result.isSuccess)")
            if let html = response.result.value {
                let token = self.parseToken(html: html)
                print("token=" + token);
                
                 let parameters = ["UserLoginType[alias]": user,
                                   "UserLoginType[password]": password,
                                   "UserLoginType[logindata]" : "",
                                   "UserLoginType[_token]" : token]
                
                Alamofire.request(submit_url, method: .post, parameters: parameters).responseString { response in
                    if let html = response.result.value {
                        let success = self.parseLoginResult(html: html)
                        if (success) {
                            let defaults = UserDefaults.standard
                            defaults.set(user, forKey: "last_login_user")
                            defaults.set(password, forKey: "last_login_pw")
                            defaults.synchronize()
                        }
                        callback(success)
                    } else {
                        callback(false)
                    }
                }
            } else {
                callback(false)
            }
        }
    }
    
    func parseLoginResult(html: String) -> Bool {
        //class="loginText error error2"
        do{
            let doc: Document = try SwiftSoup.parse(html)
            let loginErrors:Elements? = try doc.getElementsByClass("loginText error error2")
            return loginErrors?.size() == 0
        }catch Exception.Error(let _, let message){
            print(message)
        }catch{
            print("error")
        }
        return true;
    }
    
    func parseToken(html: String) -> String {
        do{
            let doc: Document = try SwiftSoup.parse(html)
            let token:String = try doc.getElementById("UserLoginType__token")!.val();
            return token
        }catch Exception.Error(let _, let message){
            print(message)
        }catch{
            print("error")
        }
        return "";
    }

    func parseUsage(html: String) -> Bool {
        do{
            let doc: Document = try SwiftSoup.parse(html)
            if let currentMonth = try doc.getElementById("currentMonth") {
                let table = try currentMonth.select("table").first()
                let avail = try table?.child(0).child(2).child(2).text()
                let used = try table?.child(0).child(3).child(2).text()
                
                let usedKB:Int = self.parseBytes(byteString:used!)
                let availKB:Int = self.parseBytes(byteString:avail!)
                
                let usedHuman = String(format:"%.2u", usedKB / 1024)
                let availHuman = String(format:"%.2u", (availKB-usedKB) / 1024)
                
                self.progressView.maxValue = 100;
                self.progressView.setProgress(value: 100 * CGFloat(usedKB) / CGFloat(availKB), animationDuration: 1)
                
                self.usedLabel.text = usedHuman;
                self.availLabel.text = availHuman;
                self.daysUntilReset.text = String(self.daysUntilEndOfMonth())
                
                let predictedDays = ((availKB-usedKB) * self.usedDays()) / usedKB
                self.predictedDays.text = String(predictedDays)
                
                self.animateView(view: self.daysUntilReset)
                self.animateView(view: self.predictedDays)
                self.animateView(view: self.usedLabel)
                self.animateView(view: self.availLabel)
                
                print(String(usedKB) + "/" + String(availKB))
                return true;
            } else {
                return false;
            }
        }catch Exception.Error(let _, let message){
            print(message)
            return false;
        }catch{
            print("error")
            return false;
        }
    }
    
    func startOfMonth() -> Date {
        return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    }
    
    func endOfMonth() -> Date {
        return Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: self.startOfMonth())!
    }
    
    func daysUntilEndOfMonth() -> Int {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: self.endOfMonth())
        return components.day!;
    }
    
    func usedDays() -> Int {
        let components = Calendar.current.dateComponents([.day], from: self.startOfMonth(), to: Date())
        return components.day!;
    }
    
    func parseBytes(byteString: String) -> Int {
        let parts = byteString.components(separatedBy: " ")
        var amount = Double(parts[0].replacingOccurrences(of: ",", with: "."))!
        if parts[1] == "MB" {
            amount *= 1024.0;
        }
        if parts[1] == "GB" {
            amount *= 1024*1024.0;
        }
        
        return Int(amount)
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

