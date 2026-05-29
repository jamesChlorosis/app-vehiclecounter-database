(function () {
  const params = new URLSearchParams(window.location.search);
  const key = params.get("key") || "";
  if (key) {
    window.localStorage.setItem("imagesafeAdminKey", key);
  }
  const gallery = document.getElementById("gallery");
  const status = document.getElementById("adminStatus");
  const refreshButton = document.getElementById("refreshButton");
  const uploadLink = document.getElementById("uploadLink");
  const dialog = document.getElementById("imageDialog");
  const dialogImage = document.getElementById("dialogImage");
  const closeDialog = document.getElementById("closeDialog");
  const totalFiles = document.getElementById("totalFiles");
  const totalSize = document.getElementById("totalSize");
  const uploaded = params.get("uploaded") || "";

  uploadLink.href = key ? `/?key=${encodeURIComponent(key)}` : "/";

  function formatBytes(bytes) {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  }

  function formatDate(value) {
    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium",
      timeStyle: "medium",
    }).format(new Date(value));
  }

  function openVault() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open("imagesafe-vault", 1);
      request.onupgradeneeded = () => {
        request.result.createObjectStore("uploads", { keyPath: "filename" });
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async function listBrowserImages() {
    const db = await openVault();
    const items = await new Promise((resolve, reject) => {
      const tx = db.transaction("uploads", "readonly");
      const request = tx.objectStore("uploads").getAll();
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    db.close();
    return items.map((item) => ({
      ...item,
      source: "browser",
      url: URL.createObjectURL(item.blob),
    }));
  }

  async function deleteBrowserImage(filename) {
    const db = await openVault();
    await new Promise((resolve, reject) => {
      const tx = db.transaction("uploads", "readwrite");
      tx.objectStore("uploads").delete(filename);
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  }

  function imageCard(image) {
    const card = document.createElement("article");
    card.className = "image-card";
    if (image.filename === uploaded) {
      card.classList.add("highlight");
    }

    const thumbButton = document.createElement("button");
    thumbButton.className = "thumb-button";
    thumbButton.type = "button";
    const thumb = document.createElement("img");
    thumb.src = image.url;
    thumb.alt = image.filename;
    thumb.loading = "lazy";
    thumbButton.append(thumb);
    thumbButton.addEventListener("click", () => {
      dialogImage.src = image.url;
      dialogImage.alt = image.filename;
      dialog.showModal();
    });

    const meta = document.createElement("div");
    meta.className = "meta";
    meta.innerHTML = `
      <strong>${image.filename}</strong>
      <span>${formatDate(image.uploadedAt)}</span>
      <span>${formatBytes(image.size)}${image.source === "browser" ? " · browser vault" : ""}</span>
    `;

    const actions = document.createElement("div");
    actions.className = "card-actions";

    const download = document.createElement("a");
    download.href = image.url;
    download.download = image.filename;
    download.textContent = "Download";

    const remove = document.createElement("button");
    remove.className = "danger-button";
    remove.type = "button";
    remove.textContent = "Delete";
    remove.addEventListener("click", async () => {
      remove.disabled = true;
      if (image.source === "browser") {
        await deleteBrowserImage(image.filename);
        card.remove();
        status.textContent = "Image deleted.";
        loadImages();
        return;
      }

      const response = await fetch(`/api/admin/images/${encodeURIComponent(image.filename)}?key=${encodeURIComponent(key)}`, {
        method: "DELETE",
      });
      if (!response.ok) {
        status.textContent = "Unable to delete image.";
        remove.disabled = false;
        return;
      }
      card.remove();
      status.textContent = "Image deleted.";
      loadImages();
    });

    actions.append(download, remove);
    card.append(thumbButton, meta, actions);
    return card;
  }

  async function loadImages() {
    status.textContent = "Loading uploads...";
    gallery.replaceChildren();

    const browserImages = await listBrowserImages();
    let serverImages = [];
    const response = await fetch(`/api/admin/images?key=${encodeURIComponent(key)}`);
    if (response.ok) {
      const data = await response.json();
      serverImages = data.images.map((image) => ({ ...image, source: "server" }));
    }

    const browserNames = new Set(browserImages.map((image) => image.filename));
    const images = [...browserImages, ...serverImages.filter((image) => !browserNames.has(image.filename))].sort(
      (a, b) => new Date(b.uploadedAt) - new Date(a.uploadedAt)
    );

    const bytes = images.reduce((sum, image) => sum + image.size, 0);
    totalFiles.textContent = String(images.length);
    totalSize.textContent = formatBytes(bytes);

    if (!images.length) {
      status.textContent = "No uploaded images yet.";
      return;
    }

    status.textContent = uploaded
      ? "Upload saved. The newest original is available below."
      : `${images.length} uploaded image${images.length === 1 ? "" : "s"}.`;
    gallery.append(...images.map(imageCard));
  }

  refreshButton.addEventListener("click", loadImages);
  closeDialog.addEventListener("click", () => dialog.close());
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });

  loadImages();
})();
