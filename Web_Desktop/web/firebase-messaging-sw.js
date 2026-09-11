importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');
firebase.initializeApp({ apiKey: "stub", projectId: "auristv" });
try { const m = firebase.messaging(); } catch (_) {}
self.addEventListener('push', function(){});
