<h1 style="display: flex; align-items: center; gap: 8px;">
  <img src="TravelLog/Assets.xcassets/AppIcon.appiconset/TripRoadAppIcon.png" width="28" height="28" alt="TripRoad icon" />
  TripRoad
</h1>

![Version](https://img.shields.io/badge/Version-1.5.0-0A84FF) [![App Store](https://img.shields.io/badge/App%20Store-Download-0D96F6?logo=appstore&logoColor=white)](https://apps.apple.com/kr/app/triproad-%EC%97%AC%ED%96%89%EC%9D%98-%EC%88%9C%EA%B0%84%EC%9D%84-%EA%B8%B0%EB%A1%9D%ED%95%98%EB%8B%A4/id6753877753)

## 1. 한 줄 소개
`여행의 순간을 텍스트·링크·사진·음성으로 기록하고, 타임라인으로 다시 돌아보는 여행 기록 앱`

## 2. 주요 기능
**🧭 여행 카드 생성**  
교통수단·일정·출발/도착지 입력

**🔎 도시 검색 최적화**  
Firestore 캐시 우선 + Functions 보강

**📝 블록형 여행 기록**  
텍스트·링크·사진·음성 블록 구성

**📅 타임라인 조회**  
날짜 기준 여행 기록 그룹화

**🔗 링크 미리보기**  
URL 정규화 + 메타데이터 자동 추출 + 링크 이동

**🖼️ 커스텀 사진 선택기**  
저화질→고화질 2단계 로딩 + 페이지네이션 + 다중 선택 최적화

**🎙️ 음성 메모**  
녹음/재생 + 단일 오디오 세션 관리 + 인터럽션/라우트 변경 대응

**📴 오프라인 대응**  
로컬 저장 + 네트워크 복구 시 자동 보정

## 3. 스크린샷
<table>
  <tr>
    <td align="center" width="25%">여행 목록 화면</td>
    <td align="center" width="25%">여행지 설정 화면</td>
    <td align="center" width="25%">여행 기록 목록 화면</td>
    <td align="center" width="25%">여행 기록 작성 화면</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/TripMock.png" width="210" /></td>
    <td align="center"><img src="docs/screenshots/TravelMock.png" width="210" /></td>
    <td align="center"><img src="docs/screenshots/JournalListMock.png" width="210" /></td>
    <td align="center"><img src="docs/screenshots/JournalAddMock.png" width="210" /></td>
  </tr>
</table>

## 4. 기술 스택
| Category | Stack | Version |
| --- | --- | --- |
| App Target | ![iOS](https://img.shields.io/badge/iOS-16.0+-000000?logo=apple&logoColor=white) | iOS Deployment Target `16.0+` |
| Language | ![Swift](https://img.shields.io/badge/Swift-5-FA7343?logo=swift&logoColor=white) | Swift `5` |
| UI | ![UIKit](https://img.shields.io/badge/UIKit-2396F3) ![SnapKit](https://img.shields.io/badge/SnapKit-1F8CE6) | SnapKit `5.7.1` |
| Reactive | ![RxSwift](https://img.shields.io/badge/RxSwift-B7178C?logo=reactivex&logoColor=white) ![RxCocoa](https://img.shields.io/badge/RxCocoa-B7178C) | RxSwift/RxCocoa `6.10.1` |
| Local DB | ![Realm](https://img.shields.io/badge/Realm-39477F?logo=realm&logoColor=white) | RealmSwift `20.0.3` |
| Backend | ![Firebase Firestore](https://img.shields.io/badge/Firestore-FFCA28?logo=firebase&logoColor=black) ![Firebase Functions](https://img.shields.io/badge/Functions-FFCA28?logo=firebase&logoColor=black) | firebase-ios-sdk `12.9.0` |
| Media / Image | ![Kingfisher](https://img.shields.io/badge/Kingfisher-1E90FF) ![PhotosUI](https://img.shields.io/badge/PhotosUI-0A84FF) ![AVFoundation](https://img.shields.io/badge/AVFoundation-111111) | Kingfisher `8.7.0` |
| UX / Utility | ![FSCalendar](https://img.shields.io/badge/FSCalendar-34A853) ![Toast--Swift](https://img.shields.io/badge/Toast--Swift-555555) ![IQKeyboardManager](https://img.shields.io/badge/IQKeyboardManager-3A3A3A) | FSCalendar `2.8.4`, Toast-Swift `5.1.1`, IQKeyboardManager `8.0.2` |
| Functions Runtime | ![Node.js](https://img.shields.io/badge/Node.js-24-339933?logo=node.js&logoColor=white) ![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white) | Node.js `24`, TypeScript `5.7.3`, firebase-functions `7.0.0` |

## 5. 아키텍처 설명
- 패턴: MVVM + Clean Architecture
- 레이어: `Presentation` / `Domain` / `Data`
- 핵심: UseCase 중심 의존성 분리 + Local(Realm) 우선 + Remote(Firebase) 보강

### Architecture DFD
![Architecture Flow](docs/architecture/DataFlow.jpg)

## 6. 핵심 기술 포인트
### 1) 도시 검색 하이브리드 구조
- 기술 목표: 검색 속도/정확도/API 비용 균형
- 설계/구현: Firestore prefix 1차 검색, miss 시 Functions fallback, `place_id` 기준 저장
- 핵심 포인트: cache-first 파이프라인으로 원격 호출 최소화

### 2) 링크 미리보기 파이프라인
- 기술 목표: 링크를 구조화된 미리보기 데이터로 저장/재사용
- 설계/구현: URL 정규화 -> 메타데이터 추출 -> 이미지/메타데이터 로컬 저장
- 핵심 포인트: TTL 기반 갱신 + 실패 재시도 제한 + 오프라인 복구 경로 설계

### 3) 도시 이미지 백필 + 로컬 우선 렌더링
- 기술 목표: 과거 데이터/오프라인에서도 이미지 표시 일관성 유지
- 설계/구현: BackfillService로 원격 보강 후 로컬 파일 저장 및 Realm 갱신
- 핵심 포인트: `localImageFilename` 우선 렌더링으로 네트워크 의존도 축소

### 4) 커스텀 사진 선택기
- 기술 목표: 대량 사진 환경에서 초기 체감 속도와 스크롤 안정성 확보
- 설계/구현: 페이지네이션, 증분 렌더링, 저화질->고화질 2단계 로딩, 썸네일 캐싱
- 핵심 포인트: `NSCache<NSString, UIImage>` 메모리 캐시로 재요청/깜빡임을 줄이고, 비동기 로딩과 화면 갱신 분리로 UI 부하 완화

### 5) 음성 메모 안정화
- 기술 목표: 시스템 이벤트 상황에서도 녹음/재생 상태 안정성 확보
- 설계/구현: `AudioCoordinator` 단일 세션 제어 + 인터럽션/라우트 변경 대응
- 핵심 포인트: 오디오 세션 생명주기 명시적 제어로 블록 간 충돌 방지

## 7. 고민한 점 (설계 의사결정)
### 1) 도시 검색 Fallback 설계
![City Search Fallback Flow](docs/troubleshooting/city-search-fallback-flow.svg)
- 설계 목표: 검색 속도, 정확도, 비용의 균형
- 선택: `Firestore prefix cache-first -> miss 시 Functions fallback`
- 정책: 오프라인은 로컬 캐시만 사용, 온라인은 필요 시 원격 보강
- 기준: `place_id` 식별 일관성 유지, 1글자 입력 원격 호출 제한

### 2) 링크 메타데이터 정책
![Link Metadata Recovery Flow](docs/troubleshooting/link-metadata-recovery-flow.svg)
- 설계 목표: 누락 없이 저장하고, 과도한 재요청 방지
- 선택: 상태 필드(`metadataUpdatedAt`, `fetchFailCount`) 기반 복구 경로 분리
- 정책: 네트워크 복구 시 nil 상태 우선 복구 + TTL 만료 갱신
- 기준값: TTL 30일, 실패 재시도 3회, Trip별 하루 1회 갱신

### 3) 과거 데이터 호환성
![Legacy Compatibility + Backfill](docs/troubleshooting/legacy-backfill-compatibility-flow.svg)
- 설계 목표: 스키마 변경 이후에도 기존 데이터 연속성 유지
- 선택: 하위호환 조회 + `CityImageBackfillService` 보강
- 정책: 온라인 보강/오프라인 유지, 복구 후 로컬 파일 및 Realm 재기록
- UI 반영: Realm `NotificationToken` 기반 즉시 갱신

### 4) 오디오 세션 안정성
![Audio Session Data Flow](docs/troubleshooting/audio-session-dataflow.svg)
- 설계 목표: 인터럽션/라우트 변경 상황에서도 재현성 있는 동작
- 선택: `AudioCoordinator` 중심 단일 세션 제어
- 정책: 단일 활성 블록, 이벤트 발생 시 `stopAll()` 안전 중지
- 기준: 실제 녹음/재생 시점에만 세션 활성화, 1초 미만 저장 차단

### 5) 사진 선택기 로딩 전략 (AsyncStream)
![Photo Loading Flow](docs/troubleshooting/ts-04-photo-loading-flow.svg)
- 설계 목표: 초기 체감 속도와 최종 화질 동시 확보
- 선택: `AsyncStream` 저화질 -> 고화질 2단계 전달
- 선택 이유: 고화질 단건 로딩은 첫 화면 공백/지연이 커서, 저화질 즉시 표시 후 고화질 치환 방식으로 체감 성능과 최종 품질을 함께 확보
- 정책: iCloud 지연 콜백(nil) 대기 처리, 페이지네이션 + 증분 렌더링
- iCloud 처리 기준: `image == nil && isInCloud == true`는 실패가 아니라 다운로드 진행 상태로 보고 스트림을 종료하지 않음
- 기준: 대량 로딩 구간 `reloadData` 최소화, `insertItems` 중심 갱신, 셀 재사용 구간은 `NSCache` hit 우선 사용
