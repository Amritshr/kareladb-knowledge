---
name: kdb-geometry
description: "Use when a task stores or reads survey, CAD or 3D data in KDB: survey points, control points and lines, traverses, 2D entities (line, arc, circle, polyline, text), layers, blocks and groups, meshes and terrains, or a canvas / WebGL viewer that loads a drawing in parts. Trigger on: survey, coordinates, northing/easting, DXF, CAD, drawing, entity, polyline, arc, layer, block, mesh, TIN, bounding box, viewport, partial load, pan/zoom with KDB."
---

# KDB for survey, CAD and 3D data

KDB has **no geometry type and no spatial index**. Do not look for `ST_*` functions or
`GEOMETRY` columns: they do not exist. Everything below uses plain columns, rows,
triggers and SQL maths, and it is fast enough up to a few hundred thousand entities per
drawing. The full topic with runnable examples is `/help/geometry-and-cad.html` on the server
(`GET $KDB_URL/help/geometry-and-cad.html`). Connecting and running SQL is in the `kdb` skill.

## The layout to use

| Thing | Table | Key columns |
|---|---|---|
| project | `projects` | `id`, `crs` (the one coordinate system of every number in it), `units` |
| survey point / shot | `points` | `(project, id)`, `x` easting, `y` northing, `z`, `code` (CP, TP, SP...), `observed` |
| raw instrument reading | `observations` | `station`, `bearing`, `vertical`, `slope`, `hi`, `ht` - coordinates are computed from these |
| drawing (also a block) | `drawings` | `id`, `project`, `name`, `props JSON` |
| layer | `layers` | `(drawing, name)`, `color`, `visible`, `locked` |
| entity | `entities` | `id UUID`, `drawing`, `layer`, `kind`, typed columns, `props JSON`, `min_x min_y max_x max_y`, `updated` |
| vertex | `vertices` | `(entity, seq)`, `x`, `y`, `z`, `bulge`; `REFERENCES entities(id) ON DELETE CASCADE` |
| mesh | `mesh_vertices`, `mesh_faces` | `(mesh, id)`; a face is three vertex ids |
| camera | `saved_views` | `(drawing, owner, name)`, `cx`, `cy`, `scale`, `rotation` - written rarely |

Rules that keep it right:

1. **One `crs` per project.** Never mix a local grid and a national grid in one table.
2. **`kind` says which columns mean something.** `line`/`polyline`: vertices. `circle`/`arc`:
   `cx cy radius` (+ `start_angle end_angle` in degrees, counter-clockwise from +x).
   `text`: `cx cy rotation` and `props.text`, `props.height`. `insert`: `block`, `cx cy rotation scale`.
   Groups: children carry the group's id in `parent`. These are DXF's conventions; keep them.
3. **The bounding box is always filled.** Vertex tables get `AFTER INSERT` and `AFTER UPDATE`
   triggers that recompute `min_x..max_y` of the entity from `min()`/`max()` over its vertices.
   Circles, text and inserts write their box in the same INSERT.
4. **Index `(drawing, min_x, min_y)`** on `entities`. The viewport query is
   `drawing = ? AND max_x >= x0 AND min_x <= x1 AND max_y >= y0 AND min_y <= y1`,
   joined to `layers` for `visible`.
5. **Vertices as rows, not JSON.** A `DOUBLE[]` is fine only for a list that is never edited
   in place and always read whole (a simplified copy for far zooms, for example).
6. **`props JSON` for the long tail** (colour, line weight, text). A field you filter on often
   gets its own column: `json_value()` cannot use an index.

## What stays in the client

Pan, zoom, the view matrix, hover and window selection never touch the database. The client
keeps a working set in memory, redraws from it every frame, and asks KDB again only when the
view leaves the loaded region (ask with a margin of about one screen). Save the camera as a
row in `saved_views` when the user stops moving or closes the drawing, not per frame.

## Maths that is already in SQL

| Need | Expression |
|---|---|
| distance | `sqrt((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1))` |
| surveyor's bearing (clockwise from north) | `degrees(atan2(x2-x1, y2-y1))`, add 360 if negative |
| coordinate from a shot | `x = sx + slope*sin(radians(vertical))*sin(radians(bearing))`, `y = ... cos(radians(bearing))`, `z = sz + hi + slope*cos(radians(vertical)) - ht` |
| arc start point / length | `cx + r*cos(radians(a0))`, `cy + r*sin(radians(a0))`; `r*radians(a1-a0)` |
| polyline length | `lag(x)`, `lag(y)` over `(PARTITION BY entity ORDER BY seq)`, sum the segment lengths; add the closing segment with `first_value()` when `closed` |
| polygon area | shoelace: `abs(sum(px*y - x*py) + closing term) / 2` with the same windows |
| mesh volume | `abs(sum(signed tetrahedron))/6` over the faces of a closed mesh |
| nearest point | narrow by a box on `x`, `y`, then `ORDER BY distance LIMIT 1` |

Use `sum(CASE WHEN ... END)`, never `max()`, for the closing term: it can be negative.

## History and several users

`SELECT ... FROM entities AS OF TIMESTAMP <t>` reads the drawing as it was; `INSERT OR
REPLACE ... SELECT * FROM entities AS OF ...` undoes an edit for everyone. `changes('entities')`
and `GET /api/changes?table=entities` give every committed change in order, so a second
viewer redraws what others change without polling. `CREATE DATABASE plan_b BRANCH OF <db>`
is a writable copy for a design alternative.

## Do not

- Do not store the camera, selection or matrix per frame.
- Do not put a whole drawing in one JSON document: it cannot be loaded in part or edited row by row.
- Do not invent `GEOMETRY`, `POINT`, `ST_Intersects`, `<->` or GiST indexes; say they are not in KDB and use the box columns.
- Do not convert between datums in SQL; that is not built in.
