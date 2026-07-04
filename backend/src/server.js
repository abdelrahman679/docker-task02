// simple node web server that displays hello world
// optimized for Docker image

const express = require("express");
// this example uses express web framework so we know what longer build times
// do and how Dockerfile layer ordering matters. If you mess up Dockerfile ordering
// you'll see long build times on every code change + build. If done correctly,
// code changes should be only a few seconds to build locally due to build cache.

const morgan = require("morgan");
// morgan provides easy logging for express, and by default it logs to stdout
// which is a best practice in Docker. Friends don't let friends code their apps to
// do app logging to files in containers.
const promBundle = require("express-prom-bundle");
const promClient = require("prom-client");

const database = require("./database");
// `database` is the existing MariaDB connection/query client used by the app
// (it already exposes a `.raw(sql, params)` method, as seen in the /healthz
// route below). We reuse this exact same client for the new CRUD endpoints
// instead of creating a second connection.

// Appi
const app = express();

app.use(morgan("common"));
app.use(
  promBundle({
    includeMethod: true,
    includePath: true,
    includeStatusCode: true,
    promClient: {
      collectDefaultMetrics: {},
    },
  })
);

// express.json() is required so req.body is populated for our POST /person
// endpoint. Without this, req.body would be undefined for JSON payloads.
app.use(express.json());

/**
 * ---------------------------------------------------------------------------
 * DATABASE INITIALIZATION
 * ---------------------------------------------------------------------------
 * Creates the `person` table if it does not already exist. This runs once,
 * when the server process starts (see the call at the bottom of this file).
 *
 * Columns:
 *   - id        : primary key, supplied by the client (not auto-increment,
 *                 since the requirement is for the caller to provide an id)
 *   - firstname : required
 *   - lastname  : required
 */
async function initDatabase() {
  const createTableSql = `
    CREATE TABLE IF NOT EXISTS person (
      id        VARCHAR(255) NOT NULL,
      firstname VARCHAR(255) NOT NULL,
      lastname  VARCHAR(255) NOT NULL,
      PRIMARY KEY (id)
    )
  `;
  await database.raw(createTableSql);
  console.log("person table is ready");
}

/**
 * ---------------------------------------------------------------------------
 * VALIDATION
 * ---------------------------------------------------------------------------
 * Small, single-purpose validation functions so each requirement has its own
 * function (per the "make separate function for every requirement" ask).
 */

// Returns true only for a non-null, non-empty (after trimming) string/value.
function isPresent(value) {
  return value !== undefined && value !== null && String(value).trim() !== "";
}

// Validates the body used to insert a person. Returns { valid, error }.
function validateInsertPersonInput(body) {
  if (!body) {
    return { valid: false, error: "Request body is required" };
  }
  const { id, firstname, lastname } = body;

  if (!isPresent(id)) {
    return { valid: false, error: "id must not be null or empty" };
  }
  if (!isPresent(firstname)) {
    return { valid: false, error: "firstname must not be null or empty" };
  }
  if (!isPresent(lastname)) {
    return { valid: false, error: "lastname must not be null or empty" };
  }
  return { valid: true, error: null };
}

// Validates the id used to fetch a person. Returns { valid, error }.
function validateGetPersonInput(id) {
  if (!isPresent(id)) {
    return { valid: false, error: "id must not be null or empty" };
  }
  return { valid: true, error: null };
}

/**
 * ---------------------------------------------------------------------------
 * DATA ACCESS FUNCTIONS
 * ---------------------------------------------------------------------------
 * These wrap the SQL so the route handlers stay focused on HTTP concerns.
 * All queries are parameterized (using ? placeholders) to prevent SQL
 * injection - the values are never concatenated into the query string.
 */

// Inserts a single person row. Throws if the query fails (e.g. duplicate id).
async function insertPersonRecord(id, firstname, lastname) {
  const insertSql = "INSERT INTO person (id, firstname, lastname) VALUES (?, ?, ?)";
  await database.raw(insertSql, [id, firstname, lastname]);
}

// Looks up a single person by id. Returns the row object, or null if not found.
async function findPersonById(id) {
  const selectSql = "SELECT id, firstname, lastname FROM person WHERE id = ?";
  const [rows] = await database.raw(selectSql, [id]);
  return rows && rows.length > 0 ? rows[0] : null;
}

/**
 * ---------------------------------------------------------------------------
 * API ENDPOINTS
 * ---------------------------------------------------------------------------
 */

// POST /person  { id, firstname, lastname } -> insert a new person
app.post("/person", function (req, res, next) {
  const { valid, error } = validateInsertPersonInput(req.body);
  if (!valid) {
    return res.status(400).json({ message: error });
  }

  const { id, firstname, lastname } = req.body;

  insertPersonRecord(id, firstname, lastname)
    .then(() => {
      res.status(201).json({ message: "Person inserted successfully", person: { id, firstname, lastname } });
    })
    .catch((err) => {
      // A duplicate primary key (id already exists) is the most likely
      // expected failure here, so give it a friendlier message.
      if (err && err.code === "ER_DUP_ENTRY") {
        return res.status(409).json({ message: `Person with id '${id}' already exists` });
      }
      next(err);
    });
});

// GET /person/:id -> fetch a person by id
app.get("/person/:id", function (req, res, next) {
  const { id } = req.params;

  const { valid, error } = validateGetPersonInput(id);
  if (!valid) {
    return res.status(400).json({ message: error });
  }

  findPersonById(id)
    .then((person) => {
      if (!person) {
        return res.status(404).json({ message: "Person not found" });
      }
      res.json({ person });
    })
    .catch(next);
});

app.get("/healthz", function(req, res, next) {
  database.raw('select VERSION() version')
    .then(([rows, columns]) => rows[0])
    .then((row) => res.json({ message: `Hello from MySQLlllll ${row.version}` }))
    .catch(next);
});

app.get("/", function(req, res) {
  // do app logic here to determine if app is truly healthy
  // you should return 200 if healthy, and anything else will fail
  // if you want, you should be able to restrict this to localhost (include ipv4 and ipv6)
  res.send("I am happy and healthyyyyy\n");
});

// Create the person table on startup. We log a failure but still export the
// app - the existing /healthz route already reports DB connectivity issues.
initDatabase().catch((err) => {
  console.error("Failed to initialize database:", err);
});

module.exports = app;
