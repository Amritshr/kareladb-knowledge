-- App users and a small accounting book, for the Querying topics (made-up data).
--   app_users   people who use the NChart app (some cities, names and logins are NULL)
--   accounts    the chart of accounts: code, name, type (asset, liability, equity, income, expense)
--   ledger      journal lines: every entry has debit lines and credit lines with the same total
-- Use it in an example with: ```kdb-example fixture=query-app
-- (it can be combined with other fixtures: fixture=sample,query-app)

CREATE TABLE app_users (
  id         INT PRIMARY KEY,
  username   STRING NOT NULL,
  email      STRING NOT NULL,
  full_name  STRING,
  city       STRING,
  plan       STRING NOT NULL,
  created_at TIMESTAMP NOT NULL,
  last_login TIMESTAMP
);

INSERT INTO app_users VALUES
  (1, 'ram',       'ram.sharma@gmail.com',   'Ram Sharma',      'Kathmandu', 'pro',   '2026-01-05T10:00:00+05:45', '2026-09-10T20:15:00+05:45'),
  (2, 'sita',      'sita.k@yahoo.com',       'Sita Karki',      'Pokhara',   'free',  '2026-02-11T09:30:00+05:45', '2026-09-09T08:00:00+05:45'),
  (3, 'hari_99',   'hari99@gmail.com',       'Hari Thapa',      'Kathmandu', 'free',  '2026-03-20T18:45:00+05:45', NULL),
  (4, 'gita',      'GITA.RAI@Gmail.com',     'Gita Rai',        'Dharan',    'pro',   '2026-04-02T07:10:00+05:45', '2026-09-11T06:30:00+05:45'),
  (5, 'bikash',    'bikash@nchart.com.np',   'Bikash Shrestha', 'Lalitpur',  'admin', '2026-01-01T09:00:00+05:45', '2026-09-11T10:05:00+05:45'),
  (6, 'anita',     'anita_m@hotmail.com',    'Anita Magar',     NULL,        'free',  '2026-06-18T21:00:00+05:45', '2026-08-30T12:00:00+05:45'),
  (7, 'suman',     'suman.gurung@gmail.com', 'Suman Gurung',    'Pokhara',   'pro',   '2026-07-07T11:11:00+05:45', '2026-09-10T09:40:00+05:45'),
  (8, 'test_user', 'test_user@example.com',  NULL,              NULL,        'free',  '2026-09-01T00:00:00+05:45', NULL);

CREATE TABLE accounts (
  code INT PRIMARY KEY,
  name STRING NOT NULL,
  type STRING NOT NULL
);

INSERT INTO accounts VALUES
  (1000, 'Cash',              'asset'),
  (1100, 'Bank - City',      'asset'),
  (1200, 'Shares at cost',    'asset'),
  (2000, 'Broker payable',    'liability'),
  (3000, 'Owner capital',     'equity'),
  (4000, 'Dividend income',   'income'),
  (4100, 'Gain on sale',      'income'),
  (5000, 'Broker commission', 'expense'),
  (5100, 'Office rent',       'expense');

CREATE TABLE ledger (
  line_id    INT PRIMARY KEY,
  entry_id   INT NOT NULL,
  entry_date TIMESTAMP NOT NULL,
  account    INT NOT NULL REFERENCES accounts(code),
  debit      DECIMAL(2),
  credit     DECIMAL(2),
  memo       STRING
);

INSERT INTO ledger VALUES
  (1,  1, '2026-09-01', 1100, 500000.00, NULL,      'Owner puts money in the bank'),
  (2,  1, '2026-09-01', 3000, NULL,      500000.00, 'Owner puts money in the bank'),
  (3,  2, '2026-09-02', 1200, 257500.00, NULL,      'Buy 500 CITY at 515'),
  (4,  2, '2026-09-02', 2000, NULL,      257500.00, 'Buy 500 CITY at 515'),
  (5,  3, '2026-09-03', 2000, 257500.00, NULL,      'Pay the broker'),
  (6,  3, '2026-09-03', 1100, NULL,      257500.00, 'Pay the broker'),
  (7,  4, '2026-09-03', 5000, 1030.00,   NULL,      'Commission on the CITY buy'),
  (8,  4, '2026-09-03', 1100, NULL,      1030.00,   'Commission on the CITY buy'),
  (9,  5, '2026-09-04', 1000, 30000.00,  NULL,      'Take cash from the bank'),
  (10, 5, '2026-09-04', 1100, NULL,      30000.00,  'Take cash from the bank'),
  (11, 6, '2026-09-05', 5100, 25000.00,  NULL,      'September rent'),
  (12, 6, '2026-09-05', 1000, NULL,      25000.00,  'September rent'),
  (13, 7, '2026-09-08', 1100, 6250.00,   NULL,      'CITY cash dividend'),
  (14, 7, '2026-09-08', 4000, NULL,      6250.00,   'CITY cash dividend'),
  (15, 8, '2026-09-10', 1100, 12600.00,  NULL,      'Sell 20 CITY at 630'),
  (16, 8, '2026-09-10', 1200, NULL,      10300.00,  'Sell 20 CITY at 630'),
  (17, 8, '2026-09-10', 4100, NULL,      2300.00,   'Sell 20 CITY at 630');
