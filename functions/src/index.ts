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
import {onCall} from "firebase-functions/v2/https";
import axios from "axios";

admin.initializeApp();
const db = admin.firestore();

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

function isKorean(text: string) {
  return /[가-힣]/.test(text);
}

function normalize(s: string) {
  return s.trim().toLowerCase();
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

  return Array.from(map.values()).slice(0, limit);
}

async function getOrCreateCityByPlaceId(placeId: string, apiKey: string, language: string): Promise<CityDoc | null> {
  const ref = db.collection("cities").doc(placeId);
  const snap = await ref.get();
  if (snap.exists) return snap.data() as CityDoc;

  // Details
  const detailsRes = await axios.get(
    "https://maps.googleapis.com/maps/api/place/details/json",
    {
      params: {
        place_id: placeId,
        key: apiKey,
        language,
        fields: "name,geometry,photos,address_components,types",
      },
    }
  );

  if (detailsRes.data.status !== "OK") return null;

  const details = detailsRes.data.result;
  const types = details.types || [];

  // 도시 타입 검증
  const name = details.name ?? "";
  const countryComponent = (details.address_components || []).find((c: any) =>
    (c.types || []).includes("country")
  );
  const country = countryComponent?.long_name ?? "알 수 없음";

  let isValidCity = false;

  if (country === "대한민국") {
  // 한국 전용 정책
    isValidCity =
    types.includes("locality") ||
    types.includes("administrative_area_level_1") ||
    (
      types.includes("administrative_area_level_2") &&
      name.endsWith("군")
    );
  } else {
  // 해외 일반화 정책
    isValidCity =
    types.includes("locality") ||
    types.includes("administrative_area_level_1");
  }

  if (!isValidCity) return null;

  // types에 locality/administrative_area_level_1 등이 섞여 들어올 수 있음
  // "도시"로 다루는 범위를 넓히려면 types 검증을 너무 빡세게 하지 않는 게 안정적임.
  const lat = details.geometry?.location?.lat;
  const lng = details.geometry?.location?.lng;
  if (typeof lat !== "number" || typeof lng !== "number") return null;


  let imageUrl: string | null = null;
  if (details.photos && details.photos.length > 0) {
    const photoRef = details.photos[0].photo_reference;
    imageUrl =
      "https://maps.googleapis.com/maps/api/place/photo" +
      `?maxwidth=800&photo_reference=${photoRef}&key=${apiKey}`;
  }

  const doc: CityDoc = {
    cityId: placeId,
    name,
    country,
    nameLower: normalize(name),
    countryLower: normalize(country),
    lat,
    lng,
    imageUrl,
    updatedAt: Date.now(),
    popularityCount: 0,
  };

  await ref.set(doc, {merge: true});
  return doc;
}

export const searchCity = onCall(async (request) => {
  const queryRaw = (request.data?.query ?? "") as string;
  const language = ((request.data?.language ?? "ko") as string) || "ko";
  const limit = Math.min(Math.max(Number(request.data?.limit ?? 10), 1), 20);

  const query = queryRaw.trim();
  if (!query) {
    return {cities: [] as CityDoc[], source: "empty"};
  }

  const apiKey = process.env.GOOGLE_API_KEY;
  if (!apiKey) {
    throw new Error("GOOGLE_API_KEY is not set");
  }

  const lower = normalize(query);

  // 1) Firestore prefix cache first (always)
  const cached = await prefixSearchCities(lower, limit);

  // 1글자 입력은 Google 호출 금지 (비용/오염 방어)
  if (lower.length < 2) {
    return {cities: cached, source: "cache-only"};
  }

  // 캐시가 충분하면 Google 호출하지 않음
  if (cached.length > 0) {
    return {cities: cached.slice(0, limit)};
  }

  let searchText = query;

  if (isKorean(query) &&
    !query.endsWith("시") &&
    !query.endsWith("군") &&
    !query.endsWith("구")) {
    searchText += " 시"; // "서울" -> "서울 시" (Google 검색 최적화)
  }

  // Google FindPlace (딱 1회)
  const findRes = await axios.get(
    "https://maps.googleapis.com/maps/api/place/findplacefromtext/json",
    {
      params: {
        input: searchText,
        inputtype: "textquery",
        fields: "place_id",
        language,
        key: apiKey,
        ...(isKorean(query) ?
          {components: "country:kr"} :
          {}),
      },
    }
  );

  const status = findRes.data?.status;
  const candidate = findRes.data?.candidates?.[0];

  if (status !== "OK" || !candidate?.place_id) {
    // Google 실패해도 캐시 결과는 반환
    return {cities: cached, source: "cache-google-empty", debug: {status}};
  }

  // 읍/면/동은 Details 호출 전에 차단
  const desc =
    candidate.formatted_address ??
    candidate.name ??
    "";

  if (
    desc.includes("읍") ||
    desc.includes("면") ||
    desc.includes("동")
  ) {
    return {cities: []};
  }

  const city = await getOrCreateCityByPlaceId(
    candidate.place_id,
    apiKey,
    language
  );

  if (!city) {
    return {cities: cached.slice(0, limit)};
  }

  // prefix + 정확매칭 1개 합치기
  const merged = [
    city,
    ...cached.filter((c) => c.cityId !== city.cityId),
  ];

  return {
    cities: merged.slice(0, limit),
  };
});

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

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
