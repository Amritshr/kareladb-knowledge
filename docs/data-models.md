# Database models: relational, hierarchical, network, NoSQL, object

> The five classic kinds of database, and how much of each KDB can be - with a picture and a working example for each.

- Category: Getting started
- Keywords: data model, database model, database type, kinds of database, relational database, RDBMS, hierarchical database, tree, org chart, parent child, network database, graph, graph database, nodes and edges, many parents, shortest route, non-relational, NoSQL, document database, document store, MongoDB, key-value, key value store, Redis, time-series database, full-text search engine, object-oriented database, OODBMS, object database, inheritance, ORM, WITH RECURSIVE, recursive query
- See also: [Constraints](constraints.md), [Joins](joins.md), [UNION and subqueries](union-subqueries.md), [Column types](column-types.md), [JSON functions](functions-json.md), [INSERT](insert.md), [SAMPLE BY](sample-by.md), [Full-text search](full-text-search.md), [Saved functions](saved-functions.md), [Stored procedures](procedures.md), [PostgreSQL protocol (port 8832)](postgres-protocol.md)

Books sort databases into five **models**, by the shape their data takes. KDB is a **relational** database, but its tables, keys, `JSON` columns and recursive queries let it act like four of the five. Only the **object-oriented** model is missing.

| Model | Data looks like | In KDB | How |
|---|---|---|---|
| [Relational](#relational) | tables linked by keys | **full** - what KDB is | tables, `PRIMARY KEY`, `REFERENCES`, joins, transactions |
| [Hierarchical](#hierarchical) | a tree: one parent each | **yes** | a column that points to its own table, read with `WITH RECURSIVE` |
| [Network](#network) | a web: many parents, loops | **yes** | a table of items and a table of links, read with `WITH RECURSIVE` |
| [Non-relational (NoSQL)](#non-relational) | documents, key-value, time-series, search | **yes**, four kinds | `JSON` columns, `INSERT OR REPLACE`, `SAMPLE BY`, `CREATE FULLTEXT INDEX` |
| [Object-oriented](#object-oriented) | classes with inheritance and methods | **partly** | objects as `JSON`, behaviour in saved functions; no classes |

- All five work through the same SQL, over HTTP, in the web console and on the [PostgreSQL port](postgres-protocol.md). One query may mix them, for example join a tree to a `JSON` column.
- KDB is one server. It is not a cluster that spreads data over many machines.

<a id="relational"></a>

## Relational

Data lives in **tables** of rows and columns. Tables are linked by **keys**: a column in one table holds the key of a row in another table, and a query joins them back together. Every rule is checked when a row is written, so the data stays correct.

> **Diagram:** Two tables, brokers and trades. The buyer column of trades references the id column of brokers.
>
> A trade can only name a broker that exists. KDB refuses any other row.

| KDB gives you | Help |
|---|---|
| `PRIMARY KEY`, `UNIQUE`, `NOT NULL`, `CHECK`, `DEFAULT` | [constraints](constraints.md) |
| foreign keys: `REFERENCES` | [constraints](constraints.md#references) |
| `JOIN`, subqueries, `UNION`, `GROUP BY` | [joins](joins.md), [union-subqueries](union-subqueries.md) |
| views, saved functions, procedures, triggers | [views](views.md), [procedures](procedures.md), [triggers](triggers.md) |
| `BEGIN`, `COMMIT`, `ROLLBACK` | [transactions](transactions.md) |

- **Good for:** users and accounts, ledgers, lists of companies and brokers - anything with rules that must always hold.
- **Notes:** there is no `ON DELETE CASCADE`: delete the child rows before the parent row.

**Example: A trade must name a real broker**

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TABLE trades (id LONG PRIMARY KEY AUTO, symbol SYMBOL, buyer INT NOT NULL REFERENCES brokers(id));
INSERT INTO brokers VALUES (58, 'Northgate Securities'), (45, 'Imperial Securities');
```

```sql
INSERT INTO trades (symbol, buyer) VALUES ('CITY', 58), ('COAST', 45);
SELECT t.id, t.symbol, b.name AS buyer FROM trades t JOIN brokers b ON b.id = t.buyer ORDER BY t.id;
```

Result:

`INSERT INTO trades (symbol, buyer) VALUES ('CITY', 58), ('COAST', 45)`

```text
2 row(s) inserted
```

`SELECT t.id, t.symbol, b.name AS buyer FROM trades AS t JOIN brokers AS b ON b.id = t.buyer ORDER BY`

| id (LONG) | symbol (SYMBOL) | buyer (STRING) |
|---|---|---|
| 1 | CITY | Northgate Securities |
| 2 | COAST | Imperial Securities |

(2 rows)

**Example: A broker that does not exist is refused** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TABLE trades (id LONG PRIMARY KEY AUTO, buyer INT NOT NULL REFERENCES brokers(id));
```

```sql
INSERT INTO trades (buyer) VALUES (99);
```

Result:

Error: `column 'buyer' = '99' has no matching row in brokers(id)`

<a id="hierarchical"></a>

## Hierarchical

Data forms a **tree**. Every item has **one** parent, and a parent may have many children: an org chart, folders, sectors and sub-sectors, forum replies.

In KDB, give the table a column that holds the parent's key and `REFERENCES` the same table. The top row has `NULL` there. A `WITH RECURSIVE` query then walks the tree: it starts at the top, and adds the children of the rows it found last, again and again, until no new rows come.

> **Diagram:** A tree. CEO at the top; CTO and CFO under the CEO; Dev Lead under the CTO; Developer under the Dev Lead.
>
> Each row keeps one link, to its boss. The recursive query builds the whole tree from those links.

- **Good for:** org charts, categories, folders, comment threads, who referred whom.
- **Notes:** there is no special tree column type (like PostgreSQL's `ltree`). A recursive query stops with an error after 100,000 rounds or 10 million rows, so a mistake cannot run forever.

**Example: An org chart: every person with their level and path**

Setup:

```sql
CREATE TABLE staff (id INT PRIMARY KEY, boss_id INT REFERENCES staff(id), name STRING NOT NULL);
INSERT INTO staff VALUES (1, NULL, 'CEO');
INSERT INTO staff VALUES (2, 1, 'CTO'), (3, 1, 'CFO');
INSERT INTO staff VALUES (4, 2, 'Dev Lead');
INSERT INTO staff VALUES (5, 4, 'Developer');
```

```sql
WITH RECURSIVE tree(id, name, depth, path) AS (
  SELECT id, name, 0, name FROM staff WHERE boss_id IS NULL
  UNION ALL
  SELECT s.id, s.name, t.depth + 1, t.path || ' > ' || s.name
  FROM staff s JOIN tree t ON s.boss_id = t.id
)
SELECT id, name, depth, path FROM tree ORDER BY path;
```

Result:

| id (INT) | name (STRING) | depth (LONG) | path (STRING) |
|---|---|---|---|
| 1 | CEO | 0 | CEO |
| 3 | CFO | 1 | CEO > CFO |
| 2 | CTO | 1 | CEO > CTO |
| 4 | Dev Lead | 2 | CEO > CTO > Dev Lead |
| 5 | Developer | 3 | CEO > CTO > Dev Lead > Developer |

(5 rows)

**Example: Everyone under the CTO**

Setup:

```sql
CREATE TABLE staff (id INT PRIMARY KEY, boss_id INT REFERENCES staff(id), name STRING NOT NULL);
INSERT INTO staff VALUES (1, NULL, 'CEO');
INSERT INTO staff VALUES (2, 1, 'CTO'), (3, 1, 'CFO');
INSERT INTO staff VALUES (4, 2, 'Dev Lead');
INSERT INTO staff VALUES (5, 4, 'Developer');
```

```sql
WITH RECURSIVE team(id, name) AS (
  SELECT id, name FROM staff WHERE name = 'CTO'
  UNION ALL
  SELECT s.id, s.name FROM staff s JOIN team t ON s.boss_id = t.id
)
SELECT id, name FROM team ORDER BY id;
```

Result:

| id (INT) | name (STRING) |
|---|---|
| 2 | CTO |
| 4 | Dev Lead |
| 5 | Developer |

(3 rows)

<a id="network"></a>

## Network

Like a tree, but an item may have **many** parents, and links may go round in a loop. The data is a web of **nodes** and **links**: roads between cities, share holdings between companies, friends of friends.

In KDB, keep the nodes in one table and the links in a second table with two `REFERENCES` columns. A `WITH RECURSIVE` query follows the links. Give it a stop rule (a maximum number of steps), because a loop in the data would otherwise go round again and again.

> **Diagram:** Four cities and the roads between them. Kathmandu to Pokhara 200 km, Kathmandu to Chitwan 150 km, Chitwan to Butwal 110 km, Pokhara to Butwal 160 km. The shortest way to Butwal is through Chitwan, 260 km.
>
> Butwal has two parents, Pokhara and Chitwan - a tree cannot hold that. The coloured route is the shortest.

- **Good for:** routes, networks of links, who owns shares in whom, recommendations.
- **Notes:** KDB is not a graph database like Neo4j: there is no Cypher language and no built-in shortest-path function. For networks of thousands of links, SQL is enough.

**Example: Every route from Kathmandu to Butwal, shortest first**

Setup:

```sql
CREATE TABLE city (name STRING PRIMARY KEY);
CREATE TABLE road (from_city STRING NOT NULL REFERENCES city(name), to_city STRING NOT NULL REFERENCES city(name), km INT NOT NULL);
INSERT INTO city VALUES ('Kathmandu'), ('Pokhara'), ('Chitwan'), ('Butwal');
INSERT INTO road VALUES ('Kathmandu', 'Pokhara', 200), ('Kathmandu', 'Chitwan', 150), ('Chitwan', 'Butwal', 110), ('Pokhara', 'Butwal', 160);
```

```sql
WITH RECURSIVE route(city, km, hops, path) AS (
  SELECT 'Kathmandu', 0, 0, 'Kathmandu'
  UNION ALL
  SELECT r.to_city, route.km + r.km, route.hops + 1, route.path || ' > ' || r.to_city
  FROM road r JOIN route ON r.from_city = route.city
  WHERE route.hops < 5
)
SELECT km, hops, path FROM route WHERE city = 'Butwal' ORDER BY km;
```

Result:

| km (LONG) | hops (LONG) | path (STRING) |
|---|---|---|
| 260 | 2 | Kathmandu > Chitwan > Butwal |
| 360 | 2 | Kathmandu > Pokhara > Butwal |

(2 rows)

<a id="non-relational"></a>

## Non-relational (NoSQL)

"Non-relational" is not one model but a family. KDB has four members of it, and each one is still a table you can join to the others.

| Kind | Other products like it | In KDB | Help |
|---|---|---|---|
| **document** | MongoDB | a `JSON` column: every row may have different fields | [column-types](column-types.md#json), [functions-json](functions-json.md) |
| **key-value** | Redis | a two-column table with a `PRIMARY KEY`, written with `INSERT OR REPLACE` | [insert](insert.md#insert-or-replace) |
| **time-series** | QuestDB, InfluxDB | a table with a time column, `PARTITION BY`, `SAMPLE BY`, `LATEST ON` | [create-table](create-table.md), [sample-by](sample-by.md) |
| **search** | Elasticsearch | `CREATE FULLTEXT INDEX`, `match`, `search_rank` | [full-text-search](full-text-search.md) |

> **Diagram:** One KDB server with four non-relational kinds: document, key-value, time-series and search, all used through the same SQL.
>
> Not four products: four ways to use one database.

- **Not in KDB:** a wide-column store (like Cassandra), a graph query language, and spreading data over many servers.
- A `JSON` value, and a whole row, can be up to 16 MB. Keep images and PDF files outside the database, and store their path.

**Example: Document: products whose fields differ**

Setup:

```sql
CREATE TABLE products (id INT PRIMARY KEY, doc JSON NOT NULL);
INSERT INTO products VALUES
  (1, '{"name": "Laptop", "price": 950, "tags": ["tech", "work"], "specs": {"ram_gb": 16}}'),
  (2, '{"name": "Shirt", "price": 20, "size": "M"}');
```

```sql
UPDATE products SET doc = json_set(doc, '$.price', 899) WHERE id = 1;
SELECT id, doc ->> 'name' AS name, json_value_double(doc, '$.price') AS price,
       json_value_long(doc, '$.specs.ram_gb') AS ram_gb, doc ->> 'size' AS size
FROM products ORDER BY id;
```

Result:

`UPDATE products SET doc = json_set(doc, '$.price', 899) WHERE id = 1`

```text
1 row(s) updated
```

`SELECT id, doc ->> 'name' AS name, json_value_double(doc, '$.price') AS price, json_value_long(doc, `

| id (INT) | name (STRING) | price (DOUBLE) | ram_gb (LONG) | size (STRING) |
|---|---|---|---|---|
| 1 | Laptop | 899 | 16 | NULL |
| 2 | Shirt | 20 | NULL | M |

(2 rows)

**Example: Key-value: a setting is replaced, not added twice**

Setup:

```sql
CREATE TABLE settings (k STRING PRIMARY KEY, v STRING);
```

```sql
INSERT OR REPLACE INTO settings VALUES ('theme', 'dark');
INSERT OR REPLACE INTO settings VALUES ('theme', 'light'), ('lang', 'ne');
SELECT k, v FROM settings ORDER BY k;
```

Result:

`INSERT OR REPLACE INTO settings VALUES ('theme', 'dark')`

```text
1 row(s) inserted
```

`INSERT OR REPLACE INTO settings VALUES ('theme', 'light'), ('lang', 'ne')`

```text
1 row(s) inserted, 1 replaced
```

`SELECT k, v FROM settings ORDER BY k`

| k (STRING) | v (STRING) |
|---|---|
| lang | ne |
| theme | light |

(2 rows)

**Example: Time-series: 15-minute candles from ticks**

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESTAMP(time) PARTITION BY DAY;
INSERT INTO ticks VALUES
  ('2026-09-10T11:00:00+05:45', 'CITY', 500), ('2026-09-10T11:05:00+05:45', 'CITY', 510),
  ('2026-09-10T11:16:00+05:45', 'CITY', 505);
```

```sql
SELECT time, first(price) AS open, max(price) AS high, min(price) AS low, last(price) AS close
FROM ticks SAMPLE BY 15m;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 500 | 510 | 500 | 510 |
| 2026-09-10T05:30:00.000Z | 505 | 505 | 505 | 505 |

(2 rows)

**Example: Search: news that talks about profit**

Setup:

```sql
CREATE TABLE news (id INT PRIMARY KEY, body STRING NOT NULL);
CREATE FULLTEXT INDEX news_body ON news (body);
INSERT INTO news VALUES (1, 'City Bank profit rises 18%'), (2, 'Hydro power output falls'), (3, 'COAST profit is flat');
```

```sql
SELECT id, body FROM news WHERE match(body, 'profit') ORDER BY id;
```

Result:

| id (INT) | body (STRING) |
|---|---|
| 1 | City Bank profit rises 18% |
| 3 | COAST profit is flat |

(2 rows)

<a id="object-oriented"></a>

## Object-oriented

An object database stores the objects of a program as they are: **classes**, **inheritance** (`class Car extends Vehicle`) and **methods** kept with the data. KDB does not have classes or inheritance. You can get part of the way:

> **Diagram:** An object database has nested fields, methods and inheritance. In KDB, nested fields become a JSON column and methods become saved functions or procedures; inheritance has no match.
>
> Two of the three parts have a match in KDB. Inheritance does not.

| An object database has | In KDB | Help |
|---|---|---|
| nested fields and lists | a `JSON` column; arrays are kept as JSON lists | [functions-json](functions-json.md), [arrays](functions-postgres.md#arrays) |
| methods | saved functions and stored procedures | [saved-functions](saved-functions.md), [procedures](procedures.md) |
| one clean shape to read | a view | [views](views.md) |
| classes and inheritance | **none**: use one table per class, or a `kind` column | |
| object ids and links between objects | a `PRIMARY KEY` and `REFERENCES` | [constraints](constraints.md) |

- **Tip:** most apps do not use an object database. They map objects to tables with an **ORM** (SQLAlchemy, Prisma, Entity Framework, GORM), which talks to KDB over the [PostgreSQL port](postgres-protocol.md).

**Example: Vehicles of different kinds: shared columns, extra fields as JSON, a function as a method**

Setup:

```sql
CREATE TABLE vehicles (id INT PRIMARY KEY, kind STRING NOT NULL CHECK (kind IN ('car', 'bike')), wheels INT NOT NULL, extra JSON DEFAULT '{}');
CREATE FUNCTION describe(kind STRING, wheels INT) RETURNS STRING AS (kind || ' with ' || wheels || ' wheels');
```

```sql
INSERT INTO vehicles VALUES (1, 'car', 4, '{"doors": 5, "fuel": "petrol"}'), (2, 'bike', 2, '{"gears": 21}');
SELECT id, describe(kind, wheels) AS description, extra ->> 'doors' AS doors, extra ->> 'gears' AS gears
FROM vehicles ORDER BY id;
```

Result:

`INSERT INTO vehicles VALUES (1, 'car', 4, '{"doors": 5, "fuel": "petrol"}'), (2, 'bike', 2, '{"gears`

```text
2 row(s) inserted
```

`SELECT id, describe(kind, wheels) AS description, extra ->> 'doors' AS doors, extra ->> 'gears' AS g`

| id (INT) | description (STRING) | doors (STRING) | gears (STRING) |
|---|---|---|---|
| 1 | car with 4 wheels | 5 | NULL |
| 2 | bike with 2 wheels | NULL | 21 |

(2 rows)
