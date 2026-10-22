# Survey, CAD and 3D data: points, drawings, blocks, meshes

> How to keep survey points, 2D drawings (lines, arcs, polylines, blocks, layers) and 3D meshes in KDB, load only the part a canvas can see, and do distance, area and volume maths in SQL - with the rule that the camera stays in the client.

- Category: Geometry & CAD
- Keywords: survey, land survey, survey data, control point, control line, traverse, total station, northing, easting, elevation, coordinates, coordinate system, projection, datum, CAD, drawing, DXF, DWG, entity, line, arc, circle, polyline, vertex, vertices, bulge, layer, block, block insert, group, 2D, 3D, mesh, triangle, TIN, terrain, point cloud, solid, bounding box, bbox, viewport, partial load, level of detail, LOD, pan, zoom, camera, canvas, WebGL, hit test, selection, area, shoelace, perimeter, bearing, distance, volume, cross section, geometry, spatial, GIS, PostGIS, R-tree
- See also: [Database models: relational, hierarchical, network, NoSQL, object](data-models.md), [Column types](column-types.md), [Constraints](constraints.md), [Triggers](triggers.md), [Views](views.md), [Math functions](functions-math.md), [Window and series functions](functions-window.md), [Time travel and branches: SELECT ... AS OF, CREATE DATABASE ... BRANCH OF](as-of-and-branches.md), [Change stream and live subscriptions: changes('t'), GET /api/changes, GET /api/subscribe](change-stream.md), [JSON functions](functions-json.md), [Indexes](indexes.md)

KDB has no geometry type and no spatial index, but it has what a drawing really is made of: numbers, ordered lists, keys, rules and history. This topic shows one layout that works for survey work, 2D CAD and 3D objects, and what to leave to the program that draws.

| You want to keep | Use | Why |
|---|---|---|
| a coordinate | `DOUBLE` columns `x`, `y`, `z` (or `DECIMAL(12,4)` for legal plans) | fast maths, plain to read, indexable |
| a list of vertices | one row per vertex with a `seq` number, or a `DOUBLE[]` when the list is only ever read whole | rows can be changed one at a time; an array is one value |
| what an entity is | a `kind` column and a few typed columns (`radius`, `start_angle`, ...) | no parsing, every value queryable |
| style, text, anything free-form | a `JSON` column | one place for the long tail, still searchable with `json_value()` |
| the shape's extent | four columns `min_x`, `min_y`, `max_x`, `max_y`, kept by a trigger | the "what is in view" query needs only these |
| a mesh | a vertex table and a face table | partial loads, volumes and sections stay SQL |
| who changed what and when | `AS OF`, the change stream, a branch | history comes with the database |

What is **not** in KDB today: `ST_Intersects`, buffers, projections between datums, and an R-tree. The bounding-box columns and a B-tree index on them do the job up to a few hundred thousand entities per drawing; beyond that a grid index would be new engine work.

Setup used by the examples below:

```sql
CREATE TABLE projects (
  id    INT PRIMARY KEY,
  name  TEXT NOT NULL,
  crs   TEXT NOT NULL,              -- the one coordinate system every number in this project is in
  units TEXT NOT NULL DEFAULT 'm'
);
CREATE TABLE points (
  project   INT NOT NULL REFERENCES projects(id),
  id        INT NOT NULL,
  x         DOUBLE NOT NULL,        -- easting
  y         DOUBLE NOT NULL,        -- northing
  z         DOUBLE,                 -- elevation, NULL when not measured
  code      TEXT NOT NULL,          -- CP control, TP traverse, SP spot shot, ...
  note      TEXT,
  observed  TIMESTAMP DEFAULT now(),
  PRIMARY KEY (project, id)
);
CREATE TABLE drawings (
  id      INT PRIMARY KEY,
  project INT NOT NULL REFERENCES projects(id),
  name    TEXT NOT NULL,
  props   JSON
);
CREATE TABLE layers (
  drawing INT NOT NULL REFERENCES drawings(id),
  name    TEXT NOT NULL,
  color   TEXT,
  visible BOOL NOT NULL DEFAULT TRUE,
  locked  BOOL NOT NULL DEFAULT FALSE,
  PRIMARY KEY (drawing, name)
);
CREATE TABLE entities (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  drawing     INT NOT NULL REFERENCES drawings(id),
  layer       TEXT NOT NULL,
  kind        TEXT NOT NULL,        -- line, polyline, arc, circle, text, insert
  closed      BOOL NOT NULL DEFAULT FALSE,
  cx          DOUBLE, cy DOUBLE,    -- circle and arc: centre; text and insert: position
  radius      DOUBLE,
  start_angle DOUBLE, end_angle DOUBLE,   -- degrees, counter-clockwise from +x
  rotation    DOUBLE NOT NULL DEFAULT 0,
  scale       DOUBLE NOT NULL DEFAULT 1,
  block       INT,                  -- kind = 'insert': the block placed here
  parent      UUID,                 -- the group this entity belongs to, if any
  props       JSON,                 -- colour, line weight, text value, ...
  min_x       DOUBLE, min_y DOUBLE, max_x DOUBLE, max_y DOUBLE,
  updated     TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX entities_view ON entities (drawing, min_x, min_y);
CREATE TABLE vertices (
  entity UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  seq    INT NOT NULL,
  x      DOUBLE NOT NULL,
  y      DOUBLE NOT NULL,
  z      DOUBLE,
  bulge  DOUBLE NOT NULL DEFAULT 0, -- a curved segment to the next vertex, as DXF writes it
  PRIMARY KEY (entity, seq)
);
CREATE TRIGGER vertices_box_i AFTER INSERT ON vertices EXECUTE BEGIN
  UPDATE entities SET min_x = s.x0, min_y = s.y0, max_x = s.x1, max_y = s.y1, updated = now()
  FROM (SELECT entity, min(x) AS x0, min(y) AS y0, max(x) AS x1, max(y) AS y1
        FROM vertices WHERE entity IN (SELECT entity FROM NEW) GROUP BY entity) s
  WHERE entities.id = s.entity;
END;
CREATE TRIGGER vertices_box_u AFTER UPDATE ON vertices EXECUTE BEGIN
  UPDATE entities SET min_x = s.x0, min_y = s.y0, max_x = s.x1, max_y = s.y1, updated = now()
  FROM (SELECT entity, min(x) AS x0, min(y) AS y0, max(x) AS x1, max(y) AS y1
        FROM vertices WHERE entity IN (SELECT entity FROM NEW) GROUP BY entity) s
  WHERE entities.id = s.entity;
END;
INSERT INTO projects VALUES (1, 'Riverside plot 12', 'EPSG:32645', 'm');
INSERT INTO points (project, id, x, y, z, code) VALUES
  (1, 1, 1000.000, 2000.000, 100.50, 'CP'),
  (1, 2, 1100.000, 2000.000, 101.20, 'CP'),
  (1, 3, 1100.000, 2080.000,  99.80, 'CP'),
  (1, 4, 1000.000, 2080.000, 100.10, 'CP'),
  (1, 5, 1052.300, 2041.700, 100.90, 'SP');
INSERT INTO drawings VALUES (1, 1, 'Site plan', '{"scale":"1:500"}');
INSERT INTO layers (drawing, name, color) VALUES (1, 'BOUNDARY', 'red'), (1, 'ROAD', 'grey'), (1, 'TEXT', 'black');
```

<a id="coordinates"></a>

## Coordinates and the one rule

Keep every coordinate of a project in **one** coordinate system, and write its name down in the project row (`crs`). Mixing a local site grid with a national grid in the same table is the most common survey data error, and no query can repair it later. Store x = easting, y = northing, z = elevation, as `DOUBLE`: 15-16 significant digits hold a millimetre at the size of a country.

**Example: The project says which coordinate system its numbers are in**

```sql
SELECT name, crs, units FROM projects;
```

Result:

| name (STRING) | crs (STRING) | units (STRING) |
|---|---|---|
| Riverside plot 12 | EPSG:32645 | m |

(1 row)

- **Notes:**
  - For legal boundary plans, where a value must print back exactly as surveyed, use `DECIMAL(12, 4)` instead ([column-types](column-types.md#decimal)). Maths on `DOUBLE` is faster.
  - A point that must be unique by its number within a project gets the composite key `(project, id)` as above; a point id can then repeat in another project.

<a id="points"></a>

## Survey points and control

One row per shot: number, x, y, z, a code and when it was observed. Control points, traverse stations and spot shots live in the same table and differ by `code`, so one index and one query serve them all. A control **line** is an ordered pair (or list) of control points, kept in its own small table.

**Example: Control points, and the distance and bearing between two of them**

Setup:

```sql
CREATE TABLE control_lines (project INT, id INT, from_pt INT, to_pt INT, PRIMARY KEY (project, id));
INSERT INTO control_lines VALUES (1, 1, 1, 2), (1, 2, 2, 3);
```

```sql
SELECT l.id,
       round(sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)), 3) AS distance,
       round(degrees(atan2(b.x - a.x, b.y - a.y)), 4)                       AS bearing_deg
FROM control_lines l
JOIN points a ON a.project = l.project AND a.id = l.from_pt
JOIN points b ON b.project = l.project AND b.id = l.to_pt
ORDER BY l.id;
```

Result:

| id (INT) | distance (DOUBLE) | bearing_deg (DOUBLE) |
|---|---|---|
| 1 | 100 | 90 |
| 2 | 80 | 0 |

(2 rows)

- **Notes:**
  - Surveyors measure bearing clockwise from north, so it is `atan2(dx, dy)`, not the mathematician's `atan2(dy, dx)`. A negative result is a bearing west of north: add 360.
  - `round(..., 3)` is for the page; keep the full `DOUBLE` in the table.

<a id="observations"></a>

## Raw observations, reduced in SQL

Keep what the instrument gave: station, bearing (or horizontal angle), slope distance, vertical angle, instrument and target heights. Coordinates are **computed** from them. When a setup turns out wrong, change one row and recompute, instead of hunting the points it touched.

**Example: A total-station shot, reduced to a coordinate**

Setup:

```sql
CREATE TABLE observations (
  id       INT PRIMARY KEY,
  project  INT, station INT,
  bearing  DOUBLE,     -- degrees from north
  vertical DOUBLE,     -- zenith angle, 90 = level
  slope    DOUBLE,     -- slope distance
  hi       DOUBLE DEFAULT 0,  -- instrument height
  ht       DOUBLE DEFAULT 0   -- target height
);
INSERT INTO observations VALUES (1, 1, 1, 45.0, 88.5, 70.711, 1.5, 1.8);
```

```sql
SELECT o.id,
       round(s.x + o.slope * sin(radians(o.vertical)) * sin(radians(o.bearing)), 3) AS x,
       round(s.y + o.slope * sin(radians(o.vertical)) * cos(radians(o.bearing)), 3) AS y,
       round(s.z + o.hi + o.slope * cos(radians(o.vertical)) - o.ht, 3)             AS z
FROM observations o
JOIN points s ON s.project = o.project AND s.id = o.station;
```

Result:

| id (INT) | x (DOUBLE) | y (DOUBLE) | z (DOUBLE) |
|---|---|---|---|
| 1 | 1049.983 | 2049.983 | 102.051 |

(1 row)

A traverse closure is the same maths summed over the legs: `sum()` of the easting and northing differences, compared with the known end point. `WITH RECURSIVE` ([union-subqueries](union-subqueries.md)) walks a traverse that is stored leg by leg.

<a id="entities"></a>

## Drawings, layers and entities

One `entities` row per thing a CAD program would call an entity. The `kind` column says which of the typed columns are meaningful; the bounding box columns are filled by a trigger from the vertices, or directly for circles and text. Layers are a table too, so visibility and lock state are data, not a convention.

**Example: A polyline from four vertices: the trigger fills its bounding box**

Setup:

```sql
INSERT INTO entities (id, drawing, layer, kind, closed) VALUES ('0f0e0d0c-0b0a-4908-8706-050403020100', 1, 'BOUNDARY', 'polyline', TRUE);
INSERT INTO vertices (entity, seq, x, y) VALUES
  ('0f0e0d0c-0b0a-4908-8706-050403020100', 1, 1000, 2000),
  ('0f0e0d0c-0b0a-4908-8706-050403020100', 2, 1100, 2000),
  ('0f0e0d0c-0b0a-4908-8706-050403020100', 3, 1100, 2080),
  ('0f0e0d0c-0b0a-4908-8706-050403020100', 4, 1000, 2080);
```

```sql
SELECT layer, kind, closed, min_x, min_y, max_x, max_y FROM entities;
```

Result:

| layer (STRING) | kind (STRING) | closed (BOOL) | min_x (DOUBLE) | min_y (DOUBLE) | max_x (DOUBLE) | max_y (DOUBLE) |
|---|---|---|---|---|---|---|
| BOUNDARY | polyline | true | 1000 | 2000 | 1100 | 2080 |

(1 row)

**Example: A circle and a text label have no vertices: write their box directly**

Setup:

```sql
INSERT INTO entities (drawing, layer, kind, cx, cy, radius, min_x, min_y, max_x, max_y)
  VALUES (1, 'ROAD', 'circle', 1050, 2040, 6, 1044, 2034, 1056, 2046);
INSERT INTO entities (drawing, layer, kind, cx, cy, rotation, props, min_x, min_y, max_x, max_y)
  VALUES (1, 'TEXT', 'text', 1052.3, 2041.7, 0, '{"text":"MH 5","height":1.5}', 1052.3, 2041.7, 1058.3, 2043.2);
```

```sql
SELECT kind, cx, cy, radius, json_value(props, '$.text') AS text FROM entities WHERE kind IN ('circle', 'text') ORDER BY kind;
```

Result:

| kind (STRING) | cx (DOUBLE) | cy (DOUBLE) | radius (DOUBLE) | text (STRING) |
|---|---|---|---|---|
| circle | 1050 | 2040 | 6 | NULL |
| text | 1052.3 | 2041.7 | NULL | MH 5 |

(2 rows)

**Example: Moving a vertex moves the box with it**

Setup:

```sql
INSERT INTO entities (id, drawing, layer, kind) VALUES ('0f0e0d0c-0b0a-4908-8706-050403020100', 1, 'ROAD', 'line');
INSERT INTO vertices (entity, seq, x, y) VALUES ('0f0e0d0c-0b0a-4908-8706-050403020100', 1, 0, 0), ('0f0e0d0c-0b0a-4908-8706-050403020100', 2, 10, 0);
```

```sql
UPDATE vertices SET x = 25, y = 12 WHERE entity = '0f0e0d0c-0b0a-4908-8706-050403020100' AND seq = 2;
SELECT kind, min_x, min_y, max_x, max_y FROM entities;
```

Result:

`UPDATE vertices SET x = 25, y = 12 WHERE entity = '0f0e0d0c-0b0a-4908-8706-050403020100' AND seq = 2`

```text
1 row(s) updated
```

`SELECT kind, min_x, min_y, max_x, max_y FROM entities`

| kind (STRING) | min_x (DOUBLE) | min_y (DOUBLE) | max_x (DOUBLE) | max_y (DOUBLE) |
|---|---|---|---|---|
| line | 0 | 0 | 25 | 12 |

(1 row)

**Example: Deleting an entity deletes its vertices**

Setup:

```sql
INSERT INTO entities (id, drawing, layer, kind) VALUES ('0f0e0d0c-0b0a-4908-8706-050403020100', 1, 'ROAD', 'line');
INSERT INTO vertices (entity, seq, x, y) VALUES ('0f0e0d0c-0b0a-4908-8706-050403020100', 1, 0, 0), ('0f0e0d0c-0b0a-4908-8706-050403020100', 2, 10, 0);
```

```sql
DELETE FROM entities WHERE id = '0f0e0d0c-0b0a-4908-8706-050403020100';
SELECT count(*) AS vertices_left FROM vertices;
```

Result:

`DELETE FROM entities WHERE id = '0f0e0d0c-0b0a-4908-8706-050403020100'`

```text
1 row(s) deleted
```

`SELECT count(*) AS vertices_left FROM vertices`

| vertices_left (LONG) |
|---|
| 0 |

(1 row)

- **Notes:**
  - Arcs: `cx`, `cy`, `radius`, `start_angle`, `end_angle` in degrees, counter-clockwise from +x, the way DXF stores them. The start point is `(cx + radius * cos(radians(start_angle)), cy + radius * sin(radians(start_angle)))`; the arc length is `radius * radians(end_angle - start_angle)`.
  - A curved polyline segment is a `bulge` on the vertex it starts at (tangent of a quarter of the included angle, again DXF's convention). Keeping DXF's conventions makes import and export a straight copy.
  - A box is a cheap over-estimate: a circle's box includes its corners, an arc's box can be computed exactly but the full circle's box is good enough to find it.
  - `props` holds colour, line weight, line type, text value, text height, and anything a plugin adds. `json_value(props, '$.text')` reads one field; an index on it is not possible, so a field you filter on often gets its own column.

<a id="blocks"></a>

## Blocks and groups

A **block** is a drawing that other drawings place. An `insert` entity names the block and where it goes (`cx`, `cy`, `rotation`, `scale`); the block's own entities are rows of the block's drawing. A **group** is an entity whose children carry its id in `parent`. `WITH RECURSIVE` resolves nesting to any depth.

**Example: A block placed twice, and the recursive query that expands both**

Setup:

```sql
INSERT INTO drawings VALUES (2, 1, 'MANHOLE', '{"block":true}');
INSERT INTO layers (drawing, name) VALUES (2, '0');
INSERT INTO entities (drawing, layer, kind, cx, cy, radius, min_x, min_y, max_x, max_y) VALUES (2, '0', 'circle', 0, 0, 0.6, -0.6, -0.6, 0.6, 0.6);
INSERT INTO entities (drawing, layer, kind, block, cx, cy, rotation, scale, min_x, min_y, max_x, max_y) VALUES
  (1, 'ROAD', 'insert', 2, 1020, 2010, 0, 1, 1019.4, 2009.4, 1020.6, 2010.6),
  (1, 'ROAD', 'insert', 2, 1080, 2060, 0, 1, 1079.4, 2059.4, 1080.6, 2060.6);
```

```sql
WITH RECURSIVE placed(drawing, kind, block, cx, cy, depth) AS (
  SELECT drawing, kind, block, cx, cy, 0 FROM entities WHERE drawing = 1 AND kind = 'insert'
  UNION ALL
  SELECT e.drawing, e.kind, e.block, p.cx + e.cx, p.cy + e.cy, p.depth + 1
  FROM placed p JOIN entities e ON e.drawing = p.block
  WHERE p.depth < 8
)
SELECT kind, cx, cy, depth FROM placed ORDER BY depth, cx;
```

Result:

| kind (STRING) | cx (DOUBLE) | cy (DOUBLE) | depth (LONG) |
|---|---|---|---|
| insert | 1020 | 2010 | 0 |
| insert | 1080 | 2060 | 0 |
| circle | 1020 | 2010 | 1 |
| circle | 1080 | 2060 | 1 |

(4 rows)

- **Notes:**
  - The example adds positions; a real insert also rotates and scales (`cx + scale * (x * cos(r) - y * sin(r))`). Do that in the client when drawing, or in a saved function ([saved-functions](saved-functions.md)) when you need it in SQL.
  - `depth < 8` stops a block that (by mistake) contains itself.
  - Groups are the same query over `parent` instead of `block`.

<a id="viewport"></a>

## Partial load: only what the canvas can see

The canvas never loads a whole drawing. It asks for the entities whose box overlaps the window it shows, plus a margin, and asks again only when the view moves out of that margin. The index on `(drawing, min_x, min_y)` narrows the scan; the other three conditions filter the rest.

**Example: Everything on visible layers that overlaps a 60 x 40 m window**

Setup:

```sql
INSERT INTO entities (drawing, layer, kind, cx, cy, radius, min_x, min_y, max_x, max_y) VALUES
  (1, 'ROAD', 'circle', 1010, 2010, 2, 1008, 2008, 1012, 2012),
  (1, 'ROAD', 'circle', 1090, 2070, 2, 1088, 2068, 1092, 2072),
  (1, 'TEXT', 'text', 1050, 2040, NULL, 1050, 2040, 1056, 2042);
UPDATE layers SET visible = FALSE WHERE drawing = 1 AND name = 'TEXT';
```

```sql
SELECT e.kind, e.layer, e.min_x, e.min_y
FROM entities e JOIN layers l ON l.drawing = e.drawing AND l.name = e.layer
WHERE e.drawing = 1 AND l.visible
  AND e.max_x >= 1000 AND e.min_x <= 1060    -- the window, x
  AND e.max_y >= 2000 AND e.min_y <= 2040    -- the window, y
ORDER BY e.layer, e.min_x;
```

Result:

| kind (STRING) | layer (STRING) | min_x (DOUBLE) | min_y (DOUBLE) |
|---|---|---|---|
| circle | ROAD | 1008 | 2008 |

(1 row)

**Example: Far out, skip what would be smaller than a pixel**

Setup:

```sql
INSERT INTO entities (drawing, layer, kind, cx, cy, radius, min_x, min_y, max_x, max_y) VALUES
  (1, 'ROAD', 'circle', 1010, 2010, 0.05, 1009.95, 2009.95, 1010.05, 2010.05),
  (1, 'ROAD', 'circle', 1090, 2070, 4, 1086, 2066, 1094, 2074);
```

```sql
SELECT kind, radius FROM entities
WHERE drawing = 1 AND kind = 'circle'
  AND greatest(max_x - min_x, max_y - min_y) >= 0.5   -- 0.5 m per pixel at this zoom
ORDER BY radius;
```

Result:

| kind (STRING) | radius (DOUBLE) |
|---|---|
| circle | 4 |

(1 row)

- **Notes:**
  - Ask with a margin of about one screen around the window, so small pans need no query at all.
  - For big polylines keep a simplified copy for far zooms (a `vertices_lod` table with every 10th vertex, or a `DOUBLE[]` in `props`); the client picks by zoom.
  - The HTTP API returns JSON the canvas can draw straight away ([http-exec](http-exec.md)); the Postgres port serves desktop CAD and GIS tools ([postgres-protocol](postgres-protocol.md)).

<a id="camera"></a>

## The camera stays in the client

Pan, zoom, the view matrix, hover and window selection change sixty times a second. None of that goes through the database: a commit costs a disk sync and a query a round trip, and the GPU or a loop over an in-memory array does the matrix multiply a thousand times faster than SQL could. The split is:

| In memory (client) | In KDB |
|---|---|
| world-to-screen matrix, camera position | the entities, as the source of truth |
| hit testing under the mouse, window selection | "what exists in this region" |
| the working set of loaded entities | levels of detail, history, who changed what |
| redraw on every frame | one query when the view leaves the loaded region |

Save the camera as a **view**, not as live state: one row per user and drawing, written when the user stops moving or closes the drawing, read when it is opened. Named views and layout viewports are rows of the same table.

**Example: A saved view: where the user left the drawing**

Setup:

```sql
CREATE TABLE saved_views (drawing INT, owner TEXT, name TEXT, cx DOUBLE, cy DOUBLE, scale DOUBLE, rotation DOUBLE DEFAULT 0, saved TIMESTAMP DEFAULT now(), PRIMARY KEY (drawing, owner, name));
```

```sql
INSERT INTO saved_views (drawing, owner, name, cx, cy, scale) VALUES (1, 'amrit', 'last', 1050, 2040, 0.25);
SELECT cx, cy, scale FROM saved_views WHERE drawing = 1 AND owner = 'amrit' AND name = 'last';
```

Result:

`INSERT INTO saved_views (drawing, owner, name, cx, cy, scale) VALUES (1, 'amrit', 'last', 1050, 2040`

```text
1 row(s) inserted
```

`SELECT cx, cy, scale FROM saved_views WHERE drawing = 1 AND owner = 'amrit' AND name = 'last'`

| cx (DOUBLE) | cy (DOUBLE) | scale (DOUBLE) |
|---|---|---|
| 1050 | 2040 | 0.25 |

(1 row)

<a id="history"></a>

## Save, open, undo and history

A save is a transaction: all the rows of the edit, or none ([transactions](transactions.md)). Opening is the viewport query above plus the layers and the saved view. For undo across sessions and "who moved this", KDB's own history does the work: `AS OF` reads a table as it was at a time, the change stream lists every committed change with its LSN, and a branch gives a writable copy of a whole database to try a redesign on.

```sql
-- The client noted the time before the edit (or the commit LSN from changes('entities')).
UPDATE entities SET cx = 1060, min_x = 1054, max_x = 1066 WHERE id = '0f0e0d0c-0b0a-4908-8706-050403020100';
SELECT cx FROM entities AS OF TIMESTAMP '2026-10-15 14:29:58.250' WHERE id = '0f0e0d0c-0b0a-4908-8706-050403020100';  -- 1050
SELECT cx FROM entities                                            WHERE id = '0f0e0d0c-0b0a-4908-8706-050403020100';  -- 1060
-- Undo it for everyone: put the old rows back.
INSERT OR REPLACE INTO entities SELECT * FROM entities AS OF TIMESTAMP '2026-10-15 14:29:58.250' WHERE drawing = 1;
```

- **Notes:**
  - Every committed change of `entities` and `vertices` is in `changes('entities')` ([change-stream](change-stream.md)); a second client subscribed to it redraws what others change without polling.
  - A long design alternative is a branch: `CREATE DATABASE plan_b BRANCH OF site` ([as-of-and-branches](as-of-and-branches.md#branch)).

<a id="three-d"></a>

## 3D: vertices, faces, volumes

A mesh is a vertex table and a face table; a solid is a closed mesh; a terrain (TIN) is a mesh whose faces come from the survey points. Rows, not one big JSON: a 16 MB document cannot be loaded in part or changed one triangle at a time, rows can.

**Example: A pyramid as a mesh, its extent and its volume**

Setup:

```sql
CREATE TABLE mesh_vertices (mesh INT, id INT, x DOUBLE, y DOUBLE, z DOUBLE, PRIMARY KEY (mesh, id));
CREATE TABLE mesh_faces (mesh INT, id INT, a INT, b INT, c INT, PRIMARY KEY (mesh, id));
INSERT INTO mesh_vertices VALUES (1,1, 0,0,0), (1,2, 10,0,0), (1,3, 10,10,0), (1,4, 0,10,0), (1,5, 5,5,9);
INSERT INTO mesh_faces VALUES (1,1, 1,2,5), (1,2, 2,3,5), (1,3, 3,4,5), (1,4, 4,1,5), (1,5, 1,3,2), (1,6, 1,4,3);
```

```sql
SELECT mesh, count(*) AS vertices, min(x) AS min_x, max(x) AS max_x, min(z) AS min_z, max(z) AS max_z
FROM mesh_vertices GROUP BY mesh;
SELECT f.mesh,
       round(abs(sum(va.x * (vb.y * vc.z - vc.y * vb.z)
                   - va.y * (vb.x * vc.z - vc.x * vb.z)
                   + va.z * (vb.x * vc.y - vc.x * vb.y)) / 6), 3) AS volume
FROM mesh_faces f
JOIN mesh_vertices va ON va.mesh = f.mesh AND va.id = f.a
JOIN mesh_vertices vb ON vb.mesh = f.mesh AND vb.id = f.b
JOIN mesh_vertices vc ON vc.mesh = f.mesh AND vc.id = f.c
GROUP BY f.mesh;
```

Result:

`SELECT mesh, count(*) AS vertices, min(x) AS min_x, max(x) AS max_x, min(z) AS min_z, max(z) AS max_`

| mesh (INT) | vertices (LONG) | min_x (DOUBLE) | max_x (DOUBLE) | min_z (DOUBLE) | max_z (DOUBLE) |
|---|---|---|---|---|---|
| 1 | 5 | 0 | 10 | 0 | 9 |

(1 row)

`SELECT f.mesh, round(abs(sum(va.x * (vb.y * vc.z - vc.y * vb.z) - va.y * (vb.x * vc.z - vc.x * vb.z)`

| mesh (INT) | volume (DOUBLE) |
|---|---|
| 1 | 300 |

(1 row)

- **Notes:**
  - The volume is the signed-tetrahedron sum over a **closed** mesh with faces wound the same way; the pyramid's 10 x 10 base and height 9 give 300.
  - Earthworks: two terrains, the same formula on each, the difference is cut or fill. A cross section is the vertices (or the face edges) within a thin box along the section line.
  - A point cloud is `points` with a `code` of its own, or a time-series table when scans arrive continuously ([create-table](create-table.md)).
  - Keep the 3D bounding box too (`min_z`, `max_z`) when a 3D viewport loads in part.

<a id="measure"></a>

## Measurements in SQL

Length, perimeter and area need only the vertices and two window functions ([functions-window](functions-window.md)): `lag()` for the vertex before, and the first vertex again to close a polygon.

**Example: Length of each polyline, perimeter and area of the closed one**

Setup:

```sql
INSERT INTO entities (id, drawing, layer, kind, closed) VALUES ('0f0e0d0c-0b0a-4908-8706-050403020100', 1, 'BOUNDARY', 'polyline', TRUE);
INSERT INTO vertices (entity, seq, x, y) VALUES
  ('0f0e0d0c-0b0a-4908-8706-050403020100', 1, 1000, 2000), ('0f0e0d0c-0b0a-4908-8706-050403020100', 2, 1100, 2000),
  ('0f0e0d0c-0b0a-4908-8706-050403020100', 3, 1100, 2080), ('0f0e0d0c-0b0a-4908-8706-050403020100', 4, 1000, 2080);
INSERT INTO entities (id, drawing, layer, kind) VALUES ('1f1e1d1c-1b1a-4918-9716-151413121110', 1, 'ROAD', 'polyline');
INSERT INTO vertices (entity, seq, x, y) VALUES
  ('1f1e1d1c-1b1a-4918-9716-151413121110', 1, 1000, 2010), ('1f1e1d1c-1b1a-4918-9716-151413121110', 2, 1030, 2050), ('1f1e1d1c-1b1a-4918-9716-151413121110', 3, 1100, 2050);
```

```sql
WITH walk AS (
  SELECT v.entity, e.closed, v.x, v.y,
         lag(v.x) OVER (PARTITION BY v.entity ORDER BY v.seq) AS px,
         lag(v.y) OVER (PARTITION BY v.entity ORDER BY v.seq) AS py,
         first_value(v.x) OVER (PARTITION BY v.entity ORDER BY v.seq) AS fx,
         first_value(v.y) OVER (PARTITION BY v.entity ORDER BY v.seq) AS fy,
         row_number() OVER (PARTITION BY v.entity ORDER BY v.seq DESC) AS from_end
  FROM vertices v JOIN entities e ON e.id = v.entity
)
SELECT entity, closed,
       round(sum(CASE WHEN px IS NULL THEN 0 ELSE sqrt((x - px) * (x - px) + (y - py) * (y - py)) END)
             + CASE WHEN closed THEN sum(CASE WHEN from_end = 1 THEN sqrt((fx - x) * (fx - x) + (fy - y) * (fy - y)) ELSE 0 END) ELSE 0 END, 3) AS length,
       CASE WHEN closed THEN round(abs(sum(CASE WHEN px IS NULL THEN 0 ELSE px * y - x * py END)
                                   + sum(CASE WHEN from_end = 1 THEN x * fy - fx * y ELSE 0 END)) / 2, 3) END AS area
FROM walk GROUP BY entity, closed ORDER BY closed DESC;
```

Result:

| entity (UUID) | closed (BOOL) | length (DOUBLE) | area (DOUBLE) |
|---|---|---|---|
| 0f0e0d0c-0b0a-4908-8706-050403020100 | true | 360 | 8000 |
| 1f1e1d1c-1b1a-4918-9716-151413121110 | false | 120 | NULL |

(2 rows)

**Example: The nearest control point to a clicked spot**

```sql
SELECT id, x, y, round(sqrt((x - 1052.3) * (x - 1052.3) + (y - 2041.7) * (y - 2041.7)), 3) AS distance
FROM points WHERE project = 1 AND code = 'CP'
ORDER BY distance LIMIT 1;
```

Result:

| id (INT) | x (DOUBLE) | y (DOUBLE) | distance (DOUBLE) |
|---|---|---|---|
| 3 | 1100 | 2080 | 61.173 |

(1 row)

- **Notes:**
  - The area is the shoelace formula; `closed` decides whether the last vertex joins back to the first.
  - A nearest-point search over many points first narrows by box (`x BETWEEN cx - r AND cx + r AND y BETWEEN ...`), then sorts the few that remain.
  - Spot heights, slopes and volumes between terrains are `GROUP BY` queries over the same tables; keep them as views ([views](views.md)) so the canvas and a report read the same numbers.

<a id="limits"></a>

## Limits and what would come next

| Today | Works up to | Beyond that |
|---|---|---|
| box columns + B-tree index | a few hundred thousand entities per drawing | a grid or R-tree index in the engine |
| maths in SQL (`sin`, `cos`, `atan2`, `sqrt`, windows) | distance, bearing, area, volume, closure | intersections, buffers, offsets: client side or a saved function |
| one `crs` per project | one grid per project | datum transformations are not built in |
| `JSON` props | free-form attributes | a field you filter on often becomes a column |

Nothing in this layout would change if a geometry type arrived later: the typed columns and the vertex rows would feed it as they are.
