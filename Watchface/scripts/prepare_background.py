import sys
from PIL import Image, ImageOps

SIZE = 454
LEVELS = 16
STEP = 4


def prepare(source, target, center_y):
    image = Image.open(source).convert("L")
    image = ImageOps.fit(image, (SIZE, SIZE), Image.LANCZOS, centering=(0.5, center_y))
    image = ImageOps.autocontrast(image, cutoff=1)
    top = (LEVELS - 1) * STEP
    image = image.point(lambda p: round(p * top / 255 / STEP) * STEP)
    image.convert("RGB").save(target)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit("uso: prepare_background.py <foto> <saida.png> [centro_vertical=0.4]")
    prepare(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.4)
