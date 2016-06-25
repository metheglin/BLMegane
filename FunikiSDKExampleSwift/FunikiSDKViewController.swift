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
        locationManager?.startUpdatingLocation()
    }
    
    var locationManager: CLLocationManager?
    
    // 日本測地系座標を世界測地系座標に変換しますが、おそらくこの処理は不要...
    func convertToWGS84( lat_tokyo: Float64, lng_tokyo: Float64 ) -> CLLocation {
        let a = 1.00010696
        let b = 0.000017467
        let c = 0.000046047
        let d = 1.000083049
        let p = 0.0046020
        let q = 0.010041
        
        let ad_bc = (a * d) + (b * c)
        let x_p = lat_tokyo + p
        let y_q = lng_tokyo + q
        
        let lat_wgs84 = ((d * x_p) + (b * y_q)) / ad_bc
        let lng_wgs84 = -1 * ((c * x_p) - (a * y_q)) / ad_bc
        
        print(String(format: "lat1 %f", lat_tokyo))
        print(String(format: "lng1 %f", lng_tokyo))
        print(String(format: "lat2 %f", lat_wgs84))
        print(String(format: "lng2 %f", lng_wgs84))
        return CLLocation( latitude: lat_wgs84, longitude: lng_wgs84 )
    }
    
    // Location更新イベント
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // WGS84（世界測地系）で取得される
        let coord = locations[0].coordinate
        
//        let now = NSDate()
//        let dateFormatter = NSDateFormatter()
//        dateFormatter.locale = NSLocale(localeIdentifier: "ja_JP")
//        dateFormatter.timeStyle = .ShortStyle
//        dateFormatter.dateStyle = .ShortStyle
//        let d = dateFormatter.stringFromDate(now)
//        print(String(format: "now: %s", d))
        
        latitudeLabel.text = String(format: "%f", coord.latitude)
        longitudeLabel.text = String(format: "%f", coord.longitude)
        
        // 距離
        let curLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        if checkInsideDangerZone( curLocation ) {
            enableCriminalSuppressor()
        } else {
            disableCriminalSuppressor()
        }
    }
    
    func checkInsideDangerZone( curLocation: CLLocation ) -> Bool {
        let dangerZones:[String:[String:Double]] = [
            "新宿駅":[
                "latitude": 35.690921,
                "longitude": 139.70025799999996,
                "radius": 200.0,
            ],
            "池袋駅":[
                "latitude": 35.728926,
                "longitude": 139.71038,
                "radius": 1000.0,
            ],
        ]
        
        for (key, zone) in dangerZones {
            print(key)
            let lat = zone["latitude"]
            let lng = zone["longitude"]
            let rad:Double? = zone["radius"]
            let targetLocation = CLLocation(latitude: lat!, longitude: lng!)
            let distance = curLocation.distanceFromLocation(targetLocation)
            print(String(format: "\(key)までの距離 %fm", distance))
            if distance <= rad {
                print("危険ゾーンに入ってます")
                return true
            }
        }
        return false
    }
    
    func enableCriminalSuppressor() {
        if (funikiManager.connected){
            funikiManager.changeLeftColor(UIColor.blueColor(), rightColor: UIColor.blueColor(), duration: 1.0, buzzerFrequency: freqFromSlider(), buzzerVolume: selectedBuzzerVolume())
        }
    }
    
    func disableCriminalSuppressor() {
        funikiManager.changeLeftColor(UIColor.blackColor(), rightColor: UIColor.blackColor(), duration: 1.0)
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
//        locationManager?.startUpdatingLocation()
        
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
        locationManager?.startUpdatingLocation()
    }
    
    func funikiManagerDidDisconnect(manager: MAFunikiManager!, error: NSError!) {

        if let actualError = error {
            print(actualError)
        }
        updateConnectionStatus()
        updateBatteryLevel()
        locationManager?.stopUpdatingLocation()
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

