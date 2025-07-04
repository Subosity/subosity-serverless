import { DOMParser } from 'https://deno.land/x/deno_dom/deno-dom-wasm.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { Logger } from '../_shared/logger.ts';
const logger = new Logger('fetch-metadata');
function normalizeUrl(input) {
  try {
    console.log('Attempting to normalize URL:', input);
    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      input = 'https://' + input;
    }
    const url = new URL(input);
    console.log('Normalized URL:', url.protocol + '//' + url.hostname);
    return url.protocol + '//' + url.hostname;
  } catch (e) {
    console.error('Failed to normalize URL:', input, e);
    throw new Error('Invalid URL format');
  }
}
async function fetchWithTimeout(url, options = {}, timeout = 10000) {
  const controller = new AbortController();
  const id = setTimeout(()=>controller.abort(), timeout);
  const response = await fetch(url, {
    ...options,
    signal: controller.signal
  });
  clearTimeout(id);
  return response;
}
async function fetchWithRedirects(url, maxRedirects = 5, timeout = 10000) {
  let response = await fetchWithTimeout(url, {}, timeout);
  let redirects = 0;
  while((response.status === 301 || response.status === 302) && redirects < maxRedirects){
    const location = response.headers.get('location');
    if (!location) break;
    response = await fetchWithTimeout(location, {}, timeout);
    redirects++;
  }
  return response;
}
async function fetchManifestIcons(manifestUrl) {
  try {
    const response = await fetchWithTimeout(manifestUrl);
    const manifest = await response.json();
    return manifest.icons?.map((icon)=>new URL(icon.src, manifestUrl).href) || [];
  } catch (error) {
    logger.error('Failed to fetch or parse manifest:', error);
    return [];
  }
}
Deno.serve(async (req)=>{
  const { pathname } = new URL(req.url);
  // Healthcheck endpoint
  if (pathname.endsWith("/healthcheck")) {
    logger.info('HealthCheck: Verifying health of "fetch-metadata" service');
    return new Response(JSON.stringify({
      status: "ok",
      service: "fetch-metadata",
      version: Deno.env.get('FUNCTION_VERSION') || "unknown"
    }), {
      headers: {
        "Content-Type": "application/json"
      }
    });
  }
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  const url = new URL(req.url);
  const urlInput = url.searchParams.get('domain');
  if (!urlInput) {
    return new Response(JSON.stringify({
      error: 'URL parameter is required'
    }), {
      status: 400,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
  try {
    const normalizedUrl = normalizeUrl(urlInput);
    const response = await fetchWithRedirects(normalizedUrl);
    const html = await response.text();
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');
    // link[rel="icon"] and apple-touch-icon
    const metadataIcons = Array.from(doc.querySelectorAll('link[rel="icon"], link[rel="apple-touch-icon"]')).map((el)=>{
      const href = el.getAttribute('href');
      return href ? new URL(href, normalizedUrl).href : null;
    }).filter(Boolean);
    // Manifest
    const manifestHref = doc.querySelector('link[rel="manifest"]')?.getAttribute('href');
    const manifestUrl = manifestHref ? new URL(manifestHref, normalizedUrl).href : null;
    const manifestIcons = manifestUrl ? await fetchManifestIcons(manifestUrl) : [];
    // og:image fallback
    const ogImage = doc.querySelector('meta[property="og:image"]')?.getAttribute('content');
    const ogImageUrl = ogImage ? new URL(ogImage, normalizedUrl).href : null;
    // favicon.ico fallback
    let rootFavicon = null;
    try {
      const faviconResponse = await fetchWithTimeout(`${normalizedUrl}/favicon.ico`);
      if (faviconResponse.ok && faviconResponse.headers.get("content-type")?.includes("image")) {
        rootFavicon = `${normalizedUrl}/favicon.ico`;
      }
    } catch (_) {
    // ignore favicon fallback errors
    }
    // Merge and de-duplicate
    const allIcons = Array.from(new Set([
      ...metadataIcons,
      ...manifestIcons,
      ogImageUrl,
      rootFavicon
    ].filter(Boolean)));
    const metadata = {
      name: doc.querySelector('meta[property="og:site_name"]')?.getAttribute('content') || doc.querySelector('title')?.textContent || '',
      description: doc.querySelector('meta[name="description"]')?.getAttribute('content') || doc.querySelector('meta[property="og:description"]')?.getAttribute('content') || '',
      icons: allIcons,
      website: normalizedUrl
    };
    return new Response(JSON.stringify(metadata), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    return new Response(JSON.stringify({
      error: 'Failed to fetch metadata: ' + error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
