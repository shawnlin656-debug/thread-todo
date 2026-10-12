const state = {
  current: {
    title: "完成产品首页的信息架构",
    note: "先梳理用户路径，再处理视觉细节。",
    type: "深度工作",
    elapsed: 36 * 60 + 24,
  },
  interrupted: [
    {
      title: "完成首页线框稿",
      note: "回到第二屏的方案比较。",
      type: "设计",
      elapsed: 28 * 60 + 12,
      interruptedAt: "12 分钟前",
      progress: 70,
    },
  ],
};

const $ = (selector) => document.querySelector(selector);
const panel = $("#threadPanel");
const currentTask = $("#currentTask");
const currentTitle = $("#currentTitle");
const currentNote = $("#currentNote");
const currentType = $("#currentType");
const timer = $("#timer");
const returnStack = $("#returnStack");
const returnCount = $("#returnCount");
const quickInput = $("#quickInput");
const toast = $("#toast");
const queueList = $("#queueList");
const islandWrap = $("#focusIslandWrap");
const island = $("#focusIsland");
const islandCurrent = $("#islandCurrent");
const islandNext = $("#islandNext");
const islandTimer = $("#islandTimer");
const islandRing = $("#islandRing");
const focusPeek = $("#focusPeek");
const RING_LENGTH = 2 * Math.PI * 5.5;
const FLIP_EVERY = 20000;
const FLIP_HOLD = 4500;
let toastTimeout;
let flipTimeout;

function formatTime(seconds) {
  const minutes = Math.floor(seconds / 60).toString().padStart(2, "0");
  const secs = (seconds % 60).toString().padStart(2, "0");
  return `${minutes}:${secs}`;
}

function showToast(title, message, icon = "↩") {
  clearTimeout(toastTimeout);
  $("#toastTitle").textContent = title;
  $("#toastText").textContent = message;
  toast.querySelector(".toast-icon").textContent = icon;
  toast.classList.add("is-visible");
  toastTimeout = setTimeout(() => toast.classList.remove("is-visible"), 3200);
}

function animateCurrent() {
  currentTask.classList.remove("task-swap");
  requestAnimationFrame(() => currentTask.classList.add("task-swap"));
}

function renderCurrent() {
  currentTitle.textContent = state.current.title;
  currentNote.textContent = state.current.note;
  currentType.textContent = state.current.type;
  renderTime();
  renderIsland();
  animateCurrent();
}

function renderTime() {
  const label = formatTime(state.current.elapsed);
  timer.textContent = label;
  islandTimer.textContent = label;
  islandRing.style.strokeDashoffset = RING_LENGTH * (1 - (state.current.elapsed % 60) / 60);
}

function nextQueued() {
  return queueList.querySelector(".queue-item:not(.is-done)");
}

function renderIsland() {
  const returning = state.interrupted[0];
  const queued = nextQueued();
  islandCurrent.textContent = state.current.title;
  islandNext.textContent = returning ? `返回 · ${returning.title}` : queued ? `下一个 · ${queued.dataset.title}` : "";
  if (!islandNext.textContent) island.classList.remove("is-flipped");

  const rows = [];
  if (returning) rows.push(peekRow("return", "完成后返回", returning.title, `${returning.interruptedAt || "刚刚"}被打断`));
  if (queued) rows.push(peekRow("queue", "接下来", queued.dataset.title, queued.querySelector("small").textContent));
  focusPeek.innerHTML = rows.join("") || '<p class="peek-empty">后面没有排队的任务。</p>';
}

function peekRow(kind, label, title, meta) {
  return `
    <button class="peek-row" type="button" data-peek="${kind}">
      <span class="peek-copy"><small>${label}</small><b>${escapeHtml(title)}</b></span>
      <span class="peek-meta">${escapeHtml(meta)}</span>
    </button>
  `;
}

// Briefly swap the left wing to the upcoming task, unless the user is already looking at the peek.
function flipIsland() {
  if (!islandNext.textContent || islandWrap.matches(":hover, :focus-within")) return;
  clearTimeout(flipTimeout);
  island.classList.add("is-flipped");
  flipTimeout = setTimeout(() => island.classList.remove("is-flipped"), FLIP_HOLD);
}

function renderInterrupted() {
  returnCount.textContent = `${state.interrupted.length} 个待继续`;
  $("#railCount").textContent = state.interrupted.length + 1;
  renderIsland();

  if (!state.interrupted.length) {
    returnStack.innerHTML = '<div class="empty-return">没有搁置的任务，你的工作线很干净。</div>';
    return;
  }

  returnStack.innerHTML = state.interrupted.map((task, index) => `
    <article class="return-card">
      <div class="thread-line"><i></i><span></span><b></b></div>
      <div class="return-copy">
        <p>${escapeHtml(task.title)}</p>
        <span>${task.interruptedAt || "刚刚"}被打断 · ${task.progress ? `进度 ${task.progress}%` : "可随时继续"}</span>
      </div>
      <button class="resume-button" data-index="${index}">继续</button>
    </article>
  `).join("");
}

function escapeHtml(value) {
  const node = document.createElement("div");
  node.textContent = value;
  return node.innerHTML;
}

function interruptWith(title, type = "临时任务") {
  state.interrupted.unshift({
    ...state.current,
    interruptedAt: "刚刚",
    progress: null,
  });
  state.current = {
    title,
    note: "临时插队 · 完成后会自动回到上一件事。",
    type,
    elapsed: 0,
  };
  renderCurrent();
  renderInterrupted();
  showToast("已为你保留原任务", `完成「${title}」后提醒你返回`, "↓");
  flipIsland();
}

function resumeTask(index, completedCurrent = false) {
  const next = state.interrupted.splice(index, 1)[0];
  if (!next) return;

  if (!completedCurrent) {
    state.interrupted.unshift({ ...state.current, interruptedAt: "刚刚", progress: null });
  }

  const previousTitle = state.current.title;
  state.current = next;
  renderCurrent();
  renderInterrupted();
  showToast(completedCurrent ? "临时任务已完成" : "已切换任务", `现在继续「${next.title}」`, "↩");

  if (completedCurrent) {
    addCompletedToQueue(previousTitle);
  }
}

function addCompletedToQueue(title) {
  const item = document.createElement("button");
  item.className = "queue-item is-done";
  item.innerHTML = `
    <span class="priority-dot"><i>✓</i></span>
    <span class="queue-copy"><b>${escapeHtml(title)}</b><small>刚刚完成</small></span>
    <svg class="chevron" viewBox="0 0 24 24" aria-hidden="true"><path d="m9 6 6 6-6 6"/></svg>
  `;
  queueList.prepend(item);
}

$("#quickAddForm").addEventListener("submit", (event) => {
  event.preventDefault();
  const title = quickInput.value.trim();
  if (!title) {
    quickInput.focus();
    return;
  }
  interruptWith(title);
  quickInput.value = "";
});

$("#addSymbol").addEventListener("click", () => quickInput.focus());

$("#completeButton").addEventListener("click", () => {
  if (state.interrupted.length) {
    resumeTask(0, true);
  } else {
    const completed = state.current.title;
    addCompletedToQueue(completed);
    state.current = {
      title: "选择下一件最重要的事",
      note: "从下方队列中选择，或添加一个新任务。",
      type: "空闲",
      elapsed: 0,
    };
    renderCurrent();
    showToast("做得好", `「${completed}」已完成`, "✓");
  }
});

$("#pauseButton").addEventListener("click", () => {
  state.interrupted.unshift({ ...state.current, interruptedAt: "刚刚", progress: null });
  state.current = {
    title: "选择下一件最重要的事",
    note: "暂停不是放弃，它已经被放进待返回列表。",
    type: "空闲",
    elapsed: 0,
  };
  renderCurrent();
  renderInterrupted();
  showToast("任务已保留", "你可以随时从“待返回”继续", "Ⅱ");
});

returnStack.addEventListener("click", (event) => {
  const button = event.target.closest(".resume-button");
  if (!button) return;
  resumeTask(Number(button.dataset.index));
});

function startQueued(item) {
  item.remove();
  interruptWith(item.dataset.title, item.dataset.type);
}

queueList.addEventListener("click", (event) => {
  const item = event.target.closest(".queue-item");
  if (!item || item.classList.contains("is-done")) return;
  startQueued(item);
});

focusPeek.addEventListener("click", (event) => {
  const row = event.target.closest(".peek-row");
  if (!row) return;
  if (row.dataset.peek === "return") resumeTask(0);
  else startQueued(nextQueued());
});

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

$("#clearDoneButton").addEventListener("click", () => {
  document.querySelectorAll(".queue-item.is-done").forEach((item) => item.remove());
});

$("#collapseButton").addEventListener("click", () => {
  panel.classList.add("is-collapsed");
  $("#collapsedRail").classList.add("is-visible");
});

$("#collapsedRail").addEventListener("click", () => {
  panel.classList.remove("is-collapsed");
  $("#collapsedRail").classList.remove("is-visible");
});

$("#soundButton").addEventListener("click", (event) => {
  event.currentTarget.classList.toggle("muted");
  showToast(
    event.currentTarget.classList.contains("muted") ? "提示音已关闭" : "提示音已开启",
    "任务返回提醒仍会显示在屏幕上",
    event.currentTarget.classList.contains("muted") ? "×" : "♪"
  );
});

setInterval(() => {
  state.current.elapsed += 1;
  renderTime();
}, 1000);
setInterval(flipIsland, FLIP_EVERY);

Glass.attach(panel, { bezel: 26, depth: 34, blur: 6 });
Glass.attach($("#collapsedRail"), { bezel: 16, depth: 16, blur: 9 });
Glass.attach(toast, { bezel: 16, depth: 16, blur: 9 });

renderTime();
renderInterrupted();
