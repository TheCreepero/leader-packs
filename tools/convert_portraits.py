"""Converts the chosen leader portraits into the pack's uncompressed 32-bit DDS files.

Reads a manifest of tab-separated lines: the kind ("large" or "small"), the source picture and
the destination. A destination ending in .dds is written as an uncompressed 32-bit DDS, one ending
in .png as a PNG (for tests and previews).

- large: the chosen portrait cropped to the 156x210 aspect around its centre and resized.
- small: the 65x67 card drawn in code around the source, which is the crop of the chosen portrait
  to the card's photo window (build.ps1 -ConvertPortraits makes it with the Manager's
  Measure-PortraitFaces.py crop). The geometry and colours come from data/portrait-card.json and
  the drawing follows the prototype the owner approved on 2026-10-31.

build.ps1 decides which portraits are out of date; this script converts every line it is given.
"""

import argparse
import json
import os
import random
import struct
import sys

from PIL import Image, ImageDraw, ImageFilter

LARGE_SIZE = (156, 210)
DDSD_CAPS_HEIGHT_WIDTH_PITCH_PIXELFORMAT = 0x0000100F
DDPF_RGB_WITH_ALPHA = 0x00000041
DDSCAPS_TEXTURE = 0x00001000


def dds_header(width, height):
    pixel_format = struct.pack(
        "<II4sIIIII",
        32,
        DDPF_RGB_WITH_ALPHA,
        b"\0\0\0\0",
        32,
        0x00FF0000,
        0x0000FF00,
        0x000000FF,
        0xFF000000,
    )
    header = struct.pack(
        "<IIIIIII44s",
        124,
        DDSD_CAPS_HEIGHT_WIDTH_PITCH_PIXELFORMAT,
        height,
        width,
        width * 4,
        0,
        0,
        b"\0" * 44,
    )
    caps = struct.pack("<IIIII", DDSCAPS_TEXTURE, 0, 0, 0, 0)
    return b"DDS " + header + pixel_format + caps


def crop_to_aspect(image, width, height):
    target_ratio = width / height
    source_width, source_height = image.size
    if source_width / source_height > target_ratio:
        kept_width = round(source_height * target_ratio)
        left = round((source_width - kept_width) / 2)
        box = (left, 0, left + kept_width, source_height)
    else:
        kept_height = round(source_width / target_ratio)
        top = round((source_height - kept_height) / 2)
        box = (0, top, source_width, top + kept_height)
    return image.crop(box).resize((width, height), Image.LANCZOS)


def scaled(box, scale):
    return tuple(value * scale for value in box)


def shadow_of(layer, radius, offset, opacity):
    alpha = layer.split()[3].filter(ImageFilter.GaussianBlur(radius))
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    shadow.putalpha(alpha.point(lambda value: int(value * opacity)))
    moved = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    moved.paste(shadow, offset)
    return moved


def card_layer(photo, settings):
    width, height = settings["size"]
    scale = settings["scale"]
    card = settings["card"]
    layer = Image.new("RGBA", (width * scale, height * scale), (0, 0, 0, 0))
    left, top, right, bottom = scaled(card["box"], scale)
    draw = ImageDraw.Draw(layer)
    draw.rectangle((left, top, right, bottom), fill=tuple(card["fill"]) + (255,))
    draw.rectangle((left, top, right, bottom), outline=tuple(card["outerEdge"]) + (255,), width=3)
    draw.rectangle((left + 3, top + 3, right - 3, bottom - 3), outline=tuple(card["bevel"]) + (255,), width=2)
    inset = card["photoInset"] * scale
    window = (left + inset, top + inset, right - inset, bottom - inset)
    fitted = photo.convert("RGB").resize((window[2] - window[0], window[3] - window[1]), Image.LANCZOS)
    darken = card["photoDarken"]
    fitted = fitted.point(lambda value: int(value * darken))
    layer.paste(fitted, (window[0], window[1]))
    vignette = card["vignette"]
    shade = Image.new("RGBA", fitted.size, (0, 0, 0, 0))
    shade_draw = ImageDraw.Draw(shade)
    for step in range(vignette["steps"]):
        shade_draw.rectangle(
            (step, step, fitted.size[0] - 1 - step, fitted.size[1] - 1 - step),
            outline=(0, 0, 0, max(0, vignette["startAlpha"] - step * vignette["fall"])),
        )
    layer.alpha_composite(shade, (window[0], window[1]))
    return layer.rotate(card["angle"], resample=Image.BICUBIC, center=((left + right) / 2, (top + bottom) / 2))


def note_layer(settings):
    width, height = settings["size"]
    scale = settings["scale"]
    note = settings["note"]
    random.seed(note["seed"])
    layer = Image.new("RGBA", (width * scale, height * scale), (0, 0, 0, 0))
    left, top, right, bottom = scaled(note["box"], scale)
    paper = Image.new("RGBA", (right - left, bottom - top), tuple(note["paper"]) + (255,))
    pixels = paper.load()
    for y in range(paper.size[1]):
        for x in range(paper.size[0]):
            red, green, blue, alpha = pixels[x, y]
            grain = random.randint(-7, 7)
            warm = int(10 * (y / paper.size[1]))
            pixels[x, y] = (max(0, red + grain - warm), max(0, green + grain - warm), max(0, blue + grain - warm * 2), alpha)
    draw = ImageDraw.Draw(paper)
    draw.rectangle((0, 0, paper.size[0] - 1, paper.size[1] - 1), outline=tuple(note["edge"]) + (255,), width=2)
    line_y = 10
    for length in (paper.size[0] * 0.55, paper.size[0] * 0.75, paper.size[0] * 0.4):
        x = 7
        points = []
        while x < 7 + length:
            points.append((x, line_y + random.randint(-1, 1)))
            x += random.randint(3, 5)
        draw.line(points, fill=tuple(note["ink"]), width=2)
        line_y += 9
    notch_y = int(paper.size[1] * 0.42)
    draw.rectangle((paper.size[0] - 4, notch_y, paper.size[0] - 1, notch_y + 10), fill=tuple(note["notch"]) + (255,))
    layer.paste(paper, (left, top))
    return layer.rotate(note["angle"], resample=Image.BICUBIC, center=((left + right) / 2, (top + bottom) / 2))


def draw_card(photo, settings):
    width, height = settings["size"]
    scale = settings["scale"]
    shadow = settings["shadow"]
    offset = (shadow["offset"], shadow["offset"])
    canvas = Image.new("RGBA", (width * scale, height * scale), (0, 0, 0, 0))
    card = card_layer(photo, settings)
    note = note_layer(settings)
    canvas.alpha_composite(shadow_of(card, shadow["cardRadius"], offset, shadow["cardOpacity"]))
    canvas.alpha_composite(card)
    canvas.alpha_composite(shadow_of(note, shadow["noteRadius"], offset, shadow["noteOpacity"]))
    canvas.alpha_composite(note)
    return canvas.resize((width, height), Image.LANCZOS)


def save_picture(picture, destination):
    folder = os.path.dirname(os.path.abspath(destination))
    os.makedirs(folder, exist_ok=True)
    if destination.lower().endswith(".png"):
        picture.save(destination)
        return
    with open(destination, "wb") as output:
        output.write(dds_header(picture.width, picture.height))
        output.write(picture.convert("RGBA").tobytes("raw", "BGRA"))


def convert(kind, source, destination, settings):
    with Image.open(source) as image:
        if kind == "large":
            picture = crop_to_aspect(image.convert("RGBA"), *LARGE_SIZE)
        elif kind == "small":
            picture = draw_card(image, settings)
        else:
            raise ValueError(f"unknown kind {kind}")
    save_picture(picture, destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--card", required=True)
    arguments = parser.parse_args()
    with open(arguments.card, encoding="utf-8") as card_file:
        settings = json.load(card_file)

    converted = 0
    failures = []
    with open(arguments.manifest, encoding="utf-8") as manifest:
        for line in manifest:
            line = line.rstrip("\r\n")
            if not line:
                continue
            fields = line.split("\t")
            if len(fields) != 3:
                failures.append(f"{line}: needs kind, source and destination")
                continue
            kind, source, destination = fields
            try:
                convert(kind, source, destination, settings)
                converted += 1
            except Exception as error:
                failures.append(f"{source}: {error}")

    print(f"portraits converted={converted} failed={len(failures)}")
    for failure in failures:
        print(f"  FAILED {failure}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
