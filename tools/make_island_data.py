#!/usr/bin/env python3
"""Genera data/island.json (Isla 1A) y comprueba que los lotes no se encimen.

Se corre una sola vez (o cuando se quiera rehacer el reparto de lotes):
    python3 tools/make_island_data.py

El JSON resultante es el que se edita a mano: el juego solo lee el JSON.
Coordenadas en metros; (0, 0) = centro del parque. +Z = sur (avenida y muelle),
-Z = norte (el volcán de fondo). El ángulo de una calle se mide como
x = cos(a), z = sin(a): 90 = sur, 180 = oeste, 270 = norte, 0 = este.
"""
import json
import math
import os

SIZES = {"S": 32, "M": 48, "L": 64}
ISLAND_RADIUS = 352.0
STREETS = [  # ángulo, ancho (la avenida del muelle es la más ancha)
    {"id": "avenida", "name": "Avenida del Muelle", "angle": 90, "width": 12, "from": 34},
    {"id": "calle_oeste", "name": "Calle del Faro", "angle": 180, "width": 7, "from": 34},
    {"id": "calle_norte", "name": "Calle de la Ceiba", "angle": 270, "width": 7, "from": 34},
    {"id": "calle_este", "name": "Calle del Sol", "angle": 0, "width": 7, "from": 34},
]
RINGS = [  # anillo: radio del frente de los lotes y de la calle circular de adentro
    {"id": "A", "front": 58, "road": 52},
    {"id": "B", "front": 118, "road": 112},
    {"id": "C", "front": 199, "road": 193},
    {"id": "D", "front": 262, "road": 256},
]
TOTAL_LOTS = 60
START_LOTS = 30
BASE_PRICE = {"S": 6000, "M": 18000, "L": 48000}
RING_FACTOR = {"A": 1.25, "B": 1.0, "C": 0.9, "D": 0.8}
PREMIUM_FACTOR = 1.3
ROAD_WIDTH = 8.0
MARGIN = 2.0   # entre el lote y el borde de la calle radial
GAP = 2.0      # entre lotes vecinos
MIXES = {"A": "SS", "B": "SLSS", "C": "SSMS", "D": "LMSL"}
# Cuántos lotes lleva cada anillo en cada sector (None = todos los que entren).
D_ONLY_SECTOR = 0  # El anillo D solo existe en el sector sur-oeste/sur-este junto al muelle.


def corners(c, s, yaw_deg):
    a = math.radians(yaw_deg)
    sa, ca = math.sin(a), math.cos(a)
    out = []
    for lx, lz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        x, z = lx * s / 2, lz * s / 2
        # Rotación en Y de Godot: x' = x cos + z sin ; z' = -x sin + z cos
        out.append((c[0] + x * ca + z * sa, c[1] - x * sa + z * ca))
    return out


def sat_overlap(p, q):
    for poly in (p, q):
        for i in range(len(poly)):
            a, b = poly[i], poly[(i + 1) % len(poly)]
            ax, az = -(b[1] - a[1]), b[0] - a[0]
            pa = [x * ax + z * az for x, z in p]
            qa = [x * ax + z * az for x, z in q]
            if max(pa) < min(qa) or max(qa) < min(pa):
                return False
    return True


def street_rect(angle, width, r0, r1):
    a = math.radians(angle)
    d = (math.cos(a), math.sin(a))
    n = (-d[1], d[0])
    h = width / 2
    return [(d[0] * r0 + n[0] * h, d[1] * r0 + n[1] * h), (d[0] * r1 + n[0] * h, d[1] * r1 + n[1] * h),
            (d[0] * r1 - n[0] * h, d[1] * r1 - n[1] * h), (d[0] * r0 - n[0] * h, d[1] * r0 - n[1] * h)]


def min_radius(poly):
    best = 1e9
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        abx, abz = b[0] - a[0], b[1] - a[1]
        t = max(0.0, min(1.0, -(a[0] * abx + a[1] * abz) / (abx * abx + abz * abz)))
        best = min(best, math.hypot(a[0] + abx * t, a[1] + abz * t))
    return best


def build_lots():
    lots = []
    n = len(STREETS)
    for ring in RINGS:
        for k in range(n):
            s0, s1 = STREETS[k], STREETS[(k + 1) % n]
            a0 = s0["angle"]
            span = (s1["angle"] - a0) % 360
            if ring["id"] == "D" and k != D_ONLY_SECTOR and k != n - 1:
                continue  # D: solo los sectores del sur (junto al muelle).
            rf = ring["front"]
            avail = math.radians(span) * rf - s0["width"] / 2 - s1["width"] / 2 - 2 * MARGIN
            mix = MIXES[ring["id"]]
            seq, total, i = [], 0.0, 0
            while True:
                s = mix[i % len(mix)]
                i += 1
                need = SIZES[s] + (GAP if seq else 0)
                if total + need > avail:
                    break
                seq.append(s)
                total += need
            # Centrado dentro del sector.
            pos = (avail - total) / 2 + MARGIN + s0["width"] / 2
            for j, s in enumerate(seq):
                size = SIZES[s]
                mid = pos + size / 2
                phi = a0 + math.degrees(mid / rf)
                r = rf + size / 2
                c = (r * math.cos(math.radians(phi)), r * math.sin(math.radians(phi)))
                yaw = math.degrees(math.atan2(-math.cos(math.radians(phi)), -math.sin(math.radians(phi))))
                lots.append({"ring": ring["id"], "sector": k, "size": s, "center": [round(c[0], 1), round(c[1], 1)],
                             "yaw": round(yaw, 1), "angle": round(phi % 360, 1)})
                pos += size + GAP
    return lots


def validate(lots):
    polys = [corners(l["center"], SIZES[l["size"]] + 1.0, l["yaw"]) for l in lots]
    for i in range(len(lots)):
        for j in range(i + 1, len(lots)):
            if sat_overlap(polys[i], polys[j]):
                raise SystemExit("Se encima: %d %d" % (i, j))
    for i, l in enumerate(lots):
        poly = corners(l["center"], SIZES[l["size"]], l["yaw"])
        mx = max(math.hypot(x, z) for x, z in poly)
        mn = min_radius(poly)
        if mx > ISLAND_RADIUS - 22.0:
            raise SystemExit("Sale de la isla: %s %.1f" % (l, mx))
        if mn < 50.0:
            raise SystemExit("Invade el parque/comercios: %s" % l)
        for ring in RINGS:
            lo, hi = ring["road"] - ROAD_WIDTH / 2 - 1.0, ring["road"] + ROAD_WIDTH / 2 + 1.0
            if not (mx < lo or mn > hi):
                raise SystemExit("Pisa una calle circular %s: %s (%.1f-%.1f)" % (ring["id"], l, mn, mx))
        for st in STREETS:
            rect = street_rect(st["angle"], st["width"] + 2.0, st["from"], ISLAND_RADIUS)
            if sat_overlap(poly, rect):
                raise SystemExit("Pisa la calle %s: %s" % (st["id"], l))


def angle_to_avenue(l):
    return abs(((l["angle"] - 90 + 180) % 360) - 180)


def finish_lots(lots):
    """Campos que dependen del reparto: ids, precios, premium, quién empieza y estado."""
    for i, l in enumerate(lots):
        l["id"] = "i%02d" % (i + 1)
        l["cluster"] = "%s%d" % (l["ring"], l["sector"])
        l["premium"] = []
        if l["ring"] == "A":
            l["premium"].append("park")      # da al parque y a los comercios
        if l["ring"] == "D":
            l["premium"].append("beach")     # da a la playa
        base = BASE_PRICE[l["size"]] * RING_FACTOR[l["ring"]] * (PREMIUM_FACTOR if l["premium"] else 1.0)
        l["price"] = int(round(base / 100.0)) * 100
    # Los 30 del comienzo: anillos A y B enteros y los 6 del anillo C más cercanos a la avenida.
    start = [l for l in lots if l["ring"] in ("A", "B")]
    c_lots = sorted((l for l in lots if l["ring"] == "C"), key=angle_to_avenue)
    start += c_lots[:START_LOTS - len(start)]
    ids = {l["id"] for l in start}
    # La parcela de regalo (S) es la más cercana a la avenida del anillo A.
    gift = sorted((l for l in lots if l["ring"] == "A" and l["size"] == "S"), key=angle_to_avenue)[0]
    k = 0
    for l in lots:
        l["start"] = l["id"] in ids
        if not l["start"]:
            l["state"] = "future"
        elif l is gift:
            l["state"] = "player"
            l["price"] = 0
        else:
            k += 1
            l["state"] = "free" if k % 3 == 0 else "npc"   # vecinos simulados y parcelas libres


def fmt_lot(l):
    keys = ["id", "ring", "sector", "cluster", "size", "center", "yaw", "angle", "price", "premium", "start", "state"]
    return json.dumps({k: l[k] for k in keys}, ensure_ascii=False)


def write_json(lots, path):
    sizes = SIZES
    doc = {
        "_ayuda": (
            "La isla (Isla 1A, prototipo). Coordenadas en METROS: (0, 0) = centro del parque, +Z = sur (avenida y muelle), "
            "-Z = norte (volcán de fondo). 'lots' = parcelas: size S/M/L (lados en 'rules.sizes'), center = [x, z], yaw = giro en grados "
            "(el frente de la casa mira al centro de la isla), ring = anillo (A cerca del parque ... D junto a la playa), "
            "start = true si existe desde el comienzo (30), state = player (tu parcela regalada), npc (vecino simulado), "
            "free (libre: terreno verde con marcador) o future (todavía no abierta). Para mover un lote basta con cambiar center/yaw; "
            "que no se encimen ni pisen una calle lo comprueba tests/test_island.tscn. 'zones' = parque, comercios (solo decorados, "
            "apagados), playa, muelle y volcán. 'streets' = calles radiales (ángulo: x = cos, z = sin; 90 = sur) y circulares. "
            "'rules' = tamaños, límite de piezas por parcela, tope de parcelas por jugador y precios base. 'houses' = rangos de las "
            "casas simuladas. 'lod' = distancias (metros desde la cámara) de cada nivel de detalle y su histéresis. "
            "tools/make_island_data.py rehace el reparto de lotes (opcional)."
        ),
        "format_version": 1,
        "seed": 20261105,
        "island": {"radius": ISLAND_RADIUS, "sea_size": 3600.0, "sea_level": -0.35, "sand_width": 22.0,
                    "south_sand_width": 40.0, "south_sand_span": 130.0, "ring_segments": 96},
        "colors": {
            "sea": "#47b6d6", "ground": "#8fd16a", "lot_npc": "#a2dc7a", "lot_free": "#c3ec8e", "lot_future": "#97cf74",
            "lot_player": "#ffd86b", "road": "#6e6a7c", "road_edge": "#d9d2c3", "sand": "#f2e0a6", "park": "#79cf6b",
            "plaza": "#eadbb8", "lake": "#56c3e6", "lake_edge": "#e8d9a8", "commerce_floor": "#d8c8aa", "path": "#e3d3aa",
            "pier": "#b98a57", "pier_post": "#7a5a3a", "volcano": "#7b5a4f", "volcano_dark": "#5a3f38", "lava": "#ff7a3d",
            "smoke": "#d6cfdc", "trunk": "#8a5a3a", "crowns": ["#4fae5a", "#69c06a", "#3f9a55"], "marker": "#ff5d73",
            "marker_future": "#c9a9ff", "bench": "#a56f45", "gazebo_roof": "#e0675a", "umbrella": ["#ff7a7a", "#ffd25c", "#6ec6ff"],
            "shop_off": "#6b6475", "shop_walls": ["#f4d9d0", "#fff0b8", "#dfe9f5", "#e6f0d4", "#e4d9f2"],
            "shop_awnings": ["#e0675a", "#5b8fd6", "#59b89c", "#f2a65a"], "door": "#8a5a3a", "glass": "#a9d6f5",
            "foundation": "#b8a58c",
            "map_sea": "#47b6d6", "map_land": "#cfe9a0", "map_sand": "#f2e0a6", "map_road": "#ffffff", "map_park": "#79cf6b",
            "map_lake": "#56c3e6", "map_commerce": "#f2a65a", "map_lot_outline": "#5a4a66", "map_lot_free": "#e8f7c6",
            "map_lot_future": "#b7c9a0", "map_player": "#ffd86b", "map_pier": "#b98a57"
        },
        "rules": {
            "sizes": sizes, "start_lots": START_LOTS, "max_lots": TOTAL_LOTS, "max_lots_per_player": 3, "gift_size": "S",
            "max_pieces_per_lot": {"S": 700, "M": 1500, "L": 2600},
            "base_price": BASE_PRICE, "ring_factor": RING_FACTOR, "premium_factor": PREMIUM_FACTOR,
            "lot_gap": GAP, "street_margin": MARGIN
        },
        "zones": {
            "park": {"center": [0, 0], "radius": 34.0, "lake": {"center": [-9, -6], "radius": 12.0},
                      "plaza": {"center": [0, 22], "radius": 8.0}, "gazebo": {"center": [14, 6], "radius": 4.5, "height": 4.4},
                      "trees": 20, "benches": 6},
            "commerce": {"inner": 37.0, "outer": 47.0, "count": 18, "depth": 8.0, "min_width": 9.0, "max_width": 13.0,
                          "min_height": 4.5, "max_height": 8.5, "active": False},
            "beach": {"umbrellas": 10, "palms": 36},
            "pier": {"angle": 90, "length": 90.0, "width": 9.0, "post_every": 6.0, "end_platform": 16.0},
            "volcano": {"center": [40.0, -600.0], "base_radius": 170.0, "height": 210.0, "crater_radius": 34.0,
                         "crater_depth": 14.0, "segments": 20, "smoke": {"enabled": True, "puffs": 7}}
        },
        "streets": {
            "radial": [{"id": st["id"], "name": st["name"], "angle": st["angle"], "width": st["width"], "from": st["from"],
                         "to": ISLAND_RADIUS - 24.0} for st in STREETS],
            "rings": [
                {"id": "r1", "radius": 52.0, "width": ROAD_WIDTH, "arc": [0, 360]},
                {"id": "r2", "radius": 112.0, "width": ROAD_WIDTH, "arc": [0, 360]},
                {"id": "r3", "radius": 193.0, "width": ROAD_WIDTH, "arc": [0, 360]},
                {"id": "r4", "radius": 256.0, "width": ROAD_WIDTH, "arc": [20, 160]}
            ],
            "sidewalk": 2.0, "tree_spacing": 16.0
        },
        "houses": {
            "S": {"cols": [8, 13], "rows": [7, 10], "floors": [1, 2]},
            "M": {"cols": [13, 20], "rows": [9, 14], "floors": [1, 3]},
            "L": {"cols": [18, 28], "rows": [12, 18], "floors": [2, 3]},
            "front_gap": 4.0, "l_shape_chance": 0.35, "flat_roof_chance": 0.25, "setback_chance": 0.6, "garden_trees": [2, 4]
        },
        "lod": {
            "distances": [70.0, 230.0, 520.0], "hysteresis": 0.12, "map_enter_radii": 2.9, "map_exit_radii": 2.5,
            "update_interval": 0.15, "builds_per_frame": 2, "lod0_max": 3, "vegetation_range": 320.0,
            "vegetation_hysteresis": 0.15, "vegetation_chunk": 140.0, "outline_max_level": 1
        },
        "demo": {
            "stress_lots": 60, "stress_houses": 100, "stress_spacing": 52.0, "warmup_frames": 40, "measure_seconds": 2.0,
            "presets": [
                {"name": "calle", "focus": "player", "distance": 42.0, "yaw": 20.0, "pitch": -40.0},
                {"name": "barrio", "focus": "i12", "distance": 210.0, "yaw": 20.0, "pitch": -50.0},
                {"name": "isla", "focus": "center", "distance": 760.0, "yaw": 0.0, "pitch": -62.0}
            ]
        }
    }
    text = json.dumps(doc, indent=1, ensure_ascii=False)
    lots_text = "[\n" + ",\n".join("  " + fmt_lot(l) for l in lots) + "\n ]"
    text = text[:-2] + ',\n "lots": ' + lots_text + "\n}\n"
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def main():
    lots = build_lots()
    # Se queda con 60: del anillo D se sacan los más lejanos a la avenida.
    extra = len(lots) - TOTAL_LOTS
    if extra > 0:
        d_lots = sorted((l for l in lots if l["ring"] == "D"), key=lambda l: -angle_to_avenue(l))
        for l in d_lots[:extra]:
            lots.remove(l)
    validate(lots)
    finish_lots(lots)
    print("lotes:", len(lots), {r["id"]: sum(1 for l in lots if l["ring"] == r["id"]) for r in RINGS},
          {s: sum(1 for l in lots if l["size"] == s) for s in "SML"},
          "start:", sum(1 for l in lots if l["start"]), {st: sum(1 for l in lots if l["state"] == st) for st in ("player", "npc", "free", "future")})
    here = os.path.dirname(os.path.abspath(__file__))
    write_json(lots, os.path.join(here, "..", "data", "island.json"))
    print("escrito data/island.json")


if __name__ == "__main__":
    main()
