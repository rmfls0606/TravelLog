//
//  TravelAddViewController.swift
//  TravelLog
//
//  Created by 이상민 on 9/29/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class TravelAddViewController: BaseViewController {
    
    // MARK: - UI
    private let scrollView = UIScrollView()
    
    private let bodyView = UIView()
    
    private let contentView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.spacing = 16
        return view
    }()
    
    // Header
    private let headerView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .center
        view.spacing = 12
        return view
    }()
    
    private let headerIconContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        return view
    }()
    
    private let headerIcon: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "airplane.departure")
        view.tintColor = .white
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    private let headerTitle: UILabel = {
        let label = UILabel()
        label.text = "새로운 여행을 시작하세요"
        label.font = .boldSystemFont(ofSize: 20)
        label.textColor = .black
        return label
    }()
    
    private let headerSubtitle: UILabel = {
        let label = UILabel()
        label.text = "간편하게 여행 정보를 입력하고\n행복한 여행 추억을 기록해보세요"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .darkGray
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    // Transport Card
    private let transportCard = BaseCardView()
    
    private let transportHeader: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = 8
        return view
    }()
    
    private let transportHeaderIcon: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "road.lanes"))
        view.tintColor = .systemBlue
        return view
    }()
    
    private let transportHeaderTitle: UILabel = {
        let label = UILabel()
        label.text = "교통수단 선택"
        label.font = .boldSystemFont(ofSize: 16)
        label.textColor = .black
        return label
    }()
    
    private let transportStack: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.spacing = 16
        view.distribution = .fillEqually
        return view
    }()
    
    private var transportButtons: [UIButton] = []
    
    private let dateRangeCard = DateRangeCardView()
    
    // FormCards
    private let departureCard = LocationCardView(
        title: "출발지",
        placeholder: "어디서 출발하시나요?",
        icon: "mappin.circle"
    )
    
    private let destinationCard = LocationCardView(
        title: "목적지",
        placeholder: "어디로 떠나시나요?",
        icon: "mappin.circle.fill"
    )
    
    // Create Button
    private let createButton = PrimaryButton(title: "여행 카드 생성하기")
    
    private let viewModel = TravelAddViewModel()
    private let disposeBag = DisposeBag()
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        headerIconContainer
            .applyGradient(
                style: .bluePurple,
                end: CGPoint(x: 1, y: 1)
            )
        
        createButton.applyGradient(
            style: .bluePurple
        )
    }
    
    override func configureHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(bodyView)
        
        bodyView.addSubview(contentView)
        
        // Header Section
        contentView.addArrangedSubview(headerView)
        headerView.addArrangedSubview(headerIconContainer)
        headerIconContainer.addSubview(headerIcon)
        headerView.addArrangedSubview(headerTitle)
        headerView.addArrangedSubview(headerSubtitle)
        
        // Transport Section
        contentView.addArrangedSubview(transportCard)
        transportCard.addSubview(transportHeader)
        transportHeader.addArrangedSubview(transportHeaderIcon)
        transportHeader.addArrangedSubview(transportHeaderTitle)
        transportCard.addSubview(transportStack)
        
        // 교통수단 버튼 추가
        Transport.allCases.enumerated().forEach { index, item in
            let button = makeTransportButton(title: item.rawValue, icon: item.iconName)
            button.tag = index
            transportButtons.append(button)
            transportStack.addArrangedSubview(button)
        }
        
        // Form Section (출발/도착, 날짜)
        contentView.addArrangedSubview(dateRangeCard)
        contentView.addArrangedSubview(departureCard)
        contentView.addArrangedSubview(destinationCard)
        
        // Create Button
        view.addSubview(createButton)
    }
    
    override func configureLayout() {
        scrollView.snp.makeConstraints { make in
            make.top.horizontalEdges.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(createButton.snp.top).offset(-16)
        }
        
        bodyView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.verticalEdges.equalToSuperview()
            make.horizontalEdges.equalToSuperview().inset(16)
        }
        
        headerIconContainer.snp.makeConstraints { make in
            make.size.equalTo(70)
        }
        
        headerIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(32)
        }
        
        transportHeader.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview().inset(22)
        }
        
        transportHeaderIcon.snp.makeConstraints { make in
            make.size.equalTo(20)
        }
        
        
        transportStack.snp.makeConstraints { make in
            make.top.equalTo(transportHeader.snp.bottom).offset(16)
            make.horizontalEdges.bottom.equalToSuperview().inset(22)
            make.height.equalTo(80)
        }
        
        // Create Button
        createButton.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview().inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
            make.height.equalTo(52)
        }
    }
    
    override func configureView() {
        view.backgroundColor = UIColor.systemGray6
        navigationItem.title = "여행지 설정"
    }
    
    override func configureBind() {
        let transportSelected = Observable.merge(
            transportButtons.enumerated().map{ index, button in
                button.rx.tap.map{ Transport.allCases[index] }
            }
        )
        
        let dateSelected = Observable.merge(
            dateRangeCard.quickButtons.enumerated().map{ index, button in
                button.rx.tap.map{ () -> (Date?, Date?) in
                    let option = QUickSelectOption.allCases[index]
                    let start = Date()
                    let end = Calendar.current.date(byAdding: .day, value: option.days - 1, to: start)
                    return (start, end)
                }
            }
        )
        
        let input = TravelAddViewModel.Input(
            transportSelected: transportSelected,
            dateSelected: dateSelected,
            calendarTapped: dateRangeCard.tapGesture.rx.event.map{ _ in },
            createButtonTapped: createButton.rx.tap
        )
        
        let output = viewModel.transform(input: input)
        
        output.selectedTransport
            .drive(with: self){ owner, selected in
                for (button, type) in zip(owner.transportButtons, Transport.allCases){
                    button.isSelected = (type == selected)
                }
                owner.dateRangeCard.updateTransportIcon(name: selected.iconName)
            }
            .disposed(by: disposeBag)
        
        output.selectedDateRange
            .drive(with: self){ owner, range in
                owner.dateRangeCard.updateRange(start: range.start, end: range.end)
            }
            .disposed(by: disposeBag)
        
        output.showCalendar
            .withLatestFrom(output.selectedDateRange)
            .emit(with: self){ owner, range in
                let vc = CalendarViewController()
                vc.updateSelectedDate(start: range.start, end: range.end)
                
                vc.selectedDateRangeRelay
                    .bind(with: owner, onNext: { owner, range in
                        owner.viewModel.updateDateRange(range: range)
                    })
                    .disposed(by: vc.disposeBag)
                
                owner.navigationController?.pushViewController(vc, animated: true)
            }
            .disposed(by: disposeBag)
        
        departureCard.tapGesture.rx.event
            .bind(with: self) { owner, _ in
                let vc = DestinationSelectorViewController()
                
                vc.selectedCity
                    .bind(with: owner) { owner, city in
                        owner.departureCard.updateValue(city.name)
                        owner.viewModel.updateDeparture(CityTable(from: city))
                    }
                    .disposed(by: vc.disposeBag)
                
                owner.navigationController?.pushViewController(vc, animated: true)
            }
            .disposed(by: disposeBag)
        
        destinationCard.tapGesture.rx.event
            .bind(with: self) { owner, _ in
                let vc = DestinationSelectorViewController()
                
                vc.selectedCity
                    .bind(with: owner) { owner, city in
                        owner.destinationCard.updateValue(city.name)
                        owner.viewModel.updateDestination(CityTable(from: city))
                    }
                    .disposed(by: vc.disposeBag)
                
                owner.navigationController?.pushViewController(vc, animated: true)
            }
            .disposed(by: disposeBag)
        
        output.saveCompleted
            .emit(with: self) { owner, _ in
                print("여행 저장 완료!")
                owner.navigationController?.popViewController(animated: true)
            }
            .disposed(by: disposeBag)
        
        // 저장 실패 시 알림
        output.saveError
            .emit(with: self) { owner, message in
                print("저장 실패:", message)
            }
            .disposed(by: disposeBag)
    }
    
    //MARK: - Component
    private func makeTransportButton(title: String, icon: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.attributedTitle = AttributedString(title,
                                                  attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 12, weight: .bold)])
        )
        
        let imageConfig = UIImage.SymbolConfiguration(scale: .medium)
        config.preferredSymbolConfigurationForImage = imageConfig
        config.image = UIImage(systemName: icon)
        config.imagePlacement = .top
        config.imagePadding = 8
        config.baseBackgroundColor = .systemGray6
        config.baseForegroundColor = .gray
        
        let button = UIButton(configuration: config)
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        
        button.configurationUpdateHandler = { btn in
            guard var newConfig = btn.configuration else { return }
            
            if btn.isSelected {
                newConfig.baseBackgroundColor = UIColor(red: 90/255, green: 140/255, blue: 255/255, alpha: 1)
                newConfig.baseForegroundColor = .white
                
                
            } else {
                newConfig.baseBackgroundColor = .systemGray6
                newConfig.baseForegroundColor = .gray
            }
            btn.configuration = newConfig
        }
        
        return button
    }
}
