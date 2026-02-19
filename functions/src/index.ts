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

export const searchCity = onCall(async (request) => {
  try {
    const query = request.data.query;

    if (!query) {
      throw new Error("Query is required");
    }

    const apiKey = process.env.GOOGLE_API_KEY;

    if (!apiKey) {
      throw new Error("GOOGLE_API_KEY is not set");
    }

    const docId = query.toLowerCase();
    const cityRef = db.collection("cities").doc(docId);
    const snapshot = await cityRef.get();

    // 캐시 존재
    if (snapshot.exists) {
      return snapshot.data();
    }

    // Google Text Search
    const textSearchRes = await axios.get(
      "https://maps.googleapis.com/maps/api/place/textsearch/json",
      {
        params: {
          query: query,
          // type: "locality",
          key: apiKey,
          language: "en",
        },
      }
    );

    const place = textSearchRes.data.results[0];
    if (!place) {
      return {
        error: "City not found",
        debug: textSearchRes.data,
      };
    }

    const placeId = place.place_id;

    // Place Details
    const detailsRes = await axios.get(
      "https://maps.googleapis.com/maps/api/place/details/json",
      {
        params: {
          place_id: placeId,
          key: apiKey,
          language: "ko",
          fields: "name,geometry,photos,address_components",
        },
      }
    );

    const details = detailsRes.data.result;

    const lat = details.geometry.location.lat;
    const lng = details.geometry.location.lng;

    const countryComponent = details.address_components.find(
      (c: any) => c.types.includes("country")
    );

    const city = details.name;

    const country = countryComponent?.long_name ?? "알 수 없음";

    // 사진 URL 생성
    let imageUrl = null;
    if (details.photos && details.photos.length > 0) {
      const photoRef = details.photos[0].photo_reference;
      imageUrl =
        "https://maps.googleapis.com/maps/api/place/photo" +
        `?maxwidth=800&photo_reference=${photoRef}&key=${apiKey}`;
    }

    const newCity = {
      cityId: docId,
      name: city,
      country: country,
      lat,
      lng,
      imageUrl,
      updatedAt: Date.now(),
    };

    await cityRef.set(newCity);

    return newCity;
  } catch (error) {
    console.error("Error searching city:", error);
    throw new Error("Failed to search city");
  }
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
