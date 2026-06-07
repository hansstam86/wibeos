#!/usr/bin/env python3
"""Inject random contacts into a persona's wibeOS Messages app.

Usage:  python3 scripts/add_contacts.py "Hans" [count]
Run while wibeOS is QUIT (it rewrites the file system on save).
"""
import base64, json, random, sys, time
from pathlib import Path

POOL = [
    {"name": "Uncle Roy", "emoji": "🎣",
     "personality": "Your uncle who forwards everything, types in all caps, and is convinced the lake is hiding something. Signs every text 'UNCLE ROY'.",
     "opener": "HANS. THE FISH ARE ACTING STRANGE AGAIN. CALL ME. UNCLE ROY"},
    {"name": "Beatrix", "emoji": "🔮",
     "personality": "A freelance oracle who bills by the prophecy. Speaks in dramatic riddles but is weirdly practical about invoicing.",
     "opener": "The mists revealed something about your Tuesday. Do you want the premium reading or the free summary?"},
    {"name": "Dmitri", "emoji": "🐦",
     "personality": "Runs the neighborhood pigeon racing league. Treats it with the gravity of Formula 1. Holds grudges about the 2024 finals.",
     "opener": "Registration for the spring derby closes Friday. Your bird showed promise. Don't waste it like last year."},
    {"name": "Lin", "emoji": "🧗",
     "personality": "Your most chaotic friend, always mid-adventure, terrible at context. Sends messages that start in the middle of a story.",
     "opener": "ok so the goat is FINE but we are no longer welcome in the village"},
    {"name": "Mr. Patterson", "emoji": "📋",
     "personality": "Building manager. Communicates exclusively in passive-aggressive notices. Deeply concerned about bins.",
     "opener": "A gentle reminder that the bins have a SYSTEM, Hans. This is reminder four (4)."},
    {"name": "Suze", "emoji": "🌶",
     "personality": "Old colleague turned hot-sauce entrepreneur. Every conversation becomes a pitch. Genuinely believes in the sauce.",
     "opener": "Not a sales thing, promise — but have you tried batch 7? It changed my marriage."},
]

def safe_name(s: str) -> str:
    return base64.b64encode(s.encode()).decode().replace("/", "_").replace("+", "-")

def main():
    persona = sys.argv[1] if len(sys.argv) > 1 else "Hans"
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    fs_file = Path.home() / "Library/Application Support/wibeOS" / f"fs_{safe_name(persona)}.json"
    fs = json.loads(fs_file.read_text()) if fs_file.exists() else []

    existing = {f["path"] for f in fs}
    picks = [c for c in random.sample(POOL, len(POOL))
             if f"/Messages/{c['name']}.json" not in existing][:count]
    now = int(time.time() * 1000)
    for c in picks:
        fs.append({
            "path": f"/Messages/{c['name']}.json",
            "type": "text",
            "modified": now,
            "content": json.dumps({
                "meta": {"name": c["name"], "emoji": c["emoji"], "personality": c["personality"]},
                "messages": [{"from": c["name"], "text": c["opener"], "time": now}],
            }),
        })
        print(f"added {c['emoji']} {c['name']}")

    fs_file.parent.mkdir(parents=True, exist_ok=True)
    fs_file.write_text(json.dumps(fs))
    print(f"→ {len(picks)} contact(s) written to {persona}'s file system")

if __name__ == "__main__":
    main()
