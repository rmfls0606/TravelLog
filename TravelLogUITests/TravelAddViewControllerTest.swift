//
//  TravelAddViewControllerTest.swift
//  TravelLogUITests
//
//  Created by 이상민 on 12/9/25.
//

import XCTest

final class TravelAddViewControllerTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    func testTravelAddViewControllerSaveSuccess() throws{
        let app = XCUIApplication()
        app.launch()
        
        //여행 추가 화면 이동
        app.buttons["trip_rightBarButtonItem_btn"].tap()
        
        //교통수단 선택
        app.buttons["transport_bus_btn"].tap()
        
        //여행 날짜 빠른 선택
        app.buttons["travel_threeNightsFourDays_btn"].tap()
        
        //여행 날짜 선택
        app.otherElements["travel_calendar_view"].tap()
        app.cells["travel_calendar_cell_1"].tap()
        app.cells["travel_calendar_cell_15"].tap()
        
        //여행 날짜 선택 후 확인
        app.buttons["travel_calendar_confirm_btn"].tap()
        
        //출발지 블록 선택
        app.otherElements["travel_departCard_view"].tap()
        //출발지 searchBar 선택
        app.textFields["travel_city_field"].tap()
        //서울 입력
        app.textFields["travel_city_field"].typeText("인천")
        //서울 선택
        app.cells["travel_city_cell_인천광역시"].tap()
        
        //도착지 블록 선택
        app.otherElements["travel_destCard_view"].tap()
        //도착지 searchBar 선택
        app.textFields["travel_city_field"].tap()
        //서울 입력
        app.textFields["travel_city_field"].typeText("서울")
        //서울 선택
        app.cells["travel_city_cell_서울특별시"].tap()
        
        //여행지 생성 버튼 클릭
        let createButton = app.buttons["travel_create_btn"]
        XCTAssert(createButton.waitForExistence(timeout: 5))
        createButton.tap()
    }
    
    func testTravelAddViewControllerSaveFailed() throws{
        
    }
}
