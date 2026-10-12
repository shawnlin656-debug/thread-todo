/**
 * Thread — an interruption-aware side-panel todo (web demo).
 *
 * The model is one focused task plus three lists:
 *   - `current`      the task being worked on, or null when idle
 *   - `interrupted`  the return path: tasks parked by an interruption, newest first
 *   - `queue`        tasks planned for later, in order
 *   - `done`         tasks completed in this session
 *
 * Every user action mutates `state` and then calls `commit()`, which saves to
 * localStorage and re-renders the panel and the notch island from scratch.
 */
"use strict";

/* -------------------------------------------------------------------------- */
/* Types                                                                      */
/* -------------------------------------------------------------------------- */

/**
 * @typedef {Object} Task
 * @property {string} id             Unique id, stable across reloads.
 * @property {string} title
 * @property {string} [note]         One-line reminder of where the work stands.
 * @property {string} type           Short category label, e.g. "深度工作".
 * @property {number} elapsed        Seconds of focus accumulated so far.
 * @property {number} [estimate]     Planned duration in minutes.
 * @property {boolean} [urgent]      Shown with a "!" marker in the queue.
 * @property {number} [progress]     Rough completion percentage, 0–100.
 * @property {number} [addedAt]      Epoch ms when the task entered the queue.
 * @property {number} [startedAt]    Epoch ms when the task first took focus.
 * @property {number} [interruptedAt] Epoch ms when the task was last parked.
 * @property {number} [completedAt]  Epoch ms when the task was completed.
 */

/**
 * @typedef {Object} AppState
 * @property {number} version
 * @property {Task|null} current
 * @property {Task[]} interrupted
 * @property {Task[]} queue
 * @property {Task[]} done
 * @property {boolean} muted
 * @property {boolean} collapsed
 */

/* -------------------------------------------------------------------------- */
/* Constants                                                                  */
/* -------------------------------------------------------------------------- */

const STORAGE_KEY = "thread.state";
/** Bump when the shape of AppState changes; older saves are discarded. */
const STATE_VERSION = 1;

const MINUTE = 60 * 1000;
const TOAST_DURATION = 3200;
/** How often the island's left wing previews the upcoming task, and for how long. */
const FLIP_EVERY = 20000;
const FLIP_HOLD = 4500;
/** Circumference of the island progress ring (r = 5.5 in a 14px viewBox). */
const RING_LENGTH = 2 * Math.PI * 5.5;

const DEFAULT_TYPE = "临时任务";
const INTERRUPT_NOTE = "临时插队 · 完成后会自动回到上一件事。";
const IDLE = {
  title: "选择下一件最重要的事",
  note: "从下方队列中选择，或添加一个新任务。",
  type: "空闲",
};

/* -------------------------------------------------------------------------- */
/* State and persistence                                                      */
/* -------------------------------------------------------------------------- */

/** @returns {string} */
function createId() {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

/**
 * Sample data shown on first launch, or after loading the page with `?reset`.
 * @returns {AppState}
 */
function seedState() {
  const now = Date.now();
  return {
    version: STATE_VERSION,
    current: {
      id: createId(),
      title: "完成产品首页的信息架构",
      note: "先梳理用户路径，再处理视觉细节。",
      type: "深度工作",
      elapsed: 36 * 60 + 24,
      startedAt: now - (36 * 60 + 24) * 1000,
    },
    interrupted: [
      {
        id: createId(),
        title: "完成首页线框稿",
        note: "回到第二屏的方案比较。",
        type: "设计",
        elapsed: 28 * 60 + 12,
        progress: 70,
        startedAt: now - 70 * MINUTE,
        interruptedAt: now - 12 * MINUTE,
      },
    ],
    queue: [
      { id: createId(), title: "回复设计团队的评审意见", type: "沟通", elapsed: 0, estimate: 10, urgent: true, addedAt: now },
      { id: createId(), title: "整理下周迭代清单", type: "规划", elapsed: 0, estimate: 25, addedAt: now },
    ],
    done: [],
    muted: false,
    collapsed: false,
  };
}

/**
 * Restore the saved state, falling back to the seed when nothing usable is stored.
 * @returns {AppState}
 */
function loadState() {
  if (new URLSearchParams(location.search).has("reset")) return seedState();
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
    if (saved?.version === STATE_VERSION) return saved;
  } catch {
    // Unreadable or blocked storage: start from the seed instead.
  }
  return seedState();
}

function saveState() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // Storage can be unavailable (private mode, quota); the demo still works in memory.
  }
}

/** @type {AppState} */
const state = loadState();

/* -------------------------------------------------------------------------- */
/* DOM references                                                             */
/* -------------------------------------------------------------------------- */

/**
 * @param {string} selector
 * @returns {HTMLElement}
 */
const $ = (selector) => document.querySelector(selector);

const panel = $("#threadPanel");
const rail = $("#collapsedRail");
const railCount = $("#railCount");
const soundButton = $("#soundButton");

const currentTask = $("#currentTask");
const currentTitle = $("#currentTitle");
const currentNote = $("#currentNote");
const currentType = $("#currentType");
const focusState = $("#focusState");
const focusStateLabel = $("#focusStateLabel");
const timer = $("#timer");
const startedAt = $("#startedAt");
const completeButton = $("#completeButton");
const pauseButton = $("#pauseButton");

const returnStack = $("#returnStack");
const returnCount = $("#returnCount");
const queueList = $("#queueList");
const clearDoneButton = $("#clearDoneButton");
const quickAddForm = $("#quickAddForm");
const quickInput = $("#quickInput");

const islandWrap = $("#focusIslandWrap");
const island = $("#focusIsland");
const islandCurrent = $("#islandCurrent");
const islandNext = $("#islandNext");
const islandTimer = $("#islandTimer");
const islandRing = $("#islandRing");
const focusPeek = $("#focusPeek");

const toast = $("#toast");
const toastIcon = toast.querySelector(".toast-icon");
const toastTitle = $("#toastTitle");
const toastText = $("#toastText");

let toastTimeout;
let flipTimeout;
/** Id of the task last painted in the "now" card, used to animate only real swaps. */
let renderedTaskId;

/* -------------------------------------------------------------------------- */
/* Formatting helpers                                                         */
/* -------------------------------------------------------------------------- */

/**
 * @param {number} seconds
 * @returns {string} "mm:ss"; minutes keep growing past 59.
 */
function formatTime(seconds) {
  const minutes = Math.floor(seconds / 60).toString().padStart(2, "0");
  const secs = (seconds % 60).toString().padStart(2, "0");
  return `${minutes}:${secs}`;
}

/**
 * @param {number} timestamp Epoch ms.
 * @returns {string} Wall-clock time, "HH:MM".
 */
function formatClock(timestamp) {
  return new Date(timestamp).toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false });
}

/**
 * @param {number} [timestamp] Epoch ms.
 * @returns {string} Relative time such as "刚刚", "12 分钟前" or "3 小时前".
 */
function formatAgo(timestamp) {
  const minutes = Math.floor((Date.now() - (timestamp ?? Date.now())) / MINUTE);
  if (minutes < 1) return "刚刚";
  if (minutes < 60) return `${minutes} 分钟前`;
  return `${Math.floor(minutes / 60)} 小时前`;
}

/**
 * Escape text for interpolation into an HTML template.
 * @param {string} value
 * @returns {string}
 */
function escapeHtml(value) {
  const node = document.createElement("div");
  node.textContent = value;
  return node.innerHTML;
}

/* -------------------------------------------------------------------------- */
/* Rendering                                                                  */
/* -------------------------------------------------------------------------- */

/** Persist the state and repaint everything that depends on it. */
function commit() {
  saveState();
  render();
}

function render() {
  renderCurrent();
  renderTime();
  renderReturnPath();
  renderQueue();
  renderIsland();
  renderChrome();
}

/** The "now" card. With no current task it shows the idle prompt and disables its actions. */
function renderCurrent() {
  const task = state.current;
  currentTitle.textContent = task?.title ?? IDLE.title;
  currentNote.textContent = task?.note ?? (task ? "" : IDLE.note);
  currentType.textContent = task?.type ?? IDLE.type;
  startedAt.textContent = task?.startedAt ? `${formatClock(task.startedAt)} 开始` : "";
  focusState.classList.toggle("is-idle", !task);
  focusStateLabel.textContent = task ? "专注中" : "空闲";
  completeButton.disabled = pauseButton.disabled = !task;

  if (renderedTaskId !== task?.id) {
    renderedTaskId = task?.id;
    currentTask.classList.remove("task-swap");
    requestAnimationFrame(() => currentTask.classList.add("task-swap"));
  }
}

/** Timer readouts in the panel and the island; runs every second, so it touches nothing else. */
function renderTime() {
  const elapsed = state.current?.elapsed ?? 0;
  const label = formatTime(elapsed);
  timer.textContent = label;
  islandTimer.textContent = state.current ? label : "--:--";
  // The ring sweeps once per minute, like a second hand.
  islandRing.style.strokeDashoffset = RING_LENGTH * (1 - (elapsed % 60) / 60);
}

function renderReturnPath() {
  returnCount.textContent = `${state.interrupted.length} 个待继续`;

  if (!state.interrupted.length) {
    returnStack.innerHTML = '<p class="empty-return">没有搁置的任务，你的工作线很干净。</p>';
    return;
  }

  returnStack.innerHTML = state.interrupted.map((task, index) => `
    <article class="return-card">
      <div class="thread-line" aria-hidden="true"><i></i><span></span><b></b></div>
      <div class="return-copy">
        <p>${escapeHtml(task.title)}</p>
        <span>${formatAgo(task.interruptedAt)}被打断 · ${task.progress ? `进度 ${task.progress}%` : "可随时继续"}</span>
      </div>
      <button class="resume-button" type="button" data-index="${index}">继续</button>
    </article>
  `).join("");
}

/**
 * Secondary line for a queued task.
 * @param {Task} task
 * @returns {string}
 */
function queueMeta(task) {
  return task.estimate ? `约 ${task.estimate} 分钟` : `${formatAgo(task.addedAt)}添加`;
}

/** Pending tasks first, numbered by position, followed by the tasks completed this session. */
function renderQueue() {
  const chevron = '<svg class="chevron" viewBox="0 0 24 24" aria-hidden="true"><path d="m9 6 6 6-6 6"/></svg>';

  const pending = state.queue.map((task, index) => `
    <button class="queue-item" type="button" data-id="${task.id}">
      <span class="priority-dot${task.urgent ? " urgent" : ""}"><i>${task.urgent ? "!" : index + 1}</i></span>
      <span class="queue-copy"><b>${escapeHtml(task.title)}</b><small>${queueMeta(task)}</small></span>
      ${chevron}
    </button>
  `);

  const done = state.done.map((task) => `
    <div class="queue-item is-done">
      <span class="priority-dot"><i>✓</i></span>
      <span class="queue-copy"><b>${escapeHtml(task.title)}</b><small>${formatAgo(task.completedAt)}完成</small></span>
    </div>
  `);

  queueList.innerHTML = pending.concat(done).join("") || '<p class="empty-return">队列是空的。输入任务后按 ⇧↵ 可以排到这里。</p>';
  clearDoneButton.hidden = !state.done.length;
}

/**
 * The notch island: current task on the left wing, timer on the right, and a peek panel
 * listing what comes next. The task to return to always outranks the queue.
 */
function renderIsland() {
  const returning = state.interrupted[0];
  const queued = state.queue[0];

  islandCurrent.textContent = state.current?.title ?? IDLE.type;
  islandNext.textContent = returning ? `返回 · ${returning.title}` : queued ? `下一个 · ${queued.title}` : "";
  if (!islandNext.textContent) island.classList.remove("is-flipped");

  const rows = [];
  if (returning) rows.push(peekRow("return", state.current ? "完成后返回" : "待继续", returning.title, `${formatAgo(returning.interruptedAt)}被打断`));
  if (queued) rows.push(peekRow("queue", "接下来", queued.title, queueMeta(queued)));
  focusPeek.innerHTML = rows.join("") || '<p class="peek-empty">后面没有排队的任务。</p>';
}

/**
 * @param {"return"|"queue"} kind Which list the row acts on when clicked.
 * @param {string} label
 * @param {string} title
 * @param {string} meta
 * @returns {string} HTML for one peek row.
 */
function peekRow(kind, label, title, meta) {
  return `
    <button class="peek-row" type="button" data-peek="${kind}">
      <span class="peek-copy"><small>${label}</small><b>${escapeHtml(title)}</b></span>
      <span class="peek-meta">${escapeHtml(meta)}</span>
    </button>
  `;
}

/** Panel chrome that mirrors state: collapsed rail, its badge, and the sound toggle. */
function renderChrome() {
  panel.classList.toggle("is-collapsed", state.collapsed);
  rail.classList.toggle("is-visible", state.collapsed);
  railCount.textContent = state.interrupted.length + (state.current ? 1 : 0);
  soundButton.classList.toggle("muted", state.muted);
  soundButton.setAttribute("aria-pressed", String(!state.muted));
}

/**
 * @param {string} title
 * @param {string} message
 * @param {string} [icon] Single glyph shown in the badge.
 */
function showToast(title, message, icon = "↩") {
  clearTimeout(toastTimeout);
  toastTitle.textContent = title;
  toastText.textContent = message;
  toastIcon.textContent = icon;
  toast.classList.add("is-visible");
  toastTimeout = setTimeout(() => toast.classList.remove("is-visible"), TOAST_DURATION);
}

/**
 * Briefly swap the island's left wing to the upcoming task. Skipped while the user is
 * already looking at the peek, so the text never moves under the pointer.
 */
function flipIsland() {
  if (!islandNext.textContent || islandWrap.matches(":hover, :focus-within")) return;
  clearTimeout(flipTimeout);
  island.classList.add("is-flipped");
  flipTimeout = setTimeout(() => island.classList.remove("is-flipped"), FLIP_HOLD);
}

/* -------------------------------------------------------------------------- */
/* Actions                                                                    */
/* -------------------------------------------------------------------------- */

/** Move the current task to the top of the return path. Does nothing when idle. */
function parkCurrent() {
  if (!state.current) return;
  state.interrupted.unshift({ ...state.current, interruptedAt: Date.now() });
  state.current = null;
}

/**
 * Give a task the focus, parking whatever was in progress so it can be resumed.
 * @param {Task} task
 */
function focusOn(task) {
  const parked = state.current;
  parkCurrent();
  state.current = { ...task, startedAt: task.startedAt ?? Date.now() };
  commit();

  if (parked) {
    showToast("已为你保留原任务", `完成「${task.title}」后提醒你返回`, "↓");
    flipIsland();
  } else {
    showToast("开始专注", `现在处理「${task.title}」`, "→");
  }
}

/**
 * Start a brand-new task right away, interrupting the current one.
 * @param {string} title
 */
function interruptWith(title) {
  focusOn({ id: createId(), title, note: INTERRUPT_NOTE, type: DEFAULT_TYPE, elapsed: 0 });
}

/**
 * Add a new task to the end of the queue without touching the current focus.
 * @param {string} title
 */
function enqueue(title) {
  state.queue.push({ id: createId(), title, type: DEFAULT_TYPE, elapsed: 0, addedAt: Date.now() });
  commit();
  showToast("已加入队列", `「${title}」排在接下来`, "+");
}

/**
 * Start a queued task now.
 * @param {string} id
 */
function startQueued(id) {
  const index = state.queue.findIndex((task) => task.id === id);
  if (index === -1) return;
  focusOn(state.queue.splice(index, 1)[0]);
}

/**
 * Switch to a parked task; the current one takes its place on the return path.
 * @param {number} index Position in `state.interrupted`.
 */
function resumeTask(index) {
  const [task] = state.interrupted.splice(index, 1);
  if (!task) return;
  parkCurrent();
  state.current = task;
  commit();
  showToast("已切换任务", `现在继续「${task.title}」`, "↩");
}

/** Finish the current task and fall back to the most recently interrupted one, if any. */
function completeCurrent() {
  const finished = state.current;
  if (!finished) return;
  state.done.unshift({ ...finished, completedAt: Date.now() });
  state.current = state.interrupted.shift() ?? null;
  commit();

  if (state.current) showToast("已完成，回到原任务", `现在继续「${state.current.title}」`, "↩");
  else showToast("做得好", `「${finished.title}」已完成`, "✓");
}

/** Set the current task aside without finishing it, leaving the panel idle. */
function pauseCurrent() {
  if (!state.current) return;
  parkCurrent();
  commit();
  showToast("任务已保留", "你可以随时从“返回路径”继续", "Ⅱ");
}

/* -------------------------------------------------------------------------- */
/* Events                                                                     */
/* -------------------------------------------------------------------------- */

// Quick add: Enter interrupts with the new task, Shift+Enter queues it for later.
quickAddForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const title = quickInput.value.trim();
  if (!title) {
    quickInput.focus();
    return;
  }
  quickInput.value = "";
  interruptWith(title);
});

quickInput.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" || !event.shiftKey || event.isComposing) return;
  event.preventDefault();
  const title = quickInput.value.trim();
  if (!title) return;
  quickInput.value = "";
  enqueue(title);
});

$("#addSymbol").addEventListener("click", () => quickInput.focus());
completeButton.addEventListener("click", completeCurrent);
pauseButton.addEventListener("click", pauseCurrent);

returnStack.addEventListener("click", (event) => {
  const button = event.target.closest(".resume-button");
  if (button) resumeTask(Number(button.dataset.index));
});

queueList.addEventListener("click", (event) => {
  const item = event.target.closest("button.queue-item");
  if (item) startQueued(item.dataset.id);
});

clearDoneButton.addEventListener("click", () => {
  state.done = [];
  commit();
});

focusPeek.addEventListener("click", (event) => {
  const row = event.target.closest(".peek-row");
  if (!row) return;
  if (row.dataset.peek === "return") resumeTask(0);
  else startQueued(state.queue[0].id);
});

// Keep aria-expanded in step with the CSS-driven peek, and cancel a flip once the peek opens.
for (const type of ["mouseenter", "mouseleave", "focusin", "focusout"]) {
  islandWrap.addEventListener(type, () => {
    const open = islandWrap.matches(":hover, :focus-within");
    island.setAttribute("aria-expanded", String(open));
    if (open) island.classList.remove("is-flipped");
  });
}

islandWrap.addEventListener("keydown", (event) => {
  if (event.key === "Escape") document.activeElement.blur();
});

$("#collapseButton").addEventListener("click", () => {
  state.collapsed = true;
  commit();
});

rail.addEventListener("click", () => {
  state.collapsed = false;
  commit();
});

soundButton.addEventListener("click", () => {
  state.muted = !state.muted;
  commit();
  showToast(state.muted ? "提示音已关闭" : "提示音已开启", "任务返回提醒仍会显示在屏幕上", state.muted ? "×" : "♪");
});

/* -------------------------------------------------------------------------- */
/* Boot                                                                       */
/* -------------------------------------------------------------------------- */

// Focus clock: only the current task accumulates time, and only while the page is open.
setInterval(() => {
  if (!state.current) return;
  state.current.elapsed += 1;
  saveState();
  renderTime();
}, 1000);

// Relative labels ("12 分钟前") go stale, so refresh the lists once a minute.
setInterval(() => {
  renderReturnPath();
  renderQueue();
  renderIsland();
}, MINUTE);

setInterval(flipIsland, FLIP_EVERY);

// Glass parameters per surface: larger, text-heavy surfaces get more frost and a deeper bezel.
Glass.attach(panel, { bezel: 26, depth: 34, blur: 6 });
Glass.attach(rail, { bezel: 16, depth: 16, blur: 9 });
Glass.attach(toast, { bezel: 16, depth: 16, blur: 9 });

render();
