//
//  Created by Matilde Inc.
//  Copyright (c) 2015 FUN'IKI Project. All rights reserved.
//

import UIKit
import CoreLocation

class FunikiSDKViewController: UIViewController, MAFunikiManagerDelegate, MAFunikiManagerDataDelegate, CLLocationManagerDelegate {

    let funikiManager = MAFunikiManager.sharedInstance()
    
    @IBOutlet var volumeSegmentedControl:UISegmentedControl!
    @IBOutlet var frequencySlider:UISlider!
    @IBOutlet var frequencyLabel:UILabel!
    @IBOutlet var connectionLabel:UILabel!
    @IBOutlet var batteryLabel:UILabel!
    @IBOutlet weak var sdkVersionLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBAction func location(sender: AnyObject) {
//        locationManager?.startUpdatingLocation()
    }
    
    var locationManager: CLLocationManager?
    
    // Delegateメソッド
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations[0].coordinate
        
        let now = NSDate()
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: "ja_JP")
        dateFormatter.timeStyle = .ShortStyle
        dateFormatter.dateStyle = .ShortStyle
        let d = dateFormatter.stringFromDate(now)
        
        latitudeLabel.text = "\(coordinate.latitude)\r\n\(d)"
        longitudeLabel.text = "\(coordinate.longitude)\n\(d)"
    }
    
    // MARK: -
    func updateConnectionStatus() {
        if funikiManager.connected {
            self.connectionLabel.text = "接続済み"
        }else {
            self.connectionLabel.text = "未接続"
        }
    }
    
    func updateBatteryLevel(){
        switch funikiManager.batteryLevel {
        case .Unknown:
            self.batteryLabel.text = "バッテリー残量:不明"
            
        case .Low:
            self.batteryLabel.text = "バッテリー残量:少ない"
            
        case .Medium:
            self.batteryLabel.text = "バッテリー残量:中"
            
        case .High:
            self.batteryLabel.text = "バッテリー残量:多い"
            
        }
    }

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.volumeSegmentedControl.selectedSegmentIndex = 2
        self.sdkVersionLabel.text = "SDK Version:" + MAFunikiManager.funikiSDKVersionString()
        
        // Location Managerの生成、初期化
        locationManager = CLLocationManager()
        if #available(iOS 9.0, *) {
            locationManager?.allowsBackgroundLocationUpdates = true
        }
        locationManager?.distanceFilter = 500 // 500m移動したら通知する。
        locationManager?.delegate = self
        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.AuthorizedAlways { // 注1
            locationManager?.requestAlwaysAuthorization()
            // 位置情報サービスを開始するか、ユーザに尋ねるダイアログを表示する。
        }
        locationManager?.startUpdatingLocation()
        
    }
    
    override func viewWillAppear(animated: Bool) {
   
        funikiManager.delegate = self
        funikiManager.dataDelegate = self
        
        updateConnectionStatus()
        updateBatteryLevel()
        buzzerFrequencyChanged(nil)
        
        super.viewWillAppear(animated)
    }
    

    // MARK: - MAFunikiManagerDelegate
    func funikiManagerDidConnect(manager: MAFunikiManager!) {
        print("SDK Version\(MAFunikiManager.funikiSDKVersionString())")
        print("Firmware Revision\(manager.firmwareRevision)")
        updateConnectionStatus()
        updateBatteryLevel()
    }
    
    func funikiManagerDidDisconnect(manager: MAFunikiManager!, error: NSError!) {

        if let actualError = error {
            print(actualError)
        }
        updateConnectionStatus()
        updateBatteryLevel()
    }
    
    func funikiManager(manager: MAFunikiManager!, didUpdateBatteryLevel batteryLevel: MAFunikiManagerBatteryLevel) {
        updateBatteryLevel()
    }
    
    func funikiManager(manager: MAFunikiManager!, didUpdateCentralState state: CBCentralManagerState) {
        updateConnectionStatus()
        updateBatteryLevel()
    }
    
    // MARK: - MAFunikiManagerDataDelegate
    func funikiManager(manager: MAFunikiManager!, didUpdateMotionData motionData: MAFunikiMotionData!) {
        print(motionData)
    }
    
    func funikiManager(manager: MAFunikiManager!, didPushButton buttonEventType: MAFunikiManagerButtonEventType) {
        
    }
    
    // MARK: - Action
    @IBAction func red(sender:AnyObject!) {
        if (funikiManager.connected){
            funikiManager.changeLeftColor(UIColor.redColor(), rightColor: UIColor.redColor(), duration: 1.0, buzzerFrequency: freqFromSlider(), buzzerVolume: selectedBuzzerVolume())
        }
    }
    
    @IBAction func green(sender:AnyObject!) {
        if (funikiManager.connected){
            funikiManager.changeLeftColor(UIColor.greenColor(), rightColor: UIColor.greenColor(), duration: 1.0, buzzerFrequency: freqFromSlider(), buzzerVolume: selectedBuzzerVolume())
        }
    }
    
    @IBAction func blue(sender:AnyObject!) {
        if (funikiManager.connected){
            funikiManager.changeLeftColor(UIColor.blueColor(), rightColor: UIColor.blueColor(), duration: 1.0, buzzerFrequency: freqFromSlider(), buzzerVolume: selectedBuzzerVolume())
        }
    }
    
    @IBAction func stop(sender:AnyObject!) {
        funikiManager.changeLeftColor(UIColor.blackColor(), rightColor: UIColor.blackColor(), duration: 1.0)
    }
    
    @IBAction func buzzerFrequencyChanged(sender:AnyObject!) {
        frequencyLabel.text = NSString(format: "%0.0ld", freqFromSlider()) as String
    }
    
    // MARK: - UI->Value
    func selectedBuzzerVolume () -> MAFunikiManagerBuzzerVolume {
        
        let selectedSegmentIndex = volumeSegmentedControl.selectedSegmentIndex
        var volume:MAFunikiManagerBuzzerVolume!
        
        switch(selectedSegmentIndex){
        case 0:
            volume = .Mute
        case 1:
            volume = .Low
        case 2:
            volume = .Medium
        case 3:
            volume = .Loud
        default:
            volume = .Mute
        }
        return volume!
    }
    
    func freqFromSlider()-> Int {
        let value:Int = Int(pow(self.frequencySlider.value, 2.0))
        // 雰囲気メガネが発音可能な周波数に丸めます
        return funikiManager.roundedBuzzerFrequency(value)
    }
}

