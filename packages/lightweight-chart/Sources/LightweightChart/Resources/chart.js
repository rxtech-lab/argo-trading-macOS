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
let dataMap = new Map(); // Map time -> { globalIndex, open, high, low, close, volume }
let isInitialized = false;
let indicatorSeries = new Map(); // Map indicatorId -> { series, signalSeries?, histogramSeries? }
let currentIndicatorSettings = null;

// Throttle state for scroll events
let lastScrollEventTime = 0;
let pendingScrollEvent = null;
let scrollThrottleMs = 200; // Only send scroll events at most every 200ms

// Store original marker data for tooltips
let markerDataMap = new Map(); // Map markerId -> full marker data

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

  dataMap.clear();
  const formattedData = data.map((d) => {
    dataMap.set(d.time, {
      globalIndex: d.globalIndex,
      volume: d.volume || 0,
      open: d.open,
      high: d.high,
      low: d.low,
      close: d.close,
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

  // Update indicators with new data
  if (currentIndicatorSettings) {
    updateIndicatorSeries();
  }

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
  console.log("[Chart] Data set complete");
}

// Set line data
function setLineData(data) {
  if (!series) return;

  dataMap.clear();
  const formattedData = data.map((d) => {
    dataMap.set(d.time, {
      globalIndex: d.globalIndex,
      volume: d.volume || 0,
      open: d.value,
      high: d.value,
      low: d.value,
      close: d.value,
    });
    return {
      time: d.time,
      value: d.value,
    };
  });

  series.setData(formattedData);

  // Update indicators with new data
  if (currentIndicatorSettings) {
    updateIndicatorSeries();
  }

  // Set volume data (neutral color for line charts)
  if (volumeSeries) {
    const volumeData = data.map((d) => ({
      time: d.time,
      value: d.volume || 0,
      color: "rgba(33, 150, 243, 0.5)",
    }));
    volumeSeries.setData(volumeData);
  }
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

// Set volume series visibility
function setVolumeVisible(visible) {
  if (!volumeSeries) return;
  volumeSeries.applyOptions({ visible: visible });
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

// ============== INDICATOR CALCULATIONS ==============

// Simple Moving Average
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
    result.push({ time: data[i].time, value: sum / period });
  }
  return result;
}

// Exponential Moving Average
function calculateEMA(data, period) {
  const result = [];
  const multiplier = 2 / (period + 1);
  let ema = null;

  for (let i = 0; i < data.length; i++) {
    if (i < period - 1) {
      continue;
    } else if (i === period - 1) {
      let sum = 0;
      for (let j = 0; j < period; j++) {
        sum += data[i - j].close;
      }
      ema = sum / period;
      result.push({ time: data[i].time, value: ema });
    } else {
      ema = (data[i].close - ema) * multiplier + ema;
      result.push({ time: data[i].time, value: ema });
    }
  }
  return result;
}

// Volume Weighted Average Price
function calculateVWAP(data) {
  const result = [];
  let cumulativeTPV = 0;
  let cumulativeVolume = 0;

  for (let i = 0; i < data.length; i++) {
    const typicalPrice = (data[i].high + data[i].low + data[i].close) / 3;
    cumulativeTPV += typicalPrice * (data[i].volume || 0);
    cumulativeVolume += data[i].volume || 0;

    if (cumulativeVolume > 0) {
      result.push({ time: data[i].time, value: cumulativeTPV / cumulativeVolume });
    }
  }
  return result;
}

// Relative Strength Index
function calculateRSI(data, period) {
  if (data.length < period + 1) return [];

  const result = [];
  let avgGain = 0;
  let avgLoss = 0;

  // Calculate initial average gain/loss
  for (let i = 1; i <= period; i++) {
    const change = data[i].close - data[i - 1].close;
    if (change > 0) avgGain += change;
    else avgLoss += Math.abs(change);
  }
  avgGain /= period;
  avgLoss /= period;

  // First RSI value
  let rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
  let rsi = 100 - 100 / (1 + rs);
  result.push({ time: data[period].time, value: rsi });

  // Subsequent values using smoothed averages
  for (let i = period + 1; i < data.length; i++) {
    const change = data[i].close - data[i - 1].close;
    const gain = change > 0 ? change : 0;
    const loss = change < 0 ? Math.abs(change) : 0;

    avgGain = (avgGain * (period - 1) + gain) / period;
    avgLoss = (avgLoss * (period - 1) + loss) / period;

    rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
    rsi = 100 - 100 / (1 + rs);
    result.push({ time: data[i].time, value: rsi });
  }
  return result;
}

// MACD calculation
function calculateMACD(data, fastPeriod, slowPeriod, signalPeriod) {
  const fastEMA = calculateEMA(data, fastPeriod);
  const slowEMA = calculateEMA(data, slowPeriod);

  const fastMap = new Map(fastEMA.map((d) => [d.time, d.value]));
  const slowMap = new Map(slowEMA.map((d) => [d.time, d.value]));

  // Calculate MACD line
  const macdLine = [];
  for (const d of data) {
    const fast = fastMap.get(d.time);
    const slow = slowMap.get(d.time);
    if (fast !== undefined && slow !== undefined) {
      macdLine.push({ time: d.time, close: fast - slow });
    }
  }

  // Calculate signal line (EMA of MACD)
  const signalLine = calculateEMA(macdLine, signalPeriod);
  const signalMap = new Map(signalLine.map((d) => [d.time, d.value]));

  const result = {
    macd: macdLine.map((d) => ({ time: d.time, value: d.close })),
    signal: signalLine,
    histogram: [],
  };

  // Calculate histogram
  for (const d of macdLine) {
    const signal = signalMap.get(d.time);
    if (signal !== undefined) {
      const histValue = d.close - signal;
      result.histogram.push({
        time: d.time,
        value: histValue,
        color: histValue >= 0 ? "rgba(38, 166, 154, 0.5)" : "rgba(239, 83, 80, 0.5)",
      });
    }
  }

  return result;
}

// ============== INDICATOR SERIES MANAGEMENT ==============

// Set indicators from Swift configuration
function setIndicators(configJson) {
  const config = typeof configJson === "string" ? JSON.parse(configJson) : configJson;
  currentIndicatorSettings = config;
  console.log("[Chart] setIndicators called:", JSON.stringify(config));
  updateIndicatorSeries();
}

// Update indicator series based on current settings and data
function updateIndicatorSeries() {
  if (!chart || !series || !currentIndicatorSettings) return;

  // Get current price data from dataMap
  const priceData = [];
  dataMap.forEach((info, time) => {
    priceData.push({
      time: time,
      open: info.open || 0,
      high: info.high || 0,
      low: info.low || 0,
      close: info.close || 0,
      volume: info.volume || 0,
    });
  });
  priceData.sort((a, b) => a.time - b.time);

  if (priceData.length === 0) {
    console.log("[Chart] No price data for indicators");
    return;
  }

  const enabledIndicators = currentIndicatorSettings.indicators.filter((ind) => ind.isEnabled);
  const enabledIds = new Set(enabledIndicators.map((ind) => ind.id));

  console.log("[Chart] Updating indicators, enabled:", enabledIndicators.length);

  // Remove indicators that are no longer enabled
  for (const [id, seriesInfo] of indicatorSeries) {
    if (!enabledIds.has(id)) {
      console.log("[Chart] Removing indicator:", id);
      chart.removeSeries(seriesInfo.series);
      if (seriesInfo.signalSeries) chart.removeSeries(seriesInfo.signalSeries);
      if (seriesInfo.histogramSeries) chart.removeSeries(seriesInfo.histogramSeries);
      indicatorSeries.delete(id);
    }
  }

  // Add or update enabled indicators
  for (const indicator of enabledIndicators) {
    updateSingleIndicator(indicator, priceData);
  }
}

function updateSingleIndicator(indicator, priceData) {
  const existing = indicatorSeries.get(indicator.id);
  const indicatorType = indicator.type.toUpperCase();

  console.log("[Chart] Updating indicator:", indicatorType, "params:", JSON.stringify(indicator.parameters));

  switch (indicatorType) {
    case "SMA":
    case "EMA":
    case "VWAP": {
      let data;
      if (indicatorType === "SMA") {
        data = calculateSMA(priceData, indicator.parameters.period || 20);
      } else if (indicatorType === "EMA") {
        data = calculateEMA(priceData, indicator.parameters.period || 12);
      } else {
        data = calculateVWAP(priceData);
      }

      console.log("[Chart] Calculated", indicatorType, "data points:", data.length);

      if (existing) {
        existing.series.setData(data);
      } else {
        const lineSeries = chart.addSeries(LightweightCharts.LineSeries, {
          color: indicator.color,
          lineWidth: 2,
          priceScaleId: "right",
        });
        lineSeries.priceScale().applyOptions({
          scaleMargins: { top: 0.1, bottom: 0.3 },
        });
        lineSeries.setData(data);
        indicatorSeries.set(indicator.id, { series: lineSeries });
      }
      break;
    }

    case "RSI": {
      const data = calculateRSI(priceData, indicator.parameters.period || 14);
      console.log("[Chart] Calculated RSI data points:", data.length);

      if (existing) {
        existing.series.setData(data);
      } else {
        const rsiSeries = chart.addSeries(LightweightCharts.LineSeries, {
          color: indicator.color,
          lineWidth: 2,
          priceScaleId: "rsi",
        });
        rsiSeries.priceScale().applyOptions({
          scaleMargins: { top: 0.85, bottom: 0.02 },
        });
        rsiSeries.setData(data);
        indicatorSeries.set(indicator.id, { series: rsiSeries });
      }
      break;
    }

    case "MACD": {
      const data = calculateMACD(
        priceData,
        indicator.parameters.fastPeriod || 12,
        indicator.parameters.slowPeriod || 26,
        indicator.parameters.signalPeriod || 9
      );
      console.log("[Chart] Calculated MACD data points:", data.macd.length);

      if (existing) {
        existing.series.setData(data.macd);
        if (existing.signalSeries) existing.signalSeries.setData(data.signal);
        if (existing.histogramSeries) existing.histogramSeries.setData(data.histogram);
      } else {
        const macdSeries = chart.addSeries(LightweightCharts.LineSeries, {
          color: indicator.color,
          lineWidth: 2,
          priceScaleId: "macd",
        });
        macdSeries.priceScale().applyOptions({
          scaleMargins: { top: 0.9, bottom: 0.02 },
        });
        macdSeries.setData(data.macd);

        const signalSeries = chart.addSeries(LightweightCharts.LineSeries, {
          color: "#FF9800",
          lineWidth: 1,
          priceScaleId: "macd",
        });
        signalSeries.setData(data.signal);

        const histogramSeries = chart.addSeries(LightweightCharts.HistogramSeries, {
          priceScaleId: "macd",
        });
        histogramSeries.setData(data.histogram);

        indicatorSeries.set(indicator.id, {
          series: macdSeries,
          signalSeries: signalSeries,
          histogramSeries: histogramSeries,
        });
      }
      break;
    }
  }
}

// Clear all indicators
function clearIndicators() {
  console.log("[Chart] Clearing all indicators");
  for (const [id, seriesInfo] of indicatorSeries) {
    chart.removeSeries(seriesInfo.series);
    if (seriesInfo.signalSeries) chart.removeSeries(seriesInfo.signalSeries);
    if (seriesInfo.histogramSeries) chart.removeSeries(seriesInfo.histogramSeries);
  }
  indicatorSeries.clear();
  currentIndicatorSettings = null;
}

// Signal to Swift that JavaScript is ready (all functions are defined)
postMessage("pageLoaded", { success: true });
