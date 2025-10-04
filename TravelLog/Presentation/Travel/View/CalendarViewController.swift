//
//  CalendarViewController.swift
//  TravelLog
//
//  Created by 이상민 on 10/3/25.
//

import UIKit
import SnapKit
import FSCalendar
import RxSwift
import RxCocoa

// MARK: - CalendarViewController
final class CalendarViewController: BaseViewController, FSCalendarDelegate, FSCalendarDataSource {
    private let headerView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "일정 선택"
        label.font = .boldSystemFont(ofSize: 20)
        label.textColor = .black
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "즐거운 여행 일정을 선택해주세요"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .darkGray
        return label
    }()
    
    private let travelCalendar: FSCalendar = {
        let view = FSCalendar()
        view.scrollDirection = .vertical
        view.placeholderType = .none
        view.scope = .month
        view.locale = Locale(identifier: "ko_KR")
        view.today = nil
        view.appearance.headerDateFormat = "YYYY년 M월"
        view.appearance.headerTitleColor = .black
        view.appearance.headerTitleFont = .systemFont(ofSize: 14, weight: .semibold)
        view.appearance.headerTitleAlignment = .left
        view.appearance.weekdayTextColor = .darkGray
        view.appearance.titleDefaultColor = .clear
        return view
    }()
    
    //선택된 기한 뷰
    private let selectedPeriodView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
        view.layer.cornerRadius = 12
        return view
    }()
    
    private let selectedTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "선택된 기간"
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .systemBlue
        label.textAlignment = .center // 중앙 정렬
        return label
    }()
    
    private let selectedRangeLabel: UILabel = {
        let label = UILabel()
        label.text = "아직 선택되지 않았습니다"
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = UIColor(red: 26/255, green: 60/255, blue: 140/255, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    private let confirmButton = PrimaryButton(title: "확인")
    
    private var selectedStartDate: Date?
    private var selectedEndDate: Date?
    
    private(set) var selectedDateRangeRelay = PublishRelay<(start: Date, end: Date)>()
    
    let disposeBag = DisposeBag()
    
    override func configureHierarchy() {
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        
        view.addSubview(travelCalendar)
        view.addSubview(selectedPeriodView)
        selectedPeriodView.addSubview(selectedTitleLabel)
        selectedPeriodView.addSubview(selectedRangeLabel)
        view.addSubview(confirmButton)
    }
    
    override func configureLayout() {
        headerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.horizontalEdges.equalToSuperview().inset(16)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview()
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview().inset(12)
        }
        
        travelCalendar.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom).offset(8)
            $0.horizontalEdges.equalTo(view.safeAreaLayoutGuide).inset(16)
            $0.bottom.equalTo(selectedPeriodView.snp.top).offset(-16)
        }
        selectedPeriodView.snp.makeConstraints {
            $0.horizontalEdges.equalTo(view.safeAreaLayoutGuide).inset(16)
            $0.height.equalTo(70)
            $0.bottom.equalTo(confirmButton.snp.top).offset(-12)
        }
        
        selectedTitleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(10)
            $0.centerX.equalToSuperview()
        }
        
        selectedRangeLabel.snp.makeConstraints {
            $0.top.equalTo(selectedTitleLabel.snp.bottom).offset(6)
            $0.centerX.equalToSuperview()
        }
        
        confirmButton.snp.makeConstraints {
            $0.horizontalEdges.equalTo(view.safeAreaLayoutGuide).inset(16)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
            $0.height.equalTo(52)
        }
    }
    
    override func configureView() {
        view.backgroundColor = .white
        travelCalendar.delegate = self
        travelCalendar.dataSource = self
        travelCalendar.register(CustomCalendarCell.self, forCellReuseIdentifier: "cell")
        
        // 최초 진입 시 현재 값 반영
        updateSelectedPeriodLabel()
        updateConfirmButtonState()
    }
    
    override func configureBind() {
        confirmButton.rx.tap
            .bind(with: self) { owner, _ in
                if let start = owner.selectedStartDate,
                   let end = owner.selectedEndDate {
                    owner.selectedDateRangeRelay.accept((start, end))
                }
                owner.navigationController?.popViewController(animated: true)
            }
            .disposed(by: disposeBag)
    }
    
    // MARK: - FSCalendar
    func calendar(_ calendar: FSCalendar, cellFor date: Date, at position: FSCalendarMonthPosition) -> FSCalendarCell {
        guard let cell = calendar.dequeueReusableCell(withIdentifier: "cell", for: date, at: position) as? CustomCalendarCell else {
            return FSCalendarCell()
        }
        
        let isToday = Calendar.current.isDateInToday(date)
        let isStart = (selectedStartDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedStartDate!))
        let isEnd = (selectedEndDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedEndDate!))
        let inRange: Bool
        if let start = selectedStartDate, let end = selectedEndDate {
            inRange = (date > start && date < end)
        } else {
            inRange = false
        }
        let weekday = Calendar.current.component(.weekday, from: date)
        let isWeekend = (weekday == 1 || weekday == 7)
        
        cell.configure(date: date,
                       isToday: isToday,
                       isStart: isStart,
                       isEnd: isEnd,
                       inRange: inRange,
                       isWeekend: isWeekend)
        return cell
    }
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        calendar.deselect(date)
        
        if selectedStartDate == nil {
            selectedStartDate = date
            selectedEndDate = nil
        } else if let start = selectedStartDate, selectedEndDate == nil {
            if date < start {
                selectedEndDate = start
                selectedStartDate = date
            } else {
                selectedEndDate = date
            }
        } else {
            selectedStartDate = date
            selectedEndDate = nil
        }
        
        refreshCalendar(calendar)
        updateSelectedPeriodLabel()
        updateConfirmButtonState()
    }
    
    private func refreshCalendar(_ calendar: FSCalendar){
        let visibleIndexPaths = calendar.collectionView.indexPathsForVisibleItems
        calendar.collectionView.reloadItems(at: visibleIndexPaths)
    }
    
    //현재 보이는 셀만 업데이트
    private func refreshVisibleCells(_ calendar: FSCalendar) {
        for case let cell as CustomCalendarCell in calendar.collectionView.visibleCells {
            guard let date = calendar.date(for: cell) else { continue }
            
            let isToday = Calendar.current.isDateInToday(date)
            let isStart = (selectedStartDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedStartDate!))
            let isEnd = (selectedEndDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedEndDate!))
            
            let inRange: Bool
            if let start = selectedStartDate, let end = selectedEndDate {
                inRange = (date > start && date < end)
            } else {
                inRange = false
            }
            
            let weekday = Calendar.current.component(.weekday, from: date)
            let isWeekend = (weekday == 1 || weekday == 7)
            
            cell.configure(date: date,
                           isToday: isToday,
                           isStart: isStart,
                           isEnd: isEnd,
                           inRange: inRange,
                           isWeekend: isWeekend)
        }
    }
    
    private func updateSelectedPeriodLabel() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        
        if let start = selectedStartDate, let end = selectedEndDate {
            // 총 기간 계산
            selectedRangeLabel.text = "\(formatter.string(from: start)) - \(formatter.string(from: end)) / 선택 완료"
            selectedRangeLabel.textColor = UIColor(red: 0.17, green: 0.24, blue: 0.45, alpha: 1.0) // 디자인용 딥 블루
            
        } else if let start = selectedStartDate {
            selectedRangeLabel.text = "\(formatter.string(from: start)) / 출발 선택"
            selectedRangeLabel.textColor = UIColor(red: 0.17, green: 0.24, blue: 0.45, alpha: 1.0) // 같은 블루
            
        } else {
            selectedRangeLabel.text = "여행 날짜를 선택해주세요"
            selectedRangeLabel.textColor = .lightGray
        }
    }
    
    private func updateConfirmButtonState() {
        if selectedStartDate != nil && selectedEndDate != nil {
            confirmButton.isEnabled = true
            confirmButton.alpha = 1.0   // 활성화
        } else {
            confirmButton.isEnabled = false
            confirmButton.alpha = 0.5   // 비활성화 (시각적으로 흐리게)
        }
    }
    
    func updateSelectedDate(start: Date?, end: Date?){
        selectedStartDate = start
        selectedEndDate = end
    }
}
