importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDS4LeXCm2Zh8_1ZoMD_NPDR8jDsIGx3OA",
  authDomain: "datingly-21f22.firebaseapp.com",
  projectId: "datingly-21f22",
  storageBucket: "datingly-21f22.firebasestorage.app",
  messagingSenderId: "914406975641",
  appId: "1:914406975641:web:d65606827be663a2fc7008",
  measurementId: "G-TNB191Y1H1"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  console.log("[firebase-messaging-sw.js] Background message:", message);
});
