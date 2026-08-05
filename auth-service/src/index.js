const express = require("express");

const app = express();

const API_KEY = "my-secret-key";

app.get("/auth", (req, res) => {
  const apiKey = req.header("X-API-Key");

  if (apiKey !== API_KEY) {
    return res.status(401).send("Unauthorized");
  }

  res.sendStatus(200);
});

app.listen(3000, () => {
  console.log("Auth service listening on port 3000");
});
