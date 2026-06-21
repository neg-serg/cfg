// In-memory caches with TTL
var _geoCache = {}; // key: cityLower -> { value: {lat, lon}, expiry: ts, errorUntil?: ts }
var _weatherCache = {}; // key: cityLower -> { value: weatherObject, expiry: ts, errorUntil?: ts }

// ── Fallback provider: wttr.in ──────────────────────────────────────────────

// WorldWeatherOnline (WWO) weather codes → WMO weather interpretation codes
// wttr.in uses WWO codes internally; this maps them to the WMO standard used
// by Open-Meteo and the WeatherIcons.js icon mapping.
var _WWO_TO_WMO = {
    "113": 0,   // Sunny / Clear
    "116": 2,   // Partly cloudy
    "119": 3,   // Cloudy
    "122": 3,   // Overcast
    "143": 45,  // Mist
    "176": 80,  // Light rain shower
    "179": 85,  // Light snow shower
    "182": 86,  // Heavy snow shower
    "185": 87,  // Light sleet showers
    "200": 95,  // Thundery outbreaks
    "227": 76,  // Blowing snow
    "230": 77,  // Blizzard
    "248": 45,  // Fog
    "260": 48,  // Freezing fog
    "263": 51,  // Light drizzle
    "266": 53,  // Drizzle
    "281": 56,  // Freezing drizzle
    "284": 57,  // Heavy freezing drizzle
    "293": 61,  // Light rain
    "296": 61,  // Light rain
    "299": 63,  // Moderate rain
    "302": 65,  // Heavy rain
    "305": 65,  // Heavy rain
    "308": 65,  // Very heavy rain
    "311": 66,  // Light sleet
    "314": 67,  // Moderate sleet
    "317": 67,  // Heavy sleet
    "320": 71,  // Light snow
    "323": 71,  // Light snow
    "326": 71,  // Light snow
    "329": 73,  // Moderate snow
    "332": 73,  // Moderate snow
    "335": 75,  // Heavy snow
    "338": 75,  // Heavy snow
    "350": 77,  // Hail
    "353": 80,  // Light rain shower
    "356": 81,  // Moderate rain shower
    "359": 82,  // Heavy rain shower
    "362": 85,  // Light sleet shower
    "365": 86,  // Moderate sleet shower
    "368": 85,  // Light snow shower
    "371": 86,  // Heavy snow shower
    "374": 85,  // Light sleet shower
    "377": 86,  // Heavy sleet shower
    "386": 95,  // Thundery outbreaks with light rain
    "389": 96,  // Thundery outbreaks with heavy rain
    "392": 97,  // Thundery snow showers
    "395": 99   // Heavy thundery snow
};

function _wwoToWmo(wwoCode) {
    return _WWO_TO_WMO[String(wwoCode)] !== undefined ? _WWO_TO_WMO[String(wwoCode)] : 2;
}

// Normalise wttr.in "format=j1" JSON to the Open-Meteo shape the QML expects.
// Handles possible truncation gracefully — returns current conditions even if
// daily forecast is missing.
function _normalizeWttrIn(data) {
    if (!data || !data.current_condition || !data.current_condition[0]) return null;
    var cc = data.current_condition[0];

    var tempC = parseFloat(cc.temp_C);
    if (isNaN(tempC)) return null;

    var wmoCode = _wwoToWmo(cc.weatherCode);
    var humidity = parseFloat(cc.humidity) || 0;
    var windDir = parseFloat(cc.winddirDegree) || 0;
    var windMs = (parseFloat(cc.windspeedKmph) || 0) / 3.6;
    var pressure = parseFloat(cc.pressure) || 0;

    // Derive daily forecast from the "weather" array (up to 7 days).
    // wttr.in doesn't provide explicit maxtempC/mintempC in free tier,
    // so we compute them from hourly entries.
    var daily = { time: [], weathercode: [], temperature_2m_max: [], temperature_2m_min: [] };
    if (data.weather && data.weather.length > 0) {
        for (var i = 0; i < data.weather.length; i++) {
            var day = data.weather[i];
            if (!day || !day.date) break;
            daily.time.push(day.date);

            var hrs = day.hourly;
            var maxT = -Infinity, minT = Infinity;
            var noonCode = wmoCode;
            if (hrs && hrs.length > 0) {
                for (var h = 0; h < hrs.length; h++) {
                    var ht = parseFloat(hrs[h].tempC);
                    if (!isNaN(ht)) { if (ht > maxT) maxT = ht; if (ht < minT) minT = ht; }
                    // Use the middle-of-day hourly for representative weather code
                    if (h === Math.floor(hrs.length / 2) && hrs[h].weatherCode)
                        noonCode = _wwoToWmo(hrs[h].weatherCode);
                }
            }
            daily.temperature_2m_max.push(isFinite(maxT) ? maxT : (parseFloat(day.avgtempC) || 0));
            daily.temperature_2m_min.push(isFinite(minT) ? minT : (parseFloat(day.avgtempC) || 0));
            daily.weathercode.push(noonCode);
        }
    }

    return {
        current: {
            temperature_2m: tempC,
            weather_code: wmoCode,
            wind_speed_10m: windMs,
            wind_direction_10m: windDir,
            relative_humidity_2m: humidity,
            surface_pressure: pressure
        },
        daily: daily,
        timezone_abbreviation: "MSK",
        _provider: "wttr.in"
    };
}

function _fetchWttrIn(latitude, longitude, callback, errorCallback, options) {
    options = options || {};
    var timeoutMs = options.timeoutMs || DEFAULTS.timeoutMs;
    var _ua = (options && options.userAgent) ? String(options.userAgent) : "Quickshell";

    var coords = String(latitude) + "," + String(longitude);
    var url = "https://wttr.in/" + coords + "?format=j1";

    _httpGetJson(url, timeoutMs, function(wData) {
        var normalized = _normalizeWttrIn(wData);
        if (normalized) {
            callback(normalized);
        } else {
            errorCallback && errorCallback("Fallback weather provider returned invalid data");
        }
    }, function(err) {
        errorCallback && errorCallback("Fallback weather error: " + (err.status || err.type || "unknown"));
    }, _ua);
}

function _now() { return Date.now(); }

function _buildUrl(base, paramsObj) {
    var qs = [];
    var obj = paramsObj || {};
    for (var key in obj) {
        if (!obj.hasOwnProperty(key)) continue;
        var val = obj[key];
        if (val === undefined || val === null) continue;
        qs.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(val)));
    }
    return qs.length ? (base + "?" + qs.join("&")) : base;
}

function _readCache(store, key) {
    var entry = store[key];
    if (!entry) return null;
    var t = _now();
    if (entry.errorUntil && t < entry.errorUntil)
        return { error: true, retryAt: entry.errorUntil };
    if (entry.expiry && t < entry.expiry)
        return { value: entry.value };
    delete store[key];
    return null;
}

function _writeCacheSuccess(store, key, value, ttlMs) {
    store[key] = { value: value, expiry: _now() + ttlMs };
}

function _writeCacheError(store, key, errTtl) {
    store[key] = { errorUntil: _now() + errTtl };
}

// Inline XMLHttpRequest — Qt.include() was removed in Qt 6, so Http.js/HttpCache.js
// cannot be included from JS. This self-contained implementation avoids that dependency.
function _httpGetJson(url, timeoutMs, success, fail, userAgent) {
    try {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        if (timeoutMs !== undefined && timeoutMs !== null) xhr.timeout = timeoutMs;
        try {
            if (xhr.setRequestHeader) {
                try { xhr.setRequestHeader('Accept', 'application/json'); } catch (e1) { /* header API unavailable */ }
                var ua = (userAgent === undefined || userAgent === null) ? 'Quickshell' : String(userAgent).trim();
                if (!ua) ua = 'Quickshell';
                try { xhr.setRequestHeader('User-Agent', ua); } catch (e2) { /* header API unavailable */ }
            }
        } catch (e) { /* ignore header setting failures */ }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try { success && success(JSON.parse(xhr.responseText)); }
                catch (pe) { fail && fail({ type: 'parse', message: 'Failed to parse JSON' }); }
            } else {
                var retryAfter = 0;
                try {
                    var ra = xhr.getResponseHeader && xhr.getResponseHeader('Retry-After');
                    if (ra) retryAfter = Number(ra) * 1000;
                } catch (he) { /* Retry-After header unavailable */ }
                fail && fail({ type: 'http', status: xhr.status, retryAfter: retryAfter });
            }
        };
        xhr.ontimeout = function() { fail && fail({ type: 'timeout' }); };
        xhr.onerror = function() { fail && fail({ type: 'network' }); };
        xhr.send();
    } catch (e) {
        fail && fail({ type: 'exception', message: String(e) });
    }
}


// Defaults (can be overridden via options argument)
var DEFAULTS = {
    geocodeTtlMs: 24 * 60 * 60 * 1000,   // 24h
    weatherTtlMs: 5 * 60 * 1000,         // 5m
    errorTtlMs: 2 * 60 * 1000,           // 2m backoff for 429/5xx
    timeoutMs: 8000                      // 8s timeout
};

function fetchCoordinates(city, callback, errorCallback, options) {
    options = options || {};
    var cfg = {
        geocodeTtlMs: options.geocodeTtlMs || DEFAULTS.geocodeTtlMs,
        errorTtlMs: options.errorTtlMs || DEFAULTS.errorTtlMs,
        timeoutMs: options.timeoutMs || DEFAULTS.timeoutMs
    };
    var key = String(city || "").trim().toLowerCase();
    if (!key) {
        if (errorCallback) errorCallback("City is empty");
        return;
    }

    var cached = _readCache(_geoCache, key);
    if (cached) {
        if (cached.error) {
            errorCallback && errorCallback("Geocoding temporarily unavailable; retry later");
            return;
        }
        if (cached.value) {
            callback(cached.value.lat, cached.value.lon);
            return;
        }
    }

    // Open-Meteo geocoding API (free, no key required)
    var geoBase = (options && options.geocodingApiBaseUrl) ? String(options.geocodingApiBaseUrl) : "https://geocoding-api.open-meteo.com/v1";
    var geoUrl = _buildUrl(geoBase + "/search", {
        name: city,
        language: "en",
        format: "json",
        count: 1
    });

    // Use shared HTTP helper with User-Agent
    var _ua = (options && options.userAgent) ? String(options.userAgent) : "Quickshell";
    var dbg = !!(options && options.debug);
    _httpGetJson(geoUrl, cfg.timeoutMs, function(geoData) {
        try {
            if (geoData && geoData.results && geoData.results.length > 0) {
                var lat = geoData.results[0].latitude;
                var lon = geoData.results[0].longitude;
                _writeCacheSuccess(_geoCache, key, { lat: lat, lon: lon }, cfg.geocodeTtlMs);
                callback(lat, lon);
            } else {
                _writeCacheError(_geoCache, key, cfg.errorTtlMs);
                errorCallback && errorCallback("City not found");
            }
        } catch (e) {
            _writeCacheError(_geoCache, key, cfg.errorTtlMs);
            errorCallback && errorCallback("Failed to parse geocoding data");
        }
    }, function(err) {
        if (err) {
            var backoff = (err.retryAfter && err.retryAfter > 0) ? err.retryAfter : 0;
            if (!backoff && (err.status === 429 || (err.status >= 500 && err.status <= 599))) backoff = cfg.errorTtlMs;
            if (backoff) _writeCacheError(_geoCache, key, backoff);
        }
        errorCallback && errorCallback("Geocoding error: " + (err.status || err.type || "unknown"));
    }, _ua);
}

function fetchWeather(latitude, longitude, callback, errorCallback, options) {
    options = options || {};
    var cfg = {
        weatherTtlMs: options.weatherTtlMs || DEFAULTS.weatherTtlMs,
        errorTtlMs: options.errorTtlMs || DEFAULTS.errorTtlMs,
        timeoutMs: options.timeoutMs || DEFAULTS.timeoutMs,
        cityKey: options.cityKey || null
    };

    var cacheKey = cfg.cityKey ? String(cfg.cityKey).toLowerCase() : null;
    if (cacheKey) {
        var cached = _readCache(_weatherCache, cacheKey);
        if (cached) {
            if (cached.error) {
                errorCallback && errorCallback("Weather temporarily unavailable; retry later");
                return;
            }
            if (cached.value) {
                callback(cached.value);
                return;
            }
        }
    }

    // Open-Meteo forecast API (free, no key required)
    var weatherBase = (options && options.weatherApiBaseUrl) ? String(options.weatherApiBaseUrl) : "https://api.open-meteo.com/v1";
    var url = _buildUrl(weatherBase + "/forecast", {
        latitude: String(latitude),
        longitude: String(longitude),
        current: "temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,is_day,relative_humidity_2m,surface_pressure",
        daily: "temperature_2m_max,temperature_2m_min,weathercode",
        wind_speed_unit: "ms",
        timezone: "auto"
    });
    var _ua = (options && options.userAgent) ? String(options.userAgent) : "Quickshell";
    var dbg = !!(options && options.debug);
    _httpGetJson(url, cfg.timeoutMs, function(weatherData) {
        if (cacheKey) _writeCacheSuccess(_weatherCache, cacheKey, weatherData, cfg.weatherTtlMs);
        callback(weatherData);
    }, function(err) {
        // Primary (Open-Meteo) failed → try fallback provider (wttr.in)
        _fetchWttrIn(latitude, longitude, function(fbData) {
            if (cacheKey) _writeCacheSuccess(_weatherCache, cacheKey, fbData, cfg.weatherTtlMs);
            callback(fbData);
        }, function(fbErr) {
            // Both providers failed → report the primary error
            if (cacheKey && err) {
                var backoff = (err.retryAfter && err.retryAfter > 0) ? err.retryAfter : 0;
                if (!backoff && (err.status === 429 || (err.status >= 500 && err.status <= 599))) backoff = cfg.errorTtlMs;
                if (backoff) _writeCacheError(_weatherCache, cacheKey, backoff);
            }
            errorCallback && errorCallback("Weather fetch error: " + (err.status || err.type || "unknown"));
        }, options);
    }, _ua);
}

function fetchCityWeather(city, callback, errorCallback, options) {
    options = options || {};
    var cityKey = String(city || "").trim();
    fetchCoordinates(cityKey, function(lat, lon) {
        fetchWeather(lat, lon, function(weatherData) {
            callback({
                city: cityKey,
                latitude: lat,
                longitude: lon,
                weather: weatherData
            });
        }, errorCallback, {
            weatherTtlMs: options.weatherTtlMs || DEFAULTS.weatherTtlMs,
            errorTtlMs: options.errorTtlMs || DEFAULTS.errorTtlMs,
            timeoutMs: options.timeoutMs || DEFAULTS.timeoutMs,
            cityKey: cityKey,
            weatherApiBaseUrl: options.weatherApiBaseUrl
        });
    }, errorCallback, {
        geocodeTtlMs: options.geocodeTtlMs || DEFAULTS.geocodeTtlMs,
        errorTtlMs: options.errorTtlMs || DEFAULTS.errorTtlMs,
        timeoutMs: options.timeoutMs || DEFAULTS.timeoutMs,
        geocodingApiBaseUrl: options.geocodingApiBaseUrl
    });
} 
