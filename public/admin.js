(function () {
  const params = new URLSearchParams(window.location.search);
  const key = params.get("key") || "";
  const gallery = document.getElementById("gallery");
  const status = document.getElementById("adminStatus");
  const refreshButton = document.getElementById("refreshButton");
  const dialog = document.getElementById("imageDialog");
  const dialogImage = document.getElementById("dialogImage");
  const closeDialog = document.getElementById("closeDialog");
  const totalFiles = document.getElementById("totalFiles");
  const totalSize = document.getElementById("totalSize");

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

  function imageCard(image) {
    const card = document.createElement("article");
    card.className = "image-card";

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
      <span>${formatBytes(image.size)}</span>
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
      const response = await fetch(`/api/admin/images/${encodeURIComponent(image.filename)}?key=${encodeURIComponent(key)}`, {
        method: "DELETE",
      });
      if (response.ok) {
        card.remove();
        status.textContent = "Image deleted.";
        loadImages();
      } else {
        status.textContent = "Unable to delete image.";
        remove.disabled = false;
      }
    });

    actions.append(download, remove);
    card.append(thumbButton, meta, actions);
    return card;
  }

  async function loadImages() {
    status.textContent = "Loading uploads...";
    gallery.replaceChildren();

    const response = await fetch(`/api/admin/images?key=${encodeURIComponent(key)}`);
    if (!response.ok) {
      status.textContent = "Unable to load uploads.";
      return;
    }

    const data = await response.json();
    const bytes = data.images.reduce((sum, image) => sum + image.size, 0);
    totalFiles.textContent = String(data.images.length);
    totalSize.textContent = formatBytes(bytes);

    if (!data.images.length) {
      status.textContent = "No uploaded images yet.";
      return;
    }

    status.textContent = `${data.images.length} uploaded image${data.images.length === 1 ? "" : "s"}.`;
    gallery.append(...data.images.map(imageCard));
  }

  refreshButton.addEventListener("click", loadImages);
  closeDialog.addEventListener("click", () => dialog.close());
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });

  loadImages();
})();
