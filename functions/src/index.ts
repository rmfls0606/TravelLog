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

function normalizeCityName(name: string): string {
  return name
    .toLowerCase()
    .replace(/^city of /, "")
    .replace(/ city$/, "")
    .replace(/-si$/, "")
    .replace(/^시티 오브 /, "")
    .replace(/시$/, "")
    .replace(/군$/, "")
    .replace(/구$/, "")
    .trim();
}

function isSubCitySuffixQuery(q: string): boolean {
  const s = q.trim();
  // "강진읍", "OO면", "OO동" 같은 '행정동/읍면'만 차단
  return /(읍|면|동)$/.test(s);
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

  const merged = Array.from(map.values());
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
        components: "country:kr",
        key: apiKey,
      },
    }
  );

  if (res.data?.status !== "OK") return null;

  const predictions = res.data?.predictions ?? [];
  if (predictions.length === 0) return null;

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

  return scored[0]?.prediction?.place_id ?? null;
}

async function getOrCreateCityByPlaceId(
  placeId: string,
  apiKey: string,
  query: string
): Promise<CityDoc | null> {
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

  if (detailsRes.data?.status !== "OK") return null;

  const details = detailsRes.data.result;
  const name = details.name ?? "";
  const types: string[] = details.types || [];

  // 🔥 대한민국만 허용
  const countryComponent = (details.address_components || []).find((c: any) =>
    (c.types || []).includes("country")
  );

  if (!countryComponent || countryComponent.long_name !== "대한민국") {
    return null;
  }

  // 🔥 읍/면/동/리 차단
  if (/(읍|면|동|리)$/.test(name)) {
    return null;
  }

  // 🔥 한국 행정 단위 허용 범위
  const isAllowedAdmin =
    types.includes("locality") ||
    types.includes("administrative_area_level_1") || // 도
    types.includes("administrative_area_level_2"); // 시/군/구

  if (!isAllowedAdmin) return null;

  // 🔥 이름 비교 (시/군/구 제거 후 비교)
  const input = normalizeCityName(query);
  const result = normalizeCityName(name);

  if (result !== input && !result.startsWith(input)) {
    return null;
  }

  const lat = details.geometry?.location?.lat;
  const lng = details.geometry?.location?.lng;
  if (typeof lat !== "number" || typeof lng !== "number") return null;

  let imageUrl: string | null = null;

  // 1️⃣ 도시 자체 photos 우선
  if (details.photos?.length > 0) {
    const bestPhoto = details.photos
      .sort((a: any, b: any) => (b.width ?? 0) - (a.width ?? 0))[0];

    const photoRef = bestPhoto.photo_reference;

    imageUrl =
      `https://maps.googleapis.com/maps/api/place/photo?maxwidth=1200&photo_reference=${photoRef}&key=${apiKey}`;
  }

  // 2️⃣ 도시 사진이 없으면 랜드마크 검색
  if (!imageUrl) {
    const landmarkRes = await axios.get(
      "https://maps.googleapis.com/maps/api/place/textsearch/json",
      {
        params: {
          query: `${name} 랜드마크`,
          region: "kr",
          language: "ko",
          key: apiKey,
        },
      }
    );

    if (landmarkRes.data?.status === "OK") {
      const landmark = landmarkRes.data.results?.find((r: any) =>
        r.types?.includes("tourist_attraction")
      );

      if (landmark?.photos?.length > 0) {
        const photoRef = landmark.photos[0].photo_reference;

        imageUrl =
          `https://maps.googleapis.com/maps/api/place/photo?maxwidth=1200&photo_reference=${photoRef}&key=${apiKey}`;
      }
    }
  }
  const doc: CityDoc = {
    cityId: placeId,
    name,
    country: "대한민국",
    nameLower: normalize(name),
    countryLower: "대한민국",
    lat,
    lng,
    imageUrl: imageUrl,
    updatedAt: Date.now(),
    popularityCount: 0,
  };

  await db.collection("cities").doc(placeId).set(doc, {merge: true});

  return doc;
}

export const searchCity = onCall(async (request) => {
  const queryRaw = (request.data?.query ?? "") as string;
  // const language = ((request.data?.language ?? "ko") as string) || "ko";
  const limit = Math.min(Math.max(Number(request.data?.limit ?? 10), 1), 20);

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

  // 1글자 입력은 Google 호출 금지 (비용/오염 방어)
  if (lower.length < 2) {
    return {cities: cached, source: "cache-only"};
  }

  // 캐시가 충분하면 Google 호출하지 않음
  if (cached.length > 0) {
    return {cities: cached.slice(0, limit)};
  }

  const placeId = await findPlaceSmart(query, apiKey);

  if (!placeId) {
    return {cities: [], source: "google-empty"};
  }

  const city = await getOrCreateCityByPlaceId(
    placeId,
    apiKey,
    query // 🔥 language 대신 query 넘긴다
  );

  if (!city) {
    return {cities: [], source: "filtered-out"};
  }

  return {
    cities: [city],
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
