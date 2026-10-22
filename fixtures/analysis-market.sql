-- Market data for the analysis function topics (MADE UP numbers, they only look real):
--   market_index the stock market index close on the same days as ochl_day of the sample fixture
--   fund_nav     month-start NAV (price of one unit) of two made-up mutual funds, GROWTH and INCOME
-- Use it in an example with: ```kdb-example fixture=sample,analysis-market

CREATE TABLE market_index (
  time  TIMESTAMP ROUND 1d,
  close DOUBLE
) TIMESERIES(time) PARTITION BY YEAR;

INSERT INTO market_index VALUES
  ('2025-12-28', 2701.4),
  ('2025-12-29', 2695.2),
  ('2025-12-30', 2690.8),
  ('2025-12-31', 2704.6),
  ('2026-08-23', 2612.3),
  ('2026-08-24', 2598.7),
  ('2026-08-25', 2590.1),
  ('2026-08-26', 2583.4),
  ('2026-08-27', 2571.9),
  ('2026-08-30', 2575.6),
  ('2026-08-31', 2569.8),
  ('2026-09-01', 2560.2),
  ('2026-09-02', 2551.7),
  ('2026-09-03', 2566.4),
  ('2026-09-06', 2579.3),
  ('2026-09-07', 2585.0),
  ('2026-09-08', 2588.6),
  ('2026-09-09', 2604.9),
  ('2026-09-10', 2611.5);

CREATE TABLE fund_nav (
  time TIMESTAMP ROUND 1d,
  fund SYMBOL,
  nav  DOUBLE
) TIMESERIES(time) PARTITION BY YEAR;

INSERT INTO fund_nav VALUES
  ('2024-09-01', 'GROWTH', 10.00), ('2024-09-01', 'INCOME', 10.00),
  ('2024-10-01', 'GROWTH', 10.21), ('2024-10-01', 'INCOME', 10.05),
  ('2024-11-01', 'GROWTH', 10.45), ('2024-11-01', 'INCOME', 10.11),
  ('2024-12-01', 'GROWTH', 10.32), ('2024-12-01', 'INCOME', 10.14),
  ('2025-01-01', 'GROWTH', 10.10), ('2025-01-01', 'INCOME', 10.12),
  ('2025-02-01', 'GROWTH', 9.78),  ('2025-02-01', 'INCOME', 10.08),
  ('2025-03-01', 'GROWTH', 9.55),  ('2025-03-01', 'INCOME', 10.05),
  ('2025-04-01', 'GROWTH', 9.71),  ('2025-04-01', 'INCOME', 10.10),
  ('2025-05-01', 'GROWTH', 9.96),  ('2025-05-01', 'INCOME', 10.16),
  ('2025-06-01', 'GROWTH', 10.28), ('2025-06-01', 'INCOME', 10.23),
  ('2025-07-01', 'GROWTH', 10.61), ('2025-07-01', 'INCOME', 10.30),
  ('2025-08-01', 'GROWTH', 10.84), ('2025-08-01', 'INCOME', 10.36),
  ('2025-09-01', 'GROWTH', 11.02), ('2025-09-01', 'INCOME', 10.41),
  ('2025-10-01', 'GROWTH', 10.87), ('2025-10-01', 'INCOME', 10.39),
  ('2025-11-01', 'GROWTH', 11.15), ('2025-11-01', 'INCOME', 10.45),
  ('2025-12-01', 'GROWTH', 11.43), ('2025-12-01', 'INCOME', 10.52),
  ('2026-01-01', 'GROWTH', 11.38), ('2026-01-01', 'INCOME', 10.55),
  ('2026-02-01', 'GROWTH', 11.70), ('2026-02-01', 'INCOME', 10.61),
  ('2026-03-01', 'GROWTH', 11.52), ('2026-03-01', 'INCOME', 10.60),
  ('2026-04-01', 'GROWTH', 11.09), ('2026-04-01', 'INCOME', 10.54),
  ('2026-05-01', 'GROWTH', 11.31), ('2026-05-01', 'INCOME', 10.58),
  ('2026-06-01', 'GROWTH', 11.66), ('2026-06-01', 'INCOME', 10.65),
  ('2026-07-01', 'GROWTH', 11.94), ('2026-07-01', 'INCOME', 10.71),
  ('2026-08-01', 'GROWTH', 12.18), ('2026-08-01', 'INCOME', 10.78);
