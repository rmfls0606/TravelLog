//
//  AppDelegate.swift
//  TravelLog
//
//  Created by 이상민 on 9/29/25.
//

import UIKit
import RealmSwift
import Firebase
import IQKeyboardManagerSwift
import Kingfisher
import RxSwift
import RxCocoa
internal import Realm

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    private lazy var cityImageBackfillService = CityImageBackfillService()
    private let disposeBag = DisposeBag()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        FirebaseApp.configure()
        
        migration()
        configureImageCache()
        cityImageBackfillService.backfillMissingCityImages()
        bindNetworkTriggeredCityImageBackfill()
        
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
        
        let config = Realm.Configuration(schemaVersion: 3) { migration, oldSchemaVersion in
            //JournalBlockTable에 링크 미리보기를 위한 linkTitle, linkDescription, linkImagePath 컬럼 추가
            if oldSchemaVersion < 1 {}
            if oldSchemaVersion < 2 {}
            if oldSchemaVersion < 3 {
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

    private func bindNetworkTriggeredCityImageBackfill() {
        SimpleNetworkState.shared.isConnectedDriver
            .distinctUntilChanged()
            .skip(1)
            .filter { $0 }
            .drive(with: self) { owner, _ in
                owner.cityImageBackfillService.backfillMissingCityImages()
            }
            .disposed(by: disposeBag)
    }
}
