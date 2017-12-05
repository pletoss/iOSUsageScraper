import Foundation
import UIKit

class SettingsViewController: UIViewController {
    
    @IBOutlet weak var container: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func onCancelAction(_ sender: Any) {
        self.dismiss(animated: true)
    }
    @IBAction func onSaveAction(_ sender: Any) {
        self.dismiss(animated: true)
    }
}
