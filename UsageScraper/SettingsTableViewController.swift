import Foundation
import UIKit

class SettingsTableViewController: UITableViewController {
    
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let defaults = UserDefaults.standard
        
        if let username = defaults.string(forKey: "smartmobil_username") {
            self.nameField.text = username
        }

        if let password = defaults.string(forKey: "smartmobil_password") {
            self.passwordField.text = password
        }
    }
    
    @IBAction func onNameChanged(_ sender: Any) {
        let defaults = UserDefaults.standard
        defaults.set(self.nameField.text, forKey: "smartmobil_username")
        defaults.synchronize()
    }
    
    @IBAction func onPasswordChanged(_ sender: Any) {
        let defaults = UserDefaults.standard
        defaults.set(self.passwordField.text, forKey: "smartmobil_password")
        defaults.synchronize()
    }
    
}

