interface JOSMLoadAndZoomParameters {
  select?: ["node" | "way" | "relation", number][];
  addTags?: Record<string, string | null>;
  zoomMode?: "download" | "selection";
  changesetComment?: string;
  changesetSource?: string;
  changesetHashtags?: string[];
  changesetTags?: Record<string, string>;
}

export function loadAndZoom(
  left: number,
  bottom: number,
  right: number,
  top: number,
  params?: JOSMLoadAndZoomParameters,
  callback?: () => void,
) {
  const search = new URLSearchParams();
  search.set("left", String(left));
  search.set("bottom", String(bottom));
  search.set("right", String(right));
  search.set("top", String(top));
  if (params?.select) {
    search.set("select", params.select.map(([type, id]) => `${type}${id}`).join(","));
  }
  if (params?.addTags) {
    search.set(
      "addtags",
      Object.entries(params.addTags)
        .map(([k, v]) => `${k}=${v ?? ""}`)
        .join("|"),
    );
  }
  if (params?.zoomMode) {
    search.set("zoom_mode", params.zoomMode);
  }
  if (params?.changesetComment) {
    search.set("changeset_comment", params.changesetComment);
  }
  if (params?.changesetSource) {
    search.set("changeset_source", params.changesetSource);
  }
  if (params?.changesetHashtags) {
    search.set("changeset_hashtags", params.changesetHashtags.join(","));
  }
  if (params?.changesetTags) {
    search.set(
      "changeset_tags",
      Object.entries(params.changesetTags)
        .map(([k, v]) => `${k}=${v}`)
        .join("|"),
    );
  }
  sendRemoteCommand(`http://127.0.0.1:8111/load_and_zoom?${search.toString()}`, callback);
}

export function addNode(lat: number, lon: number, tags: Record<string, string>, callback?: () => void) {
  const search = new URLSearchParams();
  search.set("lat", String(lat));
  search.set("lon", String(lon));
  search.set(
    "addtags",
    Object.entries(tags)
      .map(([k, v]) => `${k}=${v ?? ""}`)
      .join("|"),
  );
  sendRemoteCommand(`http://127.0.0.1:8111/add_node?${search.toString()}`, callback);
}

function sendRemoteCommand(url: string, callback?: () => void) {
  console.debug("Calling JSOM Remote Control:", url);

  const iframe = document.createElement("iframe");
  iframe.src = url;

  const timeoutId = setTimeout(() => {
    alert("Kunde inte kontakta JOSM");
    iframe.remove();
  }, 5000);

  iframe.addEventListener("load", () => {
    clearTimeout(timeoutId);
    iframe.remove();
    if (callback) callback();
  });
  document.getElementsByTagName("body")[0].append(iframe);
}
