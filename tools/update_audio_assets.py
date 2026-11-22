"""Update docs/AUDIO_ASSETS.json from a voice-generation manifest (rule 266).

docs/AUDIO_ASSETS.json (schema_version 2) has two parts:

* ``generators``: one record per generation run (model, revision, voice,
  reference, loudness target, format, language, date).
* ``files``: one record per bundled sound, keyed by ``path``
  (``sounds/<name>.ogg``). Voice lines carry ``kind: "voice"``, ``locale`` and
  ``generator``; effects carry ``kind: "effect"``.

Usage (repo root)::

    python tools/update_audio_assets.py --migrate
    python tools/update_audio_assets.py --manifest <manifest.json> \
        --generator-id voice6-2026-11-21 --date 2026-11-21 [--language English]

``--migrate`` only converts a schema_version 1 file (top-level generator
fields) into schema_version 2; it is idempotent.

With ``--manifest`` every clip of the manifest is written into ``files``:

* Clips are read from the first list found under ``files``, ``clips`` or
  ``items`` (or a dict under ``items`` whose keys are file stems).
* The target is the clip's ``path`` (``sounds/X.ogg``); without one, the
  file name of the clip's ``target`` or ``file`` (folders dropped, e.g.
  ``enUS/TankDied.ogg`` -> ``TankDied.ogg``) must be a file in ``sounds/``.
  Anything else stops the run, so copy the files into ``sounds/`` first.
* ``bytes``, ``sha256`` and ``seconds`` are measured from the file in
  ``sounds/`` (deterministic); a manifest ``sha256`` that differs stops the run
  because the bundled file is not the one the manifest describes.
* ``lufs``, ``true_peak_dbtp``, texts and seeds come from the manifest.
* ``locale`` is the clip's ``locale``, else ``deDE`` for ``*_deDE.ogg`` and
  ``enUS`` otherwise.

Top-level manifest fields (model, revision, selected_voice/voice,
reference_sha256, target_lufs, encoding/codec) fill the generator record;
missing ones are simply left out, never guessed. The output is written with
sorted generator ids, files sorted by path and two-space indentation, so a
re-run on the same inputs produces identical bytes.
"""

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "docs" / "AUDIO_ASSETS.json"
SOUNDS = ROOT / "sounds"
SCHEMA_VERSION = 2
LEGACY_GENERATOR_ID = "voice6-deDE-2026-10-20"
LEGACY_GENERATOR_FIELDS = (
    "date",
    "voice",
    "model",
    "revision",
    "reference_sha256",
    "target_lufs",
    "sample_rate",
    "channels",
    "codec",
    "scope",
)
CLIP_FIELDS = (
    "event",
    "display_text",
    "synthesis_text",
    "pronunciation_user",
    "text_status",
    "language",
    "seed_mode",
    "lufs",
    "true_peak_dbtp",
    "seed",
    "verified",
)
GENERATOR_FIELD_SOURCES = {
    "model": ("model", "model_repo"),
    "revision": ("revision", "model_revision"),
    "voice": ("voice", "selected_voice"),
    "reference_sha256": ("reference_sha256",),
    "target_lufs": ("target_lufs",),
    "codec": ("codec", "encoding"),
    "sample_rate": ("sample_rate",),
    "channels": ("channels",),
}


def die(message):
    sys.stderr.write("update_audio_assets: " + message + "\n")
    sys.exit(1)


def read_ogg_info(path):
    """Return (sample_rate, channels, seconds) of an Ogg Vorbis file."""
    data = path.read_bytes()
    offset = 0
    sample_rate = None
    channels = None
    last_granule = None
    while offset < len(data):
        if data[offset : offset + 4] != b"OggS":
            die("%s is not a complete Ogg stream" % path.name)
        granule = struct.unpack_from("<q", data, offset + 6)[0]
        segments = data[offset + 26]
        payload = offset + 27 + segments
        size = sum(data[offset + 27 : payload])
        if sample_rate is None:
            if data[payload : payload + 7] != b"\x01vorbis":
                die("%s does not start with a Vorbis header" % path.name)
            channels = data[payload + 11]
            sample_rate = struct.unpack_from("<I", data, payload + 12)[0]
        if granule >= 0:
            last_granule = granule
        offset = payload + size
    if not sample_rate or last_granule is None:
        die("%s declares no sample rate or duration" % path.name)
    return sample_rate, channels, last_granule / sample_rate


def load_assets():
    return json.loads(ASSETS.read_text(encoding="utf-8"))


def write_assets(doc):
    doc["files"] = sorted(doc["files"], key=lambda item: item["path"])
    doc["generators"] = {key: doc["generators"][key] for key in sorted(doc["generators"])}
    text = json.dumps(doc, ensure_ascii=False, indent=2) + "\n"
    ASSETS.write_text(text, encoding="utf-8", newline="\n")


def migrate(doc):
    if doc.get("schema_version") == SCHEMA_VERSION:
        return doc
    generator = {field: doc[field] for field in LEGACY_GENERATOR_FIELDS if field in doc}
    generator["language"] = "German"
    files = []
    for item in doc.get("files", []):
        item = dict(item)
        if "locale" in item:
            item["kind"] = "voice"
            item["generator"] = LEGACY_GENERATOR_ID
        else:
            item["kind"] = "effect"
        files.append(item)
    return {
        "schema_version": SCHEMA_VERSION,
        "generators": {LEGACY_GENERATOR_ID: generator},
        "files": files,
    }


def manifest_clips(manifest):
    for key in ("files", "clips", "items"):
        value = manifest.get(key)
        if isinstance(value, list):
            return [dict(item) for item in value]
        if isinstance(value, dict):
            clips = []
            for stem, item in value.items():
                if not isinstance(item, dict):
                    die("manifest %s.%s is not an object" % (key, stem))
                item = dict(item)
                item.setdefault("file", stem if stem.endswith(".ogg") else stem + ".ogg")
                clips.append(item)
            return clips
    die("manifest has no clip list under files, clips or items")
    return []


def target_name(clip):
    path = clip.get("path")
    if isinstance(path, str) and path.startswith("sounds/"):
        return path[len("sounds/") :]
    for field in ("target", "file"):
        value = clip.get(field)
        # Manifests may keep clips in per-locale folders ("enUS/TankDied.ogg").
        name = Path(value).name if isinstance(value, str) else None
        if name and (SOUNDS / name).is_file():
            return name
    die("cannot map manifest clip to a file in sounds/: %r" % {k: clip.get(k) for k in ("path", "target", "file")})
    return None


def apply_manifest(doc, manifest_path, generator_id, date, language):
    manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    generator = {"date": date, "manifest": Path(manifest_path).name}
    if language:
        generator["language"] = language
    for field, sources in GENERATOR_FIELD_SOURCES.items():
        for source in sources:
            if source in manifest:
                generator[field] = manifest[source]
                break
    doc["generators"][generator_id] = generator

    by_path = {item["path"]: item for item in doc["files"]}
    for clip in manifest_clips(manifest):
        name = target_name(clip)
        sound_path = SOUNDS / name
        if not sound_path.is_file():
            die("sounds/%s does not exist" % name)
        raw = sound_path.read_bytes()
        sha256 = hashlib.sha256(raw).hexdigest()
        if clip.get("sha256") and clip["sha256"] != sha256:
            die("sounds/%s differs from the manifest (sha256 %s != %s)" % (name, sha256, clip["sha256"]))
        sample_rate, channels, seconds = read_ogg_info(sound_path)
        locale = clip.get("locale") or ("deDE" if name.endswith("_deDE.ogg") else "enUS")
        entry = {
            "path": "sounds/" + name,
            "kind": "voice",
            "locale": locale,
            "generator": generator_id,
            "file": clip.get("file", name),
            "bytes": len(raw),
            "seconds": round(seconds, 6),
            "sample_rate": sample_rate,
            "channels": channels,
            "sha256": sha256,
        }
        for field in CLIP_FIELDS:
            if field in clip:
                entry[field] = clip[field]
        by_path[entry["path"]] = entry
    doc["files"] = list(by_path.values())
    return doc


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--migrate", action="store_true", help="only convert schema_version 1 to 2")
    parser.add_argument("--manifest", help="generation manifest (JSON)")
    parser.add_argument("--generator-id", help="id of the generation run, e.g. voice6-enUS-2026-11-21")
    parser.add_argument("--date", help="generation date, YYYY-MM-DD")
    parser.add_argument("--language", help="spoken language of the whole run (clips may carry their own)")
    args = parser.parse_args()

    doc = migrate(load_assets())
    if args.manifest:
        if not (args.generator_id and args.date):
            die("--manifest needs --generator-id and --date")
        doc = apply_manifest(doc, args.manifest, args.generator_id, args.date, args.language)
    elif not args.migrate:
        die("nothing to do: pass --migrate or --manifest")
    write_assets(doc)
    print("update_audio_assets: %d files, %d generators" % (len(doc["files"]), len(doc["generators"])))


if __name__ == "__main__":
    main()
