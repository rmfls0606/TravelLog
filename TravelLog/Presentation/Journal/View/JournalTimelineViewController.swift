//
//  JournalTimelineViewController.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import RealmSwift
import SafariServices
import AVFoundation
import Toast

final class JournalTimelineViewController: BaseViewController {
    
    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerContainer = UIView()
    private let tripImageView = UIImageView()
    private let cityLabel = UILabel()
    private let countryLabel = UILabel()
    
    private let addMemoryContainerView = UIView()
    private let addMemoryView = CustomEmptyView()
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    // MARK: - Properties
    private let viewModel: JournalTimelineViewModel
    private let disposeBag = DisposeBag()
    private let realm = try! Realm()
    private var groupedData: [(date: Date, blocks: [JournalBlockTable])] = []
    private var trip: TravelTable?
    private let deleteTappedSubject = PublishSubject<(ObjectId, ObjectId)>()
    
    // Audio playback state
    private var audioPlayer: AVAudioPlayer?
    private var playTimer: Timer?
    private var currentPlayingIndexPath: IndexPath?
    private var playbackPositions: [IndexPath: TimeInterval] = [:]
    private var playbackDurations: [IndexPath: TimeInterval] = [:]
    private var isAudioSessionActive = false
    
    // MARK: - Init
    init(tripId: ObjectId) {
        self.viewModel = JournalTimelineViewModel(tripId: tripId)
        super.init(nibName: nil, bundle: nil)
        fetchTrip(tripId)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // MARK: - Lifecycle
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        addMemoryContainerView.applyGradient(
            style: .softBluePurple,
            start: CGPoint(x: 0, y: 0.5),
            end: CGPoint(x: 1, y: 0.5),
            cornerRadius: 16
        )
        updateTableViewHeight()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let tripId = trip?.id {
            // 네트워크 복구 시: 최초 미시도만 복구(오늘 몇 번 와도 중복 호출 안 나게 NWPathMonitor가 보장)
            NetworkMonitor.shared.startMonitoring(for: tripId)
            // TTL: 오늘은 한 번만, 30일 지난 데이터들만 갱신
            AppLifecycleManager.shared.refreshExpiredLinkMetadataIfNeeded(for: tripId)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NetworkMonitor.shared.stopMonitoring()
        // 화면 이동 시 재생 중지 + 외부 세션 복원
        stopPlayback(resetUI: false, deactivateSession: true)
    }
    
    
    // MARK: - Setup
    private func fetchTrip(_ tripId: ObjectId) {
        if let trip = realm.object(ofType: TravelTable.self, forPrimaryKey: tripId) {
            self.trip = trip
            title = trip.destination?.name ?? "여행 기록"
        } else {
            title = "여행 기록"
        }
    }
    
    override func configureHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubviews(headerContainer, addMemoryContainerView, tableView)
        headerContainer.addSubviews(tripImageView, cityLabel, countryLabel)
        addMemoryContainerView.addSubview(addMemoryView)
    }
    
    override func configureLayout() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
        
        headerContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
            make.height.equalTo(headerContainer.snp.width).multipliedBy(0.4)
        }
        
        tripImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        cityLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(countryLabel.snp.top).offset(-4)
        }
        
        countryLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(16)
        }
        
        addMemoryContainerView.snp.makeConstraints { make in
            make.top.equalTo(headerContainer.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
        }
        
        addMemoryView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // ✅ 수정된 핵심: tableView 높이 고정 제거, contentView bottom에 연결
        tableView.snp.makeConstraints { make in
            make.top.equalTo(addMemoryContainerView.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview()
            make.bottom.equalToSuperview() // scrollView contentView bottom에 연결
        }
    }
    
    override func configureView() {
        view.backgroundColor = .systemGroupedBackground
        
        headerContainer.clipsToBounds = true
        headerContainer.layer.cornerRadius = 12
        headerContainer.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        
        tripImageView.contentMode = .scaleAspectFill
        tripImageView.clipsToBounds = true
        tripImageView.image = .seoul
        
        cityLabel.font = .boldSystemFont(ofSize: 20)
        cityLabel.textColor = .white
        countryLabel.font = .systemFont(ofSize: 14, weight: .medium)
        countryLabel.textColor = .white.withAlphaComponent(0.9)
        
        if let trip = trip {
            cityLabel.text = trip.destination?.name ?? "-"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            countryLabel.text = "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
        }
        
        addMemoryView.configure(
            icon: UIImage(systemName: "plus"),
            iconTint: .white,
            gradientStyle: .bluePurple,
            title: "새로운 추억 기록하기",
            subtitle: "이 여행의 특별한 순간을 남겨보세요",
            buttonTitle: "추억 기록하기",
            buttonImage: UIImage(systemName: "rectangle.and.pencil.and.ellipsis"),
            buttonGradient: .bluePurple
        )
        
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.isScrollEnabled = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 180
        tableView.tableFooterView = UIView()
        tableView.showsVerticalScrollIndicator = false
        tableView.register(JournalTextCell.self, forCellReuseIdentifier: JournalTextCell.identifier)
        tableView.register(JournalLinkCell.self, forCellReuseIdentifier: JournalLinkCell.identifier)
        tableView.register(JournalPhotoCell.self, forCellReuseIdentifier: JournalPhotoCell.identifier)
        tableView.register(JournalAudioCell.self, forCellReuseIdentifier: JournalAudioCell.reuseIdentifier)
        tableView.register(JournalDateHeaderView.self, forHeaderFooterViewReuseIdentifier: JournalDateHeaderView.identifier)
        tableView.register(JournalAddFooterView.self, forHeaderFooterViewReuseIdentifier: JournalAddFooterView.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add)
    }
    
    override func configureBind() {
        let input = JournalTimelineViewModel.Input(
            viewWillAppear: rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:))).map { _ in () },
            addTapped: addMemoryView.actionButton.rx.tap.asObservable(),
            deleteTapped: deleteTappedSubject.asObservable()
        )
        
        let output = viewModel.transform(input: input)
        
        output.journals
            .drive(with: self) { owner, journals in
                owner.updateGroupedData(from: journals)
                
                DispatchQueue.main.async {
                    let hasData = !journals.isEmpty
                    
                    owner.addMemoryContainerView.isHidden = hasData
                    owner.tableView.isHidden = !hasData
                    owner.tableView.reloadData()
                    owner.tableView.layoutIfNeeded()
                    
                    // 데이터 있을 때는 tableView를 headerContainer 바로 아래로 붙이기
                    owner.tableView.snp.remakeConstraints { make in
                        if hasData {
                            make.top.equalTo(owner.headerContainer.snp.bottom).offset(16)
                        } else {
                            make.top.equalTo(owner.addMemoryContainerView.snp.bottom).offset(16)
                        }
                        make.horizontalEdges.equalToSuperview()
                        make.bottom.equalToSuperview()
                        make.height.equalTo(owner.tableView.contentSize.height)
                    }
                    
                    owner.addMemoryContainerView.alpha = hasData ? 0 : 1
                    owner.tableView.alpha = hasData ? 1 : 0
                    owner.view.layoutIfNeeded()
                    owner.updateTableViewHeight()
                }
            }
            .disposed(by: disposeBag)
        
        output.navigateToAdd
            .bind(with: self) { owner, tripId in
                let addVM = JournalAddViewModel(tripId: tripId, date: Date())
                let addVC = JournalAddViewController(viewModel: addVM)
                addVC.hidesBottomBarWhenPushed = true
                owner.navigationController?.pushViewController(addVC, animated: true)
            }
            .disposed(by: disposeBag)
        
        navigationItem.rightBarButtonItem?.rx.tap
            .bind(with: self) { owner, _ in
                guard let trip = owner.trip else { return }
                let addVM = JournalAddViewModel(tripId: trip.id, date: Date())
                let addVC = JournalAddViewController(viewModel: addVM)
                addVC.hidesBottomBarWhenPushed = true
                owner.navigationController?.pushViewController(addVC, animated: true)
            }
            .disposed(by: disposeBag)
        
        output.deleteCompleted
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, _ in
                owner.tableView.reloadData()
            }
            .disposed(by: disposeBag)

        // 앱이 백그라운드로 갈 때 재생 일시정지 (다른 앱 전환 시)
        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification)
            .bind(with: self) { owner, _ in owner.stopPlayback(resetUI: false, deactivateSession: true) }
            .disposed(by: disposeBag)
    }
    
    // MARK: - Update Height
    private func updateTableViewHeight() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let contentHeight = self.tableView.contentSize.height
            guard contentHeight > 0 else { return } // 0일 땐 무시
            self.tableView.snp.updateConstraints { make in
                make.height.equalTo(contentHeight)
            }
            self.contentView.layoutIfNeeded()
        }
    }
    
    // MARK: - Grouping
    private func updateGroupedData(from journals: [JournalTable]) {
        let blocks = journals.flatMap { $0.blocks }
        let grouped = Dictionary(grouping: blocks) { Calendar.current.startOfDay(for: $0.createdAt) }
        groupedData = grouped
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, blocks: $0.value.sorted { $0.createdAt < $1.createdAt }) }
    }
}

// MARK: - UITableViewDataSource & Delegate
extension JournalTimelineViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int { groupedData.count }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groupedData[section].blocks.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: JournalDateHeaderView.identifier
        ) as? JournalDateHeaderView
        header?.configure(date: groupedData[section].date)
        return header
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard let footer = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: JournalAddFooterView.identifier
        ) as? JournalAddFooterView else { return nil }
        
        footer.tapGesture.rx.event
            .throttle(.milliseconds(400), scheduler: MainScheduler.instance)
            .bind(with: self) { owner, _ in
                guard let trip = owner.trip else { return }
                let date = owner.groupedData[section].date
                
                let addVM = JournalAddViewModel(tripId: trip.id, date: date)
                let addVC = JournalAddViewController(viewModel: addVM)
                addVC.hidesBottomBarWhenPushed = true
                owner.navigationController?.pushViewController(addVC, animated: true)
            }
            .disposed(by: footer.disposeBag)
        
        return footer
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 84 }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let block = groupedData[indexPath.section].blocks[indexPath.row]
        
        switch block.type {
        case .text:
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: JournalTextCell.identifier,
                for: indexPath
            ) as? JournalTextCell else {
                return UITableViewCell()
            }
            cell.configure(with: block)
            return cell
            
        case .link:
            let cell = tableView.dequeueReusableCell(withIdentifier: JournalLinkCell.identifier, for: indexPath) as! JournalLinkCell
            cell.configure(with: block)
            
            // 링크 탭 → 항상 SafariVC 시도 (형식 불량이어도 최대한 열기)
            cell.linkTapped
                .bind(with: self) { owner, urlString in
                    var openURL: URL?
                    
                    if let normalized = URLNormalizer.normalized(urlString) {
                        openURL = normalized.url
                    } else if let fallback = URL(string: "https://\(urlString)") {
                        openURL = fallback
                    } else {
                        openURL = URL(string: urlString)
                    }
                    
                    guard let finalURL = openURL else { return }
                    
                    let vc = SFSafariViewController(url: finalURL)
                    vc.preferredControlTintColor = .systemGreen
                    owner.present(vc, animated: true)
                }
                .disposed(by: cell.reuseBag)
            
            return cell
            
        case .photo:
            let cell = tableView.dequeueReusableCell(withIdentifier: JournalPhotoCell.identifier, for: indexPath) as! JournalPhotoCell
            cell.configure(with: block)
            cell.onHeightChange = { [weak self] in
                guard let self else { return }
                UIView.performWithoutAnimation {
                    self.tableView.beginUpdates()
                    self.tableView.endUpdates()
                }
                self.updateTableViewHeight()
            }
            
            cell.onPhotoTap = { [weak self] images, startIndex in
                    guard let self else { return }
                    let pager = PhotoPageLocalViewController(images: images, currentIndex: startIndex)
                    pager.modalPresentationStyle = .fullScreen
                    self.present(pager, animated: true)
                }
            
            return cell
            
        case .voice:
            let cell = tableView.dequeueReusableCell(withIdentifier: JournalAudioCell.reuseIdentifier, for: indexPath) as! JournalAudioCell
            cell.configure(with: block)
            cell.isUserInteractionEnabled = true
            cell.contentView.isUserInteractionEnabled = true
            if let voiceName = block.voiceURL {
                guard let resolvedURL = resolveVoiceURL(name: voiceName) else {
                    cell.setDuration(0)
                    cell.updateCurrentTime(0, progress: 0)
                    cell.setPlaying(false)
                    cell.isUserInteractionEnabled = false
                    cell.contentView.isUserInteractionEnabled = false
                    return cell
                }

                guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
                    showToast("녹음 파일이 없습니다.")
                    cell.setDuration(0)
                    cell.updateCurrentTime(0, progress: 0)
                    cell.setPlaying(false)
                    cell.isUserInteractionEnabled = false
                    cell.contentView.isUserInteractionEnabled = false
                    return cell
                }
                
                do {
                    // 세션 활성화 없이 길이만 계산 (외부 오디오 중단 방지)
                    let asset = AVURLAsset(url: resolvedURL)
                    var duration = CMTimeGetSeconds(asset.duration)
                    if duration.isNaN || duration.isInfinite {
                        duration = 0
                    }
                    playbackDurations[indexPath] = duration
                    cell.setDuration(duration)
                    // 이전 재생 위치가 있으면 표시 (다른 셀 재생으로 멈춘 경우)
                    let cached = playbackPositions[indexPath] ?? 0
                    let clamped = max(0, min(duration, cached))
                    let progress = duration > 0 ? clamped / duration : 0
                    cell.updateCurrentTime(clamped, progress: progress)
                    cell.setPlaying(false)
                    
                    cell.playTapped
                        .bind(with: self) { owner, _ in
                            owner.togglePlay(at: indexPath, url: resolvedURL, duration: duration, cell: cell)
                        }
                        .disposed(by: cell.reuseBag)
                    
                    cell.skipBackwardTapped
                        .bind(with: self) { owner, _ in owner.seek(by: -15, cell: cell, at: indexPath) }
                        .disposed(by: cell.reuseBag)
                    
                    cell.skipForwardTapped
                        .bind(with: self) { owner, _ in owner.seek(by: 15, cell: cell, at: indexPath) }
                        .disposed(by: cell.reuseBag)
                    
                    cell.seekChanged
                        .bind(with: self) { owner, progress in
                            owner.seek(toProgress: Double(progress), cell: cell, at: indexPath)
                        }
                        .disposed(by: cell.reuseBag)
                } catch {
                    showToast("녹음 파일을 재생할 수 없습니다.")
                    cell.setDuration(0)
                    cell.updateCurrentTime(0, progress: 0)
                    cell.setPlaying(false)
                    playbackDurations[indexPath] = 0
                    cell.isUserInteractionEnabled = false
                }
                
            } else {
                cell.setDuration(0)
                cell.updateCurrentTime(0, progress: 0)
                cell.setPlaying(false)
                playbackDurations[indexPath] = 0
                cell.isUserInteractionEnabled = false
            }
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let isFirst = (indexPath.section == 0 && indexPath.row == 0)
        if let textCell = cell as? JournalTextCell {
            textCell.setIsFirstInTimeline(isFirst)
        } else if let linkCell = cell as? JournalLinkCell {
            linkCell.setIsFirstInTimeline(isFirst)
        }else if let photoCell = cell as? JournalPhotoCell{
            photoCell.setIsFirstInTimeline(isFirst)
        } else if let audioCell = cell as? JournalAudioCell {
            audioCell.setIsFirstInTimeline(isFirst)
        }
    }
}

extension JournalTimelineViewController {
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        
        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            guard let self else { return }
            let block = self.groupedData[indexPath.section].blocks[indexPath.row]
            guard let journal = block.journal.first else { return }

            // 재생 중인 음성 셀을 삭제하는 경우 재생 정지 및 세션 해제
            if block.type == .voice, self.currentPlayingIndexPath == indexPath {
                self.stopPlayback(resetUI: true, deactivateSession: true)
            }
            
            // ViewModel에 삭제 요청 전달
            self.deleteTappedSubject.onNext((journal.id, block.id))
            completion(true)
        }
        
        deleteAction.backgroundColor = .systemRed
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - Audio Playback
private extension JournalTimelineViewController {
    func togglePlay(at indexPath: IndexPath, url: URL, duration: TimeInterval, cell: JournalAudioCell) {
        // 다른 셀 정지
        if let current = currentPlayingIndexPath, current != indexPath {
            stopPlayback(resetUI: false, deactivateSession: false)
        }
        // 동일 셀 토글
        if currentPlayingIndexPath == indexPath, audioPlayer?.isPlaying == true {
            if let player = audioPlayer {
                playbackPositions[indexPath] = player.currentTime
                player.pause()
                cell.setPlaying(false)
                stopTimerOnly()
                deactivateAudioSession()
                return
            }
        }
        guard activateAudioSession() else { return }

        do {
            // 항상 새 플레이어로 초기화 (재생 실패 방지)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 1.0
            audioPlayer?.delegate = self

            guard let player = audioPlayer else {
                showToast("녹음 파일을 재생할 수 없습니다.")
                return
            }
            let startTime = playbackPositions[indexPath] ?? 0
            if startTime > 0, startTime < player.duration {
                player.currentTime = startTime
            }
            if duration <= 0 && player.duration <= 0 {
                showToast("녹음 파일을 재생할 수 없습니다.")
                return
            }
            currentPlayingIndexPath = indexPath
            if !player.play() {
                showToast("녹음 파일을 재생할 수 없습니다.")
                return
            }
            cell.setPlaying(true)
            startTimer(for: cell, duration: player.duration)
            playbackPositions[indexPath] = player.currentTime
        } catch {
            print("Audio play error: \(error.localizedDescription)")
            showToast("녹음 파일을 재생할 수 없습니다.")
        }
    }
    
    func startTimer(for cell: JournalAudioCell, duration: TimeInterval) {
        stopTimerOnly()
        playTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self, weak cell] _ in
            guard let self, let player = self.audioPlayer, let cell else { return }
            let current = player.currentTime
            let total = player.duration > 0 ? player.duration : duration
            let progress = total > 0 ? current / total : 0
            cell.updateCurrentTime(current, progress: progress)
            if let idx = self.currentPlayingIndexPath {
                self.playbackPositions[idx] = current
            }
            if !player.isPlaying {
                cell.setPlaying(false)
                self.stopTimerOnly() // 재생 정지 시 세션/외부음원은 delegate 또는 별도 로직에서 처리
            }
        }
    }
    
    func stopTimerOnly() {
        playTimer?.invalidate()
        playTimer = nil
    }
    
    func stopPlayback() {
        stopPlayback(resetUI: true, deactivateSession: true)
    }

    private func stopPlayback(resetUI: Bool, deactivateSession: Bool) {
        let lastIndex = currentPlayingIndexPath
        let lastTime = audioPlayer?.currentTime ?? 0
        let lastDuration = audioPlayer?.duration ?? 0
        audioPlayer?.stop()
        audioPlayer = nil
        stopTimerOnly()
        if let current = currentPlayingIndexPath ?? lastIndex,
           let cell = tableView.cellForRow(at: current) as? JournalAudioCell {
            cell.setPlaying(false)
            if resetUI {
                cell.updateCurrentTime(0, progress: 0)
                playbackPositions[current] = 0
            } else {
                let clamped = max(0, min(lastDuration, lastTime))
                let progress = lastDuration > 0 ? clamped / lastDuration : 0
                cell.updateCurrentTime(clamped, progress: progress)
                playbackPositions[current] = clamped
            }
        }
        currentPlayingIndexPath = nil
        if deactivateSession { deactivateAudioSession() }
    }
    
    func seek(by seconds: TimeInterval, cell: JournalAudioCell, at indexPath: IndexPath) {
        // 재생 중인 경우에는 실제 플레이어 위치 이동
        if let player = audioPlayer, currentPlayingIndexPath == indexPath {
            let newTime = max(0, min(player.duration, player.currentTime + seconds))
            player.currentTime = newTime
            let progress = player.duration > 0 ? newTime / player.duration : 0
            cell.updateCurrentTime(newTime, progress: progress)
            playbackPositions[indexPath] = newTime
            return
        }

        // 재생 중이 아닐 때는 세션을 건드리지 않고 캐시/표시만 갱신
        let duration = playbackDurations[indexPath] ?? 0
        guard duration > 0 else { return }
        let current = playbackPositions[indexPath] ?? 0
        let newTime = max(0, min(duration, current + seconds))
        let progress = newTime / duration
        playbackPositions[indexPath] = newTime
        cell.updateCurrentTime(newTime, progress: progress)
    }
    
    func seek(toProgress progress: Double, cell: JournalAudioCell, at indexPath: IndexPath) {
        let clamped = max(0, min(1, progress))

        // 현재 재생 중인 셀일 때는 실제 플레이어 시킹
        if let player = audioPlayer, currentPlayingIndexPath == indexPath {
            let newTime = player.duration * clamped
            player.currentTime = newTime
            cell.updateCurrentTime(newTime, progress: clamped)
            playbackPositions[indexPath] = newTime
            return
        }

        // 재생 중이 아닐 때: 세션을 건드리지 않고 캐시/표시만 갱신
        let duration = playbackDurations[indexPath] ?? 0
        guard duration > 0 else { return }
        let newTime = duration * clamped
        playbackPositions[indexPath] = newTime
        cell.updateCurrentTime(newTime, progress: clamped)
    }
    
    func showToast(_ message: String) {
        var style = ToastStyle()
        style.backgroundColor = .systemRed
        style.messageColor = .white
        view.makeToast(message, duration: 2.0, position: .center, style: style)
    }

    /// 재생용 오디오 세션 구성 (외부 음원은 재생/일시정지 대응)
    private func activateAudioSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            // 이미 활성화되어 있으면 재설정 없이 통과 (외부 세션 복원 방지)
            if !isAudioSessionActive {
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true, options: [])
                try? session.overrideOutputAudioPort(.speaker)
                isAudioSessionActive = true
            }
            return true
        } catch {
            print("Audio session error: \(error.localizedDescription)")
            showToast("오디오 세션을 시작할 수 없습니다.")
            return false
        }
    }

    private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        if isAudioSessionActive {
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        }
        isAudioSessionActive = false
    }

    private func resolveVoiceURL(name: String) -> URL? {
        if name.contains("file://") {
            if let url = URL(string: name) { return url }
            return URL(fileURLWithPath: name)
        }
        if name.hasPrefix("/") {
            return URL(fileURLWithPath: name)
        }
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = docs.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            let alt = url.appendingPathExtension("m4a")
            if FileManager.default.fileExists(atPath: alt.path) {
                return alt
            }
            return url
        }
        return nil
    }
}

// MARK: - AVAudioPlayerDelegate
extension JournalTimelineViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let current = currentPlayingIndexPath,
           let cell = tableView.cellForRow(at: current) as? JournalAudioCell {
            cell.setPlaying(false)
            cell.updateCurrentTime(player.duration, progress: 1.0)
            playbackPositions[current] = 0
        }
        stopPlayback()
    }
}
