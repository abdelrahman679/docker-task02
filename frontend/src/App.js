import React, { useState } from "react";
import logo from "./logo.svg";
import "./App.css";

function App() {
  // ---------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------
  // One state variable per form field, plus a `status` object used to show
  // success/error feedback to the user after Insert/Get actions.
  const [id, setId] = useState("");
  const [firstname, setFirstname] = useState("");
  const [lastname, setLastname] = useState("");
  const [status, setStatus] = useState(null); // { type: "success" | "error", text: string }

  // ---------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------
  // Small helper reused by both validators below.
  const isPresent = (value) => value !== undefined && value !== null && value.trim() !== "";

  // Validates all three fields before an Insert call.
  function validateInsertInput() {
    if (!isPresent(id)) return "ID is required";
    if (!isPresent(firstname)) return "First Name is required";
    if (!isPresent(lastname)) return "Last Name is required";
    return null; // null means "no error"
  }

  // Validates only the ID field before a Get call.
  function validateGetInput() {
    if (!isPresent(id)) return "ID is required";
    return null;
  }

  // ---------------------------------------------------------------------
  // API CALLS
  // ---------------------------------------------------------------------
  // Calls the backend Insert endpoint. Kept separate from the click handler
  // so the HTTP concern is isolated from the validation/UI concern.
  async function insertPerson(personId, personFirstname, personLastname) {
    const response = await fetch("/api/person", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        id: personId,
        firstname: personFirstname,
        lastname: personLastname,
      }),
    });
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.message || "Failed to insert person");
    }
    return data;
  }

  // Calls the backend Get endpoint for a given id.
  async function getPerson(personId) {
    const response = await fetch(`/api/person/${encodeURIComponent(personId)}`);
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.message || "Failed to fetch person");
    }
    return data;
  }

  // ---------------------------------------------------------------------
  // EVENT HANDLERS
  // ---------------------------------------------------------------------
  async function handleInsert() {
    const validationError = validateInsertInput();
    if (validationError) {
      setStatus({ type: "error", text: validationError });
      return;
    }

    try {
      await insertPerson(id, firstname, lastname);
      setStatus({ type: "success", text: `Person '${id}' inserted successfully` });
    } catch (err) {
      setStatus({ type: "error", text: err.message });
    }
  }

  async function handleGet() {
    const validationError = validateGetInput();
    if (validationError) {
      setStatus({ type: "error", text: validationError });
      return;
    }

    try {
      const data = await getPerson(id);
      // Populate the First Name / Last Name fields from the returned record.
      setFirstname(data.person.firstname);
      setLastname(data.person.lastname);
      setStatus({ type: "success", text: `Person '${id}' found` });
    } catch (err) {
      setStatus({ type: "error", text: err.message });
    }
  }

  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />

        <div style={{ display: "flex", flexDirection: "column", gap: "8px", minWidth: "260px" }}>
          <label>
            ID
            <input
              type="text"
              value={id}
              onChange={(e) => setId(e.target.value)}
            />
          </label>
          <label>
            First Name
            <input
              type="text"
              value={firstname}
              onChange={(e) => setFirstname(e.target.value)}
            />
          </label>
          <label>
            Last Name
            <input
              type="text"
              value={lastname}
              onChange={(e) => setLastname(e.target.value)}
            />
          </label>

          <div style={{ display: "flex", gap: "8px" }}>
            <button onClick={handleInsert}>Insert</button>
            <button onClick={handleGet}>Get</button>
          </div>

          {status && (
            <p style={{ color: status.type === "error" ? "red" : "lightgreen" }}>
              {status.text}
            </p>
          )}
        </div>

        <p>
          Edit <code>src/App.js</code> and save to reload.
        </p>
        <a
          className="App-link"
          href="https://reactjs.org"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn React
        </a>
      </header>
    </div>
  );
}

export default App;
