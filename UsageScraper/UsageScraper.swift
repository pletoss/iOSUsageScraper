import Foundation

import UIKit
import Alamofire
import SwiftSoup

public class UsageScaper {
    public var usagePercent : CGFloat = 0

    public var usedMBFormatted : String = "-"
    public var availMBFormatted : String = "-"
    public var daysUntilReset : Int = 0
    public var daysPredicted : Int = 0
    
    public var usedKB : Int = 0
    public var totalKB : Int = 0
    
    public var onChangeCallback : (() -> Void)?
    public var onLoginFailed : (() -> Void)?

    var defaults : UserDefaults?
    
    init(onChange:(() -> Void)? = nil, onLoginFail:(() -> Void)? = nil) {
        self.defaults = UserDefaults.init(suiteName: "group.sprintcode.usagescraper")
        self.onChangeCallback = onChange
        self.onLoginFailed = onLoginFail
        
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
        return defaults?.string(forKey: "smartmobil_username") != nil &&
            defaults?.string(forKey: "smartmobil_password") != nil;
    }
    
    func credentialsChanged() -> Bool {
        return  (defaults?.string(forKey: "last_login_user") != defaults?.string(forKey: "smartmobil_username")) ||
            (defaults?.string(forKey: "last_login_pw") != defaults?.string(forKey: "smartmobil_password"))
    }
    
    func showLoginFailedAlert() {
        if (self.onLoginFailed != nil) {
            self.onLoginFailed!()
        }
    }
    
    public func updateUsage(callback:((Bool)->Void)? = nil) {
        if (!self.hasCredentials())
        {
            return;
        }
        
        let userName:String = (defaults?.string(forKey: "smartmobil_username"))!
        let password:String = (defaults?.string(forKey: "smartmobil_password"))!
        
        if (self.credentialsChanged()) {
            self.login(user: userName,
                       password: password,
                       callback: { success in
                        if success {
                            self.tryScrapeUsage(callback: callback)
                        } else {
                            self.showLoginFailedAlert()
                        }
            })
        } else {
            self.tryScrapeUsage(callback: { success in
                if (!success) {
                    self.login(user: userName,
                               password: password,
                               callback: { success in
                                if success {
                                    self.tryScrapeUsage(callback:callback)
                                } else {
                                    self.showLoginFailedAlert()
                                }
                    })
                } else if (callback != nil) {
                    callback!(true)
                }
            })
        }
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
                            self.defaults?.set(user, forKey: "last_login_user")
                            self.defaults?.set(password, forKey: "last_login_pw")
                            self.defaults?.synchronize()
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
                let total = try table?.child(0).child(2).child(2).text()
                let used = try table?.child(0).child(3).child(2).text()
                
                self.usedKB = self.parseBytes(byteString:used!)
                self.totalKB = self.parseBytes(byteString:total!)
                
                self.usedMBFormatted = String(format:"%.2u", usedKB / 1024)
                self.availMBFormatted = String(format:"%.2u", (totalKB-usedKB) / 1024)

                self.daysUntilReset = self.daysUntilEndOfMonth()
                self.daysPredicted = ((totalKB-usedKB) * self.usedDays()) / usedKB
                
                self.usagePercent = 100 * CGFloat(usedKB) / CGFloat(totalKB)
                
                if (self.onChangeCallback != nil) {
                    self.onChangeCallback!()
                }
                
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
}
