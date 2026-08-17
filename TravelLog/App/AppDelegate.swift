//
//  AppDelegate.swift
//  TravelLog
//
//  Created by 이상민 on 9/29/25.
//

import UIKit
import RealmSwift
import Firebase
import FirebaseAppCheck
import IQKeyboardManagerSwift
import Kingfisher
internal import Realm

/// 디버그 빌드(시뮬레이터 포함)에서는 App Attest를 쓸 수 없어 디버그 프로바이더를 쓰고,
/// 실제 배포 빌드에서는 기기 증명 기반의 App Attest를 쓴다. 반드시 FirebaseApp.configure()
/// 이전에 등록해야 이후 모든 Firestore/Functions 요청에 App Check 토큰이 자동으로 실린다.
final class TravelLogAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        AppCheck.setAppCheckProviderFactory(TravelLogAppCheckProviderFactory())
        FirebaseApp.configure()

        migration()
        configureImageCache()
        
        IQKeyboardManager.shared.isEnabled = true
        _ = SimpleNetworkState.shared
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backButtonAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: -1000, vertical: 0)
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    private func migration(){
        
        let config = Realm.Configuration(schemaVersion: 4) { migration, oldSchemaVersion in
            //JournalBlockTable에 링크 미리보기를 위한 linkTitle, linkDescription, linkImagePath 컬럼 추가
            if oldSchemaVersion < 1 {}
            if oldSchemaVersion < 2 {}
            if oldSchemaVersion < 3 {
                migration.enumerateObjects(ofType: CityTable.className()) { _, newObject in
                    newObject?["localImageFilename"] = nil
                    newObject?["cityDocId"] = nil
                }
            }
            if oldSchemaVersion < 4 {
                migration.enumerateObjects(ofType: CityTable.className()) { _, newObject in
                    newObject?["localImageFilename"] = nil
                }
            }
        }
        
        Realm.Configuration.defaultConfiguration = config
        do {
            _ = try Realm()
        } catch {
            print("Realm Migration 실패:", error.localizedDescription)
        }
    }

    private func configureImageCache() {
        let cache = ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024
        cache.memoryStorage.config.expiration = .seconds(300)
        cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024
        cache.diskStorage.config.expiration = .days(7)
    }

}
