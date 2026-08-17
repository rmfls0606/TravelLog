/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
// import {onRequest} from "firebase-functions/https";
// import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import axios from "axios";
import {getDownloadURL, getStorage} from "firebase-admin/storage";
import Anthropic from "@anthropic-ai/sdk";
import {isAllowedCountry} from "./allowedCountries";

admin.initializeApp();
const db = admin.firestore();

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

// API Key test
// export const testEnv = functions.https.onRequest((req, res) => {
//   const apiKey = process.env.GOOGLE_API_KEY;

//   res.json({
//     message: "Hello from Firebase Functions!",
//     apiKey: apiKey ? "API key is set" : "API key is not set",
//   });
// });

type CityDoc = {
  cityId: string;
  name: string;
  country: string;
  nameLower: string;
  countryLower: string;
  lat: number;
  lng: number;
  imageUrl: string | null;
  updatedAt: number;
  popularityCount?: number;
};

function normalize(s: string) {
  return s.trim().toLowerCase();
}

function cityRank(city: CityDoc, queryLower: string): number {
  const name = normalize(city.name);
  const country = normalize(city.country);

  if (name === queryLower) return 0;
  if (name.startsWith(queryLower)) return 1;
  if (name.includes(queryLower)) return 2;
  if (country === queryLower) return 3;
  if (country.startsWith(queryLower)) return 4;
  return 5;
}

function sortCitiesByQuery(cities: CityDoc[], queryLower: string): CityDoc[] {
  return [...cities].sort((a, b) => {
    const rankA = cityRank(a, queryLower);
    const rankB = cityRank(b, queryLower);
    if (rankA !== rankB) return rankA - rankB;

    const popularityA = a.popularityCount ?? 0;
    const popularityB = b.popularityCount ?? 0;
    if (popularityA !== popularityB) return popularityB - popularityA;

    if (a.name.length !== b.name.length) return a.name.length - b.name.length;

    return a.name.localeCompare(b.name);
  });
}

function projectId(): string | null {
  return process.env.GCLOUD_PROJECT ||
    process.env.GCP_PROJECT ||
    admin.app().options.projectId ||
    null;
}

function storageBucketName(): string | null {
  return process.env.FIREBASE_STORAGE_BUCKET ||
    admin.app().options.storageBucket ||
    (projectId() ? `${projectId()}.firebasestorage.app` : null);
}

function makePhotoProxyURL(photoReference: string): string | null {
  const currentProjectId = projectId();
  if (!currentProjectId || !photoReference) return null;
  const encodedPhotoReference = encodeURIComponent(photoReference);
  return `https://us-central1-${currentProjectId}.cloudfunctions.net/` +
    `cityPhotoProxy?photoReference=${encodedPhotoReference}`;
}

function pickRepresentativePhotoReference(photos: any[] | undefined): string | null {
  if (!Array.isArray(photos) || photos.length === 0) return null;

  const firstPhoto = photos.find(
    (photo) => typeof photo?.photo_reference === "string" && photo.photo_reference
  );
  return firstPhoto?.photo_reference ?? null;
}

function pickBestDetailsPhotoReference(photos: any[] | undefined): string | null {
  if (!Array.isArray(photos) || photos.length === 0) return null;

  const bestPhoto = [...photos]
    .sort((a: any, b: any) => (b.width ?? 0) - (a.width ?? 0))[0];

  return bestPhoto?.photo_reference ?? null;
}

async function searchFallbackPhotoReference(
  cityName: string,
  apiKey: string
): Promise<string | null> {
  const queries = [
    `${cityName} 랜드마크`,
  ];

  for (const query of queries) {
    const searchRes = await axios.get(
      "https://maps.googleapis.com/maps/api/place/textsearch/json",
      {
        params: {
          query,
          // region: "kr" 편향을 주면 해외 도시를 검색할 때도 결과가 한국 쪽으로
          // 쏠려 엉뚱한 사진이 나온다. 쿼리 텍스트 자체(도시명 + 랜드마크)만으로
          // 검색하도록 지역 편향을 제거한다.
          language: "ko",
          key: apiKey,
        },
      }
    );

    if (searchRes.data?.status !== "OK") {
      continue;
    }

    const places = searchRes.data.results ?? [];
    const candidate = places.find((place: any) =>
      place?.types?.includes("tourist_attraction") &&
      Array.isArray(place?.photos) &&
      place.photos.length > 0
    );

    const photoRef = pickRepresentativePhotoReference(candidate?.photos);
    if (photoRef) {
      return photoRef;
    }
  }

  return null;
}

async function persistCityPhotoToStorage(
  placeId: string,
  photoReference: string,
  apiKey: string
): Promise<string | null> {
  const bucketName = storageBucketName();
  if (!bucketName) return null;

  const bucket = getStorage().bucket(bucketName);
  const file = bucket.file(`city-images/${placeId}.jpg`);

  try {
    const photoResponse = await axios.get(
      "https://maps.googleapis.com/maps/api/place/photo",
      {
        params: {
          maxwidth: 1600,
          photo_reference: photoReference,
          key: apiKey,
        },
        responseType: "arraybuffer",
        validateStatus: (status) => status >= 200 && status < 400,
      }
    );

    const buffer = Buffer.from(photoResponse.data);
    if (buffer.length === 0) return null;

    await file.save(buffer, {
      resumable: false,
      metadata: {
        contentType: photoResponse.headers["content-type"] || "image/jpeg",
        cacheControl: "public,max-age=31536000,immutable",
      },
    });

    return await getDownloadURL(file);
  } catch {
    return null;
  }
}

function isSubCitySuffixQuery(q: string): boolean {
  const s = q.trim();
  // "강진읍", "OO면", "OO동" 같은 '행정동/읍면'만 차단
  return /(읍|면|동)$/.test(s);
}

// 완성형 한글 음절(자모가 결합된 글자, 예: "괌")인지 판별한다. 미완성 자모
// (ㄱ, ㅏ 등)나 영문/숫자 1글자와 달리, 완성형 한글 음절 1개는 "괌", "산"처럼
// 그 자체로 의미 있는 지명일 수 있어 1글자 Google 호출 금지 예외로 둔다.
function isSingleCompleteHangulSyllable(q: string): boolean {
  return /^[가-힣]$/.test(q.trim());
}

// Firestore prefix range query helper
async function prefixSearchCities(prefix: string, limit: number): Promise<CityDoc[]> {
  if (!prefix) return [];

  const end = prefix + "\uf8ff";

  const byNameSnap = await db.collection("cities")
    .orderBy("nameLower")
    .startAt(prefix)
    .endAt(end)
    .limit(limit)
    .get();

  const byCountrySnap = await db.collection("cities")
    .orderBy("countryLower")
    .startAt(prefix)
    .endAt(end)
    .limit(limit)
    .get();

  const map = new Map<string, CityDoc>();

  byNameSnap.docs.forEach((d) => map.set(d.id, d.data() as CityDoc));
  byCountrySnap.docs.forEach((d) => map.set(d.id, d.data() as CityDoc));

  // 과거(국가 제한 도입 이전)에 캐시된 문서 중 허용되지 않은 지역의 도시는
  // 걸러낸다 — 새로 만드는 문서뿐 아니라 이미 Firestore에 있는 캐시에도
  // 동일한 허용 목록을 적용해야 검색 결과가 일관된다.
  const merged = Array.from(map.values())
    .filter((city) => isAllowedCountry(city.country));

  return sortCitiesByQuery(merged, prefix).slice(0, limit);
}

async function findPlaceSmart(
  query: string,
  apiKey: string
): Promise<string | null> {
  const res = await axios.get(
    "https://maps.googleapis.com/maps/api/place/autocomplete/json",
    {
      params: {
        input: query,
        types: "(regions)",
        // components: "country:kr"였던 제한을 제거해 해외 도시도 검색되게 한다.
        key: apiKey,
      },
    }
  );

  if (res.data?.status !== "OK") {
    console.log("findPlaceSmart: autocomplete status not OK", {
      query, status: res.data?.status, errorMessage: res.data?.error_message,
    });
    return null;
  }

  const predictions = res.data?.predictions ?? [];
  if (predictions.length === 0) {
    console.log("findPlaceSmart: no predictions", {query});
    return null;
  }

  const queryLower = normalize(query);

  const scored: Array<{ prediction: any; rank: number; descLength: number }> = predictions
    .map((p: any) => {
      const mainText = normalize(p?.structured_formatting?.main_text ?? "");
      const description = normalize(p?.description ?? "");

      let rank = 5;
      if (mainText === queryLower) rank = 0;
      else if (description === queryLower) rank = 1;
      else if (mainText.startsWith(queryLower)) rank = 2;
      else if (description.startsWith(queryLower)) rank = 3;
      else if (description.includes(queryLower)) rank = 4;

      return {prediction: p, rank, descLength: description.length};
    })
    .sort((a: { prediction: any; rank: number; descLength: number },
      b: { prediction: any; rank: number; descLength: number }) => {
      if (a.rank !== b.rank) return a.rank - b.rank;
      return a.descLength - b.descLength;
    });

  console.log("findPlaceSmart: chosen prediction", {
    query,
    predictionCount: predictions.length,
    chosen: scored[0]?.prediction?.description,
    placeId: scored[0]?.prediction?.place_id ?? null,
  });

  return scored[0]?.prediction?.place_id ?? null;
}

const HANGUL_PATTERN = /[가-힣]/;

async function getOrCreateCityByPlaceId(
  placeId: string,
  apiKey: string,
  query: string,
  displayNameHint: string | null
): Promise<CityDoc | null> {
  const existingSnap = await db.collection("cities").doc(placeId).get();
  const existingData = existingSnap.data() as CityDoc | undefined;

  const detailsRes = await axios.get(
    "https://maps.googleapis.com/maps/api/place/details/json",
    {
      params: {
        place_id: placeId,
        key: apiKey,
        language: "ko",
        fields: "name,geometry,address_components,types,photos",
      },
    }
  );

  if (detailsRes.data?.status !== "OK") {
    console.log("getOrCreateCityByPlaceId: details status not OK", {
      placeId, query, status: detailsRes.data?.status,
    });
    return null;
  }

  const details = detailsRes.data.result;
  const name = details.name ?? "";
  const types: string[] = details.types || [];

  console.log("getOrCreateCityByPlaceId: details fetched", {placeId, query, name, types});

  // 국가 정보가 없는 결과는 도시로 취급하지 않는다.
  const countryComponent = (details.address_components || []).find((c: any) =>
    (c.types || []).includes("country")
  );

  if (!countryComponent) {
    console.log("getOrCreateCityByPlaceId: rejected — no country component", {placeId, name});
    return null;
  }

  const country = countryComponent.long_name as string;

  // 허용된 지역군(한국/일본/동남아시아/중화권/남태평양/유럽/미주/중앙아시아/
  // 서아시아/중남미)에 속한 국가만 신규 캐시로 만든다.
  if (!isAllowedCountry(country)) {
    console.log("getOrCreateCityByPlaceId: rejected — country not in allowed regions", {
      placeId, name, country,
    });
    return null;
  }

  // 읍/면/동/리 차단 (한국 행정구역 접미사). 이 접미사는 대한민국 주소에서만 실제
  // 행정구역을 의미하고, "파리"(리)처럼 해외 지명이 한글 표기상 우연히 같은 글자로
  // 끝나는 경우가 있어 국가가 대한민국일 때로 한정한다.
  const isKoreanAddress = country === "대한민국" || country === "한국";
  if (isKoreanAddress && /(읍|면|동|리)$/.test(name)) {
    console.log("getOrCreateCityByPlaceId: rejected — sub-district suffix", {placeId, name});
    return null;
  }

  // 도시/행정구역급 결과만 허용 (개별 장소/주소 제외) — 국가에 관계없이 적용되는 일반 필터.
  // 괌은 자체 ISO 국가 코드를 가진 자치령이라 Google이 country 타입으로 분류하지만,
  // 실질적으로는 하나의 도시/여행지 단위로 쓰이므로 예외로 허용한다.
  const isGuam = country === "괌" && types.includes("country");
  const isAllowedAdmin =
    types.includes("locality") ||
    types.includes("administrative_area_level_1") ||
    types.includes("administrative_area_level_2") ||
    isGuam;

  if (!isAllowedAdmin) {
    console.log("getOrCreateCityByPlaceId: rejected — type not allowed", {placeId, name, types});
    return null;
  }

  // 이름 비교는 하지 않는다: details를 항상 language: "ko"로 요청하므로 name은
  // 한국어로 로컬라이즈되지만, query는 findPlaceSmart에 넘긴 원문(외국 도시는 영어/
  // 현지어일 수 있음) 그대로다. 서로 다른 언어를 문자열로 비교하면 해외 도시는
  // 거의 항상 불일치로 잘못 걸러진다. 실제 검증은 findPlaceSmart가 이미 같은 언어의
  // 예측 텍스트(mainText/description)로 유사도 순위를 매겨 최적 후보를 고르는 단계에서
  // 끝났으므로, 여기서는 국가/행정구역 타입 검증만으로 충분하다.
  console.log("getOrCreateCityByPlaceId: accepted", {placeId, query, name, country});

  const lat = details.geometry?.location?.lat;
  const lng = details.geometry?.location?.lng;
  if (typeof lat !== "number" || typeof lng !== "number") return null;

  let imageUrl: string | null = null;

  let photoRef = pickBestDetailsPhotoReference(details.photos);
  if (!photoRef) {
    photoRef = await searchFallbackPhotoReference(name, apiKey);
  }

  if (photoRef) {
    imageUrl = await persistCityPhotoToStorage(placeId, photoRef, apiKey);
    if (!imageUrl) {
      imageUrl = makePhotoProxyURL(photoRef);
    }
  }

  // Google이 이 place에 대해 한국어 번역을 갖고 있지 않으면 language: "ko"를
  // 요청해도 name이 영어/현지어 그대로 온다 (예: "Phu Quoc"). 이미 한글로 온
  // 경우는 손대지 않고, 한글이 아닐 때만 티켓 스캔이 함께 보낸 한글 이름
  // 힌트로 대체한다 — 기존에 이미 정상적으로 한글화된 도시(예: 인천, 서울)의
  // 이름을 실수로 덮어쓰지 않기 위함이다.
  const trimmedHint = displayNameHint?.trim();
  const resolvedName = (!HANGUL_PATTERN.test(name) && trimmedHint) ? trimmedHint : name;

  const doc: CityDoc = {
    cityId: placeId,
    name: resolvedName,
    country,
    nameLower: normalize(resolvedName),
    countryLower: normalize(country),
    lat,
    lng,
    imageUrl: imageUrl,
    updatedAt: Date.now(),
    popularityCount: existingData?.popularityCount ?? 0,
  };

  await db.collection("cities").doc(placeId).set(doc, {merge: true});

  return doc;
}

export const searchCity = onCall(async (request) => {
  const queryRaw = (request.data?.query ?? "") as string;
  // const language = ((request.data?.language ?? "ko") as string) || "ko";
  const limit = Math.min(Math.max(Number(request.data?.limit ?? 10), 1), 20);
  const displayNameHintRaw = request.data?.displayName;
  const displayNameHint =
    typeof displayNameHintRaw === "string" && displayNameHintRaw.trim() ?
      displayNameHintRaw.trim() :
      null;

  const query = queryRaw.trim();
  if (!query) {
    return {cities: [] as CityDoc[], source: "empty"};
  }

  const apiKey = process.env.GOOGLE_API_KEY;
  if (!apiKey) {
    throw new Error("GOOGLE_API_KEY is not set");
  }

  if (isSubCitySuffixQuery(query)) {
    return {cities: [] as CityDoc[], source: "blocked-subcity"};
  }

  const lower = normalize(query);

  // 1) Firestore prefix cache first (always)
  const cached = await prefixSearchCities(lower, limit);

  // 1글자 입력은 Google 호출 금지 (비용/오염 방어) — 단, "괌"처럼 그 자체로
  // 지명이 될 수 있는 완성형 한글 음절 1개는 예외로 허용한다.
  if (lower.length < 2 && !isSingleCompleteHangulSyllable(query)) {
    return {cities: cached, source: "cache-only"};
  }

  // 캐시가 충분하면 Google 호출하지 않음
  if (cached.length > 0) {
    return {cities: cached.slice(0, limit)};
  }

  const placeId = await findPlaceSmart(query, apiKey);

  if (!placeId) {
    console.log("searchCity: no place found via autocomplete", {query});
    return {cities: [], source: "google-empty"};
  }

  const city = await getOrCreateCityByPlaceId(
    placeId,
    apiKey,
    query, // 🔥 language 대신 query 넘긴다
    displayNameHint
  );

  if (!city) {
    console.log("searchCity: place found but rejected by filters", {query, placeId});
    return {cities: [], source: "filtered-out"};
  }

  console.log("searchCity: resolved city", {query, city});

  return {
    cities: [city],
  };
});

// ---------------------------------------------------------------------------
// Ticket OCR (parseTicketImage)
// ---------------------------------------------------------------------------

type TicketTransport = "airplane" | "bus" | "train";

type TicketExtraction = {
  isTicket: boolean;
  transport: TicketTransport | null;
  departureCity: string | null;
  departureCityKorean: string | null;
  departureCountry: string | null;
  destinationCity: string | null;
  destinationCityKorean: string | null;
  destinationCountry: string | null;
  startDate: string | null;
  startTime: string | null;
  endDate: string | null;
  endTime: string | null;
  confidence: number;
  notes: string | null;
};

// 시스템 프롬프트가 개인식별정보를 결과에 담지 말라고 지시하지만, 모델이 그 지시를
// 어기고 notes 등 자유 텍스트 필드에 여권번호·전화번호 형식의 문자열을 남기는
// 경우를 대비한 방어선이다. Cloud Logging에 평문으로 남지 않도록 로그에 찍기
// 직전에만 적용하고, 실제로 앱에 반환되는 result 객체는 건드리지 않는다.
function redactPotentialPIIForLogging(value: unknown): unknown {
  const json = JSON.stringify(value);

  const redacted = json
    .replace(/[A-Za-z]{1,2}[0-9]{6,9}/g, "[MASKED]") // 여권번호 형식
    .replace(/\+?[0-9][0-9()\-.\s]{5,17}[0-9)]/g, (match) => {
      const digitCount = (match.match(/[0-9]/g) ?? []).length;
      return digitCount >= 7 && digitCount <= 15 ? "[MASKED]" : match;
    });

  try {
    return JSON.parse(redacted);
  } catch {
    return "[unable to redact for logging]";
  }
}

const TICKET_EXTRACTION_SCHEMA = {
  type: "object",
  properties: {
    isTicket: {
      type: "boolean",
      description:
        "Whether the image is a readable transportation ticket or " +
        "boarding pass (bus, train, or airplane) that shows route and " +
        "date information. False for unrelated photos or unreadable " +
        "images.",
    },
    transport: {
      anyOf: [
        {type: "string", enum: ["airplane", "bus", "train"]},
        {type: "null"},
      ],
      description: "The mode of transport shown on the ticket.",
    },
    departureCity: {
      anyOf: [{type: "string"}, {type: "null"}],
      description:
        "Departure city name, as its commonly-used English/international " +
        "name (e.g. 'Incheon', 'Seoul', 'Paris', 'Phu Quoc') — this name " +
        "is used as a search query against a worldwide place database, " +
        "which matches English/international names far more reliably " +
        "than a Korean transliteration for less-famous places. The " +
        "app itself will localize the resolved city into Korean for " +
        "display, so do not translate it yourself.",
    },
    departureCityKorean: {
      anyOf: [{type: "string"}, {type: "null"}],
      description:
        "The same departure city, but as the commonly-used Korean name/" +
        "transliteration (e.g. '인천', '서울', '파리', '푸꾸옥') — used " +
        "only as a display fallback for places Google's database has no " +
        "Korean translation for. Use the well-known Korean " +
        "transliteration, not a literal/character-by-character " +
        "transcription.",
    },
    departureCountry: {
      anyOf: [{type: "string"}, {type: "null"}],
      description:
        "Best-guess country of the departure city, in Korean (e.g. " +
        "'대한민국', '프랑스', '베트남') — matching this app's data, " +
        "which stores country names in Korean for every country.",
    },
    destinationCity: {
      anyOf: [{type: "string"}, {type: "null"}],
      description:
        "Destination city name, as its commonly-used English/" +
        "international name (e.g. 'Incheon', 'Seoul', 'Paris', 'Phu " +
        "Quoc') — this name is used as a search query against a " +
        "worldwide place database, which matches English/international " +
        "names far more reliably than a Korean transliteration for " +
        "less-famous places. The app itself will localize the resolved " +
        "city into Korean for display, so do not translate it yourself.",
    },
    destinationCityKorean: {
      anyOf: [{type: "string"}, {type: "null"}],
      description:
        "The same destination city, but as the commonly-used Korean " +
        "name/transliteration (e.g. '인천', '서울', '파리', '푸꾸옥') — " +
        "used only as a display fallback for places Google's database " +
        "has no Korean translation for. Use the well-known Korean " +
        "transliteration, not a literal/character-by-character " +
        "transcription.",
    },
    destinationCountry: {
      anyOf: [{type: "string"}, {type: "null"}],
      description:
        "Best-guess country of the destination city, in Korean (e.g. " +
        "'대한민국', '프랑스', '베트남') — matching this app's data, " +
        "which stores country names in Korean for every country.",
    },
    startDate: {
      anyOf: [{type: "string"}, {type: "null"}],
      description: "Departure date in ISO 8601 (YYYY-MM-DD).",
    },
    startTime: {
      anyOf: [{type: "string"}, {type: "null"}],
      description:
        "Departure time in 24-hour HH:mm, if shown on the ticket.",
    },
    endDate: {
      anyOf: [{type: "string"}, {type: "null"}],
      description:
        "Arrival or return date in ISO 8601 (YYYY-MM-DD), if shown (e.g. " +
        "a round-trip or multi-day ticket). Null if not shown.",
    },
    endTime: {
      anyOf: [{type: "string"}, {type: "null"}],
      description: "Arrival time in 24-hour HH:mm, if shown on the ticket.",
    },
    confidence: {
      type: "number",
      description:
        "Overall confidence in this extraction, from 0 (no confidence) " +
        "to 1 (fully confident).",
    },
    notes: {
      anyOf: [{type: "string"}, {type: "null"}],
      description:
        "Any ambiguity or assumption worth flagging to the user, in " +
        "English. Null if none.",
    },
  },
  required: [
    "isTicket", "transport", "departureCity", "departureCityKorean",
    "departureCountry", "destinationCity", "destinationCityKorean",
    "destinationCountry", "startDate", "startTime",
    "endDate", "endTime", "confidence", "notes",
  ],
  additionalProperties: false,
};

const TICKET_EXTRACTION_SYSTEM_PROMPT =
  "You extract structured trip data from a single photo of a public " +
  "transportation ticket or boarding pass. Tickets may be for a bus, " +
  "train, or airplane, from any country, in any language, and in any " +
  "layout (printed, mobile screenshot, or handwritten). Read the whole " +
  "image carefully, including small print, before answering. If the " +
  "image is not a recognizable ticket, set isTicket to false and leave " +
  "the other fields null except confidence (0) and notes (briefly why). " +
  "Never guess a date or city you cannot actually read on the ticket — " +
  "use null instead of fabricating a value. If the ticket shows a " +
  "3-letter IATA airport code (e.g. ICN, GMP, NRT, HND, CDG), report " +
  "the city where THAT SPECIFIC airport is physically located, not a " +
  "broader metro-area label that may be printed next to it for " +
  "marketing purposes — e.g. report 'Incheon' for ICN even if the " +
  "ticket prints 'Seoul' next to it (Gimpo/GMP is the airport actually " +
  "in Seoul), and 'Narita' for NRT rather than 'Tokyo' (Haneda/HND is " +
  "the airport actually in Tokyo). If the departure or destination is " +
  "printed as a bus terminal or train station name rather than a plain " +
  "city name (e.g. a specific terminal brand name, or a station name " +
  "with a suffix like '역'/'Station'/'터미널'/'Terminal'), report the " +
  "city that terminal or station is located in, not the terminal/" +
  "station's own name — e.g. report '서울' (not '센트럴시티' or " +
  "'서울역') and '대구' (not '동대구터미널' or '동대구역'). If none of " +
  "the above apply, use the city name as printed. Only extract " +
  "itinerary fields: transport " +
  "type, departure/destination city and country, and start/end date " +
  "and time. Do not extract, return, infer, or repeat the passenger's " +
  "name, passport number, ticket/booking number, seat number, " +
  "barcode/QR contents, date of birth, payment details, or any other " +
  "personal identifier, even if visible in the image — ignore that " +
  "information entirely.";

const ALLOWED_TICKET_IMAGE_MEDIA_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
] as const;

type TicketImageMediaType = typeof ALLOWED_TICKET_IMAGE_MEDIA_TYPES[number];

// ~5MB of base64 (roughly 3.7MB original image) — comfortably under the
// callable function's 10MB request-body limit while still allowing a
// reasonably high-resolution photo.
const MAX_TICKET_IMAGE_BASE64_LENGTH = 5 * 1024 * 1024;

function isTicketImageMediaType(value: string): value is TicketImageMediaType {
  return (ALLOWED_TICKET_IMAGE_MEDIA_TYPES as readonly string[]).includes(value);
}

export const parseTicketImage = onCall(
  {secrets: [anthropicApiKey]},
  async (request): Promise<{ result: TicketExtraction }> => {
    const imageBase64 = (request.data?.imageBase64 ?? "") as string;
    const mimeType = (request.data?.mimeType ?? "") as string;

    if (!imageBase64) {
      throw new HttpsError("invalid-argument", "imageBase64 is required");
    }
    if (!isTicketImageMediaType(mimeType)) {
      throw new HttpsError(
        "invalid-argument",
        `mimeType must be one of: ${ALLOWED_TICKET_IMAGE_MEDIA_TYPES.join(", ")}`
      );
    }
    if (imageBase64.length > MAX_TICKET_IMAGE_BASE64_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        "Image is too large; please resize before uploading"
      );
    }

    const client = new Anthropic({apiKey: anthropicApiKey.value()});

    let response;
    try {
      response = await client.messages.create({
        model: "claude-sonnet-5",
        max_tokens: 2048,
        // 정해진 스키마로 이미지 한 장을 읽어 채우는, 다단계 추론이 필요 없는 작업이라
        // thinking을 끄고 effort를 낮춰 토큰 사용량을 줄인다. (특정 티켓 형식에서
        // 정확도가 떨어지면 가장 먼저 되돌려볼 지점이기도 하다.)
        thinking: {type: "disabled"},
        system: TICKET_EXTRACTION_SYSTEM_PROMPT,
        messages: [{
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: mimeType,
                data: imageBase64,
              },
            },
            {
              type: "text",
              text: "Extract the trip data from this ticket photo.",
            },
          ],
        }],
        output_config: {
          format: {type: "json_schema", schema: TICKET_EXTRACTION_SCHEMA},
          effort: "low",
        },
      });
    } catch (error) {
      console.error("parseTicketImage: Claude request failed", error);
      throw new HttpsError("internal", "Failed to reach the extraction model");
    }

    if (response.stop_reason === "refusal") {
      throw new HttpsError(
        "failed-precondition",
        "The model declined to process this image"
      );
    }

    const textBlock = response.content.find((block) => block.type === "text");
    if (!textBlock || textBlock.type !== "text") {
      throw new HttpsError("internal", "No structured result returned");
    }

    let result: TicketExtraction;
    try {
      result = JSON.parse(textBlock.text) as TicketExtraction;
    } catch (error) {
      console.error("parseTicketImage: failed to parse model output", error);
      throw new HttpsError("internal", "Failed to parse extraction result");
    }

    console.log("parseTicketImage: extraction result", redactPotentialPIIForLogging(result));

    return {result};
  }
);

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

export const cityPhotoProxy = onRequest(async (request, response) => {
  // onRequest는 onCall과 달리 App Check를 자동으로 강제하지 않아, 헤더의
  // App Check 토큰을 직접 검증한다. 이 값은 앱(Kingfisher 요청 수정자)이
  // 붙여 보내며, 앱을 거치지 않은 요청(curl 등)은 토큰 자체가 없거나
  // 위조가 불가능해 여기서 걸러진다.
  const appCheckToken = request.header("X-Firebase-AppCheck");
  if (!appCheckToken) {
    response.status(401).send("Missing App Check token");
    return;
  }
  try {
    await admin.appCheck().verifyToken(appCheckToken);
  } catch {
    response.status(401).send("Invalid App Check token");
    return;
  }

  const photoReference = String(request.query.photoReference ?? "").trim();
  const apiKey = process.env.GOOGLE_API_KEY;

  if (!photoReference) {
    response.status(400).send("Missing photoReference");
    return;
  }

  if (!apiKey) {
    response.status(500).send("GOOGLE_API_KEY is not set");
    return;
  }

  try {
    const photoResponse = await axios.get(
      "https://maps.googleapis.com/maps/api/place/photo",
      {
        params: {
          maxwidth: 1200,
          photo_reference: photoReference,
          key: apiKey,
        },
        responseType: "stream",
        validateStatus: (status) => status >= 200 && status < 400,
      }
    );

    const contentType = photoResponse.headers["content-type"];
    const cacheControl = photoResponse.headers["cache-control"] || "public, max-age=604800";

    if (contentType) {
      response.setHeader("Content-Type", contentType);
    }
    response.setHeader("Cache-Control", cacheControl);

    photoResponse.data.pipe(response);
  } catch (error: any) {
    const status = error?.response?.status ?? 502;
    response.status(status).send("Failed to fetch city image");
  }
});

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
