<script setup>
import { ref, onUnmounted } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { Sqlite } from "../lune.js";

// ---- state ----
const db = ref(null);
const status = ref("closed"); // closed | open | error
const statusMsg = ref("");

// create table form
const createSql = ref(
  "CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY AUTOINCREMENT, body TEXT, created_at TEXT)"
);
const createResult = ref(null);

// insert form
const insertBody = ref("Hello from Lune!");
const insertResult = ref(null);

// query form
const querySql = ref("SELECT * FROM notes ORDER BY id DESC");
const queryRows = ref(null);

// exec form
const execSql = ref("DELETE FROM notes WHERE id = 1");
const execResult = ref(null);

// ---- helpers ----
function fmt(obj) {
  return JSON.stringify(obj, null, 2);
}

// ---- open / close ----
async function openDb() {
  try {
    db.value = await Sqlite.open(":memory:");
    status.value = "open";
    statusMsg.value = `handle: ${db.value}`;
  } catch (err) {
    status.value = "error";
    statusMsg.value = err.message || String(err);
  }
}

async function closeDb() {
  if (!db.value) return;
  await Sqlite.close(db.value);
  db.value = null;
  status.value = "closed";
  statusMsg.value = "";
  createResult.value = null;
  insertResult.value = null;
  queryRows.value = null;
  execResult.value = null;
}

onUnmounted(() => {
  if (db.value) Sqlite.close(db.value).catch(() => { });
});

// ---- exec (create table) ----
async function runCreate() {
  if (!db.value) return;
  try {
    createResult.value = await Sqlite.exec(db.value, createSql.value, []);
  } catch (err) {
    createResult.value = { error: err.message || String(err) };
  }
}

// ---- insert ----
async function runInsert() {
  if (!db.value) return;
  const now = new Date().toISOString();
  try {
    insertResult.value = await Sqlite.exec(
      db.value,
      "INSERT INTO notes (body, created_at) VALUES (?, ?)",
      [insertBody.value, now]
    );
  } catch (err) {
    insertResult.value = { error: err.message || String(err) };
  }
}

// ---- query ----
async function runQuery() {
  if (!db.value) return;
  try {
    queryRows.value = await Sqlite.query(db.value, querySql.value, []);
  } catch (err) {
    queryRows.value = [{ error: err.message || String(err) }];
  }
}

// ---- arbitrary exec ----
async function runExec() {
  if (!db.value) return;
  try {
    execResult.value = await Sqlite.exec(db.value, execSql.value, []);
  } catch (err) {
    execResult.value = { error: err.message || String(err) };
  }
}
</script>

<template>
  <SectionHead eyebrow="Database" title="SQLite">
    <template #desc>
      Embedded SQLite database access. Open a handle with
      <code>Sqlite.open</code>, run statements with
      <code>Sqlite.exec</code>, and fetch rows with
      <code>Sqlite.query</code>. This demo uses an in-memory database.
    </template>
  </SectionHead>

  <div class="card-grid">
    <!-- Open / Close -->
    <div class="card">
      <span class="card-label">Connection</span>

      <div class="status-row">
        <span class="dot" :class="status"></span>
        <span class="status-text">{{ status }}</span>
        <span v-if="statusMsg" class="handle">{{ statusMsg }}</span>
      </div>

      <div class="btn-row">
        <button class="primary" :disabled="!!db" @click="openDb">Open :memory:</button>
        <button class="danger" :disabled="!db" @click="closeDb">Close</button>
      </div>
    </div>

    <!-- Create table -->
    <div class="card">
      <span class="card-label">Sqlite.exec — create table</span>
      <textarea v-model="createSql" :disabled="!db" rows="3" />
      <button class="primary" :disabled="!db" @click="runCreate">Run</button>
      <pre v-if="createResult !== null" class="result-pre" :class="{ err: createResult.error }">{{ fmt(createResult) }}
    </pre>
    </div>

    <!-- Insert -->
    <div class="card">
      <span class="card-label">Sqlite.exec — insert</span>
      <div class="field-row">
        <label class="field-label">Body</label>
        <input v-model="insertBody" :disabled="!db" type="text" />
      </div>
      <button class="primary" :disabled="!db" @click="runInsert">Insert</button>
      <pre v-if="insertResult !== null" class="result-pre" :class="{ err: insertResult.error }">{{ fmt(insertResult) }}
    </pre>
    </div>

    <!-- Query -->
    <div class="card">
      <span class="card-label">Sqlite.query — select rows</span>
      <textarea v-model="querySql" :disabled="!db" rows="2" />
      <button class="primary" :disabled="!db" @click="runQuery">Query</button>
      <template v-if="queryRows !== null">
        <div v-if="!queryRows.length" class="log-empty">No rows.</div>
        <div v-else class="table-wrap">
          <table>
            <thead>
              <tr>
                <th v-for="col in Object.keys(queryRows[0])" :key="col">{{ col }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, i) in queryRows" :key="i">
                <td v-for="col in Object.keys(queryRows[0])" :key="col">{{ row[col] ?? 'NULL' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </div>

    <!-- Arbitrary exec -->
    <div class="card">
      <span class="card-label">Sqlite.exec — arbitrary statement</span>
      <textarea v-model="execSql" :disabled="!db" rows="2" />
      <button class="primary" :disabled="!db" @click="runExec">Run</button>
      <pre v-if="execResult !== null" class="result-pre" :class="{ err: execResult.error }">{{ fmt(execResult) }}</pre>
    </div>
  </div>
</template>

<style scoped>
.status-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
  font-size: 0.85em;
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 99px;
  flex-shrink: 0;
}

.dot.open {
  background: var(--ok, #34d399);
  box-shadow: 0 0 6px rgba(52, 211, 153, 0.6);
}

.dot.closed {
  background: var(--muted, #64748b);
}

.dot.error {
  background: var(--err, #f87171);
}

.status-text {
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-size: 0.78em;
  color: var(--muted);
}

.handle {
  font-family: var(--font-mono);
  font-size: 0.78em;
  color: var(--muted);
  word-break: break-all;
}

.btn-row {
  display: flex;
  gap: 0.6rem;
}

.field-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.field-label {
  font-size: 0.78em;
  font-weight: 600;
  letter-spacing: 0.04em;
  color: var(--muted);
  text-transform: uppercase;
  width: 3.5rem;
  flex-shrink: 0;
}

textarea {
  width: 100%;
  resize: vertical;
  font-family: var(--font-mono);
  font-size: 0.82em;
  background: rgba(0, 0, 0, 0.2);
  border: 1px solid var(--border);
  border-radius: 4px;
  color: inherit;
  padding: 0.4rem 0.6rem;
  margin-bottom: 0.5rem;
}

.result-pre {
  margin-top: 0.65rem;
  padding: 0.5rem 0.65rem;
  background: rgba(0, 0, 0, 0.25);
  border: 1px solid var(--border);
  border-radius: 6px;
  font-family: var(--font-mono);
  font-size: 0.8em;
  white-space: pre-wrap;
  word-break: break-all;
  max-height: 180px;
  overflow-y: auto;
}

.result-pre.err {
  border-color: var(--err, #f87171);
  color: var(--err, #f87171);
}

.table-wrap {
  margin-top: 0.65rem;
  overflow-x: auto;
  border: 1px solid var(--border);
  border-radius: 6px;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.82em;
  font-family: var(--font-mono);
}

th,
td {
  padding: 0.3rem 0.6rem;
  text-align: left;
  border-bottom: 1px solid var(--border);
  white-space: nowrap;
}

th {
  background: rgba(255, 255, 255, 0.04);
  font-weight: 700;
  letter-spacing: 0.05em;
  font-size: 0.9em;
  color: var(--muted);
}

tr:last-child td {
  border-bottom: none;
}

.log-empty {
  margin-top: 0.5rem;
  font-size: 0.82em;
  color: var(--muted);
  font-style: italic;
}
</style>
