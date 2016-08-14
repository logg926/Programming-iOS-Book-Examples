
import UIKit
import Foundation

@objc protocol Dummy {
    func _performMemoryWarning() // shut the compiler up
}

class ViewController : UIViewController {
    
    // ignore; just making sure it compiles
    
    // NSCache now comes across as a true Swift generic!
    // so you have to resolve those generics explicitly
    // feels like a bug to me, but whatever
    
    private let _cache = NSCache<NSString, AnyObject>()
    var cachedData : Data {
        let key = "somekey"
        var data = self._cache.object(forKey:key) as? Data
        if data != nil {
            return data!
        }
        // ... recreate data here ...
        data = Data(bytes:[1,2,3,4]) // recreated data
        self._cache.setObject(data!, forKey: key)
        return data!
    }
    
    private var _purgeable = NSPurgeableData()
    var purgeabledata : Data {
        // surprisingly tricky to get content access barriers correct
        if self._purgeable.beginContentAccess() && self._purgeable.length > 0 {
            let result = self._purgeable.copy() as! Data
            self._purgeable.endContentAccess()
            return result
        } else {
            // ... recreate data here ...
            let data = Data(bytes:[6,7,8,9]) // recreated data
            self._purgeable = NSPurgeableData(data:data)
            self._purgeable.endContentAccess() // must call "end"!
            return data
        }
    }
    

    // this is the actual example
    
    private var _myBigData : Data! = nil
    var myBigData : Data! {
        set (newdata) {
            self._myBigData = newdata
        }
        get {
            if _myBigData == nil {
                let fm = FileManager()
                let f = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("myBigData")
                if let d = try? Data(contentsOf:f) {
                    print("loaded big data from disk")
                    self._myBigData = d
                    do {
                        try fm.removeItem(at:f)
                        print("deleted big data from disk")
                    } catch {
                        print("Couldn't remove temp file")
                    }
                }
            }
            return self._myBigData
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // wow, this is some big data!
        self.myBigData = "howdy".data(using:.utf8, allowLossyConversion: false)
    }
    
    // tap button to prove we've got big data
    
    @IBAction func doButton (_ sender:AnyObject?) {
        let s = String(data: self.myBigData, encoding:.utf8)
        let av = UIAlertController(title: "Got big data, and it says:", message: s, preferredStyle: .alert)
        av.addAction(UIAlertAction(title: "OK", style: .cancel))
        self.present(av, animated: true)
    }
    
    // to test, run the app in the simulator and trigger a memory warning
    
    func saveAndReleaseMyBigData() {
        if let myBigData = self.myBigData {
            print("unloading big data")
            let f = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("myBigData")
            try? myBigData.write(to:f)
            self.myBigData = nil
        }
    }
    
    override func didReceiveMemoryWarning() {
        print("did receive memory warning")
        super.didReceiveMemoryWarning()
        self.saveAndReleaseMyBigData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // on device
    // private API (you'd have to remove it from shipping code)
    
    @IBAction func doButton2(_ sender: AnyObject) {
        UIApplication.shared.perform(#selector(Dummy._performMemoryWarning))
    }
    
    @IBAction func testCaches(_ sender: AnyObject) {
        print(self.cachedData)
        print(self.purgeabledata)
    }
    // backgrounding
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(backgrounding), name: .UIApplicationDidEnterBackground, object: nil)
    }
    
    func backgrounding(_ n:Notification) {
        self.saveAndReleaseMyBigData()
    }
    
}
