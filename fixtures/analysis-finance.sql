-- Money data for the finance and date topics (MADE UP numbers):
--   cash_flows  money out (negative) and money in (positive) of two investments, with dates
--   loans       bank loans: amount, yearly interest rate and number of years
--   invoices    sales of the NChart app, for fiscal year reports
-- Use it in an example with: ```kdb-example fixture=analysis-finance
-- (it can be combined with other fixtures: fixture=sample,analysis-finance)

CREATE TABLE cash_flows (
  id        INT PRIMARY KEY,
  project   STRING NOT NULL,
  flow_date DATE NOT NULL,
  amount    DOUBLE NOT NULL,
  memo      STRING
);

INSERT INTO cash_flows VALUES
  (1,  'VOLT_SHARES', '2024-01-15', -185000, 'Buy 1000 VOLT shares at 185'),
  (2,  'VOLT_SHARES', '2024-12-20',    5000, 'Cash dividend'),
  (3,  'VOLT_SHARES', '2025-12-18',    7500, 'Cash dividend'),
  (4,  'VOLT_SHARES', '2026-09-10',  191200, 'Sell 1000 VOLT shares at 191.2'),
  (5,  'SOLAR_ROOF',   '2025-01-01', -500000, 'Buy and fit the solar panels'),
  (6,  'SOLAR_ROOF',   '2025-07-16',   55000, 'Electricity bill saved'),
  (7,  'SOLAR_ROOF',   '2026-01-15',   62000, 'Electricity bill saved'),
  (8,  'SOLAR_ROOF',   '2026-07-16',   64000, 'Electricity bill saved'),
  (9,  'SOLAR_ROOF',   '2027-01-15',   66000, 'Electricity bill saved'),
  (10, 'SOLAR_ROOF',   '2027-07-16',   68000, 'Electricity bill saved'),
  (11, 'SOLAR_ROOF',   '2028-01-15',   70000, 'Electricity bill saved'),
  (12, 'SOLAR_ROOF',   '2028-07-16',   72000, 'Electricity bill saved'),
  (13, 'SOLAR_ROOF',   '2029-01-15',   74000, 'Electricity bill saved'),
  (14, 'SOLAR_ROOF',   '2029-07-16',   76000, 'Electricity bill saved');

CREATE TABLE loans (
  id          INT PRIMARY KEY,
  purpose     STRING NOT NULL,
  principal   DOUBLE NOT NULL,
  annual_rate DOUBLE NOT NULL,
  years       INT NOT NULL
);

INSERT INTO loans VALUES
  (1, 'Home loan',      5000000, 0.105, 20),
  (2, 'Car loan',       1800000, 0.12,   7),
  (3, 'Education loan',  800000, 0.09,   5);

CREATE TABLE invoices (
  id           INT PRIMARY KEY,
  invoice_date TIMESTAMP NOT NULL,
  customer     STRING NOT NULL,
  plan         STRING NOT NULL,
  amount       DECIMAL(2) NOT NULL
);

INSERT INTO invoices VALUES
  (1,  '2025-06-20', 'ram',    'pro yearly',   12000.00),
  (2,  '2025-07-16', 'sita',   'pro monthly',   1500.00),
  (3,  '2025-07-17', 'hari',   'pro monthly',   1500.00),
  (4,  '2025-09-05', 'gita',   'pro yearly',   12000.00),
  (5,  '2025-11-20', 'bikash', 'pro 3 months',  4500.00),
  (6,  '2026-01-12', 'suman',  'pro monthly',   1500.00),
  (7,  '2026-03-30', 'anita',  'pro yearly',   12000.00),
  (8,  '2026-05-14', 'ram',    'pro 3 months',  4500.00),
  (9,  '2026-07-10', 'sita',   'pro yearly',   12000.00),
  (10, '2026-07-20', 'hari',   'pro monthly',   1500.00),
  (11, '2026-08-25', 'gita',   'pro 3 months',  4500.00),
  (12, '2026-09-10', 'maya',   'pro yearly',   12000.00);
