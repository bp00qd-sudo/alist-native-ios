import Foundation
import Security
import CoreLocation
import AVFoundation

@MainActor
final class BackgroundKeepAliveCoordinator: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var locationEnabled = false
    @Published private(set) var audioEnabled = false
    @Published private(set) var locationStatus = "未启用"
    @Published private(set) var audioStatus = "未启用"

    private let locationManager = CLLocationManager()
    private var audioPlayer: AVAudioPlayer?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func setLocationEnabled(_ enabled: Bool) {
        locationEnabled = enabled
        if enabled {
            locationStatus = "请求权限中"
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
        } else {
            locationManager.stopUpdatingLocation()
            locationStatus = "已停止"
        }
    }

    func setAudioEnabled(_ enabled: Bool) {
        audioEnabled = enabled
        if enabled {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                audioStatus = "运行中"
                // 实际项目中由资源文件提供极短静音循环音频。
            } catch {
                audioStatus = "不可用"
            }
        } else {
            audioPlayer?.stop()
            audioPlayer = nil
            audioStatus = "已停止"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationStatus = locationEnabled ? "运行中" : "已停止"
        case .denied, .restricted: locationStatus = "不可用"
        case .notDetermined: locationStatus = "权限待确认"
        @unknown default: locationStatus = "未知"
        }
    }
}

enum KeychainStore {
    static func write(_ value: String, service: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        let add: [String: Any] = query.merging([
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]) { _, new in new }
        SecItemAdd(add as CFDictionary, nil)
    }

    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
