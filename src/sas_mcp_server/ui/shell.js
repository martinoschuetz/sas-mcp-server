// Shared runtime for every view. Runs as an inline module after the vendored
// ext-apps bridge; exposes a small `sas` global the view's own module uses.
//
// What it does for a view: connects to the host, hands the view the tool's
// input and result as they arrive, applies the host's theme, reports the
// view's size, owns the fullscreen toggle, and wraps the few host calls a
// view needs — call a tool, post a message into the chat, hand the model
// context — with the result parsing that FastMCP's shapes require. Views
// never talk to the bridge directly.
const bridge = globalThis.__MCP_EXT_APPS__;
const meta = globalThis.SAS_VIEW || { tool: "", view: "", title: "SAS Viya", version: "" };
// Which of this view's companion tools the deployment actually registered.
// MCP_TIERS and MCP_READ_ONLY can withhold any of them, and a control that can
// only ever fail is worse than no control.
const available = new Set(meta.can || []);

const app = new bridge.App(
  { name: `SAS Viya ${meta.title}`, version: meta.version || "0" },
  { availableDisplayModes: ["inline", "fullscreen"] },
);

const handlers = { input: [], result: [], theme: [], display: [] };
let hostTheme = "";
let displayMode = "inline";

// --- display mode -------------------------------------------------------------
// Every view gets the same ⤢ button, in the header's right-hand group, and the
// same `data-display` attribute on <html> for its CSS to key on. The button
// exists only where the host says it offers fullscreen: a control the host
// would refuse is worse than none. Views size their scroll region with the
// `fill` class (see shell.css) rather than with their own numbers.
const fullscreenButton = document.createElement("button");
fullscreenButton.id = "sas-fullscreen";
fullscreenButton.type = "button";
fullscreenButton.hidden = true;
fullscreenButton.addEventListener("click", () => sas.toggleFullscreen());

function mountFullscreenButton() {
  const head = document.querySelector("#root > .head");
  if (!head) return;
  // The header's last child is the pills/badges row, which every view rebuilds
  // with replaceChildren() when a result arrives — so the button cannot live
  // inside it, or it shows while the tool runs and vanishes with the result.
  // Wrap that row and the button together instead; the view keeps its row.
  const slot = head.lastElementChild;
  if (slot && slot !== head.firstElementChild) {
    const side = document.createElement("div");
    side.className = "row head-side";
    head.replaceChild(side, slot);
    side.append(slot, fullscreenButton);
  } else {
    head.append(fullscreenButton);
  }
}

function applyDisplay(ctx) {
  const hc = ctx || app.getHostContext() || {};
  if (hc.displayMode) displayMode = hc.displayMode;
  document.documentElement.dataset.display = displayMode;
  const full = displayMode === "fullscreen";
  fullscreenButton.textContent = full ? "⤡" : "⤢";
  fullscreenButton.title = full ? "Exit fullscreen" : "Open in fullscreen";
  fullscreenButton.setAttribute("aria-pressed", String(full));
  const modes = hc.availableDisplayModes || app.getHostContext()?.availableDisplayModes || [];
  fullscreenButton.hidden = !modes.includes("fullscreen");
  for (const fn of handlers.display) fn(displayMode);
}

function applyTheme(ctx) {
  if (!ctx) return;
  try {
    if (ctx.styles?.variables) bridge.applyHostStyleVariables(ctx.styles.variables);
    if (ctx.styles?.css?.fonts) bridge.applyHostFonts(ctx.styles.css.fonts);
    if (ctx.theme) {
      bridge.applyDocumentTheme(ctx.theme);
      document.documentElement.dataset.theme = ctx.theme;
      hostTheme = ctx.theme;
    }
  } catch (err) {
    console.warn("theme not applied", err);
  }
  for (const fn of handlers.theme) fn(ctx);
  applyDisplay(ctx);
}

/** Text of a tool result's content blocks, joined. */
function textOf(result) {
  return (result?.content || [])
    .filter((c) => c && c.type === "text" && typeof c.text === "string")
    .map((c) => c.text)
    .join("\n");
}

/** The value a tool returned, from either the structured or the text form.
 *  FastMCP wraps a non-object return (a string, a list) as {result: ...} in
 *  structuredContent; a dict return arrives as itself. */
function parseResult(result) {
  const sc = result?.structuredContent;
  if (sc && typeof sc === "object") {
    const keys = Object.keys(sc);
    if (!(keys.length === 1 && keys[0] === "result")) return sc;
    return sc.result;
  }
  const text = textOf(result);
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

const sas = {
  app,
  tool: meta.tool,
  view: meta.view,
  input: null,
  result: null,
  get theme() {
    return hostTheme;
  },
  onInput(fn) {
    handlers.input.push(fn);
    if (sas.input) fn(sas.input);
  },
  onResult(fn) {
    handlers.result.push(fn);
    if (sas.result) fn(sas.result.data, sas.result.raw);
  },
  onTheme(fn) {
    handlers.theme.push(fn);
  },
  /** The host's current display mode: "inline", "fullscreen" or "pip". */
  get display() {
    return displayMode;
  },
  /** Called with the mode whenever it changes; a view that draws to a
   *  canvas or measures itself redraws here. */
  onDisplay(fn) {
    handlers.display.push(fn);
  },
  /** Is *name* a tool this deployment registered? Ask before offering a
   *  control that calls it — `MCP_READ_ONLY` and `MCP_TIERS` withhold tools
   *  from a view exactly as they withhold them from the model. Only the
   *  view's declared `calls` are listed, so an unlisted name reads false. */
  can(name) {
    return available.has(name);
  },
  /** Call a server tool through the host. Resolves to the parsed value;
   *  rejects with the tool's own message when it reports an error. */
  async call(name, args) {
    const result = await app.callServerTool({ name, arguments: args || {} });
    if (result?.isError) throw new Error(textOf(result) || `${name} failed`);
    return parseResult(result);
  },
  /** Post a message into the chat as the person — the host then lets the
   *  model respond, so use it only for something they did on purpose. */
  async say(text) {
    await app.sendMessage({ role: "user", content: [{ type: "text", text }] });
  },
  /** Hand the model context silently (no turn). Hosts may not support it;
   *  a refusal is not an error for the person. */
  async context(text, structured) {
    try {
      const params = { content: [{ type: "text", text }] };
      if (structured) params.structuredContent = structured;
      await app.updateModelContext(params);
    } catch (err) {
      console.info("model context not accepted by this host", err?.message || err);
    }
  },
  /** Ask the host for fullscreen, or back to inline from it. The host has
   *  the last word: its answer, or its next context change, sets the mode. */
  async toggleFullscreen() {
    const want = displayMode === "fullscreen" ? "inline" : "fullscreen";
    try {
      const r = await app.requestDisplayMode({ mode: want });
      if (r?.mode) displayMode = r.mode;
    } catch (err) {
      console.info("display mode not accepted by this host", err?.message || err);
    }
    applyDisplay();
  },
  /** DOM helper: el("td", {class: "num", onclick: fn}, "text", node, ...). */
  el(tag, attrs, ...children) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs || {})) {
      if (value == null || value === false) continue;
      if (key === "class") node.className = value;
      else if (key === "dataset") Object.assign(node.dataset, value);
      else if (key.startsWith("on") && typeof value === "function") node.addEventListener(key.slice(2), value);
      else if (key in node && typeof value !== "string") node[key] = value;
      else node.setAttribute(key, value === true ? "" : String(value));
    }
    for (const child of children.flat()) {
      if (child == null || child === false) continue;
      node.append(child.nodeType ? child : document.createTextNode(String(child)));
    }
    return node;
  },
  fmt: {
    int(n) {
      return Number(n).toLocaleString();
    },
    /** A cell for display: null stays null (rendered by the caller), numbers
     *  keep their precision, objects become JSON. */
    cell(v) {
      if (v == null) return null;
      if (typeof v === "number") return Number.isInteger(v) ? String(v) : String(+v.toPrecision(12));
      if (typeof v === "object") return JSON.stringify(v);
      return String(v);
    },
    isNumeric(v) {
      return typeof v === "number" || (typeof v === "string" && v.trim() !== "" && !Number.isNaN(Number(v)));
    },
  },
  /** Show a message in the view's banner (kind: ok | warn | bad | ""). */
  banner(text, kind) {
    const box = document.getElementById("banner");
    if (!box) return;
    if (!text) {
      box.hidden = true;
      return;
    }
    box.textContent = text;
    box.className = `banner ${kind || ""}`.trim();
    box.hidden = false;
  },
  busy(on) {
    const root = document.getElementById("root");
    if (root) root.classList.toggle("busy", !!on);
  },
  /** One-line description of an error for a banner. */
  errorText(err) {
    const text = err?.message || String(err);
    return text.length > 600 ? `${text.slice(0, 600)}…` : text;
  },
};

app.ontoolinput = (params) => {
  sas.input = params?.arguments || {};
  for (const fn of handlers.input) fn(sas.input);
};
app.ontoolresult = (result) => {
  const data = parseResult(result);
  sas.result = { data, raw: result };
  for (const fn of handlers.result) fn(data, result);
};
app.ontoolcancelled = (params) => {
  sas.banner(`The call was cancelled${params?.reason ? `: ${params.reason}` : "."}`, "warn");
};
app.onhostcontextchanged = (ctx) => applyTheme(ctx);

mountFullscreenButton();

sas.ready = app
  .connect()
  .then(() => {
    applyTheme(app.getHostContext());
    try {
      app.setupSizeChangedNotifications();
    } catch (err) {
      console.info("size notifications unavailable", err?.message || err);
    }
  })
  .catch((err) => {
    sas.banner(`Could not connect to the host: ${sas.errorText(err)}`, "bad");
  });

globalThis.sas = sas;
