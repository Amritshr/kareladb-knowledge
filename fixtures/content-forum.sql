-- A small forum (tutorial chapter 17): threads and posts, no indexes.
-- Use it in an example with: ```kdb-example fixture=content-forum
CREATE TABLE threads (
  id LONG PRIMARY KEY,
  title STRING NOT NULL,
  created_at TIMESTAMP NOT NULL
);

CREATE TABLE posts (
  id LONG PRIMARY KEY,
  thread_id LONG NOT NULL REFERENCES threads(id),
  parent_id LONG,
  author STRING NOT NULL,
  body STRING NOT NULL,
  created_at TIMESTAMP NOT NULL
);

INSERT INTO threads VALUES
  (1, 'Is CITY a good buy?', '2026-09-01T10:00:00+05:45'),
  (2, 'Hydropower IPOs this month', '2026-09-02T09:00:00+05:45');

INSERT INTO posts VALUES
  (1, 1, NULL, 'ram',  'CITY dividend looks good this year.',   '2026-09-01T10:00:00+05:45'),
  (2, 1, 1,    'sita', 'I agree, the profit grew 18%.',          '2026-09-01T10:05:00+05:45'),
  (3, 1, 1,    'hari', 'Price is high now. Wait for a dip.',     '2026-09-01T10:20:00+05:45'),
  (4, 1, NULL, 'gita', 'What about the bonus shares?',           '2026-09-01T11:00:00+05:45'),
  (5, 1, 4,    'ram',  'Bonus is 10% this time.',                '2026-09-01T11:30:00+05:45'),
  (6, 1, NULL, 'sita', 'सिटी बैंकको नाफा राम्रो छ।',              '2026-09-01T12:00:00+05:45'),
  (7, 2, NULL, 'hari', 'Two hydro IPOs open next week.',         '2026-09-02T09:00:00+05:45'),
  (8, 2, 7,    'gita', 'Which ones?',                            '2026-09-02T09:10:00+05:45');
