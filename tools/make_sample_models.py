#!/usr/bin/env python3
"""Genera los .glb de ejemplo de la Fase 7 (silla, mesa y un peinado) SIN Blender.

Uso (desde la carpeta del proyecto):
    python3 tools/make_sample_models.py

Escribe en assets/models/. Sirve para probar el camino del arte de punta a punta
(docs/estilo.md) y como ejemplo de las convenciones:
  - 1 celda = 1 metro, pivote en el centro de la base (y = 0 es el piso),
  - el frente mira hacia +Z (en glTF +Z es el frente),
  - formas redondeadas con pocos polígonos,
  - materiales con nombre (wood, cloth_red, hair...): el juego los pinta
    desde data/palette.json, así que acá el color es solo de referencia.
Solo usa la biblioteca estándar de Python.
"""
import json
import math
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PALETTE = json.load(open(os.path.join(ROOT, "data", "palette.json"), encoding="utf-8"))["materials"]


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material_factor(name):
    hexa = PALETTE.get(name, "#ffffff").lstrip("#")
    r, g, b = (int(hexa[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return [srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0]


class Mesh:
    """Triángulos agrupados por material."""

    def __init__(self):
        self.prims = {}  # material -> (positions, normals, indices)

    def _prim(self, material):
        return self.prims.setdefault(material, ([], [], []))

    def rounded_prism(self, material, cx, cz, w, d, y0, y1, radius, arc_steps=3):
        """Prisma de esquinas redondeadas (cilindro si radius = w/2 = d/2)."""
        radius = min(radius, w / 2.0, d / 2.0)
        outline = []  # (x, z, nx, nz)
        corners = [(1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)]
        for sx, sz, start in corners:
            ccx = cx + sx * (w / 2.0 - radius)
            ccz = cz + sz * (d / 2.0 - radius)
            for i in range(arc_steps + 1):
                a = math.radians(start + 90.0 * i / arc_steps)
                nx, nz = math.cos(a), math.sin(a)
                outline.append((ccx + nx * radius, ccz + nz * radius, nx, nz))
        positions, normals, indices = self._prim(material)
        n = len(outline)
        base = len(positions)
        for x, z, nx, nz in outline:
            positions.append((x, y0, z)); normals.append((nx, 0.0, nz))
            positions.append((x, y1, z)); normals.append((nx, 0.0, nz))
        for i in range(n):
            j = (i + 1) % n
            a0, a1, b0, b1 = base + 2 * i, base + 2 * i + 1, base + 2 * j, base + 2 * j + 1
            indices += [a0, a1, b0, a1, b1, b0]
        for y, ny in ((y1, 1.0), (y0, -1.0)):
            center = len(positions)
            positions.append((cx, y, cz)); normals.append((0.0, ny, 0.0))
            ring = len(positions)
            for x, z, _, _ in outline:
                positions.append((x, y, z)); normals.append((0.0, ny, 0.0))
            for i in range(n):
                j = (i + 1) % n
                if ny > 0:
                    indices += [center, ring + j, ring + i]
                else:
                    indices += [center, ring + i, ring + j]

    def dome(self, material, cx, cy, cz, rx, ry, rz, rings=4, segments=10, cut=0.0):
        """Media esfera (casquete) apoyada en y = cy; `cut` baja el borde."""
        positions, normals, indices = self._prim(material)
        base = len(positions)
        for r in range(rings + 1):
            phi = (math.pi / 2.0) * r / rings  # 0 = polo, pi/2 = borde
            for s in range(segments):
                theta = 2.0 * math.pi * s / segments
                nx = math.sin(phi) * math.cos(theta)
                ny = math.cos(phi)
                nz = math.sin(phi) * math.sin(theta)
                positions.append((cx + rx * nx, cy + ry * ny - cut * (r / rings), cz + rz * nz))
                normals.append((nx, ny, nz))
        for r in range(rings):
            for s in range(segments):
                a = base + r * segments + s
                b = base + r * segments + (s + 1) % segments
                c = base + (r + 1) * segments + s
                e = base + (r + 1) * segments + (s + 1) % segments
                indices += [a, b, c, b, e, c]


def write_glb(path, name, mesh):
    materials, primitives = [], []
    blob = bytearray()
    accessors, views = [], []

    def add_view(data, target):
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
        blob.extend(data)
        return len(views) - 1

    for material, (positions, normals, indices) in mesh.prims.items():
        materials.append({"name": material, "pbrMetallicRoughness": {
            "baseColorFactor": material_factor(material), "metallicFactor": 0.0, "roughnessFactor": 1.0}})
        pos_data = b"".join(struct.pack("<3f", *p) for p in positions)
        nor_data = b"".join(struct.pack("<3f", *n) for n in normals)
        idx_data = b"".join(struct.pack("<H", i) for i in indices)
        mins = [min(p[k] for p in positions) for k in range(3)]
        maxs = [max(p[k] for p in positions) for k in range(3)]
        accessors.append({"bufferView": add_view(pos_data, 34962), "componentType": 5126, "count": len(positions),
                          "type": "VEC3", "min": mins, "max": maxs})
        accessors.append({"bufferView": add_view(nor_data, 34962), "componentType": 5126, "count": len(normals), "type": "VEC3"})
        accessors.append({"bufferView": add_view(idx_data, 34963), "componentType": 5123, "count": len(indices), "type": "SCALAR"})
        primitives.append({"attributes": {"POSITION": len(accessors) - 3, "NORMAL": len(accessors) - 2},
                           "indices": len(accessors) - 1, "material": len(materials) - 1})
    while len(blob) % 4:
        blob.append(0)
    document = {
        "asset": {"version": "2.0", "generator": "Neighborhood tools/make_sample_models.py"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": primitives}],
        "materials": materials, "accessors": accessors, "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    json_bytes = json.dumps(document, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * (-len(json_bytes) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(blob)
    with open(path, "wb") as out:
        out.write(struct.pack("<4sII", b"glTF", 2, total))
        out.write(struct.pack("<I4s", len(json_bytes), b"JSON") + json_bytes)
        out.write(struct.pack("<I4s", len(blob), b"BIN\0") + bytes(blob))
    triangles = sum(len(p[2]) for p in mesh.prims.values()) // 3
    print("%s: %d triángulos, %d bytes, materiales %s" % (os.path.relpath(path, ROOT), triangles, total, list(mesh.prims)))


def chair():
    """Silla de 1 x 1 celda, 0,9 m de alto. Respaldo atrás (-Z), frente a +Z."""
    m = Mesh()
    seat_y = 0.45
    m.rounded_prism("cloth_red", 0, 0.02, 0.62, 0.62, seat_y, seat_y + 0.1, 0.12)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.rounded_prism("wood", sx * 0.25, 0.02 + sz * 0.25, 0.08, 0.08, 0, seat_y, 0.04, 2)
    m.rounded_prism("wood", 0, -0.27, 0.62, 0.07, seat_y + 0.1, 0.9, 0.03, 2)
    return m


def table():
    """Mesa de 2 x 1 celdas, 0,78 m de alto."""
    m = Mesh()
    m.rounded_prism("wood_light", 0, 0, 1.86, 0.88, 0.7, 0.78, 0.16)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.rounded_prism("wood", sx * 0.82, sz * 0.32, 0.1, 0.1, 0, 0.7, 0.05, 2)
    return m


def hair_round():
    """Pelo redondo para la cabeza del personaje (radio 0,3 m, centro en el origen)."""
    m = Mesh()
    m.dome("hair", 0, 0.02, 0, 0.33, 0.33, 0.33, rings=4, segments=12, cut=0.12)
    return m


if __name__ == "__main__":
    out_dir = os.path.join(ROOT, "assets", "models")
    os.makedirs(os.path.join(out_dir, "character"), exist_ok=True)
    write_glb(os.path.join(out_dir, "chair.glb"), "chair", chair())
    write_glb(os.path.join(out_dir, "table.glb"), "table", table())
    write_glb(os.path.join(out_dir, "character", "hair_round.glb"), "hair_round", hair_round())
