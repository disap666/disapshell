#!/usr/bin/python3
"""Weather backend for RiceWeather (Open-Meteo, no API key).

Usage: weather.py <city or ""> <c|f> <ms|kmh>
Prints one JSON object. Location: geocoded city, or a guess by IP (wttr.in)
cached for 12 h. The last good forecast is cached, so when the network is
down the widget still shows data, flagged "stale".
"""
import json, sys, time, urllib.parse, urllib.request
from datetime import datetime
from pathlib import Path

CACHE = Path.home() / ".cache/rice-weather"
CACHE.mkdir(parents=True, exist_ok=True)
UA = {"User-Agent": "rice-weather/1.0"}

# WMO weather codes -> (description, kind)
WMO = {
    0: ("Ясно", "clear"), 1: ("Почти ясно", "clear"), 2: ("Переменная облачность", "partly"), 3: ("Пасмурно", "cloudy"),
    45: ("Туман", "fog"), 48: ("Изморозь и туман", "fog"),
    51: ("Слабая морось", "drizzle"), 53: ("Морось", "drizzle"), 55: ("Сильная морось", "drizzle"),
    56: ("Ледяная морось", "drizzle"), 57: ("Сильная ледяная морось", "drizzle"),
    61: ("Небольшой дождь", "rain"), 63: ("Дождь", "rain"), 65: ("Ливень", "rain"),
    66: ("Ледяной дождь", "rain"), 67: ("Сильный ледяной дождь", "rain"),
    71: ("Небольшой снег", "snow"), 73: ("Снег", "snow"), 75: ("Сильный снег", "snow"), 77: ("Снежная крупа", "snow"),
    80: ("Кратковременный дождь", "rain"), 81: ("Ливневый дождь", "rain"), 82: ("Сильный ливень", "rain"),
    85: ("Снегопад", "snow"), 86: ("Сильный снегопад", "snow"),
    95: ("Гроза", "storm"), 96: ("Гроза с градом", "storm"), 99: ("Сильная гроза с градом", "storm"),
}
WET = {"drizzle", "rain", "snow", "storm"}

def get(url, timeout=12):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
        return json.loads(r.read().decode())

def cached(name, max_age, fetch):
    f = CACHE / name
    try:
        d = json.loads(f.read_text())
        if time.time() - d["_at"] < max_age: return d
    except Exception: pass
    d = fetch(); d["_at"] = time.time()
    f.write_text(json.dumps(d, ensure_ascii=False))
    return d

def locate(city):
    if city:
        key = "geo-" + "".join(c for c in city.lower() if c.isalnum())[:40] + ".json"
        def fetch():
            r = get("https://geocoding-api.open-meteo.com/v1/search?count=1&language=ru&name=" + urllib.parse.quote(city))
            if not r.get("results"): raise LookupError("город не найден")
            g = r["results"][0]
            return {"lat": g["latitude"], "lon": g["longitude"], "name": g["name"], "country": g.get("country", "")}
        return cached(key, 30 * 86400, fetch)
    def fetch():
        a = get("https://wttr.in/?format=j1")["nearest_area"][0]
        return {"lat": float(a["latitude"]), "lon": float(a["longitude"]), "name": a["areaName"][0]["value"], "country": a["country"][0]["value"]}
    return cached("geo-auto.json", 12 * 3600, fetch)

def summary(cur, hourly, now_i, wind_unit):
    """One sentence about the next 12 hours."""
    kind = WMO.get(cur["weather_code"], ("", "cloudy"))[1]
    nxt = hourly[now_i:now_i + 13]
    word = lambda k: "снег" if k == "snow" else "гроза" if k == "storm" else "дождь"
    if kind in WET:
        for h in nxt[1:]:
            if h["pop"] < 30 and h["precip"] == 0:
                return f"{word(kind).capitalize()} закончится около {h['time'][-5:]}"
        return f"{word(kind).capitalize()} в ближайшие 12 часов"
    for h in nxt[1:]:
        if h["pop"] >= 55:
            k = WMO.get(h["code"], ("", "rain"))[1]
            return f"Около {h['time'][-5:]} начнётся {word(k if k in WET else 'rain')}" + (f" ({h['pop']}%)" if h["pop"] < 90 else "")
    strong = 10 if wind_unit == "ms" else 36
    if cur["wind_speed_10m"] >= strong:
        return "Сильный ветер"
    temps = [h["temp"] for h in nxt]
    if temps:
        hi, lo = max(temps), min(temps)
        if hi - cur["temperature_2m"] >= 3:
            h = nxt[temps.index(hi)]; return f"Потеплеет до {round(hi)}° к {h['time'][-5:]}"
        if cur["temperature_2m"] - lo >= 3:
            h = nxt[temps.index(lo)]; return f"Похолодает до {round(lo)}° к {h['time'][-5:]}"
    return "Без осадков в ближайшие 12 часов"

def main():
    city = sys.argv[1] if len(sys.argv) > 1 else ""
    temp_unit = "fahrenheit" if (sys.argv[2] if len(sys.argv) > 2 else "c") == "f" else "celsius"
    wind_unit = "kmh" if (sys.argv[3] if len(sys.argv) > 3 else "ms") == "kmh" else "ms"
    out_file = CACHE / "last.json"
    try:
        loc = locate(city)
        q = urllib.parse.urlencode({
            "latitude": loc["lat"], "longitude": loc["lon"], "timezone": "auto", "forecast_days": 7,
            "temperature_unit": temp_unit, "wind_speed_unit": wind_unit,
            "current": "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m,surface_pressure,is_day",
            "hourly": "temperature_2m,precipitation_probability,precipitation,weather_code,is_day",
            "daily": "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,uv_index_max",
        })
        r = get("https://api.open-meteo.com/v1/forecast?" + q)
        c, h, d = r["current"], r["hourly"], r["daily"]
        hourly = [{"time": h["time"][i], "temp": h["temperature_2m"][i], "pop": h["precipitation_probability"][i] or 0,
                   "precip": h["precipitation"][i] or 0, "code": h["weather_code"][i], "day": h["is_day"][i]} for i in range(len(h["time"]))]
        now_key = c["time"][:13]
        now_i = next((i for i, x in enumerate(hourly) if x["time"][:13] == now_key), 0)
        desc, kind = WMO.get(c["weather_code"], ("", "cloudy"))
        data = {
            "ok": True, "stale": False, "fetched": time.time(),
            "place": loc["name"], "country": loc.get("country", ""),
            "units": {"temp": "°F" if temp_unit == "fahrenheit" else "°", "wind": "км/ч" if wind_unit == "kmh" else "м/с"},
            "current": {"temp": c["temperature_2m"], "feels": c["apparent_temperature"], "humidity": c["relative_humidity_2m"],
                        "precip": c["precipitation"], "code": c["weather_code"], "desc": desc, "kind": kind, "cloud": c["cloud_cover"],
                        "wind": c["wind_speed_10m"], "gust": c["wind_gusts_10m"], "windDir": c["wind_direction_10m"],
                        "pressure": round(c["surface_pressure"] * 0.750062), "day": c["is_day"], "time": c["time"]},
            "hourly": [dict(x, kind=WMO.get(x["code"], ("", "cloudy"))[1]) for x in hourly[now_i:now_i + 25]],
            "daily": [{"date": d["time"][i], "code": d["weather_code"][i], "kind": WMO.get(d["weather_code"][i], ("", "cloudy"))[1],
                       "desc": WMO.get(d["weather_code"][i], ("", ""))[0],
                       "max": d["temperature_2m_max"][i], "min": d["temperature_2m_min"][i], "pop": d["precipitation_probability_max"][i] or 0,
                       "uv": d["uv_index_max"][i], "sunrise": d["sunrise"][i][-5:], "sunset": d["sunset"][i][-5:]} for i in range(len(d["time"]))],
        }
        data["summary"] = summary(c, hourly, now_i, wind_unit)
        out_file.write_text(json.dumps(data, ensure_ascii=False))
        print(json.dumps(data, ensure_ascii=False))
    except Exception as e:
        try:
            data = json.loads(out_file.read_text()); data["stale"] = True; data["error"] = str(e)
        except Exception:
            data = {"ok": False, "error": "нет сети" if isinstance(e, OSError) else str(e)}
        print(json.dumps(data, ensure_ascii=False))

main()
