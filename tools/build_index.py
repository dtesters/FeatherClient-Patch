"""Build a Feather-compatible version index from Dawn's public one.

Dawn re-hosts Feather's version index in the same format, but its manifests now
include `linux-arm` native libraries, an OS value the last Feather launch engine
doesn't know, so it refuses to parse them. This script mirrors the index and
manifests with those entries stripped and recomputes sha1/size.

usage: build_index.py OUT_DIR BASE_URL
  OUT_DIR   folder to write version_index.json and manifests/<name>.json into
  BASE_URL  URL prefix the manifests will be served from, e.g.
            file:///C:/Users/me/AppData/Roaming/.feather/dawn-index
            https://raw.githubusercontent.com/user/repo/main/index
"""
import hashlib, json, os, sys, urllib.request

SOURCE = "https://api.dawn.gg/v2/deployments/game/stable/version_index.json"
KNOWN_OS = {"windows", "windows-arm", "windows_intel_legacy", "linux", "osx", "osx-arm"}
# The Feather engine reads only {hash, name} from the cosmetic asset index and always downloads
# from assets.feathercdn.net/<name>. Dawn's index lists cosmetics that exist only on Dawn's CDN,
# which 404 there and stall the download forever, so use Feather's own (still live) asset index.
FEATHER_ASSETS = "https://assets.feathercdn.net/feather_assets_index.json"
# The launcher UI also loads these frozen configs. A version missing from them stalls
# "Version Loading" and freezes the Mods tab, so republish them with Dawn's newer versions added.
FEATHER_MODS = "https://electron-launcher.feathermc.com/mods.json"
FEATHER_MODRINTH = "https://electron-launcher.feathermc.com/modrinth.json"


def write_ui_configs(out_dir, version_names):
    mods = json.loads(fetch(FEATHER_MODS))
    for name in version_names:
        if name not in mods["mcVersions"]:
            mods["mcVersions"].append(name)
    modrinth = json.loads(fetch(FEATHER_MODRINTH))
    for name in version_names:
        if name not in modrinth["mcVersions"] and "-" in name:
            version, loader = name.rsplit("-", 1)
            modrinth["mcVersions"][name] = {"version": version, "loader": loader}
    for fname, obj in (("mods.json", mods), ("modrinth.json", modrinth)):
        with open(os.path.join(out_dir, fname), "w") as f:
            json.dump(obj, f, separators=(",", ":"))


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "FeatherClient-Patch"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def clean(manifest):
    removed = 0
    for lib in manifest.get("native_libraries", []):
        natives = lib.get("natives", {})
        for os_name in [k for k in natives if k not in KNOWN_OS]:
            del natives[os_name]
            removed += 1
    for lib in manifest.get("libraries", []):
        rules = lib.get("rules")
        if not rules:
            continue
        kept = [r for r in rules if r.get("os", {}).get("name") in (None, *KNOWN_OS)]
        removed += len(rules) - len(kept)
        lib["rules"] = kept
    return removed


def asset_index_arg(manifest):
    args = manifest.get("minecraft_arguments") or []
    if isinstance(args, str):
        args = args.split()
    for i, a in enumerate(args[:-1]):
        if a == "--assetIndex":
            return args[i + 1]
    return None


def main():
    out_dir, base = sys.argv[1], sys.argv[2].rstrip("/")
    os.makedirs(os.path.join(out_dir, "manifests"), exist_ok=True)
    index = json.loads(fetch(SOURCE))
    feather_assets = {
        "name": "feather_assets.json",
        "sha1": hashlib.sha1(fetch(FEATHER_ASSETS)).hexdigest(),
        "url": FEATHER_ASSETS,
    }
    kept = []
    for entry in index["metadata"]:
        name = entry["name"]
        raw = fetch(entry["info"]["url"])
        if hashlib.sha1(raw).hexdigest() != entry["info"]["sha1"]:
            sys.exit(f"sha1 mismatch for {name}; aborting")
        manifest = json.loads(raw)
        # Dawn's NeoForge manifests use a newer schema (no game_assets_index) this engine can't parse.
        if "game_assets_index" not in manifest:
            print(f"{name:20} skipped (unsupported manifest format)")
            continue
        removed = clean(manifest)
        # Dawn names newer game asset indexes after Mojang's id (e.g. 34.json), but the launch args
        # still pass --assetIndex <version>-feather-game; the engine saves the index under its name.
        arg = asset_index_arg(manifest)
        if arg:
            manifest["game_assets_index"]["name"] = f"{arg}.json"
        manifest["assets_index"] = feather_assets
        data = json.dumps(manifest, separators=(",", ":")).encode()
        with open(os.path.join(out_dir, "manifests", f"{name}.json"), "wb") as f:
            f.write(data)
        entry["download_size"] = len(data)
        entry["info"]["sha1"] = hashlib.sha1(data).hexdigest()
        entry["info"]["url"] = f"{base}/manifests/{name}.json"
        kept.append(entry)
        print(f"{name:20} stripped {removed}")
    index["metadata"] = kept
    with open(os.path.join(out_dir, "version_index.json"), "w") as f:
        json.dump(index, f, separators=(",", ":"))
    write_ui_configs(out_dir, [e["name"] for e in index["metadata"]])
    print(f"wrote {len(index['metadata'])} versions to {out_dir}")


if __name__ == "__main__":
    main()
