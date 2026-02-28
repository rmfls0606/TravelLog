<h1 style="display: flex; align-items: center; gap: 8px;">
  <img src="TravelLog/Assets.xcassets/AppIcon.appiconset/TripRoadAppIcon.png" width="28" height="28" alt="TripRoad icon" />
  TripRoad
</h1>

![Version](https://img.shields.io/badge/Version-1.5.0-0A84FF) [![App Store](https://img.shields.io/badge/App%20Store-Download-0D96F6?logo=appstore&logoColor=white)](https://apps.apple.com/kr/app/triproad-%EC%97%AC%ED%96%89%EC%9D%98-%EC%88%9C%EA%B0%84%EC%9D%84-%EA%B8%B0%EB%A1%9D%ED%95%98%EB%8B%A4/id6753877753)

## 1. 한 줄 소개
`여행의 순간을 텍스트·링크·사진·음성으로 기록하고, 타임라인으로 다시 돌아보는 여행 기록 앱`

## 2. 주요 기능
<div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;">
  <div style="background:#f1f3f6;border:1px solid #d7dce3;border-radius:10px;padding:14px;color:#111111;">
    <b>🧭 여행 카드 생성</b><br>
    <span style="color:#111111;">교통수단·일정·출발/도착지 입력</span>
  </div>
  <div style="background:#f1f3f6;border:1px solid #d7dce3;border-radius:10px;padding:14px;color:#111111;">
    <b>🔎 도시 검색 최적화</b><br>
    <span style="color:#111111;">Firestore 캐시 우선 + Functions 보강</span>
  </div>
  <div style="background:#f1f3f6;border:1px solid #d7dce3;border-radius:10px;padding:14px;color:#111111;">
    <b>📝 블록형 여행 기록</b><br>
    <span style="color:#111111;">텍스트·링크·사진·음성 블록 구성</span>
  </div>
  <div style="background:#f1f3f6;border:1px solid #d7dce3;border-radius:10px;padding:14px;color:#111111;">
    <b>📅 타임라인 조회</b><br>
    <span style="color:#111111;">날짜 기준 여행 기록 그룹화</span>
  </div>
  <div style="background:#f1f3f6;border:1px solid #d7dce3;border-radius:10px;padding:14px;color:#111111;">
    <b>🔗 링크 미리보기</b><br>
    <span style="color:#111111;">URL 정규화 + 메타데이터 자동 추출</span>
  </div>
  <div style="background:#f1f3f6;border:1px solid #d7dce3;border-radius:10px;padding:14px;color:#111111;">
    <b>🖼️ 커스텀 사진 선택기</b><br>
    <span style="color:#111111;">저화질 → 고화질 2단계 로딩 + 페이지네이션 + 다중 선택 최적화</span>
  </div>
  <div style="background:#f1f3f6;border:1px solid #d7dce3;border-radius:10px;padding:14px;color:#111111;">
    <b>🎙️ 음성 메모</b><br>
    <span style="color:#111111;">단일 오디오 세션 관리 + 인터럽션/라우트 변경 대응</span>
  </div>
  <div style="background:#f1f3f6;border:1px solid #d7dce3;border-radius:10px;padding:14px;color:#111111;">
    <b>📴 오프라인 대응</b><br>
    <span style="color:#111111;">로컬 저장 + 네트워크 복구 시 자동 보정</span>
  </div>
</div>

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
- 레이어:
- `Presentation`: ViewController + ViewModel (입력/상태 관리)
- `Domain`: Entity + UseCase + Repository Protocol (비즈니스 규칙)
- `Data`: Realm Repository + Firestore/Functions DataSource (구현체)

### Architecture DFD
![Architecture Flow](docs/architecture/DataFlow.jpg)

## 6. 핵심 기술 포인트
### 1) 도시 검색 하이브리드 구조 (Cache-First + Fallback)
- 문제: 도시 자동완성에서 정확도/응답속도/외부 API 비용을 동시에 관리해야 했습니다.
- 해결 방식:
- Firestore prefix 검색(`nameLower`, `countryLower`)을 1차로 수행
- 결과 부족/미존재 시 Firebase Functions `searchCity`로 fallback
- `place_id` 기준 저장으로 중복 데이터 방지
- 효과: 캐시 hit 구간은 빠르게 응답하고, miss 구간만 원격 보강하여 비용과 품질을 균형화했습니다.

### 2) 링크 미리보기 파이프라인
- 문제: 사용자가 입력한 URL 형식이 다양하고, 오프라인/실패 상황에서 미리보기 누락이 발생했습니다.
- 해결 방식:
- `URLNormalizer`로 URL 정규화(스키마 보정 포함)
- `LPMetadataProvider`로 제목/설명/이미지 추출
- 이미지를 문서 디렉토리에 저장하고 Realm에 메타데이터 기록
- 효과: 링크 블록이 단순 URL 텍스트가 아닌, 재진입 시에도 유지되는 미리보기 카드로 동작합니다.

### 3) 도시 이미지 백필(Backfill) + 로컬 우선 렌더링
- 문제: 과거 데이터에는 `imageURL`, `localImageFilename`이 비어 있는 경우가 있어 화면 일관성이 떨어졌습니다.
- 해결 방식:
- 백필 서비스에서 Firestore 조회 -> miss 시 Functions 호출
- 획득한 URL 이미지를 로컬 파일로 저장 후 Realm 갱신
- UI는 `localImageFilename` 우선, 없을 때만 URL fallback
- 효과: 네트워크 상태와 무관하게 재방문 시 이미지 안정성이 높아졌습니다.

### 4) 커스텀 사진 선택기 (대용량 대응)
- 문제: 대량 이미지 환경에서 `reloadData()` 중심 갱신은 성능 저하/깜빡임/크래시 위험이 있었습니다.
- 해결 방식:
- 페이지네이션 + `insertItems` 기반 증분 렌더링
- `AsyncStream`으로 저화질 -> 고화질 2단계 로딩
- iCloud nil 콜백 분기 처리 + `NSCache` 썸네일 캐싱
- 효과: 초기 체감 속도와 스크롤 안정성을 함께 확보했습니다.

### 5) 음성 메모 안정화 (단일 세션 관리)
- 문제: 다중 블록 재생/녹음, 라우트 변경, 인터럽션 상황에서 오디오 세션 충돌이 발생할 수 있었습니다.
- 해결 방식:
- `AudioCoordinator`로 단일 녹음/재생 세션 보장
- 인터럽션/라우트 변경/백그라운드 진입 시 `stopAll()` 처리
- 실제 재생/녹음 시점에만 세션 활성화
- 효과: 예외 상황에서도 재생/녹음 상태가 꼬이지 않도록 안정성을 높였습니다.

## 7. 성능 개선
> 아래 수치는 코드에 반영된 운영 수치입니다.

- 검색 입력 제어
- debounce: `400ms`
- skeleton 셀: `5개`
- Firestore page limit: `20`
- Functions 결과 limit: 기본 `10`, 최대 `20`
- 1글자 입력은 원격 호출 제한(캐시 우선)

- 링크 메타데이터 캐시 정책
- TTL: `30일`
- 실패 재시도 상한: `3회` (`fetchFailCount < 3`)
- Trip별 TTL 갱신: `하루 1회`

- 이미지 캐시/저장 전략
- Kingfisher 메모리 캐시: `50MB`, 만료 `300초`
- Kingfisher 디스크 캐시: `200MB`, 만료 `7일`
- 장기 보존은 FileManager(`CityImages`) + Realm filename 참조

- 사진 선택기 최적화
- 페이지네이션 배치: `300개`
- `reloadData` 중심 갱신에서 `insertItems` 기반 증분 갱신으로 전환
- `AsyncStream` 저화질 -> 고화질 스트리밍 + iCloud nil 콜백 분기 처리

- 음성 처리 안정화
- 녹음 최소 길이: `1초`
- 재생 건너뛰기: `±15초`
- 타이머 업데이트 주기: `0.05초`
- 세션 충돌 시 `stopAll()`로 단일 오디오 세션 유지

## 8. 트러블슈팅
- 도시 검색 시 이상 데이터/중복 데이터 유입
- 원인: query 문자열 기반 저장, 불완전한 정규화
- 해결: `place_id` 문서 키 사용 + 도시 타입 필터링 + prefix 캐시 우선 구조

- 링크 메타데이터가 오프라인에서 누락되는 문제
- 원인: 최초 요청 실패 후 갱신 타이밍 부재
- 해결: `metadataUpdatedAt` + `fetchFailCount` + 네트워크 복구 시 재시도 경로 추가

- 과거 여행 카드/타임라인의 도시 이미지 누락
- 원인: 이전 스키마 데이터의 `imageURL/localImageFilename` 빈 값
- 해결: 백필 서비스 도입(원격 조회 -> 로컬 저장 -> Realm 갱신), Realm 변경 감지로 UI 즉시 반영

- 사진 페이지네이션 중 크래시
- 원인: 대량 로딩 시 `reloadData()` 남용
- 해결: `performBatchUpdates + insertItems`로 변경해 증분 렌더링

- 오디오 재생 시 외부 오디오와 세션 충돌
- 원인: 세션 활성/비활성 경계 불명확
- 해결: 실제 녹음/재생 시점에만 세션 활성화, 인터럽션/라우트 변경 시 안전 중지











## 9. 폴더 구조
```text
TripRoad
├─ TravelLog
│  ├─ App
│  ├─ Presentation
│  │  ├─ Base
│  │  ├─ Common
│  │  ├─ Trip
│  │  ├─ Travel
│  │  └─ Journal
│  ├─ Domain
│  │  ├─ Entity
│  │  ├─ Repository
│  │  └─ UseCase
│  └─ Data
│     ├─ DataSource
│     ├─ Repository
│     └─ Realm
├─ functions
│  └─ src/index.ts
└─ Firebase
```

고려사항
트러블 슈팅
고민한 점
성능 개선
