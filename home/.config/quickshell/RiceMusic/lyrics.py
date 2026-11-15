"""Fetch and cache LRCLIB lyrics. The single argument is a JSON track key."""
import hashlib
import json
import re
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def parse_lrc(text):
    lines = []
    offset = re.search(r"\[offset:([+-]?\d+)\]", text, re.I)
    offset = int(offset[1]) / 1000 if offset else 0
    for raw in text.splitlines():
        stamps = re.findall(r"\[(\d+):(\d+(?:\.\d+)?)\]", raw)
        words = re.sub(r"\[[^\]]*\]", "", raw).strip()
        for minutes, seconds in stamps:
            lines.append({"time": max(0, int(minutes) * 60 + float(seconds) + offset), "text": words})
    return sorted(lines, key=lambda line: line["time"])


def get(endpoint, params):
    request = Request("https://lrclib.net/api/" + endpoint + "?" + urlencode(params),
                      headers={"User-Agent": "RiceMusic/1.0 (Quickshell desktop lyrics)"})
    with urlopen(request, timeout=10) as response:
        return json.load(response)


def normalize(value):
    return re.sub(r"\W+", "", value.casefold())


def fetch(key):
    title, artist, album, duration = json.loads(key)
    cache = Path.home() / ".cache/rice-music/lyrics" / (hashlib.sha256(key.encode()).hexdigest() + ".json")
    if cache.exists():
        try:
            return json.loads(cache.read_text())
        except (OSError, ValueError):
            pass
    try:
        item = get("get", {"track_name": title, "artist_name": artist, "album_name": album, "duration": duration})
    except HTTPError as error:
        if error.code != 404:
            raise
        item = None
    if not item:
        results = get("search", {"track_name": title, "artist_name": artist})
        candidates = [r for r in results if normalize(r.get("trackName", "")) == normalize(title)
                      and normalize(r.get("artistName", "")) == normalize(artist)
                      and (not duration or abs(r.get("duration", 0) - duration) < 5)]
        item = next((r for r in candidates if r.get("syncedLyrics")), candidates[0] if candidates else None)
    if not item:
        return {"message": "Текст пока не найден."}
    if item.get("instrumental"):
        return {"message": "Инструментальный трек, слов нет"}
    lines = parse_lrc(item.get("syncedLyrics") or "")
    result = {"lines": lines, "synced": bool(lines)}
    if not lines:
        result["lines"] = [{"time": -1, "text": line.strip()} for line in (item.get("plainLyrics") or "").splitlines() if line.strip()]
        result["message"] = "Текст без синхронизации" if result["lines"] else "Текст пока не найден"
    if result["lines"]:
        try:
            cache.parent.mkdir(parents=True, exist_ok=True)
            cache.write_text(json.dumps(result, ensure_ascii=False))
        except OSError:
            pass
    return result


if __name__ == "__main__":
    try:
        result = fetch(sys.argv[1])
    except (URLError, TimeoutError, OSError):
        result = {"message": "Нет связи с сервисом текстов. Открой обложку повторно."}
    except (ValueError, KeyError, TypeError):
        result = {"message": "Не удалось прочитать текст. Открой обложку повторно."}
    print(json.dumps(result, ensure_ascii=False))
