-- Short news articles in English and Nepali (tutorial chapter 17), no indexes.
-- Use it in an example with: ```kdb-example fixture=content-news
CREATE TABLE news (
  id LONG PRIMARY KEY,
  symbol STRING,
  published_at TIMESTAMP NOT NULL,
  title STRING NOT NULL,
  body STRING
);

INSERT INTO news VALUES
  (1, 'CITY', '2026-08-01T11:00:00+05:45', 'City Bank profit rises 18%',
      'City Bank reported a net profit of $3.27 billion. The bank will pay a 12.5% dividend.'),
  (2, 'CITY', '2026-08-01T11:30:00+05:45', 'सिटी बैंकको नाफा बढ्यो',
      'सिटी बैंकले चौथो त्रैमासिकमा ३ अर्ब २७ करोड नाफा कमाएको छ। लाभांश १२.५ प्रतिशत।'),
  (3, 'VOLT', '2026-08-15T10:00:00+05:45', 'Hydropower company plans IPO',
      'Volt River Hydropower will sell new shares. The IPO opens next month.'),
  (4, NULL,    '2026-09-01T08:00:00+05:45', 'Market index closes at 2,840',
      'Banks and hydropower shares moved up. City Bank led the gainers.'),
  (5, 'COAST',  '2026-09-02T09:00:00+05:45', 'Coastal Bank merger talks',
      'Coastal Bank Bank is in talks about a merger. No loan changes are planned.');
