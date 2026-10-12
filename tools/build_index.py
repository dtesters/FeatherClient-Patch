"""Build a Feather-compatible version index from Dawn's public one.

Every version up to 26.2 is listed twice: under its usual name it runs the original Feather client
(Feather's final build, archived at featherarchived/builds-cf.feathercdn.net), and under a
"-dawn" name it runs Dawn's. Versions released after Feather shut down are Dawn-only.

Dawn re-hosts Feather's version index in the same format, but its manifests now
include `linux-arm` native libraries, an OS value the last Feather launch engine
doesn't know, so it refuses to parse them. This script mirrors the index and
manifests with those entries stripped and recomputes sha1/size.

usage: build_index.py OUT_DIR BASE_URL
  OUT_DIR   folder to write version_index.json and manifests/<name>.json into
  BASE_URL  URL prefix the manifests will be served from, e.g.
            https://raw.githubusercontent.com/user/repo/main/index
"""
import copy, hashlib, json, os, re, sys, urllib.request

SOURCE = "https://api.dawn.gg/v2/deployments/game/stable/version_index.json"
KNOWN_OS = {"windows", "windows-arm", "windows_intel_legacy", "linux", "osx", "osx-arm"}
# The Feather engine reads only {hash, name} from the cosmetic asset index and downloads from a
# hard-coded https://assets.feathercdn.net/<name>. Dawn's index (a superset of Feather's) lists
# cosmetics that exist only on Dawn's CDN, which 404 there and stall the download forever.
# Current patches rewrite that host to https://assets.dawn.gg/assets/ (same length, same paths),
# so v2/ uses Dawn's full index. The top-level index keeps Feather's own for launchers patched
# before that, which still download from feathercdn.
FEATHER_ASSETS = "https://assets.feathercdn.net/feather_assets_index.json"
# The launcher UI also loads these frozen configs. A version missing from them stalls
# "Version Loading" and freezes the Mods tab, so republish them with Dawn's newer versions added.
# Everything else the launcher UI loads from there (it won't even start without the language
# files). The patch points the launcher at mirror/electron-launcher/ in this repo.
ELECTRON_LAUNCHER = "https://electron-launcher.feathermc.com/"
LAUNCHER_FILES = ["launch-background.json", "partner-server-meta.json", "server-templates2.json",
                  "mod-validation2.json", "mods.json", "modrinth.json", "languages2/language_list.json"]
TOOLS = os.path.dirname(os.path.abspath(__file__))
# Feather's final client jars (release 1782267228), pinned by sha1 so the archive can't swap them.
FEATHER_BUILDS = os.path.join(TOOLS, "feather_builds.json")
# A real Feather final-build manifest (1.21.8): source of Feather's own natives and CEF build.
FEATHER_TEMPLATE = os.path.join(TOOLS, "feather_template.json")
# Libraries Dawn added on top of Feather's final build (which already shipped gg/dawn/dawn-renderer).
DAWN_ONLY = ("gg/dawn/server-api/", "io/github/humbleui/")


def copy_version_keys(node, src, dst):
    """Give version `dst` the same per-version mod entries as `src`, anywhere in the config."""
    if isinstance(node, dict):
        if src in node and dst not in node:
            node[dst] = copy.deepcopy(node[src])
        for v in list(node.values()):
            copy_version_keys(v, src, dst)
    elif isinstance(node, list):
        for v in node:
            copy_version_keys(v, src, dst)


def fetch_or_keep(url, path):
    """Refresh a mirrored file from Feather if it still answers; otherwise keep the last good copy."""
    try:
        data = fetch(url)
        json.loads(data)  # don't overwrite a good copy with an error page
    except Exception as e:
        if not os.path.exists(path):
            raise
        print(f"  kept mirrored copy of {url} ({e.__class__.__name__})")
        with open(path, "rb") as f:
            return f.read()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    return data


def mirror_launcher_files(mirror_dir):
    """Copy the launcher's config/language files so it still starts if Feather's server goes away."""
    root = os.path.join(mirror_dir, "electron-launcher")
    for name in LAUNCHER_FILES:
        fetch_or_keep(ELECTRON_LAUNCHER + name, os.path.join(root, *name.split("/")))
    with open(os.path.join(root, "languages2", "language_list.json"), "rb") as f:
        codes = [l["code"] for l in json.load(f)["languages"]]
    for code in codes:
        name = f"languages2/{code}.json"
        try:
            fetch_or_keep(ELECTRON_LAUNCHER + name, os.path.join(root, *name.split("/")))
        except Exception as e:
            print(f"  no copy of {name} ({e.__class__.__name__})")
    return root


def write_ui_configs(out_dir, version_names, aliases, launcher_mirror):
    """aliases: {Dawn variant name: the Feather name whose mod entries it shares}"""
    with open(os.path.join(launcher_mirror, "mods.json"), "rb") as f:
        mods = json.load(f)
    with open(os.path.join(launcher_mirror, "modrinth.json"), "rb") as f:
        modrinth = json.load(f)
    for dst, src in aliases.items():
        for key in ("mods", "defaultMods", "dependencies"):
            copy_version_keys(mods[key], src, dst)
        copy_version_keys(modrinth["mcVersions"], src, dst)
    # the Modrinth version picker lists these keys; keep only names that are versions in the index
    for name in [k for k in modrinth["mcVersions"] if k not in version_names]:
        del modrinth["mcVersions"][name]
    for name in version_names:
        if name not in mods["mcVersions"]:
            mods["mcVersions"].append(name)
        if name not in modrinth["mcVersions"] and "-" in name:
            loader = "fabric" if name.endswith("-fabric") else "forge"  # same rule as the launcher UI
            modrinth["mcVersions"][name] = {"version": name.split("-", 1)[0], "loader": loader}
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


def art_key(name):
    """maven path without the version: net/digitalingot/fcef/0.1.1/fcef-0.1.1.jar -> net/digitalingot/fcef"""
    return "/".join(name.split("/")[:-2])


def is_client_jar(lib):
    return bool(lib.get("feather")) and re.match(r"net/digitalingot/feather-(fabric-)?\d", lib["name"]) is not None


def to_feather(dawn, template, build, feather_name):
    """Turn one of Dawn's manifests back into Feather's: original client jar, natives and CEF."""
    m = copy.deepcopy(dawn)
    tlibs = {art_key(l["name"]): l for l in template["libraries"]}
    tnat = {art_key(next(iter(n["natives"].values()))["name"]): n for n in template["native_libraries"]}

    def lib(l):
        k = art_key(l["name"])
        if k.startswith(DAWN_ONLY):
            return None
        if is_client_jar(l):
            # own path, so switching between the Feather and Dawn variants doesn't redownload either
            return dict(l, name=f"net/digitalingot/feather-final/{feather_name}/feather-{feather_name}.jar", **build)
        if k.startswith("net/digitalingot/") and k in tlibs:  # Feather's CEF build etc.
            return copy.deepcopy(tlibs[k])
        return l

    m["libraries"] = [x for x in map(lib, m["libraries"]) if x]
    # add back Feather's own pins that Dawn dropped (e.g. netty-codec-http 4.1.97 from 1.21.11 on)
    have = {art_key(l["name"]) for l in m["libraries"] if l.get("feather")}
    fabric = "knot" in m.get("main_class", "").lower()  # template is a Fabric build; legacy 1.8.9/1.12.2 keep Dawn's set
    for k, l in tlibs.items():
        if fabric and l.get("feather") and k not in have and not is_client_jar(l) and not k.startswith("software/bernie/"):
            m["libraries"].append(copy.deepcopy(l))
    m["mods"] = [x for x in map(lib, m.get("mods", [])) if x]
    natives = []
    for n in m["native_libraries"]:
        k = art_key(next(iter(n["natives"].values()))["name"])
        if k.startswith(DAWN_ONLY):
            continue
        natives.append(copy.deepcopy(tnat[k]) if k.startswith("net/digitalingot/") and k in tnat else n)
    m["native_libraries"] = natives
    swapped = sum("/feather-final/" in l["name"] for l in m["libraries"] + m["mods"])
    if swapped != 1:
        raise ValueError(f"expected one client jar, swapped {swapped}")
    return m


def variant_names(dawn_name):
    """Dawn's name -> (Feather's original name, Feather variant name, Dawn variant name).

    The launcher's version picker shows names with "-fabric" stripped, so these read as
    "1.21.8-feather" / "1.21.8-dawn". Legacy versions have no loader suffix (Feather called
    1.8.9-forge plain "1.8.9"); the UI treats anything without "-fabric" as Forge.
    """
    v, loader = dawn_name.rsplit("-", 1)
    if loader == "forge":
        return v, f"{v}-feather", f"{v}-dawn"
    return dawn_name, f"{v}-feather-{loader}", f"{v}-dawn-{loader}"


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
    mirror_dir = os.path.join(os.path.dirname(os.path.abspath(out_dir)), "mirror")
    launcher_mirror = mirror_launcher_files(mirror_dir)
    index = json.loads(fetch(SOURCE))
    feather_assets = {
        "name": "feather_assets.json",
        "sha1": hashlib.sha1(fetch_or_keep(FEATHER_ASSETS, os.path.join(mirror_dir, "feather_assets_index.json"))).hexdigest(),
        "url": FEATHER_ASSETS,
    }
    builds = json.load(open(FEATHER_BUILDS))
    template = json.load(open(FEATHER_TEMPLATE))
    clean(template)
    versions, aliases, dawn_assets = [], {}, None

    def emit(entry, name, manifest):
        versions.append((entry, name, dict(manifest, name=name)))

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
        dawn_assets = dawn_assets or manifest["assets_index"]
        original, feather_name, dawn_name = variant_names(name)
        # both variants share the mod entries Feather's configs list under the original name
        aliases[dawn_name] = original
        if original in builds:
            emit(entry, feather_name, to_feather(manifest, template, builds[original], original))
            aliases[feather_name] = original
            print(f"{name:20} stripped {removed}; {feather_name} + {dawn_name}")
        else:
            print(f"{name:20} stripped {removed}; {dawn_name} only (no Feather build)")
        emit(entry, dawn_name, manifest)
    for sub, assets in (("", feather_assets), ("v2", dawn_assets)):
        write_tree(os.path.join(out_dir, sub), f"{base}/{sub}".rstrip("/"), index, versions, assets)
    write_ui_configs(out_dir, [name for _, name, _ in versions], aliases, launcher_mirror)
    print(f"wrote {len(versions)} versions to {out_dir} (and v2/)")


def write_tree(out_dir, base, index, versions, assets):
    os.makedirs(os.path.join(out_dir, "manifests"), exist_ok=True)
    metadata = []
    for entry, name, manifest in versions:
        data = json.dumps(dict(manifest, assets_index=assets), separators=(",", ":")).encode()
        with open(os.path.join(out_dir, "manifests", f"{name}.json"), "wb") as f:
            f.write(data)
        e = copy.deepcopy(entry)
        e["name"] = name
        e["download_size"] = len(data)
        e["info"]["name"] = f"{name}.json"  # the engine caches the manifest under this file name
        e["info"]["sha1"] = hashlib.sha1(data).hexdigest()
        e["info"]["url"] = f"{base}/manifests/{name}.json"
        metadata.append(e)
    with open(os.path.join(out_dir, "version_index.json"), "w") as f:
        json.dump(dict(index, metadata=metadata), f, separators=(",", ":"))


if __name__ == "__main__":
    main()
