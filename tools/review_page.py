"""Build the portrait review page of a pack from the data LeaderPacks.ps1 prepares.

The data file lists every leader whose latest portrait round awaits the owner's decision, with the
source photo, the coloured photo and the round's candidates. Each image goes into the page as a
data URI twice: at the game's 156x210 and at three times that for a closer look. Prints one JSON
line. Exit 0 is an answer, 1 a wrong call, 2 a failure.
"""

import argparse
import base64
import html
import io
import json
import os
import sys

from PIL import Image

GAME_SIZE = (156, 210)
VIEW_SIZE = (468, 630)


class CallError(Exception):
    pass


def fit(image, size):
    ratio = size[0] / float(size[1])
    width, height = image.size
    if width / float(height) > ratio:
        new_width = int(round(height * ratio))
        left = (width - new_width) // 2
        image = image.crop((left, 0, left + new_width, height))
    else:
        image = image.crop((0, 0, width, int(round(width / ratio))))
    return image.resize(size, Image.LANCZOS)


def data_uri(path, size, kind):
    if not path or not os.path.isfile(path):
        return None
    with Image.open(path) as image:
        fitted = fit(image.convert("RGB"), size)
    buffer = io.BytesIO()
    if kind == "png":
        fitted.save(buffer, format="PNG", optimize=True)
        mime = "image/png"
    else:
        fitted.save(buffer, format="JPEG", quality=86)
        mime = "image/jpeg"
    return "data:%s;base64,%s" % (mime, base64.b64encode(buffer.getvalue()).decode("ascii"))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", required=True)
    parser.add_argument("--template", required=True)
    parser.add_argument("--out", required=True)
    arguments = parser.parse_args()
    try:
        if not os.path.isfile(arguments.data):
            raise CallError("No review data at %s" % arguments.data)
        if not os.path.isfile(arguments.template):
            raise CallError("No page template at %s" % arguments.template)
        with open(arguments.data, "r", encoding="utf-8-sig") as handle:
            data = json.load(handle)
        page_leaders = []
        candidate_count = 0
        missing = []
        for leader in data.get("leaders", []):
            candidates = []
            for candidate in leader.get("candidates", []):
                game = data_uri(candidate.get("file"), GAME_SIZE, "png")
                if game is None:
                    missing.append(candidate.get("file"))
                    continue
                candidates.append(
                    {
                        "seed": candidate.get("seed"),
                        "likeness": candidate.get("likeness"),
                        "game": game,
                        "view": data_uri(candidate.get("file"), VIEW_SIZE, "jpeg"),
                    }
                )
            candidate_count += len(candidates)
            page_leaders.append(
                {
                    "key": leader.get("key"),
                    "name": leader.get("name"),
                    "role": leader.get("role"),
                    "round": leader.get("round"),
                    "seeds": leader.get("seeds", []),
                    "previous": leader.get("previous"),
                    "credit": leader.get("credit") or "",
                    "creditUrl": leader.get("creditUrl") or "",
                    "photo": data_uri(leader.get("photo"), VIEW_SIZE, "jpeg"),
                    "colour": data_uri(leader.get("colour"), VIEW_SIZE, "jpeg"),
                    "candidates": candidates,
                }
            )
        page_data = {"pack": data.get("pack"), "displayName": data.get("displayName"), "leaders": page_leaders}
        with open(arguments.template, "r", encoding="utf-8") as handle:
            template = handle.read()
        if "/*DATA*/null" not in template:
            raise CallError("The page template has no /*DATA*/null placeholder")
        page = template.replace("/*DATA*/null", json.dumps(page_data, ensure_ascii=False).replace("</", "<\\/"))
        title = "<title>Portrait Review: %s</title>" % html.escape(str(data.get("displayName") or data.get("pack") or ""))
        page = page.replace("<title>Portrait Review</title>", title, 1)
        os.makedirs(os.path.dirname(os.path.abspath(arguments.out)), exist_ok=True)
        with open(arguments.out, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(page)
    except CallError as error:
        print(json.dumps({"error": str(error)}))
        return 1
    except Exception as error:
        print(json.dumps({"failure": "%s: %s" % (type(error).__name__, error)}))
        return 2
    print(
        json.dumps(
            {
                "out": os.path.abspath(arguments.out),
                "leaders": len(page_leaders),
                "candidates": candidate_count,
                "missing": missing,
                "bytes": os.path.getsize(arguments.out),
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
