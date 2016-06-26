//
//  Created by Matilde Inc.
//  Copyright (c) 2015 FUN'IKI Project. All rights reserved.
//

import UIKit
import CoreLocation

class FunikiSDKViewController: UIViewController, MAFunikiManagerDelegate, MAFunikiManagerDataDelegate, CLLocationManagerDelegate {

    let funikiManager = MAFunikiManager.sharedInstance()
    
    @IBOutlet var volumeSegmentedControl:UISegmentedControl!
    @IBOutlet var connectionLabel:UILabel!
    @IBOutlet var batteryLabel:UILabel!
    @IBOutlet weak var sdkVersionLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBAction func location(sender: AnyObject) {
        locationManager?.startUpdatingLocation()
    }
    @IBOutlet weak var dangerStatusLabel: UILabel!
    
    var locationManager: CLLocationManager?
    var dangerZones: JSON?
    
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
        let coord = locations[0].coordinate
        
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
    
    func getDangerZones() {
        self.dangerZones = JSON(url:"https://s3-ap-northeast-1.amazonaws.com/sakalava/BLMegane/danger_zones.json")
        print("dangerZones\(dangerZones)")
    }
    
    func getNearesDangerZone( curLocation: CLLocation ) -> (nearestDangerName:String, nearestDistance:Double, nearest:JSON) {
        let nearestObj:[String:Double] = [
            "latitude": 0.0,
            "longitude": 0.0,
            "radius": 0.0,
        ]
        var nearest:JSON = JSON(nearestObj)
        var nearestDistance:Double = Double.infinity
        var nearestDangerName = ""
        
        for (key, zone) in self.dangerZones! {
            let lat:Double? = zone["latitude"].asDouble
            let lng:Double? = zone["longitude"].asDouble
            let targetLocation = CLLocation(latitude: lat!, longitude: lng!)
            let distance = curLocation.distanceFromLocation(targetLocation)
            if distance < nearestDistance {
                nearestDangerName = key as! String
                nearest = zone
                nearestDistance = distance
            }
            print(String(format: "\(key)までの距離 %fm", distance))
        }
        return (nearestDangerName, nearestDistance, nearest)
    }
    
    func checkInsideDangerZone( curLocation: CLLocation ) -> Bool {
        let dangerZone:(String,Double,JSON) = getNearesDangerZone( curLocation )
        let key = dangerZone.0
        let distance:Double = dangerZone.1
        let zone:JSON = dangerZone.2
        let radius:Double? = zone["radius"].asDouble
        
        if distance <= radius {
//            print("危険ゾーンに入ってます")
            dangerStatusLabel.text = "危険ゾーン\(key)に入りました"
            return true
        }
//        print("最寄りの危険ゾーンまで\(distance)mです")
        dangerStatusLabel.text = String(format: "最寄りの危険ゾーン\(key)まで%dmです", Int(distance))
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
        locationManager?.distanceFilter = 75 // 75mごとに通知
        locationManager?.delegate = self
        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.AuthorizedAlways { // 注1
            locationManager?.requestAlwaysAuthorization()
            // 位置情報サービスを開始するか、ユーザに尋ねるダイアログを表示する。
        }
        getDangerZones()
        
    }
    
    override func viewWillAppear(animated: Bool) {
   
        funikiManager.delegate = self
        funikiManager.dataDelegate = self
        
        updateConnectionStatus()
        updateBatteryLevel()
        
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
    
    @IBAction func stop(sender:AnyObject!) {
        funikiManager.changeLeftColor(UIColor.blackColor(), rightColor: UIColor.blackColor(), duration: 1.0)
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
        let value:Int = Int(pow(500.0, 2.0))
        // 雰囲気メガネが発音可能な周波数に丸めます
        return funikiManager.roundedBuzzerFrequency(value)
    }
}

