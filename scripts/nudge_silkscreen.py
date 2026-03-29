import pcbnew

MIN_MM = 0.15  # 6 mil ≈ 0.1524mm; KiCad default 0.15mm is usually fine
MIN = pcbnew.FromMM(MIN_MM)

board = pcbnew.GetBoard()

F_SILK = pcbnew.F_SilkS
B_SILK = pcbnew.B_SilkS

changed = 0

def bump_width(obj, get_fn, set_fn, kind):
    global changed
    try:
        w = get_fn()
        if w is not None and w < MIN:
            set_fn(MIN)
            changed += 1
    except Exception:
        pass

# 1) Board-level drawings (lines, arcs, text, etc.)
for d in board.GetDrawings():
    if d.GetLayer() not in (F_SILK, B_SILK):
        continue

    # Shapes often have GetWidth/SetWidth
    if hasattr(d, "GetWidth") and hasattr(d, "SetWidth"):
        bump_width(d, d.GetWidth, d.SetWidth, "DRAWING")

    # PCB_TEXT typically uses GetTextThickness/SetTextThickness
    if hasattr(d, "GetTextThickness") and hasattr(d, "SetTextThickness"):
        bump_width(d, d.GetTextThickness, d.SetTextThickness, "TEXT")

# 2) Footprint-level items (graphics + text inside footprints)
for fp in board.GetFootprints():
    # Footprint reference/value text + user text
    for t in fp.GraphicalItems():
        if t.GetLayer() not in (F_SILK, B_SILK):
            continue

        if hasattr(t, "GetWidth") and hasattr(t, "SetWidth"):
            bump_width(t, t.GetWidth, t.SetWidth, "FP_SHAPE")

        if hasattr(t, "GetTextThickness") and hasattr(t, "SetTextThickness"):
            bump_width(t, t.GetTextThickness, t.SetTextThickness, "FP_TEXT")

print(f"Silkscreen strokes bumped to >= {MIN_MM}mm on {changed} items.")
pcbnew.Refresh()
