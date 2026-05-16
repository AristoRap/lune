import api from "../lunejs/app/App.js";
import {
  quit,
  environment,
  screenInfo,
  clipboardRead,
  clipboardWrite,
  minimize,
  maximize,
  center,
  setTitle,
  setSize,
  openFile,
  openFiles,
  openDir,
  saveFile,
  messageInfo,
  messageWarning,
  messageError,
  messageQuestion,
  trayShow,
  trayHide,
  traySetMenu,
  notify,
  on,
  off,
  emit,
} from "../lunejs/runtime/runtime.js";

// ── sections ─────────────────────────────────────────────

const sections = [
  {
    id: "bindings",
    label: "Bindings",
    html: `
      <h2>Bindings</h2>
      <p class="desc">Crystal methods called from JavaScript via <code>@[Lune::Bind]</code>. Every call returns a <code>Promise</code>.</p>

      <div class="card">
        <div class="card-label">Greet</div>
        <div class="row">
          <input id="greet-in" type="text" placeholder="Your name…" />
          <button id="greet-btn" class="primary">Call</button>
        </div>
        <div class="result" id="greet-out"></div>
      </div>

      <div class="card">
        <div class="card-label">Reverse string</div>
        <div class="row">
          <input id="rev-in" type="text" placeholder="hello world" />
          <button id="rev-btn">Call</button>
        </div>
        <div class="result" id="rev-out"></div>
      </div>

      <div class="card">
        <div class="card-label">File info</div>
        <div class="row">
          <input id="fi-in" type="text" placeholder="/path/to/file" />
          <button id="fi-btn">Call</button>
        </div>
        <pre class="result mono" id="fi-out"></pre>
      </div>
    `,
    init(el) {
      el.querySelector("#greet-btn").addEventListener("click", async () => {
        const r = await api.Demo.Greet(el.querySelector("#greet-in").value);
        el.querySelector("#greet-out").textContent = r;
      });

      el.querySelector("#rev-btn").addEventListener("click", async () => {
        const r = await api.Demo.Reverse(el.querySelector("#rev-in").value);
        el.querySelector("#rev-out").textContent = r;
      });

      el.querySelector("#fi-btn").addEventListener("click", async () => {
        const raw = await api.Demo.FileInfo(el.querySelector("#fi-in").value);
        const data = JSON.parse(raw);
        el.querySelector("#fi-out").textContent = JSON.stringify(data, null, 2);
      });
    },
  },

  {
    id: "events",
    label: "Events",
    html: `
      <h2>Events</h2>
      <p class="desc">Bidirectional event bus — Crystal↔JavaScript via <code>app.emit</code> / <code>emit()</code>.</p>

      <div class="card">
        <div class="card-label">Live clock — Crystal → JS</div>
        <div class="clock" id="clock">—</div>
        <p class="hint">Crystal emits <code>"tick"</code> every second from a background fiber.</p>
      </div>

      <div class="card">
        <div class="card-label">Ping / Pong — JS → Crystal → JS</div>
        <div class="row">
          <input id="ping-in" type="text" value="hello" />
          <button id="ping-btn" class="primary">Ping</button>
        </div>
        <div class="log" id="pong-log"></div>
      </div>

      <div class="card">
        <div class="card-label">File progress — async binding + events</div>
        <button id="prog-btn">Pick files &amp; process</button>
        <div id="prog-wrap" style="display:none; flex-direction:column; gap:0.5rem">
          <div class="progress-track"><div id="prog-bar" class="progress-bar"></div></div>
          <p id="prog-label" class="hint"></p>
        </div>
      </div>

      <div class="card">
        <div class="card-label">File drop — scoped drop zones</div>
        <div class="drop-zone-grid">
          <div class="drop-target" style="--lune-drop-target: drop" id="drop-a">
            <span>Zone A</span>
            <span style="font-size:0.8em">Drop here</span>
          </div>
          <div class="drop-target drop-target--alt" style="--lune-drop-target: drop" id="drop-b">
            <span>Zone B</span>
            <span style="font-size:0.8em">Drop here</span>
          </div>
        </div>
        <div class="log" id="drop-log"><div class="log-empty">Dropped files appear here…</div></div>
      </div>
    `,
    init(el) {
      const tickH = (ts) => {
        el.querySelector("#clock").textContent = new Date(
          ts,
        ).toLocaleTimeString();
      };
      on("tick", tickH);

      const pongLog = el.querySelector("#pong-log");
      const pongH = (data) => {
        const d = document.createElement("div");
        d.className = "log-entry";
        d.textContent = `← pong: ${JSON.stringify(data)}`;
        pongLog.prepend(d);
      };
      on("pong", pongH);

      el.querySelector("#ping-btn").addEventListener("click", async () => {
        const v = el.querySelector("#ping-in").value;
        const d = document.createElement("div");
        d.className = "log-entry out";
        d.textContent = `→ ping: ${JSON.stringify(v)}`;
        pongLog.prepend(d);
        await emit("ping", v);
      });

      const progWrap = el.querySelector("#prog-wrap");
      const progBar = el.querySelector("#prog-bar");
      const progLabel = el.querySelector("#prog-label");

      const progH = ({ done, total, name }) => {
        progWrap.style.display = "flex";
        progBar.style.width = `${(done / total) * 100}%`;
        progLabel.textContent = `${done}/${total} — ${name}`;
      };
      on("fileProgress", progH);

      el.querySelector("#prog-btn").addEventListener("click", async () => {
        const paths = await openFiles("Select files to process");
        if (!paths.length) return;
        progWrap.style.display = "none";
        progBar.style.width = "0%";
        await api.Demo.ProcessFiles(paths);
      });

      const dropLog = el.querySelector("#drop-log");

      const dropH = ({ x, y, paths }) => {
        dropLog.querySelector(".log-empty")?.remove();
        const hit = document.elementFromPoint(x, y);
        const zone = hit?.closest("#drop-b") ? "B" : "A";
        paths.forEach((p) => {
          const d = document.createElement("div");
          d.className = "log-entry";
          d.textContent = `[Zone ${zone}] ${p}`;
          dropLog.prepend(d);
        });
      };
      on("fileDrop", dropH);

      return () => {
        off("tick", tickH);
        off("pong", pongH);
        off("fileProgress", progH);
        off("fileDrop", dropH);
      };
    },
  },

  {
    id: "system",
    label: "System",
    html: `
      <h2>System</h2>
      <p class="desc">Runtime environment, screen info, and native notifications.</p>

      <div class="card">
        <div class="card-label">Environment</div>
        <button id="env-btn">Get environment</button>
        <pre class="result mono" id="env-out"></pre>
      </div>

      <div class="card">
        <div class="card-label">Screen info</div>
        <button id="screen-btn">Get screen info</button>
        <pre class="result mono" id="screen-out"></pre>
      </div>

      <div class="card">
        <div class="card-label">Notification</div>
        <div class="form-grid">
          <input id="notif-title" type="text" placeholder="Title" value="Hello from Lune" />
          <input id="notif-body"  type="text" placeholder="Message" value="This is a native notification." />
        </div>
        <button id="notif-btn" class="primary">Send notification</button>
      </div>
    `,
    init(el) {
      el.querySelector("#env-btn").addEventListener("click", async () => {
        el.querySelector("#env-out").textContent = JSON.stringify(
          await environment(),
          null,
          2,
        );
      });

      el.querySelector("#screen-btn").addEventListener("click", async () => {
        el.querySelector("#screen-out").textContent = JSON.stringify(
          await screenInfo(),
          null,
          2,
        );
      });

      el.querySelector("#notif-btn").addEventListener("click", async () => {
        await notify(
          el.querySelector("#notif-title").value,
          el.querySelector("#notif-body").value,
        );
      });
    },
  },

  {
    id: "clipboard",
    label: "Clipboard",
    html: `
      <h2>Clipboard</h2>
      <p class="desc">Read from and write to the system clipboard.</p>

      <div class="card">
        <div class="card-label">Read</div>
        <button id="read-btn">Read clipboard</button>
        <div class="result" id="read-out"></div>
      </div>

      <div class="card">
        <div class="card-label">Write</div>
        <div class="row">
          <input id="write-in" type="text" placeholder="Text to copy…" />
          <button id="write-btn" class="primary">Write</button>
        </div>
        <div class="result" id="write-out"></div>
      </div>
    `,
    init(el) {
      el.querySelector("#read-btn").addEventListener("click", async () => {
        el.querySelector("#read-out").textContent =
          (await clipboardRead()) || "(empty)";
      });

      el.querySelector("#write-btn").addEventListener("click", async () => {
        await clipboardWrite(el.querySelector("#write-in").value);
        el.querySelector("#write-out").textContent = "Written to clipboard.";
      });
    },
  },

  {
    id: "window",
    label: "Window",
    html: `
      <h2>Window</h2>
      <p class="desc">Native window controls from JavaScript.</p>

      <div class="card">
        <div class="card-label">Controls</div>
        <div class="btn-row">
          <button id="min-btn">Minimize</button>
          <button id="max-btn">Maximize</button>
          <button id="center-btn">Center</button>
        </div>
      </div>

      <div class="card">
        <div class="card-label">Set title</div>
        <div class="row">
          <input id="title-in" type="text" value="Lune Example" />
          <button id="title-btn">Set</button>
        </div>
      </div>

      <div class="card">
        <div class="card-label">Set size</div>
        <div class="row">
          <input id="w-in" type="number" value="1100" />
          <input id="h-in" type="number" value="740" />
          <button id="size-btn" class="primary">Resize</button>
        </div>
      </div>
    `,
    init(el) {
      el.querySelector("#min-btn").addEventListener("click", () => minimize());
      el.querySelector("#max-btn").addEventListener("click", () => maximize());
      el.querySelector("#center-btn").addEventListener("click", () => center());

      el.querySelector("#title-btn").addEventListener("click", async () => {
        await setTitle(el.querySelector("#title-in").value);
      });

      el.querySelector("#size-btn").addEventListener("click", async () => {
        await setSize(
          parseInt(el.querySelector("#w-in").value),
          parseInt(el.querySelector("#h-in").value),
        );
      });
    },
  },

  {
    id: "dialogs",
    label: "Dialogs",
    html: `
      <h2>Dialogs</h2>
      <p class="desc">Native file pickers and message dialogs.</p>

      <div class="card">
        <div class="card-label">File pickers</div>
        <div class="btn-row">
          <button id="open-file-btn">Open file</button>
          <button id="open-files-btn">Open files</button>
          <button id="open-dir-btn">Open folder</button>
          <button id="save-file-btn">Save file</button>
        </div>
        <pre class="result mono" id="picker-out"></pre>
      </div>

      <div class="card">
        <div class="card-label">Message dialogs</div>
        <div class="btn-row">
          <button id="msg-info-btn">Info</button>
          <button id="msg-warn-btn">Warning</button>
          <button id="msg-err-btn">Error</button>
          <button id="msg-q-btn" class="primary">Question</button>
        </div>
        <div class="result" id="dialog-out"></div>
      </div>
    `,
    init(el) {
      const pickerOut = el.querySelector("#picker-out");

      el.querySelector("#open-file-btn").addEventListener("click", async () => {
        pickerOut.textContent =
          (await openFile("Select a file")) || "(cancelled)";
      });
      el.querySelector("#open-files-btn").addEventListener(
        "click",
        async () => {
          const ps = await openFiles("Select files");
          pickerOut.textContent = ps.length ? ps.join("\n") : "(cancelled)";
        },
      );
      el.querySelector("#open-dir-btn").addEventListener("click", async () => {
        pickerOut.textContent =
          (await openDir("Select a folder")) || "(cancelled)";
      });
      el.querySelector("#save-file-btn").addEventListener("click", async () => {
        pickerOut.textContent =
          (await saveFile("Save as", "export.txt")) || "(cancelled)";
      });

      const dialogOut = el.querySelector("#dialog-out");

      el.querySelector("#msg-info-btn").addEventListener("click", () =>
        messageInfo("Information", "This is an info dialog from Lune."),
      );
      el.querySelector("#msg-warn-btn").addEventListener("click", () =>
        messageWarning("Warning", "Something might need your attention."),
      );
      el.querySelector("#msg-err-btn").addEventListener("click", () =>
        messageError("Error", "Something went wrong!"),
      );
      el.querySelector("#msg-q-btn").addEventListener("click", async () => {
        dialogOut.textContent = `Answer: ${await messageQuestion("Confirm", "Do you want to proceed?")}`;
      });
    },
  },

  {
    id: "tray",
    label: "Tray",
    html: `
      <h2>System Tray</h2>
      <p class="desc">Status bar icon with optional context menu. Click and menu events are relayed via the event bus.</p>

      <div class="card">
        <div class="card-label">Icon</div>
        <div class="btn-row">
          <button id="tray-show-btn" class="primary">Show</button>
          <button id="tray-hide-btn">Hide</button>
        </div>
      </div>

      <div class="card">
        <div class="card-label">Context menu</div>
        <div class="btn-row">
          <button id="tray-menu-a-btn">Menu A (Open · Quit)</button>
          <button id="tray-menu-b-btn">Menu B (Pause · Resume · Quit)</button>
          <button id="tray-menu-clear-btn">Clear menu</button>
        </div>
      </div>

      <div class="card">
        <div class="card-label">Event log</div>
        <div class="log" id="tray-log"><div class="log-empty">Tray events appear here…</div></div>
      </div>
    `,
    init(el) {
      el.querySelector("#tray-show-btn").addEventListener("click", () =>
        trayShow(""),
      );
      el.querySelector("#tray-hide-btn").addEventListener("click", () =>
        trayHide(),
      );
      const menuBtnA = el.querySelector("#tray-menu-a-btn");
      const menuBtnB = el.querySelector("#tray-menu-b-btn");

      function setActiveMenu(active) {
        menuBtnA.classList.toggle("primary", active === "a");
        menuBtnB.classList.toggle("primary", active === "b");
      }

      menuBtnA.addEventListener("click", () => {
        traySetMenu([
          { id: "open", label: "Open" },
          { id: "---", label: "" },
          { id: "quit", label: "Quit" },
        ]);
        setActiveMenu("a");
      });
      menuBtnB.addEventListener("click", () => {
        traySetMenu([
          { id: "pause", label: "Pause" },
          { id: "resume", label: "Resume" },
          { id: "---", label: "" },
          { id: "quit", label: "Quit" },
        ]);
        setActiveMenu("b");
      });
      el.querySelector("#tray-menu-clear-btn").addEventListener("click", () => {
        traySetMenu([]);
        setActiveMenu(null);
      });

      const log = el.querySelector("#tray-log");
      const trayH = (id) => {
        log.querySelector(".log-empty")?.remove();
        const d = document.createElement("div");
        d.className = "log-entry";
        d.textContent = `trayEvent: ${JSON.stringify(id)}`;
        log.prepend(d);
        if (id === "quit") quit();
      };
      on("trayEvent", trayH);

      return () => off("trayEvent", trayH);
    },
  },
];

// ── nav ───────────────────────────────────────────────────

const navList = document.getElementById("nav-list");
const contentEl = document.getElementById("content");
let currentCleanup = null;

function activate(id) {
  currentCleanup?.();
  currentCleanup = null;

  navList.querySelectorAll("li").forEach((li) => {
    li.classList.toggle("active", li.dataset.id === id);
  });

  const s = sections.find((x) => x.id === id);
  if (!s) return;
  contentEl.innerHTML = s.html;
  currentCleanup = s.init?.(contentEl) ?? null;
}

sections.forEach((s) => {
  const li = document.createElement("li");
  li.textContent = s.label;
  li.dataset.id = s.id;
  li.addEventListener("click", () => activate(s.id));
  navList.appendChild(li);
});

activate("bindings");
