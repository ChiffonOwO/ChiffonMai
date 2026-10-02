"""
把 assets/cover/*.png 转 webp 并压到 <20KB，转完删原 PNG。

策略（按顺序尝试，找到第一条命中的就停）：
  1) quality=80, method=6, 原始分辨率
  2) quality -= 5 直到 quality=20，每档重试一次
  3) quality 到底后仍 >20KB：长边 *= 0.85，最小 240px，重置 quality=80 再来
  4) 三步都不行：抛错，保留 PNG，不删

用法：
  python tool/compress_cover.py             # 处理所有 PNG
  python tool/compress_cover.py path/a.png path/b.png   # 只处理指定文件
"""
import io
import sys
from pathlib import Path
from PIL import Image

SRC_DIR = Path(r"D:\flutterProjects\my_first_flutter_app\assets\cover")
TARGET_BYTES = 20 * 1024
MIN_QUALITY = 20
MIN_DIM = 240
DIM_STEP = 0.85


def compress(src: Path):
    """返回 (输出webp路径, final_quality, final_longest, final_bytes)；不删原文件。"""
    dst = src.with_suffix(".webp")
    img = Image.open(src)
    if img.mode in ("RGBA", "P"):
        img = img.convert("RGB")  # 混 RGBA 会让 webp 体积飘，先拍平

    quality = 80
    longest = max(img.size)
    last = None
    while True:
        buf = io.BytesIO()
        img.save(buf, format="WEBP", quality=quality, method=6)
        size = buf.tell()
        last = (size, quality, longest)
        if size < TARGET_BYTES:
            dst.write_bytes(buf.getvalue())
            return dst, quality, longest, size
        if quality > MIN_QUALITY:
            quality -= 5
            continue
        if longest * DIM_STEP < MIN_DIM:
            break  # 再缩就糊到 <240 了，认栽
        longest = max(1, int(longest * DIM_STEP))
        img = img.resize(
            (int(img.size[0] * DIM_STEP), int(img.size[1] * DIM_STEP)),
            Image.LANCZOS,
        )
        quality = 80  # 降分辨率后从 quality=80 重来
    raise RuntimeError(f"压不到 {TARGET_BYTES // 1024}KB: {src.name}, last={last}")


def main():
    targets = [Path(a) for a in sys.argv[1:]] or sorted(SRC_DIR.glob("*.png"))
    if not targets:
        print("no png files found")
        return

    rows = []
    for p in targets:
        orig_kb = p.stat().st_size / 1024
        try:
            out, q, longest, new_bytes = compress(p)
            new_kb = new_bytes / 1024
            rows.append((p, orig_kb, out, new_kb, q, longest, None))
        except Exception as e:
            rows.append((p, orig_kb, None, None, None, None, str(e)))

    name_w = max(len(str(r[0].relative_to(SRC_DIR))) for r in rows)
    print(f"{'name'.ljust(name_w)}  {'origKB':>7}  {'webpKB':>7}  {'q':>3}  {'longest':>7}  status")
    print("-" * (name_w + 40))
    for p, o, out, n, q, longest, err in rows:
        rel = str(p.relative_to(SRC_DIR))
        if err:
            print(f"{rel.ljust(name_w)}  {o:7.1f}  FAIL: {err}")
            continue
        mark = "OK" if n < 20 else "OVER"
        print(
            f"{rel.ljust(name_w)}  {o:7.1f}  {n:7.1f}  {q:>3}  {longest:>7}  {mark}"
        )

    # 转完删原 PNG（失败的保留）
    deleted, kept = [], []
    for p, o, out, n, q, longest, err in rows:
        if err:
            kept.append(p)
            continue
        p.unlink()
        deleted.append(out)
    print()
    print(f"converted: {len(deleted)}, deleted PNG: {len(deleted)}, kept (failed): {len(kept)}")
    for k in kept:
        print(f"  kept: {k.name}")


if __name__ == "__main__":
    main()
