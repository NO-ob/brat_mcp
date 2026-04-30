// ==UserScript==
// @name         Gemma-chan Iframe
// @namespace    http://tampermonkey.net/
// @version      3.2
// @description  Embeds the remote UI into the DOM while rewriting paths with the base tag
// @match        *://localhost:*/*
// @match        *://127.0.0.1:*/*
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    // 1. Inject Styles
    const fontLink = document.createElement('link');
    fontLink.href = 'https://fonts.googleapis.com/css2?family=M+PLUS+Rounded+1c:wght@400;700&display=swap';
    fontLink.rel = 'stylesheet';
    document.head.appendChild(fontLink);

    // 2. Create Floating Container
    const container = document.createElement('div');
    container.id = 'gemma-floating-container';
    container.style.position = 'fixed';
    container.style.bottom = '24px';
    container.style.right = '24px';
    container.style.width = '380px';
    container.style.height = '420px';
    container.style.zIndex = '999999';
    container.style.borderRadius = '1rem';
    container.style.border = '2px solid #374151';
    container.style.boxShadow = '0 8px 32px rgba(0,0,0,0.5)';
    container.style.backgroundColor = '#030712';
    container.style.overflow = 'hidden';
    container.style.resize = 'both';
    container.style.minWidth = '340px';
    container.style.minHeight = '360px';
    container.style.maxWidth = '600px';
    container.style.maxHeight = '600px';

    container.innerHTML = `
        <div id="gemma-header" class="flex justify-between items-center px-3 py-2 bg-gray-900/90 border-b border-gray-800 select-none" style="cursor: move; height: 38px; font-family: 'M PLUS Rounded 1c', sans-serif;">
            <div class="flex items-center gap-2">
                <span class="text-pink-400 font-bold text-xs animate-pulse">● Gemma-chan</span>
            </div>
            <div class="flex items-center gap-2">
                <button id="gemma-min-btn" class="text-gray-400 hover:text-white text-xs">─</button>
                <button id="gemma-close-btn" class="text-gray-500 hover:text-pink-500 text-xs font-bold">✖</button>
            </div>
        </div>

        <div id="gemma-body" style="height: calc(100% - 38px); width: 100%; position: relative;">
            <iframe id="gemma-iframe"
                style="width: 100%; height: 100%; border: none; background: #111827;"
                sandbox="allow-same-origin allow-scripts allow-forms">
            </iframe>
        </div>
    `;

    document.body.appendChild(container);

    // 3. Retrieve and Inject Content
    async function loadIframe() {
        try {
            const res = await fetch('http://127.0.0.1:6969/avatar');
            let html = await res.text();

            // Inject the <base> tag right after the <head> tag to resolve relative paths
            const baseTag = '<base href="http://127.0.0.1:6969/">';
            html = html.replace('<head>', '<head>' + baseTag);

            const iframe = document.getElementById('gemma-iframe');
            if (iframe) {
                iframe.srcdoc = html;
            }
        } catch (e) {
            console.error('Failed to load avatar:', e);
        }
    }

    loadIframe();

    // 4. Drag functionality
    const header = document.getElementById('gemma-header');
    let isDragging = false;
    let offsetX, offsetY;

    header.addEventListener('mousedown', (e) => {
        isDragging = true;
        offsetX = e.clientX - container.getBoundingClientRect().left;
        offsetY = e.clientY - container.getBoundingClientRect().top;
        e.preventDefault();
    });

    window.addEventListener('mousemove', (e) => {
        if (!isDragging) return;
        let newX = e.clientX - offsetX;
        let newY = e.clientY - offsetY;

        newX = Math.max(10, Math.min(newX, window.innerWidth - container.offsetWidth - 10));
        newY = Math.max(10, Math.min(newY, window.innerHeight - container.offsetHeight - 10));

        container.style.left = `${newX}px`;
        container.style.top = `${newY}px`;
        container.style.right = 'unset';
        container.style.bottom = 'unset';
    });

    window.addEventListener('mouseup', () => { isDragging = false; });

    // 5. Minimize / Close Events
    document.getElementById('gemma-min-btn').addEventListener('click', () => {
        const body = document.getElementById('gemma-body');
        const minBtn = document.getElementById('gemma-min-btn');
        if (body.style.display === 'none') {
            body.style.display = 'block';
            container.style.height = '420px';
            minBtn.textContent = '─';
        } else {
            body.style.display = 'none';
            container.style.height = '38px';
            minBtn.textContent = '＋';
        }
    });

    document.getElementById('gemma-close-btn').addEventListener('click', () => {
        container.remove();
    });
})();
