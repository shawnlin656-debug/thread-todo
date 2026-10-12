/**
 * Liquid Glass material.
 *
 * Refraction follows the approach in https://kube.io/blog/liquid-glass-css-svg/:
 * a squircle bezel profile is ray-traced with Snell's law into a displacement map,
 * which an SVG filter applies through backdrop-filter. Only Chromium accepts SVG
 * filters there, so other browsers keep the CSS blur declared in styles.css.
 * The specular rim is drawn from the same surface normals and works everywhere.
 *
 * Usage: give the element `data-glass` (styles.css supplies tint, shadow and the
 * fallback blur), then call `Glass.attach(element, options)`. The element must be
 * positioned and have a uniform border-radius.
 */
"use strict";

/**
 * @typedef {Object} GlassOptions
 * @property {number} [bezel]    Width in px of the curved edge where refraction happens.
 * @property {number} [depth]    Glass thickness in px; a deeper slab bends the backdrop further.
 * @property {number} [blur]     Frosting, as a Gaussian standard deviation in px.
 * @property {number} [saturate] Saturation multiplier applied to the refracted backdrop.
 */

const Glass = (() => {
  const SVG_NS = "http://www.w3.org/2000/svg";
  /** Index of refraction of glass; air is 1. */
  const IOR = 1.5;
  /** Resolution of the 1D refraction lookup across the bezel. */
  const PROFILE_SAMPLES = 128;
  /** Unit vector from the surface toward the light, in screen space (upper left). */
  const TO_LIGHT = { x: -0.6, y: -0.8 };
  /** @type {Required<GlassOptions>} */
  const DEFAULTS = { bezel: 18, depth: 20, blur: 10, saturate: 1.6 };

  const canRefract = /Chrom(e|ium)\//.test(navigator.userAgent) && CSS.supports("backdrop-filter", "url(#glass)");
  /** Per-element bookkeeping: options, the shine layer, last rendered size, current filter. */
  const hosts = new Map();
  let defs;
  let sequence = 0;

  /** @returns {SVGDefsElement} The shared, lazily created container for generated filters. */
  function filterDefs() {
    if (defs) return defs;
    const svg = document.createElementNS(SVG_NS, "svg");
    svg.setAttribute("aria-hidden", "true");
    svg.style.cssText = "position:absolute;width:0;height:0;pointer-events:none";
    defs = svg.appendChild(document.createElementNS(SVG_NS, "defs"));
    document.body.append(svg);
    return defs;
  }

  /**
   * Convex squircle: height of the glass surface from the outer edge (t = 0) to the flat interior (t = 1).
   * @param {number} t
   * @returns {number} Height in the range 0–1.
   */
  const surface = (t) => Math.pow(1 - Math.pow(1 - t, 4), 0.25);

  /**
   * How far, in px, a vertical ray lands from its entry point at each step across the bezel.
   * @param {number} bezel
   * @param {number} depth
   * @returns {Float32Array} Displacement per sample, outer edge first.
   */
  function refractionProfile(bezel, depth) {
    const slab = depth * 0.6;
    const profile = new Float32Array(PROFILE_SAMPLES);
    const delta = 0.001;
    for (let i = 0; i < PROFILE_SAMPLES; i++) {
      const t = (i + 0.5) / PROFILE_SAMPLES;
      const slope = ((surface(Math.min(t + delta, 1)) - surface(Math.max(t - delta, 0))) / (2 * delta)) * (depth / bezel);
      const incidence = Math.atan(slope);
      const refracted = Math.asin(Math.sin(incidence) / IOR);
      profile[i] = Math.tan(incidence - refracted) * (surface(t) * depth + slab);
    }
    return profile;
  }

  /**
   * Nearest-edge query for a rounded rectangle.
   * @param {number} x
   * @param {number} y
   * @param {number} width
   * @param {number} height
   * @param {number} radius
   * @returns {{inside: number, nx: number, ny: number}} Depth inside the shape in px (negative
   *   outside) and the outward unit normal of the nearest edge.
   */
  function edge(x, y, width, height, radius) {
    const cx = x - width / 2;
    const cy = y - height / 2;
    const qx = Math.abs(cx) - (width / 2 - radius);
    const qy = Math.abs(cy) - (height / 2 - radius);
    const sx = cx < 0 ? -1 : 1;
    const sy = cy < 0 ? -1 : 1;
    if (qx > 0 && qy > 0) {
      const length = Math.hypot(qx, qy);
      return { inside: radius - length, nx: (sx * qx) / length, ny: (sy * qy) / length };
    }
    return qx > qy ? { inside: radius - qx, nx: sx, ny: 0 } : { inside: radius - qy, nx: 0, ny: sy };
  }

  /**
   * Encode the refraction as an image: red and green hold the x and y offsets, 128 is neutral.
   * @returns {{url: string, scale: number}} PNG data URL and the matching feDisplacementMap scale.
   */
  function displacementMap(width, height, radius, bezel, depth) {
    const profile = refractionProfile(bezel, depth);
    const reach = Math.max(...profile);
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext("2d");
    const image = context.createImageData(width, height);
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const offset = (y * width + x) * 4;
        const { inside, nx, ny } = edge(x + 0.5, y + 0.5, width, height, radius);
        let bend = 0;
        if (inside >= 0 && inside < bezel) {
          bend = profile[Math.min(PROFILE_SAMPLES - 1, Math.floor((inside / bezel) * PROFILE_SAMPLES))] / reach;
        }
        // A convex bezel pulls its image from further inside the shape.
        image.data[offset] = 128 - 127 * nx * bend;
        image.data[offset + 1] = 128 - 127 * ny * bend;
        image.data[offset + 2] = 128;
        image.data[offset + 3] = 255;
      }
    }
    context.putImageData(image, 0, 0);
    // feDisplacementMap offsets by scale × (channel − 0.5), and the channels span ±127/255.
    return { url: canvas.toDataURL(), scale: (reach * 255) / 127 };
  }

  /**
   * Draw the rim highlight as a white image whose alpha follows how each edge faces the light.
   * @returns {string} PNG data URL at device resolution (capped at 2x).
   */
  function specularMap(width, height, radius, bezel) {
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    const rim = 1.4;
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(width * ratio);
    canvas.height = Math.round(height * ratio);
    const context = canvas.getContext("2d");
    const image = context.createImageData(canvas.width, canvas.height);
    for (let y = 0; y < canvas.height; y++) {
      for (let x = 0; x < canvas.width; x++) {
        const { inside, nx, ny } = edge((x + 0.5) / ratio, (y + 0.5) / ratio, width, height, radius);
        if (inside < 0 || inside >= bezel) continue;
        const facing = nx * TO_LIGHT.x + ny * TO_LIGHT.y;
        // Light catches the edge facing it and exits, dimmer, through the opposite edge.
        const lit = Math.pow(Math.max(facing, 0), 1.6) + 0.5 * Math.pow(Math.max(-facing, 0), 2.2);
        const edgeLine = Math.max(0, 1 - inside / rim);
        const sheen = Math.pow(1 - inside / bezel, 3) * 0.12 * lit;
        const offset = (y * canvas.width + x) * 4;
        image.data[offset] = image.data[offset + 1] = image.data[offset + 2] = 255;
        image.data[offset + 3] = 255 * Math.min(1, edgeLine * (0.16 + 0.84 * lit) + sheen);
      }
    }
    context.putImageData(image, 0, 0);
    return canvas.toDataURL();
  }

  /**
   * Rebuild the shine and, where supported, the refraction filter. No-op if the size is unchanged.
   * @param {HTMLElement} host
   */
  function render(host) {
    const entry = hosts.get(host);
    const width = host.offsetWidth;
    const height = host.offsetHeight;
    if (!width || !height || (width === entry.width && height === entry.height)) return;
    entry.width = width;
    entry.height = height;

    const { blur, saturate, depth } = entry.options;
    const radius = Math.min(parseFloat(getComputedStyle(host).borderTopLeftRadius) || 0, width / 2, height / 2);
    const bezel = Math.min(entry.options.bezel, width / 2, height / 2);
    entry.shine.style.backgroundImage = `url(${specularMap(width, height, radius, bezel)})`;
    if (!canRefract) return;

    const map = displacementMap(width, height, radius, bezel, depth);
    const filter = document.createElementNS(SVG_NS, "filter");
    // A fresh id per render: Chromium does not repaint the backdrop when a referenced filter mutates.
    filter.id = `glass-${++sequence}`;
    for (const [name, value] of Object.entries({ x: 0, y: 0, width, height, filterUnits: "userSpaceOnUse", primitiveUnits: "userSpaceOnUse", "color-interpolation-filters": "sRGB" })) {
      filter.setAttribute(name, value);
    }
    filter.innerHTML = `
      <feGaussianBlur in="SourceGraphic" stdDeviation="${blur}" result="frost" />
      <feImage href="${map.url}" x="0" y="0" width="${width}" height="${height}" preserveAspectRatio="none" result="map" />
      <feDisplacementMap in="frost" in2="map" scale="${map.scale}" xChannelSelector="R" yChannelSelector="G" result="bent" />
      <feColorMatrix in="bent" type="saturate" values="${saturate}" />`;
    filterDefs().append(filter);
    host.style.backdropFilter = `url(#${filter.id})`;
    entry.filter?.remove();
    entry.filter = filter;
  }

  // Both maps are baked for an exact pixel size, so every resize needs a rebuild.
  const resizes = new ResizeObserver((entries) => {
    for (const { target } of entries) requestAnimationFrame(() => render(target));
  });

  /**
   * Turn an element into a glass surface and keep it in sync with its size.
   * @param {HTMLElement} host
   * @param {GlassOptions} [options]
   */
  function attach(host, options = {}) {
    const shine = document.createElement("span");
    shine.className = "glass-shine";
    shine.setAttribute("aria-hidden", "true");
    host.append(shine);
    hosts.set(host, { options: { ...DEFAULTS, ...options }, shine });
    resizes.observe(host);
  }

  return { attach };
})();
