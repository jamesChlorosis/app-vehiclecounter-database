(function () {
  const state = {
    token: window.localStorage.getItem("autopilotToken") || "",
    tasks: [],
    selectedTaskId: "",
  };

  const loginView = document.getElementById("loginView");
  const appView = document.getElementById("appView");
  const loginForm = document.getElementById("loginForm");
  const loginError = document.getElementById("loginError");
  const taskRows = document.getElementById("taskRows");
  const taskCount = document.getElementById("taskCount");
  const taskDetail = document.getElementById("taskDetail");
  const runLog = document.getElementById("runLog");
  const taskForm = document.getElementById("taskForm");
  const formError = document.getElementById("formError");
  const triggerJson = document.getElementById("triggerJson");
  const actionsJson = document.getElementById("actionsJson");

  const presets = {
    internship: {
      trigger: {
        type: "time_recurring",
        cron_expression: "0 8 * * *",
        human_label: "Every day at 8:00 AM",
      },
      actions: [
        {
          type: "web_scrape",
          config: { url: "https://example.com/jobs", selector: "body" },
        },
        {
          type: "ai_summarize",
          config: {
            text: "{{result}}",
            prompt: "Find new cybersecurity internships in this page text. Return concise bullets.",
          },
        },
        {
          type: "send_telegram",
          config: { chat_id: "YOUR_CHAT_ID", message_template: "{{result}}" },
        },
      ],
    },
    price: {
      trigger: {
        type: "event_poll",
        poll_interval_seconds: 300,
        condition: { type: "price_threshold", params: { ticker: "AAPL", above: 200 } },
      },
      actions: [
        {
          type: "send_discord",
          config: { message_template: "Price alert: {{triggerOutput}}" },
        },
      ],
    },
  };

  function showApp() {
    loginView.classList.toggle("hidden", Boolean(state.token));
    appView.classList.toggle("hidden", !state.token);
  }

  async function api(path, options) {
    const response = await fetch(`/api${path}`, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        Authorization: state.token ? `Bearer ${state.token}` : "",
        ...(options && options.headers ? options.headers : {}),
      },
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.error || response.statusText);
    return data;
  }

  function fmt(value) {
    if (!value) return "-";
    return new Date(value).toLocaleString();
  }

  function triggerLabel(trigger) {
    if (!trigger) return "-";
    if (trigger.type === "time_once") return `Once: ${fmt(trigger.run_at)}`;
    if (trigger.type === "time_recurring") return trigger.human_label || trigger.cron_expression;
    return `Poll ${trigger.poll_interval_seconds}s: ${trigger.condition.type}`;
  }

  function statusBadge(status) {
    return `<span class="status-badge status-${status}">${status}</span>`;
  }

  function renderTasks() {
    taskCount.textContent = String(state.tasks.length);
    if (!state.tasks.length) {
      taskRows.innerHTML = '<tr><td class="px-4 py-6 text-zinc-500" colspan="6">No tasks yet.</td></tr>';
      taskDetail.innerHTML = '<p class="text-zinc-500">Select or create a task.</p>';
      return;
    }

    taskRows.innerHTML = state.tasks
      .map(
        (task) => `
          <tr class="${task.id === state.selectedTaskId ? "bg-zinc-800/60" : ""}">
            <td class="px-4 py-3 align-top">
              <button class="text-left font-medium text-white hover:text-cyan-300" data-detail="${task.id}">${escapeHtml(task.name)}</button>
              <div class="mt-1 max-w-xs truncate text-xs text-zinc-500">${escapeHtml(task.description || "")}</div>
            </td>
            <td class="px-4 py-3 align-top text-zinc-300">${escapeHtml(triggerLabel(task.trigger))}</td>
            <td class="px-4 py-3 align-top text-zinc-400">${fmt(task.last_run_at)}</td>
            <td class="px-4 py-3 align-top text-zinc-400">${fmt(task.next_run_at)}</td>
            <td class="px-4 py-3 align-top">${statusBadge(task.status)}</td>
            <td class="px-4 py-3 align-top">
              <div class="flex gap-2">
                <button class="border border-zinc-700 px-2 py-1 text-xs hover:border-cyan-400" data-run="${task.id}">Run</button>
                <button class="border border-zinc-700 px-2 py-1 text-xs hover:border-zinc-300" data-toggle="${task.id}">${task.status === "paused" ? "Resume" : "Pause"}</button>
                <button class="border border-zinc-700 px-2 py-1 text-xs hover:border-red-300" data-delete="${task.id}">Delete</button>
              </div>
            </td>
          </tr>
        `,
      )
      .join("");
  }

  function renderDetail(task, runs) {
    if (!task) {
      taskDetail.innerHTML = '<p class="text-zinc-500">Select or create a task.</p>';
      return;
    }

    taskDetail.innerHTML = `
      <div class="space-y-4">
        <div>
          <h3 class="text-base font-semibold text-white">${escapeHtml(task.name)}</h3>
          <p class="mt-1 text-zinc-400">${escapeHtml(task.description || "")}</p>
        </div>
        <div>
          <div class="mb-2 text-xs uppercase tracking-wider text-zinc-500">Trigger</div>
          <pre class="overflow-auto border border-zinc-800 bg-zinc-950 p-3 text-xs">${escapeHtml(JSON.stringify(task.trigger, null, 2))}</pre>
        </div>
        <div>
          <div class="mb-2 text-xs uppercase tracking-wider text-zinc-500">Actions</div>
          <pre class="overflow-auto border border-zinc-800 bg-zinc-950 p-3 text-xs">${escapeHtml(JSON.stringify(task.actions, null, 2))}</pre>
        </div>
        <div>
          <div class="mb-2 text-xs uppercase tracking-wider text-zinc-500">Recent runs</div>
          <div class="space-y-2">${runs.length ? runs.map(renderRunRow).join("") : '<p class="text-zinc-500">No runs yet.</p>'}</div>
        </div>
      </div>
    `;
  }

  function renderRunRow(run) {
    return `
      <button class="block w-full border border-zinc-800 bg-zinc-950 p-3 text-left hover:border-cyan-400" data-log="${run.id}">
        <div class="flex items-center justify-between gap-3">
          <span>${statusBadge(run.status)}</span>
          <span class="text-xs text-zinc-500">${fmt(run.started_at)}</span>
        </div>
        <div class="mt-2 truncate text-xs text-zinc-400">${escapeHtml(run.error || run.output || "")}</div>
      </button>
    `;
  }

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  async function loadTasks() {
    const data = await api("/tasks");
    state.tasks = data.tasks;
    if (!state.selectedTaskId && state.tasks[0]) state.selectedTaskId = state.tasks[0].id;
    renderTasks();
    if (state.selectedTaskId) await loadDetail(state.selectedTaskId);
  }

  async function loadDetail(id) {
    state.selectedTaskId = id;
    renderTasks();
    const data = await api(`/tasks/${id}`);
    renderDetail(data.task, data.runs);
  }

  async function runTask(id) {
    const data = await api(`/tasks/${id}/run`, { method: "POST", body: "{}" });
    runLog.textContent = JSON.stringify(data.run, null, 2);
    await loadTasks();
  }

  async function toggleTask(id) {
    const task = state.tasks.find((item) => item.id === id);
    await api(`/tasks/${id}/${task && task.status === "paused" ? "resume" : "pause"}`, { method: "POST", body: "{}" });
    await loadTasks();
  }

  async function deleteTask(id) {
    await api(`/tasks/${id}`, { method: "DELETE" });
    if (state.selectedTaskId === id) state.selectedTaskId = "";
    await loadTasks();
  }

  function setPreset(name) {
    const preset = presets[name];
    triggerJson.value = JSON.stringify(preset.trigger, null, 2);
    actionsJson.value = JSON.stringify(preset.actions, null, 2);
  }

  loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    loginError.textContent = "";
    try {
      const data = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: document.getElementById("email").value,
          password: document.getElementById("password").value,
        }),
      }).then(async (response) => {
        const body = await response.json();
        if (!response.ok) throw new Error(body.error || response.statusText);
        return body;
      });
      state.token = data.token;
      window.localStorage.setItem("autopilotToken", state.token);
      showApp();
      await loadTasks();
    } catch (error) {
      loginError.textContent = error.message;
    }
  });

  taskForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    formError.textContent = "";
    try {
      const payload = {
        name: document.getElementById("taskName").value,
        description: document.getElementById("taskDescription").value,
        trigger: JSON.parse(triggerJson.value),
        actions: JSON.parse(actionsJson.value),
      };
      const data = await api("/tasks", { method: "POST", body: JSON.stringify(payload) });
      state.selectedTaskId = data.task.id;
      taskForm.reset();
      setPreset("internship");
      await loadTasks();
    } catch (error) {
      formError.textContent = error.message;
    }
  });

  document.addEventListener("click", async (event) => {
    const target = event.target.closest("button");
    if (!target) return;
    if (target.dataset.detail) await loadDetail(target.dataset.detail);
    if (target.dataset.run) await runTask(target.dataset.run);
    if (target.dataset.toggle) await toggleTask(target.dataset.toggle);
    if (target.dataset.delete) await deleteTask(target.dataset.delete);
    if (target.dataset.log) {
      const data = await api(`/runs/${target.dataset.log}`);
      runLog.textContent = JSON.stringify(data.run, null, 2);
    }
    if (target.dataset.preset) setPreset(target.dataset.preset);
  });

  document.getElementById("refreshButton").addEventListener("click", loadTasks);
  document.getElementById("logoutButton").addEventListener("click", () => {
    state.token = "";
    window.localStorage.removeItem("autopilotToken");
    showApp();
  });

  setPreset("internship");
  showApp();
  if (state.token) loadTasks().catch(() => {
    state.token = "";
    window.localStorage.removeItem("autopilotToken");
    showApp();
  });
})();
