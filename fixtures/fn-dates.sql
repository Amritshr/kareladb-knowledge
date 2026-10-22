-- Dates for the date and time functions (made-up data, times written with a zone offset, here +05:45):
--   signups      new users of the NChart app: id, email, created_at (TIMESTAMP)
--   forum_posts  posts in the NChart forum: id, author, topic, created_at (TIMESTAMP)
--   listings     when companies were listed on the stock exchange: symbol, listed_on (DATE)
-- Use it in an example with: ```kdb-example fixture=fn-dates
-- (it can be combined with other fixtures: fixture=sample,fn-dates)

CREATE TABLE signups (
  id         INT PRIMARY KEY,
  email      STRING NOT NULL,
  created_at TIMESTAMP NOT NULL
);

INSERT INTO signups VALUES
  (1,  'ram@gmail.com',     '2026-09-01T09:15:00+05:45'),
  (2,  'sita@yahoo.com',    '2026-09-01T13:40:00+05:45'),
  (3,  'hari@gmail.com',    '2026-09-01T22:05:00+05:45'),
  (4,  'gita@gmail.com',    '2026-09-02T02:30:00+05:45'),
  (5,  'bikash@gmail.com',  '2026-09-02T11:00:00+05:45'),
  (6,  'anita@hotmail.com', '2026-09-03T08:20:00+05:45'),
  (7,  'suman@gmail.com',   '2026-09-03T19:45:00+05:45'),
  (8,  'maya@gmail.com',    '2026-09-03T23:50:00+05:45'),
  (9,  'kiran@gmail.com',   '2026-09-04T10:10:00+05:45'),
  (10, 'nabin@yahoo.com',   '2026-09-06T12:00:00+05:45');

CREATE TABLE forum_posts (
  id         INT PRIMARY KEY,
  author     STRING NOT NULL,
  topic      STRING NOT NULL,
  created_at TIMESTAMP NOT NULL
);

INSERT INTO forum_posts VALUES
  (1,  'ram',    'CITY dividend',   '2026-08-16T10:00:00+05:45'),
  (2,  'sita',   'CITY dividend',   '2026-08-18T14:30:00+05:45'),
  (3,  'hari',   'Hydro IPOs',       '2026-08-20T09:10:00+05:45'),
  (4,  'gita',   'Hydro IPOs',       '2026-08-23T11:45:00+05:45'),
  (5,  'ram',    'COAST merger',      '2026-08-25T16:00:00+05:45'),
  (6,  'bikash', 'COAST merger',      '2026-08-27T20:20:00+05:45'),
  (7,  'anita',  'COAST merger',      '2026-08-29T08:00:00+05:45'),
  (8,  'suman',  'Market today',      '2026-08-30T15:05:00+05:45'),
  (9,  'ram',    'Market today',      '2026-09-02T12:00:00+05:45'),
  (10, 'sita',   'Market today',      '2026-09-03T13:30:00+05:45'),
  (11, 'hari',   'Hydro IPOs',       '2026-09-06T10:15:00+05:45'),
  (12, 'gita',   'CITY dividend',   '2026-09-07T18:00:00+05:45'),
  (13, 'maya',   'Market today',      '2026-09-09T11:20:00+05:45'),
  (14, 'kiran',  'Market today',      '2026-09-10T14:50:00+05:45');

CREATE TABLE listings (
  symbol    STRING PRIMARY KEY,
  listed_on DATE NOT NULL
);

INSERT INTO listings VALUES
  ('CITY', '1986-01-01'),
  ('COAST',  '1998-07-28'),
  ('VOLT', '2019-08-28'),
  ('TELCO',   '2008-07-11'),
  ('ACME', '2015-05-08');
