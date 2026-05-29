(function () {
  const allowedTypes = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);
  const maxBytes = 10 * 1024 * 1024;

  const uploadPanel = document.getElementById("uploadPanel");
  const editorPanel = document.getElementById("editorPanel");
  const imageInput = document.getElementById("imageInput");
  const errorText = document.getElementById("errorText");
  const canvas = document.getElementById("canvas");
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  const brushSizeInput = document.getElementById("brushSize");
  const undoButton = document.getElementById("undoButton");
  const downloadButton = document.getElementById("downloadButton");
  const cursorPreview = document.getElementById("cursorPreview");
  const toolButtons = Array.from(document.querySelectorAll("[data-tool]"));
  const dropZone = document.getElementById("dropZone");
  const fileName = document.getElementById("fileName");
  const imageMeta = document.getElementById("imageMeta");
  const brushValue = document.getElementById("brushValue");
  const toolStatus = document.getElementById("toolStatus");
  const historyCount = document.getElementById("historyCount");

  let tool = "black";
  let brushSize = Number(brushSizeInput.value);
  let isDrawing = false;
  let lastPoint = null;
  const history = [];

  function setError(message) {
    errorText.textContent = message || "";
  }

  function setBusy(isBusy) {
    dropZone.classList.toggle("busy", isBusy);
  }

  function updateEditorStatus() {
    brushValue.textContent = `${brushSize}px`;
    historyCount.textContent = String(history.length);
    toolStatus.textContent = `${tool === "black" ? "Black" : "Blur"} brush active`;
  }

  function friendlyFileError(file) {
    if (!file) return "Please choose an image file.";
    if (!allowedTypes.has(file.type)) return "Please choose a JPG, PNG, WEBP, or GIF image.";
    if (file.size > maxBytes) return "That image is larger than 10MB. Please choose a smaller file.";
    return "";
  }

  function pushHistory() {
    if (history.length >= 30) {
      history.shift();
    }
    history.push(ctx.getImageData(0, 0, canvas.width, canvas.height));
    undoButton.disabled = history.length === 0;
    updateEditorStatus();
  }

  function undo() {
    const previous = history.pop();
    if (!previous) return;
    ctx.putImageData(previous, 0, 0);
    undoButton.disabled = history.length === 0;
    updateEditorStatus();
  }

  function canvasPoint(event) {
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;
    return {
      x: (event.clientX - rect.left) * scaleX,
      y: (event.clientY - rect.top) * scaleY,
    };
  }

  function paintBlack(from, to) {
    ctx.save();
    ctx.globalCompositeOperation = "source-over";
    ctx.strokeStyle = "#000";
    ctx.fillStyle = "#000";
    ctx.lineWidth = brushSize;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.beginPath();
    ctx.moveTo(from.x, from.y);
    ctx.lineTo(to.x, to.y);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(to.x, to.y, brushSize / 2, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  function paintBlur(point) {
    const radius = brushSize / 2;
    const sx = Math.max(0, Math.floor(point.x - radius));
    const sy = Math.max(0, Math.floor(point.y - radius));
    const size = Math.ceil(brushSize);
    const sw = Math.min(size, canvas.width - sx);
    const sh = Math.min(size, canvas.height - sy);
    if (sw <= 0 || sh <= 0) return;

    const scratch = document.createElement("canvas");
    scratch.width = sw;
    scratch.height = sh;
    const scratchCtx = scratch.getContext("2d");
    scratchCtx.filter = `blur(${Math.max(6, Math.round(brushSize / 4))}px)`;
    scratchCtx.drawImage(canvas, sx, sy, sw, sh, 0, 0, sw, sh);

    ctx.save();
    ctx.beginPath();
    ctx.arc(point.x, point.y, radius, 0, Math.PI * 2);
    ctx.clip();
    ctx.drawImage(scratch, sx, sy);
    ctx.restore();
  }

  function draw(event) {
    if (!isDrawing) return;
    const point = canvasPoint(event);
    if (tool === "black") {
      paintBlack(lastPoint || point, point);
    } else {
      paintBlur(point);
    }
    lastPoint = point;
  }

  async function storeOriginal(file) {
    const formData = new FormData();
    formData.append("image", file);
    const response = await fetch("/api/upload", {
      method: "POST",
      body: formData,
    });
    if (!response.ok) {
      const data = await response.json().catch(() => ({}));
      throw new Error(data.error || "The image could not be uploaded. Please try again.");
    }
  }

  function loadCanvas(file) {
    const image = new Image();
    image.onload = () => {
      canvas.width = image.naturalWidth;
      canvas.height = image.naturalHeight;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(image, 0, 0);
      history.length = 0;
      undoButton.disabled = true;
      fileName.textContent = file.name;
      imageMeta.textContent = `${image.naturalWidth} x ${image.naturalHeight} px`;
      updateEditorStatus();
      uploadPanel.classList.add("hidden");
      editorPanel.classList.remove("hidden");
      URL.revokeObjectURL(image.src);
    };
    image.onerror = () => setError("That image could not be opened. Please try a different file.");
    image.src = URL.createObjectURL(file);
  }

  async function handleFile(file) {
    const message = friendlyFileError(file);
    if (message) {
      setError(message);
      return;
    }

    setError("");
    setBusy(true);
    try {
      await storeOriginal(file);
      loadCanvas(file);
    } catch (error) {
      setError(error.message);
    } finally {
      setBusy(false);
    }
  }

  imageInput.addEventListener("change", () => {
    handleFile(imageInput.files && imageInput.files[0]);
  });

  ["dragenter", "dragover"].forEach((eventName) => {
    dropZone.addEventListener(eventName, (event) => {
      event.preventDefault();
      dropZone.classList.add("dragging");
    });
  });

  ["dragleave", "drop"].forEach((eventName) => {
    dropZone.addEventListener(eventName, (event) => {
      event.preventDefault();
      dropZone.classList.remove("dragging");
    });
  });

  dropZone.addEventListener("drop", (event) => {
    handleFile(event.dataTransfer.files && event.dataTransfer.files[0]);
  });

  toolButtons.forEach((button) => {
    button.addEventListener("click", () => {
      tool = button.dataset.tool;
      toolButtons.forEach((item) => item.classList.toggle("active", item === button));
      updateEditorStatus();
    });
  });

  brushSizeInput.addEventListener("input", () => {
    brushSize = Number(brushSizeInput.value);
    cursorPreview.style.width = `${brushSize}px`;
    cursorPreview.style.height = `${brushSize}px`;
    updateEditorStatus();
  });

  canvas.addEventListener("pointerdown", (event) => {
    canvas.setPointerCapture(event.pointerId);
    isDrawing = true;
    lastPoint = canvasPoint(event);
    pushHistory();
    draw(event);
  });

  canvas.addEventListener("pointermove", (event) => {
    cursorPreview.style.display = "block";
    cursorPreview.style.left = `${event.clientX}px`;
    cursorPreview.style.top = `${event.clientY}px`;
    draw(event);
  });

  canvas.addEventListener("pointerup", (event) => {
    isDrawing = false;
    lastPoint = null;
    canvas.releasePointerCapture(event.pointerId);
  });

  canvas.addEventListener("pointerleave", () => {
    cursorPreview.style.display = "none";
  });

  undoButton.addEventListener("click", undo);

  downloadButton.addEventListener("click", () => {
    const link = document.createElement("a");
    link.download = `redacted-${Date.now()}.png`;
    link.href = canvas.toDataURL("image/png");
    link.click();
  });

  updateEditorStatus();
})();
