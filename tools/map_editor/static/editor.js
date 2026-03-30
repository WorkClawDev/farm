/**
 * Pastoral Tales Map Editor - Main JavaScript
 * Canvas-based tile map editor with brush, eraser, fill, eyedropper tools.
 */

const MAP_COLS = 30;
const MAP_ROWS = 20;
const TILE_SIZE = 16;
const CELL_SIZE_DEFAULT = 24; // display size per tile

// State
let tiles = [];
let selectedTileId = 0;
let currentTool = 'brush';
let isPainting = false;
let zoom = 2;
let showGrid = true;
let cellSize = CELL_SIZE_DEFAULT;
let tileThumbnails = {}; // tileId -> base64 PNG
let tileDefs = [];
let tileImage = null; // full atlas Image

// DOM
const canvas = document.getElementById('map-canvas');
const ctx = canvas.getContext('2d');
const tooltip = document.getElementById('tooltip');
const previewModal = document.getElementById('preview-modal');
const exportModal = document.getElementById('export-modal');
const statusEl = document.getElementById('status');
const cursorPosEl = document.getElementById('cursor-pos');
const selectedTileLabelEl = document.getElementById('selected-tile-label');
const mapSizeEl = document.getElementById('map-size');
const zoomSlider = document.getElementById('zoom-slider');
const zoomLabel = document.getElementById('zoom-label');
const toggleGridCheckbox = document.getElementById('toggle-grid');

// ─── Initialization ─────────────────────────────────────────────────────────

async function init() {
    mapSizeEl.textContent = `${MAP_COLS} × ${MAP_ROWS}`;
    await loadTilePalette();
    await loadMap();
    setupCanvas();
    setupEventListeners();
    render();
}

async function loadTilePalette() {
    try {
        const res = await fetch('/api/tiles');
        const data = await res.json();
        tileDefs = data.tiles || [];
        tileThumbnails = data.thumbnails || {};
        renderTilePalette();
    } catch (e) {
        console.error('Failed to load tiles:', e);
        statusEl.textContent = '加载瓦片失败!';
    }
}

function renderTilePalette() {
    const palette = document.getElementById('tile-palette');
    palette.innerHTML = '';
    for (const tile of tileDefs) {
        const btn = document.createElement('button');
        btn.className = 'tile-btn' + (tile.id === selectedTileId ? ' selected' : '');
        btn.dataset.tileId = tile.id;
        btn.title = `${tile.id}: ${tile.name} (${tile.walkable ? '可通行' : '不可通行'})`;

        if (tileThumbnails[tile.id]) {
            const img = document.createElement('img');
            img.src = 'data:image/png;base64,' + tileThumbnails[tile.id];
            img.alt = tile.name;
            btn.appendChild(img);
        } else {
            // Fallback colored placeholder
            btn.style.background = getPlaceholderColor(tile.id);
            btn.textContent = tile.id;
        }

        const idLabel = document.createElement('span');
        idLabel.className = 'tile-id';
        idLabel.textContent = tile.id;
        btn.appendChild(idLabel);

        const nameLabel = document.createElement('span');
        nameLabel.className = 'tile-name';
        nameLabel.textContent = tile.name;
        btn.appendChild(nameLabel);

        btn.addEventListener('click', () => selectTile(tile.id));
        palette.appendChild(btn);
    }
}

function getPlaceholderColor(id) {
    const colors = [
        '#4a7c59','#3d6b4f','#5a8c69','#6a9c79',  // grasses
        '#c4a35a','#a48c3a','#7a6c2a','#d4b36a',  // dry/path/dirt
        '#3a6a9a','#4a7aaa','#c8b87a','#8a7a5a',  // water/sand
        '#7a5a3a','#9a7a5a','#6a5a4a','#5a4a3a',  // fence/wood/stone/farm
    ];
    return colors[id % colors.length];
}

function selectTile(id) {
    selectedTileId = id;
    document.querySelectorAll('.tile-btn').forEach(btn => {
        btn.classList.toggle('selected', parseInt(btn.dataset.tileId) === id);
    });
    selectedTileLabelEl.textContent = `当前瓦片: ${id} (${tileDefs.find(t=>t.id===id)?.name || '?'})`;
}

// ─── Map Data ────────────────────────────────────────────────────────────────

function createEmptyMap() {
    return Array.from({ length: MAP_ROWS }, () => Array(MAP_COLS).fill(0));
}

async function loadMap() {
    try {
        const res = await fetch('/api/map');
        const data = await res.json();
        tiles = data.tiles || createEmptyMap();
        // Ensure correct dimensions
        while (tiles.length < MAP_ROWS) tiles.push(Array(MAP_COLS).fill(0));
        tiles = tiles.slice(0, MAP_ROWS).map(row => {
            while (row.length < MAP_COLS) row.push(0);
            return row.slice(0, MAP_COLS);
        });
        statusEl.textContent = '地图已加载';
    } catch (e) {
        console.error('Load error:', e);
        tiles = createEmptyMap();
        statusEl.textContent = '使用空白地图';
    }
}

async function saveMap() {
    try {
        const res = await fetch('/api/map', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: 'farm_layout', tiles })
        });
        const data = await res.json();
        if (data.success) {
            statusEl.textContent = '✅ 地图已保存!';
            setTimeout(() => { statusEl.textContent = '就绪'; }, 2000);
        } else {
            statusEl.textContent = '❌ 保存失败: ' + (data.error || '未知错误');
        }
    } catch (e) {
        statusEl.textContent = '❌ 保存失败: ' + e.message;
    }
}

// ─── Canvas Setup ───────────────────────────────────────────────────────────

function setupCanvas() {
    canvas.width = MAP_COLS * cellSize;
    canvas.height = MAP_ROWS * cellSize;
}

function render() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Draw tiles
    for (let row = 0; row < MAP_ROWS; row++) {
        for (let col = 0; col < MAP_COLS; col++) {
            const tileId = tiles[row][col];
            drawTile(col, row, tileId);
        }
    }

    // Draw grid
    if (showGrid) {
        ctx.strokeStyle = 'rgba(255,255,255,0.08)';
        ctx.lineWidth = 1;
        for (let x = 0; x <= MAP_COLS; x++) {
            ctx.beginPath();
            ctx.moveTo(x * cellSize + 0.5, 0);
            ctx.lineTo(x * cellSize + 0.5, canvas.height);
            ctx.stroke();
        }
        for (let y = 0; y <= MAP_ROWS; y++) {
            ctx.beginPath();
            ctx.moveTo(0, y * cellSize + 0.5);
            ctx.lineTo(canvas.width, y * cellSize + 0.5);
            ctx.stroke();
        }
    }
}

function drawTile(col, row, tileId) {
    const x = col * cellSize;
    const y = row * cellSize;

    // Background
    ctx.fillStyle = getPlaceholderColor(tileId);
    ctx.fillRect(x, y, cellSize, cellSize);

    // If we have the atlas thumbnail, draw it scaled
    if (tileThumbnails[tileId]) {
        const img = new Image();
        img.src = 'data:image/png;base64,' + tileThumbnails[tileId];
        img.onload = () => {
            ctx.imageSmoothingEnabled = false;
            ctx.drawImage(img, x, y, cellSize, cellSize);
        };
        // Draw colored rect as fallback until image loads
        ctx.fillStyle = getPlaceholderColor(tileId);
        ctx.fillRect(x, y, cellSize, cellSize);
    }
}

// ─── Event Listeners ─────────────────────────────────────────────────────────

function setupEventListeners() {
    // Canvas mouse events
    canvas.addEventListener('mousedown', onCanvasMouseDown);
    canvas.addEventListener('mousemove', onCanvasMouseMove);
    canvas.addEventListener('mouseup', onCanvasMouseUp);
    canvas.addEventListener('mouseleave', onCanvasMouseLeave);
    canvas.addEventListener('contextmenu', e => e.preventDefault());

    // Tool buttons
    document.querySelectorAll('.tool-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            currentTool = btn.dataset.tool;
            document.querySelectorAll('.tool-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            updateCursor();
        });
    });

    // Action buttons
    document.getElementById('btn-new').addEventListener('click', () => {
        if (confirm('确定新建空白地图吗？当前更改将丢失。')) {
            tiles = createEmptyMap();
            render();
            statusEl.textContent = '空白地图已创建';
        }
    });
    document.getElementById('btn-save').addEventListener('click', saveMap);
    document.getElementById('btn-load').addEventListener('click', async () => {
        if (confirm('加载地图将覆盖当前编辑，是否继续？')) {
            await loadMap();
            render();
        }
    });
    document.getElementById('btn-export').addEventListener('click', exportCode);
    document.getElementById('btn-preview').addEventListener('click', showPreview);

    // Zoom
    zoomSlider.addEventListener('input', () => {
        zoom = parseFloat(zoomSlider.value);
        zoomLabel.textContent = zoom + '×';
        cellSize = Math.round(CELL_SIZE_DEFAULT * zoom);
        setupCanvas();
        render();
    });

    // Grid toggle
    toggleGridCheckbox.addEventListener('change', () => {
        showGrid = toggleGridCheckbox.checked;
        render();
    });

    // Modal close
    document.getElementById('preview-close').addEventListener('click', () => {
        previewModal.style.display = 'none';
    });
    document.getElementById('export-close').addEventListener('click', () => {
        exportModal.style.display = 'none';
    });
    document.getElementById('export-copy').addEventListener('click', () => {
        const ta = document.getElementById('export-code');
        ta.select();
        document.execCommand('copy');
        statusEl.textContent = '✅ 代码已复制到剪贴板!';
        setTimeout(() => { statusEl.textContent = '就绪'; }, 2000);
    });

    // Keyboard shortcuts
    document.addEventListener('keydown', e => {
        if (e.target.tagName === 'TEXTAREA' || e.target.tagName === 'INPUT') return;
        if (e.key === 'b' || e.key === 'B') switchTool('brush');
        if (e.key === 'e' || e.key === 'E') switchTool('eraser');
        if (e.key === 'f' || e.key === 'F') switchTool('fill');
        if (e.key === 'i' || e.key === 'I') switchTool('eyedropper');
        if ((e.ctrlKey || e.metaKey) && e.key === 's') {
            e.preventDefault();
            saveMap();
        }
    });
}

function switchTool(tool) {
    currentTool = tool;
    document.querySelectorAll('.tool-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tool === tool);
    });
    updateCursor();
}

function updateCursor() {
    const cursors = {
        brush: 'crosshair',
        eraser: 'cell',
        fill: 'cell',
        eyedropper: 'copy'
    };
    canvas.style.cursor = cursors[currentTool] || 'crosshair';
}

// ─── Canvas Interaction ───────────────────────────────────────────────────────

function getCellFromEvent(e) {
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;
    const x = (e.clientX - rect.left) * scaleX;
    const y = (e.clientY - rect.top) * scaleY;
    const col = Math.floor(x / cellSize);
    const row = Math.floor(y / cellSize);
    if (col < 0 || col >= MAP_COLS || row < 0 || row >= MAP_ROWS) return null;
    return { col, row };
}

function onCanvasMouseDown(e) {
    e.preventDefault();
    const cell = getCellFromEvent(e);
    if (!cell) return;

    if (e.button === 2) {
        // Right click = eyedropper
        const prev = currentTool;
        currentTool = 'eyedropper';
        applyTool(cell.col, cell.row);
        currentTool = prev;
        return;
    }

    isPainting = true;
    applyTool(cell.col, cell.row);
}

function onCanvasMouseMove(e) {
    const cell = getCellFromEvent(e);

    // Tooltip
    if (cell) {
        cursorPosEl.textContent = `坐标: (${cell.col}, ${cell.row})`;
        tooltip.style.display = 'block';
        tooltip.style.left = (e.clientX + 12) + 'px';
        tooltip.style.top = (e.clientY + 12) + 'px';
        const tileId = tiles[cell.row][cell.col];
        const def = tileDefs.find(t => t.id === tileId);
        tooltip.textContent = `(${cell.col}, ${cell.row}) → ${tileId}: ${def?.name || '?'}`;
    } else {
        tooltip.style.display = 'none';
    }

    if (isPainting && cell) {
        applyTool(cell.col, cell.row);
    }
}

function onCanvasMouseUp() {
    isPainting = false;
}

function onCanvasMouseLeave() {
    isPainting = false;
    tooltip.style.display = 'none';
}

function applyTool(col, row) {
    switch (currentTool) {
        case 'brush':
            tiles[row][col] = selectedTileId;
            break;
        case 'eraser':
            tiles[row][col] = 0; // grass
            break;
        case 'fill':
            floodFill(row, col, tiles[row][col], selectedTileId);
            break;
        case 'eyedropper':
            const id = tiles[row][col];
            selectTile(id);
            statusEl.textContent = `已选择瓦片: ${id}`;
            break;
    }
    render();
}

function floodFill(row, col, targetId, replacementId) {
    if (targetId === replacementId) return;
    const stack = [[row, col]];
    const visited = new Set();
    while (stack.length > 0) {
        const [r, c] = stack.pop();
        const key = r * MAP_COLS + c;
        if (visited.has(key)) continue;
        if (r < 0 || r >= MAP_ROWS || c < 0 || c >= MAP_COLS) continue;
        if (tiles[r][c] !== targetId) continue;
        visited.add(key);
        tiles[r][c] = replacementId;
        stack.push([r - 1, c], [r + 1, c], [r, c - 1], [r, c + 1]);
    }
}

// ─── Export & Preview ────────────────────────────────────────────────────────

async function exportCode() {
    try {
        const res = await fetch('/api/export/gdscript');
        const data = await res.json();
        document.getElementById('export-code').value = data.code || '';
        exportModal.style.display = 'flex';
    } catch (e) {
        // Fallback: generate locally
        let code = '# GDScript array exported from Map Editor\n';
        code += `const EXPORTED_LAYOUT := [\n`;
        for (const row of tiles) {
            code += `\t[${row.join(',')}],\n`;
        }
        code += ']';
        document.getElementById('export-code').value = code;
        exportModal.style.display = 'flex';
    }
}

function showPreview() {
    const previewCanvas = document.getElementById('preview-canvas');
    const pCtx = previewCanvas.getContext('2d');

    const previewCell = 16; // actual tile size
    previewCanvas.width = MAP_COLS * previewCell;
    previewCanvas.height = MAP_ROWS * previewCell;

    // Load full atlas for preview
    if (!tileImage) {
        // Try to draw placeholder colors if atlas not loaded
        for (let row = 0; row < MAP_ROWS; row++) {
            for (let col = 0; col < MAP_COLS; col++) {
                pCtx.fillStyle = getPlaceholderColor(tiles[row][col]);
                pCtx.fillRect(col * previewCell, row * previewCell, previewCell, previewCell);
            }
        }
    }

    // Draw tiles using thumbnails
    for (let row = 0; row < MAP_ROWS; row++) {
        for (let col = 0; col < MAP_COLS; col++) {
            const tileId = tiles[row][col];
            if (tileThumbnails[tileId]) {
                const img = new Image();
                img.src = 'data:image/png;base64,' + tileThumbnails[tileId];
                img.onload = () => {
                    pCtx.imageSmoothingEnabled = false;
                    pCtx.drawImage(img, col * previewCell, row * previewCell, previewCell, previewCell);
                };
            } else {
                pCtx.fillStyle = getPlaceholderColor(tileId);
                pCtx.fillRect(col * previewCell, row * previewCell, previewCell, previewCell);
            }
        }
    }

    previewModal.style.display = 'flex';
}

// ─── Start ──────────────────────────────────────────────────────────────────
init();
