#!/usr/bin/env python3
"""Download the latest FFmpeg XCFramework bundle from stovak/ffmpeg-framework.

This script locates the most recent tagged release in the upstream
`stovak/ffmpeg-framework` repository, finds the associated GitHub Actions
artifact that packages the prebuilt XCFrameworks, downloads it, and extracts
all `.xcframework` directories into the Swift package's `xcframework/`
folder.

Authentication:
  * Set `FFMPEG_FRAMEWORK_TOKEN` (preferred) or `GITHUB_TOKEN` to a GitHub
    personal access token with `actions:read` scope in order to download the
    workflow artifact.
  * Unauthenticated requests are used for metadata queries, but the artifact
    download itself requires authentication. The script will exit with an
    error if the token is not available.

Usage:
  python3 Scripts/download_latest_xcframeworks.py [destination]

If no destination is supplied, the script defaults to `xcframework/` inside the
current working directory.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import tarfile
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional
from urllib.error import HTTPError
from urllib.request import Request, urlopen

OWNER = os.environ.get("FFMPEG_FRAMEWORK_OWNER", "stovak")
REPO = os.environ.get("FFMPEG_FRAMEWORK_REPO", "ffmpeg-framework")
ARTIFACT_NAME = os.environ.get("FFMPEG_FRAMEWORK_ARTIFACT", "ffmpeg-xcframeworks")
TOKEN = os.environ.get("FFMPEG_FRAMEWORK_TOKEN") or os.environ.get("GITHUB_TOKEN")
USER_AGENT = os.environ.get("FFMPEG_FRAMEWORK_USER_AGENT", "SwiftFFMpegDownloader/1.0")

DEFAULT_DESTINATION = Path("xcframework")
EXPECTED_FRAMEWORKS = {
    "libavcodec.xcframework",
    "libavdevice.xcframework",
    "libavfilter.xcframework",
    "libavformat.xcframework",
    "libavutil.xcframework",
    "libpostproc.xcframework",
    "libswresample.xcframework",
    "libswscale.xcframework",
}


@dataclass
class Release:
    tag_name: str
    target_branch: Optional[str]
    commit_sha: Optional[str]


@dataclass
class Artifact:
    id: int
    name: str
    download_url: str


def _base_headers() -> Dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": USER_AGENT,
    }
    if TOKEN:
        headers["Authorization"] = f"Bearer {TOKEN}"
    return headers


def github_json(path: str) -> dict:
    url = f"https://api.github.com/repos/{OWNER}/{REPO}{path}"
    req = Request(url, headers=_base_headers())
    with urlopen(req) as resp:  # type: ignore[arg-type]
        return json.load(resp)


def download_file(url: str, destination: Path) -> None:
    req = Request(url, headers=_base_headers())
    try:
        with urlopen(req) as resp, destination.open("wb") as fh:  # type: ignore[arg-type]
            shutil.copyfileobj(resp, fh)
    except HTTPError as exc:  # pragma: no cover - runtime failure path
        if exc.code == 401:
            raise RuntimeError(
                "GitHub rejected the artifact download. Provide a token via "
                "FFMPEG_FRAMEWORK_TOKEN or GITHUB_TOKEN with actions:read scope."
            ) from exc
        raise


def resolve_release() -> Release:
    data = github_json("/releases/latest")
    tag = data.get("tag_name")
    if not tag:
        raise RuntimeError("Unable to determine the latest release tag name.")

    commit_sha = resolve_tag_commit(tag)
    return Release(
        tag_name=tag,
        target_branch=data.get("target_commitish"),
        commit_sha=commit_sha,
    )


def resolve_tag_commit(tag: str) -> Optional[str]:
    try:
        ref = github_json(f"/git/ref/tags/{tag}")
    except HTTPError as exc:  # pragma: no cover - runtime failure path
        if exc.code == 404:
            return None
        raise

    obj = ref.get("object", {})
    obj_type = obj.get("type")
    sha = obj.get("sha")
    if not sha:
        return None

    if obj_type == "commit":
        return sha

    if obj_type == "tag":
        tag_obj = github_json(f"/git/tags/{sha}")
        tag_obj_inner = tag_obj.get("object", {})
        if tag_obj_inner.get("type") == "commit":
            return tag_obj_inner.get("sha")

    return None


def find_workflow_run(release: Release) -> Optional[dict]:
    runs = github_json("/actions/runs?per_page=100").get("workflow_runs", [])
    if release.commit_sha:
        for run in runs:
            if run.get("head_sha") == release.commit_sha:
                return run
    if release.target_branch:
        for run in runs:
            if run.get("head_branch") == release.target_branch:
                return run
    return runs[0] if runs else None


def find_artifact_for_run(run_id: int) -> Artifact:
    artifacts = github_json(f"/actions/runs/{run_id}/artifacts?per_page=100").get("artifacts", [])
    for art in artifacts:
        if art.get("name") == ARTIFACT_NAME:
            return Artifact(
                id=art["id"],
                name=art["name"],
                download_url=art["archive_download_url"],
            )
    available = ", ".join(sorted(art.get("name", "<unknown>") for art in artifacts)) or "<none>"
    raise RuntimeError(
        f"Could not find artifact named '{ARTIFACT_NAME}'. Available artifacts: {available}."
    )


def extract_artifact(archive: Path, destination: Path) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        with zipfile.ZipFile(archive) as zf:
            zf.extractall(temp_path)

        inner_candidates: List[Path] = []
        for pattern in ("**/*.tar", "**/*.tar.gz", "**/*.tgz"):
            inner_candidates.extend(temp_path.glob(pattern))
        extraction_root = temp_path
        if inner_candidates:
            inner_candidates.sort(key=lambda p: len(p.parts))
            tar_path = inner_candidates[0]
            with tarfile.open(tar_path) as tf:
                tf.extractall(temp_path)
        frameworks = locate_frameworks(extraction_root)
        if not frameworks:
            raise RuntimeError("No .xcframework directories were found in the downloaded artifact.")

        if destination.exists():
            shutil.rmtree(destination)
        destination.mkdir(parents=True, exist_ok=True)

        for name, framework_path in frameworks.items():
            shutil.copytree(framework_path, destination / name)


def locate_frameworks(root: Path) -> Dict[str, Path]:
    result: Dict[str, Path] = {}
    for path in root.rglob("*.xcframework"):
        if path.name in EXPECTED_FRAMEWORKS and path.is_dir():
            result[path.name] = path
    missing = EXPECTED_FRAMEWORKS - set(result.keys())
    if missing:
        print(
            "Warning: missing expected frameworks from artifact: " + ", ".join(sorted(missing)),
            file=sys.stderr,
        )
    return result


def ensure_token() -> None:
    if TOKEN:
        return
    raise RuntimeError(
        "Downloading GitHub Actions artifacts requires authentication. Set "
        "FFMPEG_FRAMEWORK_TOKEN or GITHUB_TOKEN with a token that has actions:read access."
    )


def main(argv: List[str]) -> int:
    destination = Path(argv[1]) if len(argv) > 1 else DEFAULT_DESTINATION

    ensure_token()

    print(f"Resolving latest release in {OWNER}/{REPO}…")
    release = resolve_release()
    print(f"Latest release tag: {release.tag_name}")
    if release.commit_sha:
        print(f"Release commit SHA: {release.commit_sha}")
    if release.target_branch:
        print(f"Release target branch: {release.target_branch}")

    run = find_workflow_run(release)
    if not run:
        raise RuntimeError("Unable to locate a workflow run to download artifacts from.")

    print(f"Using workflow run {run['id']} ({run.get('head_branch')} @ {run.get('head_sha')})")
    artifact = find_artifact_for_run(run_id=run["id"])
    print(f"Downloading artifact '{artifact.name}' (id={artifact.id})…")

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir) / "artifact.zip"
        download_file(artifact.download_url, temp_path)
        print("Extracting frameworks…")
        extract_artifact(temp_path, destination)

    print(f"XCFrameworks extracted to {destination}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
