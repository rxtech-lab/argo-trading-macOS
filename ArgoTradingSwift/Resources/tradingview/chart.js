// Helper to send messages to Swift (defined first for console override)
function postMessage(type, data) {
  if (
    window.webkit &&
    window.webkit.messageHandlers &&
    window.webkit.messageHandlers[type]
  ) {
    window.webkit.messageHandlers[type].postMessage(data);
  }
}

// Override console to send logs to Swift
(function () {
  const originalConsole = {
    log: console.log.bind(console),
    warn: console.warn.bind(console),
    error: console.error.bind(console),
  };

  function sendToSwift(level, args) {
    const message = args
      .map((arg) =>
        typeof arg === "object" ? JSON.stringify(arg) : String(arg)
      )
      .join(" ");
    postMessage("consoleLog", { level: level, message: message });
  }

  console.log = function (...args) {
    originalConsole.log(...args);
    sendToSwift("log", args);
  };
  console.warn = function (...args) {
    originalConsole.warn(...args);
    sendToSwift("warn", args);
  };
  console.error = function (...args) {
    originalConsole.error(...args);
    sendToSwift("error", args);
  };
})();

// Global state
let chart = null;
let series = null;
let volumeSeries = null;
let currentChartType = "Candlestick";
let allMarkers = [];
let tradeMarkers = [];
let markMarkers = [];
let dataMap = new Map(); // Map time -> { globalIndex, data }
let isInitialized = false;

// Throttle state for scroll events
let lastScrollEventTime = 0;
let pendingScrollEvent = null;
let scrollThrottleMs = 200; // Only send scroll events at most every 200ms

// Store original marker data for tooltips
let markerDataMap = new Map(); // Map markerId -> full marker data

// Indicator series storage
let indicatorSeries = {
  sma: new Map(), // period -> series
  ema: new Map(), // period -> series
  bollingerBands: null, // { upper, middle, lower }
  rsi: null, // { series, pane }
  macd: null, // { macdLine, signalLine, histogram, pane }
};

// Raw OHLCV data for indicator calculations
let rawData = [];

// Initialize chart with options
function initializeChart(chartType) {
  const container = document.getElementById("chart-container");
  document.getElementById("loading").style.display = "none";

  currentChartType = chartType;

  chart = LightweightCharts.createChart(container, {
    layout: {
      background: { type: "solid", color: "transparent" },
      textColor: "#888888",
      attributionLogo: false,
    },
    grid: {
      vertLines: { color: "rgba(42, 46, 57, 0.5)" },
      horzLines: { color: "rgba(42, 46, 57, 0.5)" },
    },
    crosshair: {
      mode: LightweightCharts.CrosshairMode.MagnetOHLC,
      vertLine: {
        color: "rgba(224, 227, 235, 0.1)",
        width: 1,
        style: 0,
        labelBackgroundColor: "#2B2B43",
      },
      horzLine: {
        color: "rgba(224, 227, 235, 0.1)",
        width: 1,
        style: 0,
        labelBackgroundColor: "#2B2B43",
      },
    },
    rightPriceScale: {
      borderColor: "rgba(197, 203, 206, 0.3)",
      scaleMargins: { top: 0.1, bottom: 0.1 },
    },
    timeScale: {
      borderColor: "rgba(197, 203, 206, 0.3)",
      timeVisible: true,
      secondsVisible: false,
      minBarSpacing: 10,
      maxBarSpacing: 13,
    },
    handleScale: {
      mouseWheel: true,
      pinch: true,
      axisPressedMouseMove: true,
    },
    handleScroll: {
      mouseWheel: true,
      pressedMouseMove: true,
      horzTouchDrag: true,
      vertTouchDrag: false,
    },
    autoSize: true,
  });

  // Create series based on type (v4+ API)
  if (chartType === "Candlestick") {
    series = chart.addSeries(LightweightCharts.CandlestickSeries);
    series.applyOptions({
      upColor: "#26a69a",
      downColor: "#ef5350",
      borderVisible: false,
      wickUpColor: "#26a69a",
      wickDownColor: "#ef5350",
    });
  } else {
    series = chart.addSeries(LightweightCharts.LineSeries);
    series.applyOptions({
      color: "#2196F3",
      lineWidth: 2,
      crosshairMarkerVisible: true,
      crosshairMarkerRadius: 4,
    });
  }

  // Adjust main series scale margins to leave room for volume
  series.priceScale().applyOptions({
    scaleMargins: {
      top: 0.1,
      bottom: 0.3,
    },
  });

  // Create volume series as overlay histogram
  volumeSeries = chart.addSeries(LightweightCharts.HistogramSeries, {
    priceFormat: {
      type: "volume",
    },
    priceScaleId: "", // Empty string creates an overlay
  });

  // Position volume at the bottom 30% of the chart
  volumeSeries.priceScale().applyOptions({
    scaleMargins: {
      top: 0.7,
      bottom: 0,
    },
  });

  // Subscribe to visible range changes for infinite scroll (throttled)
  chart.timeScale().subscribeVisibleLogicalRangeChange((logicalRange) => {
    if (logicalRange === null) return;

    const now = Date.now();
    const eventData = { from: logicalRange.from, to: logicalRange.to };

    // Throttle: only send events at most every scrollThrottleMs
    if (now - lastScrollEventTime >= scrollThrottleMs) {
      lastScrollEventTime = now;
      pendingScrollEvent = null;
      postMessage("visibleRangeChange", eventData);
    } else {
      // Store pending event to send after throttle period
      pendingScrollEvent = eventData;
      setTimeout(() => {
        if (pendingScrollEvent) {
          lastScrollEventTime = Date.now();
          postMessage("visibleRangeChange", pendingScrollEvent);
          pendingScrollEvent = null;
        }
      }, scrollThrottleMs - (now - lastScrollEventTime));
    }
  });

  // Subscribe to crosshair move for OHLCV legend and tooltips
  chart.subscribeCrosshairMove((param) => {
    handleCrosshairMove(param);
  });

  // Handle resize
  const resizeObserver = new ResizeObserver((entries) => {
    if (entries.length > 0 && chart) {
      const { width, height } = entries[0].contentRect;
      chart.resize(width, height);
    }
  });
  resizeObserver.observe(container);

  isInitialized = true;
  postMessage("ready", { success: true });
}

// Handle crosshair movement
function handleCrosshairMove(param) {
  const tooltip = document.getElementById("tooltip");

  if (!param.point || !param.time || param.point.x < 0 || param.point.y < 0) {
    tooltip.style.display = "none";
    postMessage("crosshairMove", {
      time: null,
      price: null,
      globalIndex: null,
      ohlcv: null,
    });
    return;
  }

  const seriesData = param.seriesData.get(series);
  if (!seriesData) return;

  const dataInfo = dataMap.get(param.time);
  const globalIndex = dataInfo ? dataInfo.globalIndex : null;

  // Build OHLCV data
  let ohlcv;
  if (seriesData.open !== undefined) {
    ohlcv = {
      open: seriesData.open,
      high: seriesData.high,
      low: seriesData.low,
      close: seriesData.close,
      volume: dataInfo ? dataInfo.volume : 0,
    };
  } else {
    ohlcv = {
      open: seriesData.value,
      high: seriesData.value,
      low: seriesData.value,
      close: seriesData.value,
      volume: dataInfo ? dataInfo.volume : 0,
    };
  }

  postMessage("crosshairMove", {
    time: param.time,
    price: seriesData.close || seriesData.value,
    globalIndex: globalIndex,
    ohlcv: ohlcv,
  });

  // Check for marker hover
  checkMarkerHover(param);
}

// Check if hovering near a marker
function checkMarkerHover(param) {
  const hoveredTime = param.time;

  // Find markers at or near this time
  const tolerance = 0; // Exact match for now

  // Collect ALL markers at this time
  const matchingMarkers = [];
  for (const [markerId, markerData] of markerDataMap) {
    if (Math.abs(markerData.time - hoveredTime) <= tolerance) {
      matchingMarkers.push(markerData);
    }
  }

  if (matchingMarkers.length > 0) {
    // Send marker data to Swift for native tooltip
    postMessage("markerHover", {
      markers: matchingMarkers,
      screenX: param.point.x,
      screenY: param.point.y,
    });
  } else {
    // No markers - dismiss tooltip
    postMessage("markerHover", null);
  }
}

// Show tooltip for markers (handles multiple markers at same time)
function showMarkerTooltip(markers, point) {
  const tooltip = document.getElementById("tooltip");
  const container = document.getElementById("chart-container");
  const containerRect = container.getBoundingClientRect();

  let html = "";

  // Sort markers: trades first, then marks
  const sortedMarkers = markers.sort((a, b) => {
    if (a.markerType === "trade" && b.markerType !== "trade") return -1;
    if (a.markerType !== "trade" && b.markerType === "trade") return 1;
    return 0;
  });

  sortedMarkers.forEach((markerData, index) => {
    // Add separator between multiple markers
    if (index > 0) {
      html += `<div class="tooltip-separator"></div>`;
    }

    if (markerData.markerType === "trade") {
      const isBuy = markerData.isBuy;
      const arrow = isBuy ? "&#9650;" : "&#9660;";
      const colorClass = isBuy ? "buy" : "sell";
      const sectionClass = isBuy ? "trade" : "trade sell";

      html += `<div class="tooltip-section ${sectionClass}">`;
      html += `<div class="tooltip-section-label">Trade</div>`;
      html += `
              <div class="tooltip-header">
                  <div class="tooltip-icon ${colorClass}">${arrow}</div>
                  <div class="tooltip-title">${isBuy ? "BUY" : "SELL"}</div>
                  <div class="tooltip-chip trade">TRADE</div>
              </div>
              <div class="tooltip-row">
                  <span class="tooltip-label">Symbol</span>
                  <span class="tooltip-value">${markerData.symbol || "-"}</span>
              </div>
              <div class="tooltip-row">
                  <span class="tooltip-label">Position</span>
                  <span class="tooltip-value">${
                    markerData.positionType || "-"
                  }</span>
              </div>
              <div class="tooltip-row">
                  <span class="tooltip-label">Date</span>
                  <span class="tooltip-value">${formatDate(
                    markerData.time
                  )}</span>
              </div>
              <div class="tooltip-row">
                  <span class="tooltip-label">Qty</span>
                  <span class="tooltip-value">${formatNumber(
                    markerData.executedQty,
                    4
                  )}</span>
              </div>
              <div class="tooltip-row">
                  <span class="tooltip-label">Price</span>
                  <span class="tooltip-value">${formatNumber(
                    markerData.executedPrice,
                    2
                  )}</span>
              </div>
          `;

      if (!isBuy && markerData.pnl !== undefined) {
        const pnlClass = markerData.pnl >= 0 ? "pnl-positive" : "pnl-negative";
        html += `
                  <div class="tooltip-row">
                      <span class="tooltip-label">PnL</span>
                      <span class="tooltip-value ${pnlClass}">${formatNumber(
          markerData.pnl,
          2
        )}</span>
                  </div>
              `;
      }

      if (markerData.reason) {
        html += `<div class="tooltip-reason">${markerData.reason}</div>`;
      }
      html += `</div>`; // Close tooltip-section
    } else if (markerData.markerType === "mark") {
      html += `<div class="tooltip-section mark">`;
      html += `<div class="tooltip-section-label">Signal</div>`;
      html += `
              <div class="tooltip-header">
                  <div class="tooltip-icon" style="color: ${
                    markerData.color
                  };">&#9679;</div>
                  <div class="tooltip-title">${markerData.title || "Mark"}</div>
                  <div class="tooltip-chip mark">SIGNAL</div>
              </div>
          `;

      if (markerData.category) {
        html += `
                  <div class="tooltip-row">
                      <span class="tooltip-label">Category</span>
                      <span class="tooltip-value">${markerData.category}</span>
                  </div>
              `;
      }

      if (markerData.signalType) {
        html += `
                  <div class="tooltip-row">
                      <span class="tooltip-label">Signal</span>
                      <span class="tooltip-value">${markerData.signalType}</span>
                  </div>
              `;
      }

      if (markerData.message) {
        html += `<div class="tooltip-reason">${markerData.message}</div>`;
      }

      if (markerData.signalReason) {
        html += `<div class="tooltip-reason">${markerData.signalReason}</div>`;
      }
      html += `</div>`; // Close tooltip-section
    }
  });

  tooltip.innerHTML = html;
  tooltip.style.display = "block";

  // Position tooltip
  let left = point.x + 15;
  let top = point.y - 10;

  // Adjust if tooltip would go off screen
  const tooltipRect = tooltip.getBoundingClientRect();
  if (left + tooltipRect.width > containerRect.width) {
    left = point.x - tooltipRect.width - 15;
  }
  if (top + tooltipRect.height > containerRect.height) {
    top = containerRect.height - tooltipRect.height - 10;
  }
  if (top < 10) top = 10;

  tooltip.style.left = left + "px";
  tooltip.style.top = top + "px";
}
// Format number
function formatNumber(value, decimals) {
  if (value === undefined || value === null) return "-";
  return value.toFixed(decimals);
}

// Format date from Unix timestamp
function formatDate(timestamp) {
  if (!timestamp) return "-";
  const date = new Date(timestamp * 1000);
  return date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

// Set candlestick data
function setCandlestickData(data) {
  console.log(
    "[Chart] setCandlestickData called with",
    data ? data.length : 0,
    "items"
  );
  if (!series) {
    console.error("[Chart] setCandlestickData: series is null");
    return;
  }
  if (!data || data.length === 0) {
    console.warn("[Chart] setCandlestickData: no data provided");
    return;
  }

  console.log("[Chart] First item:", JSON.stringify(data[0]));
  console.log("[Chart] Last item:", JSON.stringify(data[data.length - 1]));

  // Store raw data for indicator calculations
  rawData = data.map((d) => ({
    time: d.time,
    open: d.open,
    high: d.high,
    low: d.low,
    close: d.close,
    volume: d.volume || 0,
  }));

  dataMap.clear();
  const formattedData = data.map((d) => {
    dataMap.set(d.time, {
      globalIndex: d.globalIndex,
      volume: d.volume || 0,
    });
    return {
      time: d.time,
      open: d.open,
      high: d.high,
      low: d.low,
      close: d.close,
    };
  });

  console.log("[Chart] Setting", formattedData.length, "candles to series");
  series.setData(formattedData);

  // Set volume data with color based on candle direction
  if (volumeSeries) {
    const volumeData = data.map((d) => ({
      time: d.time,
      value: d.volume || 0,
      color:
        d.close >= d.open
          ? "rgba(38, 166, 154, 0.5)"
          : "rgba(239, 83, 80, 0.5)",
    }));
    volumeSeries.setData(volumeData);
  }

  // Recalculate any active indicators with the new data
  recalculateIndicators();

  console.log("[Chart] Data set complete");
}

// Set line data
function setLineData(data) {
  if (!series) return;

  // Store raw data for indicator calculations (use value as close for line charts)
  rawData = data.map((d) => ({
    time: d.time,
    open: d.value,
    high: d.value,
    low: d.value,
    close: d.value,
    volume: d.volume || 0,
  }));

  dataMap.clear();
  const formattedData = data.map((d) => {
    dataMap.set(d.time, {
      globalIndex: d.globalIndex,
      volume: d.volume || 0,
    });
    return {
      time: d.time,
      value: d.value,
    };
  });

  series.setData(formattedData);

  // Set volume data (neutral color for line charts)
  if (volumeSeries) {
    const volumeData = data.map((d) => ({
      time: d.time,
      value: d.volume || 0,
      color: "rgba(33, 150, 243, 0.5)",
    }));
    volumeSeries.setData(volumeData);
  }

  // Recalculate any active indicators with the new data
  recalculateIndicators();
}

// Update single data point (for streaming)
function updateCandlestickData(data) {
  if (!series) return;

  dataMap.set(data.time, {
    globalIndex: data.globalIndex,
    volume: data.volume || 0,
  });
  series.update({
    time: data.time,
    open: data.open,
    high: data.high,
    low: data.low,
    close: data.close,
  });

  // Update volume
  if (volumeSeries) {
    volumeSeries.update({
      time: data.time,
      value: data.volume || 0,
      color:
        data.close >= data.open
          ? "rgba(38, 166, 154, 0.5)"
          : "rgba(239, 83, 80, 0.5)",
    });
  }
}

// Update single line data point
function updateLineData(data) {
  if (!series) return;

  dataMap.set(data.time, {
    globalIndex: data.globalIndex,
    volume: data.volume || 0,
  });
  series.update({
    time: data.time,
    value: data.value,
  });

  // Update volume
  if (volumeSeries) {
    volumeSeries.update({
      time: data.time,
      value: data.volume || 0,
      color: "rgba(33, 150, 243, 0.5)",
    });
  }
}

// Set markers (trades and marks)
function setMarkers(markerData) {
  if (!series) return;

  markerDataMap.clear();
  tradeMarkers = [];
  markMarkers = [];

  markerData.forEach((m) => {
    // Store full marker data for tooltip
    markerDataMap.set(m.id, m);

    const marker = {
      time: m.time,
      position: m.position,
      color: m.color,
      shape: m.shape,
      text: m.text,
      id: m.id,
    };

    if (m.markerType === "trade") {
      tradeMarkers.push(marker);
    } else {
      markMarkers.push(marker);
    }
  });

  updateVisibleMarkers();
}

// Update markers on the chart
function updateVisibleMarkers() {
  if (!series) return;

  // Combine all markers and sort by time
  const allMarkers = [...tradeMarkers, ...markMarkers];
  allMarkers.sort((a, b) => a.time - b.time);

  console.log("[Chart] Updating visible markers:", allMarkers.length);
  try {
    // series.setMarkers(allMarkers);
    LightweightCharts.createSeriesMarkers(series, allMarkers);
  } catch (error) {
    console.error(`[Chart] Error updating visible markers: ${error}`);
  }
}

// Clear all markers
function clearAllMarkers() {
  if (!series) return;

  tradeMarkers = [];
  markMarkers = [];
  markerDataMap.clear();
  try {
    console.log("[Chart] Clearing markers");
    LightweightCharts.createSeriesMarkers(series, []);
  } catch (error) {
    console.error(`[Chart] Error clearing markers: ${error}`);
  }
}

// Scroll to specific time (centers view on the timestamp)
function scrollToTime(timestamp) {
  if (!chart || !series) return;

  // Find data point closest to timestamp
  let closestTime = null;
  let minDiff = Infinity;

  dataMap.forEach((info, time) => {
    const diff = Math.abs(time - timestamp);
    if (diff < minDiff) {
      minDiff = diff;
      closestTime = time;
    }
  });

  if (closestTime !== null) {
    // Get visible range width to keep same zoom level
    const currentRange = chart.timeScale().getVisibleLogicalRange();
    if (currentRange) {
      const rangeWidth = currentRange.to - currentRange.from;
      // Find logical index for this time
      const dataArray = Array.from(dataMap.keys()).sort((a, b) => a - b);
      const logicalIndex = dataArray.indexOf(closestTime);
      if (logicalIndex >= 0) {
        const halfWidth = rangeWidth / 2;
        chart.timeScale().setVisibleLogicalRange({
          from: logicalIndex - halfWidth,
          to: logicalIndex + halfWidth,
        });
      }
    }
  }
}

// Set visible logical range
function setVisibleRange(from, to) {
  if (!chart) return;
  chart.timeScale().setVisibleLogicalRange({ from: from, to: to });
}

// Resize chart
function resizeChart(width, height) {
  if (!chart) return;
  chart.resize(width, height);
}

// Fit content to view
function fitContent() {
  if (!chart) return;
  chart.timeScale().fitContent();
}

// Scroll to realtime (latest data)
function scrollToRealtime() {
  if (!chart) return;
  chart.timeScale().scrollToRealTime();
}

// Get visible range (called from Swift to get current range)
function getVisibleRange() {
  if (!chart) return null;
  return chart.timeScale().getVisibleLogicalRange();
}

// Switch chart type
function switchChartType(newType) {
  if (!chart || currentChartType === newType) return;

  // Store current data
  const currentData = [];
  dataMap.forEach((info, time) => {
    currentData.push({ time, ...info });
  });

  // Remove old series
  chart.removeSeries(series);

  // Create new series (v4+ API)
  currentChartType = newType;
  if (newType === "Candlestick") {
    series = chart.addSeries(LightweightCharts.CandlestickSeries);
    series.applyOptions({
      upColor: "#26a69a",
      downColor: "#ef5350",
      borderVisible: false,
      wickUpColor: "#26a69a",
      wickDownColor: "#ef5350",
    });
  } else {
    series = chart.addSeries(LightweightCharts.LineSeries);
    series.applyOptions({
      color: "#2196F3",
      lineWidth: 2,
      crosshairMarkerVisible: true,
      crosshairMarkerRadius: 4,
    });
  }

  // Apply scale margins to new series (to leave room for volume)
  series.priceScale().applyOptions({
    scaleMargins: {
      top: 0.1,
      bottom: 0.3,
    },
  });

  // Restore markers
  updateVisibleMarkers();
}

// ============================================================================
// TECHNICAL INDICATORS
// ============================================================================

// Indicator colors
const INDICATOR_COLORS = {
  sma20: "#FF6B6B",
  sma50: "#4ECDC4",
  sma200: "#45B7D1",
  ema12: "#96CEB4",
  ema26: "#FFEAA7",
  bollingerUpper: "#DDA0DD",
  bollingerMiddle: "#9370DB",
  bollingerLower: "#DDA0DD",
  rsi: "#FF9F43",
  macdLine: "#6C5CE7",
  signalLine: "#FD79A8",
  histogram: "#74B9FF",
};

// Calculate Simple Moving Average
function calculateSMA(data, period) {
  const result = [];
  for (let i = 0; i < data.length; i++) {
    if (i < period - 1) {
      continue;
    }
    let sum = 0;
    for (let j = 0; j < period; j++) {
      sum += data[i - j].close;
    }
    result.push({
      time: data[i].time,
      value: sum / period,
    });
  }
  return result;
}

// Calculate Exponential Moving Average
function calculateEMA(data, period) {
  const result = [];
  const multiplier = 2 / (period + 1);

  // Start with SMA for first value
  let sum = 0;
  for (let i = 0; i < period && i < data.length; i++) {
    sum += data[i].close;
  }

  if (data.length >= period) {
    let ema = sum / period;
    result.push({
      time: data[period - 1].time,
      value: ema,
    });

    for (let i = period; i < data.length; i++) {
      ema = (data[i].close - ema) * multiplier + ema;
      result.push({
        time: data[i].time,
        value: ema,
      });
    }
  }
  return result;
}

// Calculate Bollinger Bands
function calculateBollingerBands(data, period = 20, stdDev = 2) {
  const upper = [];
  const middle = [];
  const lower = [];

  for (let i = period - 1; i < data.length; i++) {
    // Calculate SMA
    let sum = 0;
    for (let j = 0; j < period; j++) {
      sum += data[i - j].close;
    }
    const sma = sum / period;

    // Calculate standard deviation
    let squaredSum = 0;
    for (let j = 0; j < period; j++) {
      squaredSum += Math.pow(data[i - j].close - sma, 2);
    }
    const std = Math.sqrt(squaredSum / period);

    const time = data[i].time;
    upper.push({ time, value: sma + stdDev * std });
    middle.push({ time, value: sma });
    lower.push({ time, value: sma - stdDev * std });
  }

  return { upper, middle, lower };
}

// Calculate RSI
function calculateRSI(data, period = 14) {
  const result = [];
  if (data.length < period + 1) return result;

  let gains = 0;
  let losses = 0;

  // Calculate initial average gain/loss
  for (let i = 1; i <= period; i++) {
    const change = data[i].close - data[i - 1].close;
    if (change >= 0) {
      gains += change;
    } else {
      losses -= change;
    }
  }

  let avgGain = gains / period;
  let avgLoss = losses / period;

  // First RSI value
  const rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
  result.push({
    time: data[period].time,
    value: 100 - 100 / (1 + rs),
  });

  // Calculate subsequent RSI values using smoothed averages
  for (let i = period + 1; i < data.length; i++) {
    const change = data[i].close - data[i - 1].close;
    const currentGain = change >= 0 ? change : 0;
    const currentLoss = change < 0 ? -change : 0;

    avgGain = (avgGain * (period - 1) + currentGain) / period;
    avgLoss = (avgLoss * (period - 1) + currentLoss) / period;

    const rsi = avgLoss === 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss);
    result.push({
      time: data[i].time,
      value: rsi,
    });
  }

  return result;
}

// Calculate MACD
function calculateMACD(data, fastPeriod = 12, slowPeriod = 26, signalPeriod = 9) {
  const fastEMA = calculateEMA(data, fastPeriod);
  const slowEMA = calculateEMA(data, slowPeriod);

  // Create a map for fast lookup
  const fastMap = new Map(fastEMA.map((d) => [d.time, d.value]));
  const slowMap = new Map(slowEMA.map((d) => [d.time, d.value]));

  // Calculate MACD line (fast - slow)
  const macdLine = [];
  for (const point of slowEMA) {
    const fastValue = fastMap.get(point.time);
    if (fastValue !== undefined) {
      macdLine.push({
        time: point.time,
        value: fastValue - point.value,
      });
    }
  }

  // Calculate signal line (EMA of MACD line)
  const signalLine = [];
  if (macdLine.length >= signalPeriod) {
    const multiplier = 2 / (signalPeriod + 1);

    // Start with SMA
    let sum = 0;
    for (let i = 0; i < signalPeriod; i++) {
      sum += macdLine[i].value;
    }
    let ema = sum / signalPeriod;
    signalLine.push({
      time: macdLine[signalPeriod - 1].time,
      value: ema,
    });

    for (let i = signalPeriod; i < macdLine.length; i++) {
      ema = (macdLine[i].value - ema) * multiplier + ema;
      signalLine.push({
        time: macdLine[i].time,
        value: ema,
      });
    }
  }

  // Calculate histogram
  const signalMap = new Map(signalLine.map((d) => [d.time, d.value]));
  const histogram = [];
  for (const point of macdLine) {
    const signalValue = signalMap.get(point.time);
    if (signalValue !== undefined) {
      const value = point.value - signalValue;
      histogram.push({
        time: point.time,
        value: value,
        color: value >= 0 ? "rgba(38, 166, 154, 0.7)" : "rgba(239, 83, 80, 0.7)",
      });
    }
  }

  return { macdLine, signalLine, histogram };
}

// Add SMA indicator
function addSMA(period) {
  if (!chart || !rawData.length) return;

  // Remove existing SMA with same period
  removeSMA(period);

  const smaData = calculateSMA(rawData, period);
  if (smaData.length === 0) return;

  const colorKey = `sma${period}`;
  const color = INDICATOR_COLORS[colorKey] || "#FF6B6B";

  const smaSeries = chart.addSeries(LightweightCharts.LineSeries, {
    priceScaleId: "right",
  });
  smaSeries.applyOptions({
    color: color,
    lineWidth: 1,
    crosshairMarkerVisible: false,
    title: `SMA ${period}`,
  });
  smaSeries.setData(smaData);

  indicatorSeries.sma.set(period, smaSeries);
  console.log(`[Chart] Added SMA ${period}`);
}

// Remove SMA indicator
function removeSMA(period) {
  if (!chart) return;

  const smaSeries = indicatorSeries.sma.get(period);
  if (smaSeries) {
    chart.removeSeries(smaSeries);
    indicatorSeries.sma.delete(period);
    console.log(`[Chart] Removed SMA ${period}`);
  }
}

// Add EMA indicator
function addEMA(period) {
  if (!chart || !rawData.length) return;

  // Remove existing EMA with same period
  removeEMA(period);

  const emaData = calculateEMA(rawData, period);
  if (emaData.length === 0) return;

  const colorKey = `ema${period}`;
  const color = INDICATOR_COLORS[colorKey] || "#96CEB4";

  const emaSeries = chart.addSeries(LightweightCharts.LineSeries, {
    priceScaleId: "right",
  });
  emaSeries.applyOptions({
    color: color,
    lineWidth: 1,
    crosshairMarkerVisible: false,
    title: `EMA ${period}`,
  });
  emaSeries.setData(emaData);

  indicatorSeries.ema.set(period, emaSeries);
  console.log(`[Chart] Added EMA ${period}`);
}

// Remove EMA indicator
function removeEMA(period) {
  if (!chart) return;

  const emaSeries = indicatorSeries.ema.get(period);
  if (emaSeries) {
    chart.removeSeries(emaSeries);
    indicatorSeries.ema.delete(period);
    console.log(`[Chart] Removed EMA ${period}`);
  }
}

// Add Bollinger Bands
function addBollingerBands(period = 20, stdDev = 2) {
  if (!chart || !rawData.length) return;

  // Remove existing Bollinger Bands
  removeBollingerBands();

  const bbData = calculateBollingerBands(rawData, period, stdDev);
  if (bbData.upper.length === 0) return;

  // Upper band
  const upperSeries = chart.addSeries(LightweightCharts.LineSeries, {
    priceScaleId: "right",
  });
  upperSeries.applyOptions({
    color: INDICATOR_COLORS.bollingerUpper,
    lineWidth: 1,
    lineStyle: 2, // Dashed
    crosshairMarkerVisible: false,
  });
  upperSeries.setData(bbData.upper);

  // Middle band (SMA)
  const middleSeries = chart.addSeries(LightweightCharts.LineSeries, {
    priceScaleId: "right",
  });
  middleSeries.applyOptions({
    color: INDICATOR_COLORS.bollingerMiddle,
    lineWidth: 1,
    crosshairMarkerVisible: false,
    title: "BB",
  });
  middleSeries.setData(bbData.middle);

  // Lower band
  const lowerSeries = chart.addSeries(LightweightCharts.LineSeries, {
    priceScaleId: "right",
  });
  lowerSeries.applyOptions({
    color: INDICATOR_COLORS.bollingerLower,
    lineWidth: 1,
    lineStyle: 2, // Dashed
    crosshairMarkerVisible: false,
  });
  lowerSeries.setData(bbData.lower);

  indicatorSeries.bollingerBands = {
    upper: upperSeries,
    middle: middleSeries,
    lower: lowerSeries,
  };
  console.log("[Chart] Added Bollinger Bands");
}

// Remove Bollinger Bands
function removeBollingerBands() {
  if (!chart || !indicatorSeries.bollingerBands) return;

  chart.removeSeries(indicatorSeries.bollingerBands.upper);
  chart.removeSeries(indicatorSeries.bollingerBands.middle);
  chart.removeSeries(indicatorSeries.bollingerBands.lower);
  indicatorSeries.bollingerBands = null;
  console.log("[Chart] Removed Bollinger Bands");
}

// Add RSI indicator
function addRSI(period = 14) {
  if (!chart || !rawData.length) return;

  // Remove existing RSI
  removeRSI();

  const rsiData = calculateRSI(rawData, period);
  if (rsiData.length === 0) return;

  // Create RSI series in a separate pane
  const rsiSeries = chart.addSeries(LightweightCharts.LineSeries, {
    priceScaleId: "rsi",
  });
  rsiSeries.applyOptions({
    color: INDICATOR_COLORS.rsi,
    lineWidth: 2,
    crosshairMarkerVisible: true,
    title: "RSI",
    priceFormat: {
      type: "custom",
      formatter: (price) => price.toFixed(1),
    },
  });

  // Position RSI at the bottom
  rsiSeries.priceScale().applyOptions({
    scaleMargins: {
      top: 0.8,
      bottom: 0.02,
    },
    borderVisible: true,
    autoScale: false,
    entireTextOnly: true,
  });

  rsiSeries.setData(rsiData);

  indicatorSeries.rsi = { series: rsiSeries };
  console.log("[Chart] Added RSI");
}

// Remove RSI indicator
function removeRSI() {
  if (!chart || !indicatorSeries.rsi) return;

  chart.removeSeries(indicatorSeries.rsi.series);
  indicatorSeries.rsi = null;
  console.log("[Chart] Removed RSI");
}

// Add MACD indicator
function addMACD(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9) {
  if (!chart || !rawData.length) return;

  // Remove existing MACD
  removeMACD();

  const macdData = calculateMACD(rawData, fastPeriod, slowPeriod, signalPeriod);
  if (macdData.macdLine.length === 0) return;

  // Create histogram
  const histogramSeries = chart.addSeries(LightweightCharts.HistogramSeries, {
    priceScaleId: "macd",
  });
  histogramSeries.applyOptions({
    priceFormat: {
      type: "custom",
      formatter: (price) => price.toFixed(4),
    },
  });
  histogramSeries.setData(macdData.histogram);

  // MACD line
  const macdLineSeries = chart.addSeries(LightweightCharts.LineSeries, {
    priceScaleId: "macd",
  });
  macdLineSeries.applyOptions({
    color: INDICATOR_COLORS.macdLine,
    lineWidth: 2,
    crosshairMarkerVisible: false,
    title: "MACD",
    priceFormat: {
      type: "custom",
      formatter: (price) => price.toFixed(4),
    },
  });
  macdLineSeries.setData(macdData.macdLine);

  // Signal line
  const signalLineSeries = chart.addSeries(LightweightCharts.LineSeries, {
    priceScaleId: "macd",
  });
  signalLineSeries.applyOptions({
    color: INDICATOR_COLORS.signalLine,
    lineWidth: 1,
    crosshairMarkerVisible: false,
    priceFormat: {
      type: "custom",
      formatter: (price) => price.toFixed(4),
    },
  });
  signalLineSeries.setData(macdData.signalLine);

  // Position MACD at the bottom
  macdLineSeries.priceScale().applyOptions({
    scaleMargins: {
      top: 0.85,
      bottom: 0.02,
    },
    borderVisible: true,
  });

  indicatorSeries.macd = {
    macdLine: macdLineSeries,
    signalLine: signalLineSeries,
    histogram: histogramSeries,
  };
  console.log("[Chart] Added MACD");
}

// Remove MACD indicator
function removeMACD() {
  if (!chart || !indicatorSeries.macd) return;

  chart.removeSeries(indicatorSeries.macd.histogram);
  chart.removeSeries(indicatorSeries.macd.macdLine);
  chart.removeSeries(indicatorSeries.macd.signalLine);
  indicatorSeries.macd = null;
  console.log("[Chart] Removed MACD");
}

// Show/hide volume
function showVolume(visible) {
  if (!volumeSeries) return;

  if (visible) {
    volumeSeries.applyOptions({
      visible: true,
    });
    console.log("[Chart] Volume shown");
  } else {
    volumeSeries.applyOptions({
      visible: false,
    });
    console.log("[Chart] Volume hidden");
  }
}

// Remove all indicators
function removeAllIndicators() {
  // Remove all SMAs
  for (const [period] of indicatorSeries.sma) {
    removeSMA(period);
  }

  // Remove all EMAs
  for (const [period] of indicatorSeries.ema) {
    removeEMA(period);
  }

  // Remove Bollinger Bands
  removeBollingerBands();

  // Remove RSI
  removeRSI();

  // Remove MACD
  removeMACD();

  console.log("[Chart] All indicators removed");
}

// Recalculate all active indicators (called after data update)
function recalculateIndicators() {
  // Store active indicators
  const activeSMA = Array.from(indicatorSeries.sma.keys());
  const activeEMA = Array.from(indicatorSeries.ema.keys());
  const hasBB = indicatorSeries.bollingerBands !== null;
  const hasRSI = indicatorSeries.rsi !== null;
  const hasMACD = indicatorSeries.macd !== null;

  // Re-add active indicators with new data
  for (const period of activeSMA) {
    addSMA(period);
  }
  for (const period of activeEMA) {
    addEMA(period);
  }
  if (hasBB) {
    addBollingerBands(20, 2);
  }
  if (hasRSI) {
    addRSI(14);
  }
  if (hasMACD) {
    addMACD(12, 26, 9);
  }
}

// Signal to Swift that JavaScript is ready (all functions are defined)
postMessage("pageLoaded", { success: true });
