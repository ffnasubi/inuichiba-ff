const { onRequest } = require("firebase-functions/v2/https");

exports.helloWorld = onRequest(
  { region: "asia-northeast1" },
  (req, res) => {
    res.send("Hello from Firebase (asia-northeast1)!");
  }
);
