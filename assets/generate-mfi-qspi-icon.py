#!/usr/bin/env python3

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


SCALE = 2
SIZE = 1024
CANVAS = SIZE * SCALE


def scale(value: float) -> int:
    return round(value * SCALE)


def color_at(ratio: float) -> tuple[int, int, int, int]:
    top = (10, 35, 52)
    bottom = (18, 83, 96)
    return tuple(
        round(start + (end - start) * ratio)
        for start, end in zip(top, bottom)
    ) + (255,)


def main() -> None:
    output_dir = Path(__file__).resolve().parent
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))

    background = Image.new("RGBA", (1, CANVAS))
    background.putdata([color_at(y / (CANVAS - 1)) for y in range(CANVAS)])
    background = background.resize((CANVAS, CANVAS))

    mask = Image.new("L", (CANVAS, CANVAS), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (scale(32), scale(32), scale(992), scale(992)),
        radius=scale(220),
        fill=255,
    )
    canvas.alpha_composite(Image.composite(background, Image.new("RGBA", background.size), mask))

    shine = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shine_draw = ImageDraw.Draw(shine)
    shine_draw.rounded_rectangle(
        (scale(64), scale(52), scale(960), scale(470)),
        radius=scale(170),
        fill=(255, 255, 255, 20),
    )
    shine = shine.filter(ImageFilter.GaussianBlur(scale(30)))
    canvas.alpha_composite(Image.composite(shine, Image.new("RGBA", shine.size), mask))

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (scale(252), scale(275), scale(772), scale(825)),
        radius=scale(92),
        fill=(0, 0, 0, 115),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(scale(34)))
    canvas.alpha_composite(shadow)

    pins = ImageDraw.Draw(canvas)
    pin_color = (64, 226, 196, 255)
    pin_positions = (360, 465, 570, 675)
    for position in pin_positions:
        pins.rounded_rectangle(
            (scale(174), scale(position - 24), scale(310), scale(position + 24)),
            radius=scale(18),
            fill=pin_color,
        )
        pins.rounded_rectangle(
            (scale(714), scale(position - 24), scale(850), scale(position + 24)),
            radius=scale(18),
            fill=pin_color,
        )

    chip = ImageDraw.Draw(canvas)
    chip.rounded_rectangle(
        (scale(260), scale(282), scale(764), scale(818)),
        radius=scale(88),
        fill=(233, 243, 245, 255),
        outline=(193, 214, 220, 255),
        width=scale(9),
    )
    chip.rounded_rectangle(
        (scale(305), scale(327), scale(719), scale(773)),
        radius=scale(56),
        fill=(218, 233, 237, 255),
        outline=(176, 202, 210, 255),
        width=scale(5),
    )

    bolt_shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(bolt_shadow).polygon(
        [
            (scale(544), scale(378)),
            (scale(394), scale(604)),
            (scale(500), scale(604)),
            (scale(438), scale(760)),
            (scale(648), scale(514)),
            (scale(536), scale(514)),
        ],
        fill=(94, 57, 0, 70),
    )
    bolt_shadow = bolt_shadow.filter(ImageFilter.GaussianBlur(scale(16)))
    canvas.alpha_composite(bolt_shadow)

    bolt = ImageDraw.Draw(canvas)
    bolt.polygon(
        [
            (scale(548), scale(365)),
            (scale(375), scale(615)),
            (scale(494), scale(615)),
            (scale(428), scale(790)),
            (scale(662), scale(505)),
            (scale(534), scale(505)),
        ],
        fill=(255, 181, 54, 255),
        outline=(218, 132, 20, 255),
        width=scale(6),
    )
    bolt.rounded_rectangle(
        (scale(128), scale(884), scale(896), scale(918)),
        radius=scale(17),
        fill=(81, 224, 199, 220),
    )

    final = canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    for size in (48, 64, 128, 256, 512, 1024):
        resized = final.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(output_dir / f"mfi-qspi-forge-{size}.png")


if __name__ == "__main__":
    main()
