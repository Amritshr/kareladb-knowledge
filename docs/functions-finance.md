# Finance and price functions

> Money math like Excel (interest, loan EMI, NPV, IRR, XIRR, CAGR), price ticks and pivot points for traders.

- Category: Functions — math
- Keywords: finance, money, interest, loan, EMI, monthly installment, installment, loan payment, future value, present value, number of periods, net present value, internal rate of return, XNPV, XIRR, return on investment, compound annual growth rate, CAGR, compound interest, savings, SIP, fixed deposit, cash flow, discount rate, Excel, tick size, price tick, round to tick, stock exchange, pivot points, support, resistance, floor pivots, fibonacci, camarilla, woodie, accounting
- See also: [Math functions](functions-math.md), [Returns and risk](functions-returns-risk.md), [Date and time functions (fiscal_year)](functions-date-time.md#fiscal_year), [Aggregate functions](functions-aggregate.md), [Technical indicators](functions-indicators.md)

These functions do the money math that people usually do in Excel: interest, loan installments, the value of future money today, and the yearly return of an investment. There are also two tools for traders: **price ticks** and **pivot points**.

- **Rates are fractions:** 8% is `0.08`, not `8`. A result like `0.0777` means 7.77%.
- **Periods must match the rate.** For a monthly installment, use the monthly rate (`0.12 / 12`) and the number of months (`5 * 12`).
- **Sign rule (like Excel):** money that **goes out** of your pocket is **negative**, money that **comes in** is **positive**. When you take a loan of 1,000,000, the bank gives you money (`+1000000`), and `pmt` gives the installment you pay back as a negative number.
- A `NULL` argument gives `NULL`. A result that is not a real number (no answer exists) is also `NULL`, not an error.
- The functions are **scalar** (one row in, one value out), except `xnpv` and `xirr`, which are **aggregates**: they read the cash flows of many rows ([aggregate functions](functions-aggregate.md)).
- **Returns** `DOUBLE`. Use `round(x, 2)` for dollars and cents.

The sample data of this page (fixture `analysis-finance`, made-up numbers) has `cash_flows` (money out and in of two investments, with dates), `loans` and `invoices`.

**Example: The monthly EMI of every loan, and the interest paid in total** (sample data: analysis-finance)

```sql
SELECT purpose, principal, annual_rate, years,
       round(-pmt(annual_rate / 12, years * 12, principal), 2) AS monthly_emi,
       round(-pmt(annual_rate / 12, years * 12, principal) * years * 12 - principal, 2) AS total_interest
FROM loans
ORDER BY id;
```

Result:

| purpose (STRING) | principal (DOUBLE) | annual_rate (DOUBLE) | years (INT) | monthly_emi (DOUBLE) | total_interest (DOUBLE) |
|---|---|---|---|---|---|
| Home loan | 5000000 | 0.105 | 20 | 49918.99 | 6980558.64 |
| Car loan | 1800000 | 0.12 | 7 | 31774.92 | 869093.2 |
| Education loan | 800000 | 0.09 | 5 | 16606.68 | 196401.05 |

(3 rows)

**Example: Yearly return of two investments from their dated cash flows** (sample data: analysis-finance)

```sql
SELECT project, count(*) AS cash_flows, sum(amount) AS money_gained,
       round(xirr(amount, flow_date) * 100, 2) AS yearly_return_pct
FROM cash_flows
GROUP BY project
ORDER BY project;
```

Result:

| project (STRING) | cash_flows (LONG) | money_gained (DOUBLE) | yearly_return_pct (DOUBLE) |
|---|---|---|---|
| SOLAR_ROOF | 10 | 107000 | 7.77 |
| VOLT_SHARES | 4 | 18700 | 3.8 |

(2 rows)

## cagr

Syntax:

```sql
cagr(start_value, end_value, years)
```

The **compound annual growth rate**: the same yearly growth that turns `start_value` into `end_value` in `years` years. If a share went from 400 to 505 in 3 years, it grew about 8.08% **every year** on average (not 26.25% / 3). The formula is `(end / start) ^ (1 / years) - 1`.

| Argument | Type | Meaning |
|---|---|---|
| `start_value` | number | the value at the start, more than 0 |
| `end_value` | number | the value at the end, 0 or more |
| `years` | number | how many years between them, more than 0; a fraction like `0.7` is fine |

- **Returns:** `DOUBLE`, a fraction per year (`0.08` is 8% a year).
- **NULL:** `NULL` when an argument is `NULL`, when `start_value` is 0 or less, when `end_value` is below 0, and when `years` is 0 or less.
- **Notes:** a value that falls to `0` gives `-1` (you lost everything). For years between two dates, use `datediff('d', from, to) / 365.0`.

**Example** (sample data: analysis-finance)

```sql
SELECT round(cagr(400, 505, 3), 4) AS share_growth, round(cagr(100000, 146932.81, 5), 4) AS deposit, cagr(100, 0, 2) AS lost_all, cagr(0, 50, 2) AS bad_start;
```

Result:

| share_growth (DOUBLE) | deposit (DOUBLE) | lost_all (DOUBLE) | bad_start (STRING) |
|---|---|---|---|
| 0.0808 | 0.08 | -1 | NULL |

(1 row)

**Example: Yearly growth of each share from its first to its last close** (sample data: sample)

```sql
SELECT symbol, first_close, last_close, days,
       round(cagr(first_close, last_close, days / 365.0) * 100, 2) AS cagr_pct
FROM (SELECT symbol, first(close) AS first_close, last(close) AS last_close,
             datediff('d', min(time), max(time)) AS days
      FROM ochl_day
      GROUP BY symbol) t
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | first_close (DOUBLE) | last_close (DOUBLE) | days (LONG) | cagr_pct (DOUBLE) |
|---|---|---|---|---|
| CITY | 542.2 | 504.9 | 256 | -9.66 |
| COAST | 424.8 | 376.1 | 256 | -15.94 |
| VOLT | 191.7 | 191.2 | 256 | -0.37 |

(3 rows)

**Example: Yearly growth of two mutual funds over two years** (sample data: analysis-market)

```sql
SELECT fund, first(nav) AS start_nav, last(nav) AS end_nav,
       round(cagr(first(nav), last(nav), 23 / 12.0) * 100, 2) AS cagr_pct
FROM fund_nav
GROUP BY fund
ORDER BY fund;
```

Result:

| fund (SYMBOL) | start_nav (DOUBLE) | end_nav (DOUBLE) | cagr_pct (DOUBLE) |
|---|---|---|---|
| GROWTH | 10 | 12.18 | 10.84 |
| INCOME | 10 | 10.78 | 4 |

(2 rows)

<a id="compound_interest"></a>

## compound_interest

Syntax:

```sql
compound_interest(principal, rate, years)
compound_interest(principal, rate, years, times_per_year)
```

The **interest** you earn when interest is added to the money again and again (compounding), so later interest is also paid on earlier interest. It gives only the interest, not the total: add `principal` for the final amount.

| Argument | Type | Meaning |
|---|---|---|
| `principal` | number | the money you put in |
| `rate` | number | the yearly interest rate as a fraction (`0.08` for 8%) |
| `years` | number | how many years; a fraction like `0.5` is fine |
| `times_per_year` | number | how often interest is added in a year; default `1`. `4` = every quarter, `12` = every month |

- **Returns:** `DOUBLE`: `principal × ((1 + rate / times_per_year) ^ (times_per_year × years) - 1)`.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** `times_per_year` of 0 or less is an error. More compounding gives a little more interest.

**Example: Interest on 100,000 at 8% for 5 years: yearly, quarterly and monthly** (sample data: analysis-finance)

```sql
SELECT round(compound_interest(100000, 0.08, 5), 2) AS yearly,
       round(compound_interest(100000, 0.08, 5, 4), 2) AS quarterly,
       round(compound_interest(100000, 0.08, 5, 12), 2) AS monthly,
       round(100000 + compound_interest(100000, 0.08, 5), 2) AS final_amount;
```

Result:

| yearly (DOUBLE) | quarterly (DOUBLE) | monthly (DOUBLE) | final_amount (DOUBLE) |
|---|---|---|---|
| 46932.81 | 48594.74 | 48984.57 | 146932.81 |

(1 row)

**Example: Interest must be added at least once a year** (sample data: analysis-finance; shows an error)

```sql
SELECT compound_interest(100000, 0.08, 5, 0);
```

Result:

Error: `line 1, column 8: compound_interest: the number of times per year must be more than 0`

## fv

Syntax:

```sql
fv(rate, periods, payment)
fv(rate, periods, payment, present_value)
fv(rate, periods, payment, present_value, type)
```

The **future value**: how much money you have after `periods` periods, when you save `payment` every period and/or put in `present_value` at the start, with interest `rate` per period. The same as Excel `FV`.

| Argument | Type | Meaning |
|---|---|---|
| `rate` | number | interest per period as a fraction (monthly: `0.12 / 12`) |
| `periods` | number | how many periods |
| `payment` | number | money paid in every period; **negative** when you pay it |
| `present_value` | number | money at the start; default `0`; **negative** when you put it in |
| `type` | `0` or `1` | `0` (default): payments at the **end** of each period; `1`: at the **start** |

- **Returns:** `DOUBLE`. Positive when you get money back at the end.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** `type` other than 0 or 1 is an error. With `rate` 0 the result is simply `-(present_value + payment × periods)`.

**Example: Save 5,000 a month for 10 years at 10% a year (a SIP)** (sample data: analysis-finance)

```sql
SELECT round(fv(0.10 / 12, 120, -5000), 2) AS after_10_years,
       5000 * 120 AS paid_in,
       round(fv(0.10 / 12, 120, -5000, 0, 1), 2) AS paying_at_month_start;
```

Result:

| after_10_years (DOUBLE) | paid_in (LONG) | paying_at_month_start (DOUBLE) |
|---|---|---|
| 1024224.89 | 600000 | 1032760.1 |

(1 row)

**Example: A fixed deposit of 100,000 for 5 years at 8% (nothing added every year)** (sample data: analysis-finance)

```sql
SELECT round(fv(0.08, 5, 0, -100000), 2) AS maturity_amount;
```

Result:

| maturity_amount (DOUBLE) |
|---|
| 146932.81 |

(1 row)

## pv

Syntax:

```sql
pv(rate, periods, payment)
pv(rate, periods, payment, future_value)
pv(rate, periods, payment, future_value, type)
```

The **present value**: how much future money is worth **today**. Money later is worth less than money now, because money now can earn interest. The same as Excel `PV`.

| Argument | Type | Meaning |
|---|---|---|
| `rate` | number | interest (or discount rate) per period as a fraction |
| `periods` | number | how many periods |
| `payment` | number | money received (positive) or paid (negative) every period |
| `future_value` | number | money at the end; default `0` |
| `type` | `0` or `1` | `0` (default): payments at the end of each period; `1`: at the start |

- **Returns:** `DOUBLE`. It has the **opposite** sign of the money you get: to receive money later, you pay (negative) today.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** `type` other than 0 or 1 is an error.

**Example: What is a pension of 20,000 a month for 15 years worth today, at 9% a year?** (sample data: analysis-finance)

```sql
SELECT round(-pv(0.09 / 12, 15 * 12, 20000), 2) AS worth_today, 20000 * 15 * 12 AS paid_in_total;
```

Result:

| worth_today (DOUBLE) | paid_in_total (LONG) |
|---|---|
| 1971868.18 | 3600000 |

(1 row)

**Example: How much to put in today to have 500,000 in 4 years at 7%?** (sample data: analysis-finance)

```sql
SELECT round(pv(0.07, 4, 0, 500000), 2) AS deposit_today;
```

Result:

| deposit_today (DOUBLE) |
|---|
| -381447.61 |

(1 row)

## pmt

Syntax:

```sql
pmt(rate, periods, present_value)
pmt(rate, periods, present_value, future_value)
pmt(rate, periods, present_value, future_value, type)
```

The **payment** for every period of a loan or a savings plan. For a loan it is the **EMI** (equated monthly installment): the same amount every month that pays back the loan and its interest. The same as Excel `PMT`.

| Argument | Type | Meaning |
|---|---|---|
| `rate` | number | interest per period (monthly: yearly rate `/ 12`) |
| `periods` | number | how many payments (months: years `× 12`), not 0 |
| `present_value` | number | the loan amount you get (positive) |
| `future_value` | number | money left at the end; default `0`. For a savings goal, use `0` as `present_value` and the goal here |
| `type` | `0` or `1` | `0` (default): pay at the end of each period; `1`: at the start |

- **Returns:** `DOUBLE`, **negative** for money you pay. Use `-pmt(...)` to show the EMI as a positive number.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** `periods` of 0 and `type` other than 0 or 1 are errors. With `rate` 0 the payment is simply `-(present_value + future_value) / periods`.

**Example: EMI of a 1,000,000 loan for 5 years at 12% a year** (sample data: analysis-finance)

```sql
SELECT round(pmt(0.12 / 12, 5 * 12, 1000000), 2) AS emi,
       round(-pmt(0.12 / 12, 5 * 12, 1000000) * 60, 2) AS paid_back_in_total,
       pmt(0, 12, 120000) AS no_interest;
```

Result:

| emi (DOUBLE) | paid_back_in_total (DOUBLE) | no_interest (DOUBLE) |
|---|---|---|
| -22244.45 | 1334666.86 | -10000 |

(1 row)

**Example: Save for a goal: how much a month to have 100,000 in a year at 12%?** (sample data: analysis-finance)

```sql
SELECT round(-pmt(0.01, 12, 0, 100000), 2) AS save_each_month;
```

Result:

| save_each_month (DOUBLE) |
|---|
| 7884.88 |

(1 row)

**Example: The EMI table of all loans** (sample data: analysis-finance)

```sql
SELECT purpose, principal, round(annual_rate * 100, 2) AS rate_pct, years,
       round(-pmt(annual_rate / 12, years * 12, principal), 2) AS emi
FROM loans
ORDER BY emi DESC;
```

Result:

| purpose (STRING) | principal (DOUBLE) | rate_pct (DOUBLE) | years (INT) | emi (DOUBLE) |
|---|---|---|---|---|
| Home loan | 5000000 | 10.5 | 20 | 49918.99 |
| Car loan | 1800000 | 12 | 7 | 31774.92 |
| Education loan | 800000 | 9 | 5 | 16606.68 |

(3 rows)

**Example: The number of payments cannot be 0** (sample data: analysis-finance; shows an error)

```sql
SELECT pmt(0.01, 0, 100000);
```

Result:

Error: `line 1, column 8: pmt: the number of periods must not be 0`

## nper

Syntax:

```sql
nper(rate, payment, present_value)
nper(rate, payment, present_value, future_value)
nper(rate, payment, present_value, future_value, type)
```

The **number of periods**: how many payments it takes to pay back a loan (or reach a savings goal) with a fixed `payment`. The same as Excel `NPER`.

| Argument | Type | Meaning |
|---|---|---|
| `rate` | number | interest per period |
| `payment` | number | the payment every period; **negative** when you pay |
| `present_value` | number | the loan amount (positive) |
| `future_value` | number | money left at the end; default `0` |
| `type` | `0` or `1` | `0` (default): pay at the end of each period; `1`: at the start |

- **Returns:** `DOUBLE`, often with a fraction: `47.3` months means 47 full payments and a small last one. Use `ceil` for whole months.
- **NULL:** `NULL` when an argument is `NULL`, and when the loan is never paid back (the payment is not bigger than the interest).
- **Notes:** `type` other than 0 or 1 is an error.

**Example: How many months to pay back 1,000,000 at 12% a year, paying 25,000 a month?** (sample data: analysis-finance)

```sql
SELECT round(nper(0.12 / 12, -25000, 1000000), 2) AS months,
       ceil(nper(0.12 / 12, -25000, 1000000)) AS whole_months,
       nper(0, -10000, 120000) AS no_interest,
       nper(0.01, -100, 100000) AS never_paid_back;
```

Result:

| months (DOUBLE) | whole_months (DOUBLE) | no_interest (DOUBLE) | never_paid_back (STRING) |
|---|---|---|---|
| 51.34 | 52 | 12 | NULL |

(1 row)

## npv

Syntax:

```sql
npv(rate, value1, value2, ...)
```

The **net present value**: all future cash flows brought back to today's value with the discount `rate`, and added up. A **discount rate** is the yearly return you could get somewhere else (for example from a fixed deposit). When the NPV is **above 0**, the project earns more than that; below 0, less. The same as Excel `NPV`.

| Argument | Type | Meaning |
|---|---|---|
| `rate` | number | discount rate per period, more than -1 |
| `value1, value2, ...` | numbers | the cash flow at the **end** of period 1, 2, ... (up to 63 values) |

- **Returns:** `DOUBLE`: `value1 / (1 + rate) + value2 / (1 + rate)² + ...`.
- **NULL:** `NULL` when an argument is `NULL`, and when `rate` is -1 or less.
- **Notes:** like Excel, `value1` is already one period away. Money you pay **today** (period 0) is not discounted: add it outside, `-1000000 + npv(rate, ...)`. For cash flows on real dates use [xnpv](#xnpv).

**Example: Is a 1,000,000 project with these yearly profits worth it at a 10% discount rate?** (sample data: analysis-finance)

```sql
SELECT round(-1000000 + npv(0.10, 300000, 350000, 400000, 250000), 2) AS npv_at_10_pct,
       round(-1000000 + npv(0.15, 300000, 350000, 400000, 250000), 2) AS npv_at_15_pct;
```

Result:

| npv_at_10_pct (DOUBLE) | npv_at_15_pct (DOUBLE) |
|---|---|
| 33262.76 | -68535.35 |

(1 row)

**Example: Careful: the first value is one year away** (sample data: analysis-finance)

```sql
SELECT round(npv(0.10, -1000, 300, 400, 500), 2) AS all_discounted,
       round(-1000 + npv(0.10, 300, 400, 500), 2) AS today_not_discounted;
```

Result:

| all_discounted (DOUBLE) | today_not_discounted (DOUBLE) |
|---|---|
| -19.12 | -21.04 |

(1 row)

## irr

Syntax:

```sql
irr(value0, value1, value2, ...)
```

The **internal rate of return**: the discount rate that makes the NPV of the cash flows exactly `0`. It is the yearly (or per period) return of the investment. Compare it with a bank rate: an IRR of 12% is better than a deposit at 8%. The same as Excel `IRR`.

| Argument | Type | Meaning |
|---|---|---|
| `value0` | number | the cash flow **today** (usually the money you invest, negative) |
| `value1, value2, ...` | numbers | the cash flow at the end of period 1, 2, ... (2 to 64 values in total) |

- **Returns:** `DOUBLE`, a fraction per period (`0.0889` is 8.89%).
- **NULL:** `NULL` when an argument is `NULL`, and when there is no answer: the values need at least one negative and one positive value.
- **Notes:** the periods are equal (years, or months). For cash flows on real dates use [xirr](#xirr). KDB starts looking at 10% and then searches wider.

**Example: Return of a project: invest 1,000,000, get money back for 4 years** (sample data: analysis-finance)

```sql
SELECT round(irr(-1000000, 300000, 350000, 400000, 250000) * 100, 2) AS irr_pct,
       irr(-1000, 1100) AS ten_pct,
       irr(100, 200) AS no_negative_value;
```

Result:

| irr_pct (DOUBLE) | ten_pct (DOUBLE) | no_negative_value (STRING) |
|---|---|---|
| 11.54 | 0.1 | NULL |

(1 row)

**Example: NPV at the IRR is 0** (sample data: analysis-finance)

```sql
SELECT round(-1000000 + npv(irr(-1000000, 300000, 350000, 400000, 250000), 300000, 350000, 400000, 250000), 6) AS npv_at_irr;
```

Result:

| npv_at_irr (DOUBLE) |
|---|
| 0 |

(1 row)

## xnpv

Syntax:

```sql
xnpv(rate, amount, date)
```

The **net present value of cash flows on real dates**. It is an **aggregate**: every row is one cash flow. Each amount is discounted by the years between its date and the **earliest** date of the group (days / 365), so money on the first date is not discounted. The same as Excel `XNPV`.

| Argument | Type | Meaning |
|---|---|---|
| `rate` | number | yearly discount rate as a fraction, more than -1; read from the first row |
| `amount` | number | the cash flow of the row: negative for money out, positive for money in |
| `date` | `DATE`, `TIMESTAMP` or date text | the day of the cash flow |

- **Returns:** `DOUBLE`, in the money of the earliest date.
- **NULL:** rows where `amount` or `date` is NULL are skipped. No rows, a NULL `rate` or a `rate` of -1 or less give `NULL`.
- **Notes:** the rows can come in any order. Works with `GROUP BY` (one NPV per project).

**Example: NPV of each investment at a 5% and a 10% discount rate** (sample data: analysis-finance)

```sql
SELECT project,
       round(xnpv(0.05, amount, flow_date), 2) AS xnpv_5_pct,
       round(xnpv(0.10, amount, flow_date), 2) AS xnpv_10_pct
FROM cash_flows
GROUP BY project
ORDER BY project;
```

Result:

| project (STRING) | xnpv_5_pct (DOUBLE) | xnpv_10_pct (DOUBLE) |
|---|---|---|
| SOLAR_ROOF | 34320.05 | -25132.15 |
| VOLT_SHARES | -5423.7 | -25726.21 |

(2 rows)

**Example: The date must be a date** (sample data: analysis-finance; shows an error)

```sql
SELECT xnpv(0.1, amount, memo) FROM cash_flows;
```

Result:

Error: `line 1, column 8: xnpv: needs a date, got 'Buy 1000 VOLT shares at 185'`

## xirr

Syntax:

```sql
xirr(amount, date)
xirr(amount, date, guess)
```

The **yearly return of cash flows on real dates**: the rate where [xnpv](#xnpv) is `0`. It is an **aggregate**: every row is one cash flow. Use it for a share you bought, got dividends for, and sold; or for a SIP with payments on different days. The same as Excel `XIRR`.

| Argument | Type | Meaning |
|---|---|---|
| `amount` | number | the cash flow: negative for money out (buy), positive for money in (dividend, sell) |
| `date` | `DATE`, `TIMESTAMP` or date text | the day of the cash flow |
| `guess` | number | where the search starts; default `0.1` (10%). Rarely needed |

- **Returns:** `DOUBLE`, a fraction per year.
- **NULL:** rows where `amount` or `date` is NULL are skipped. `NULL` when there are no rows, and when there is no answer (all amounts have the same sign).
- **Notes:** the rows can come in any order. Years are counted as days / 365, like Excel.

**Example: Every cash flow of the VOLT shares, and the yearly return** (sample data: analysis-finance)

```sql
SELECT flow_date, amount, memo FROM cash_flows WHERE project = 'VOLT_SHARES' ORDER BY flow_date;

SELECT round(xirr(amount, flow_date) * 100, 2) AS yearly_return_pct
FROM cash_flows
WHERE project = 'VOLT_SHARES';
```

Result:

`SELECT flow_date, amount, memo FROM cash_flows WHERE project = 'VOLT_SHARES' ORDER BY flow_date`

| flow_date (DATE) | amount (DOUBLE) | memo (STRING) |
|---|---|---|
| 2024-01-15 | -185000 | Buy 1000 VOLT shares at 185 |
| 2024-12-20 | 5000 | Cash dividend |
| 2025-12-18 | 7500 | Cash dividend |
| 2026-09-10 | 191200 | Sell 1000 VOLT shares at 191.2 |

(4 rows)

`SELECT round(xirr(amount, flow_date) * 100, 2) AS yearly_return_pct FROM cash_flows WHERE project = `

| yearly_return_pct (DOUBLE) |
|---|
| 3.8 |

(1 row)

**Example: Check: XNPV at the XIRR rate is 0 (the rate comes from a subquery)** (sample data: analysis-finance)

```sql
SELECT round(abs(xnpv(r.rate, c.amount, c.flow_date)), 4) AS xnpv_at_xirr
FROM cash_flows c
CROSS JOIN (SELECT xirr(amount, flow_date) AS rate FROM cash_flows WHERE project = 'VOLT_SHARES') r
WHERE c.project = 'VOLT_SHARES';
```

Result:

| xnpv_at_xirr (DOUBLE) |
|---|
| 0 |

(1 row)

**Example: An aggregate cannot be inside another aggregate** (sample data: analysis-finance; shows an error)

```sql
SELECT xnpv(xirr(amount, flow_date), amount, flow_date) FROM cash_flows;
```

Result:

Error: `line 1, column 13: 'xirr' is an aggregate and cannot be used inside the aggregate 'xnpv'; compute it in a subquery first: SELECT xnpv(x) FROM (SELECT xirr(...) AS x FROM t GROUP BY ...) s`

**Example: Only money in: no return can be found** (sample data: analysis-finance)

```sql
SELECT xirr(amount, flow_date) AS xirr
FROM cash_flows
WHERE amount > 0;
```

Result:

| xirr (STRING) |
|---|
| NULL |

(1 row)

<a id="round_tick"></a>

## round_tick, floor_tick, ceil_tick

Syntax:

```sql
round_tick(price)
round_tick(price, tick)
floor_tick(price)
floor_tick(price, tick)
ceil_tick(price)
ceil_tick(price, tick)
```

Moves a price to the nearest allowed **tick**. The **tick size** is the smallest step a price can move on the exchange. On some exchanges it is `0.1`: 512.3 and 512.4 are prices, 512.35 is not. Use these functions for order prices, stop-losses and targets that you compute (like `close - 2 × ATR`).

| Function | Moves the price | 512.37 with tick 0.1 |
|---|---|---|
| `round_tick` | to the nearest tick (a half goes up, away from zero) | `512.4` |
| `floor_tick` | down to the tick at or below | `512.3` |
| `ceil_tick` | up to the tick at or above | `512.4` |

| Argument | Type | Meaning |
|---|---|---|
| `price` | number | the price |
| `tick` | number | the tick size, more than 0; default `0.1` |

- **Returns:** `DOUBLE`, with no more decimals than the tick has (no `512.30000000001`).
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** a tick of 0 or less is an error. Use `floor_tick` for a buy limit and a stop-loss of a long position (never above your number), `ceil_tick` for a sell target.

**Example** (sample data: analysis-finance)

```sql
SELECT round_tick(512.34) AS a, round_tick(512.35) AS half_up, floor_tick(512.39) AS down, ceil_tick(512.31) AS up,
       round_tick(512.37, 0.05) AS tick_005, round_tick(512.3, 1) AS whole_dollar;
```

Result:

| a (DOUBLE) | half_up (DOUBLE) | down (DOUBLE) | up (DOUBLE) | tick_005 (DOUBLE) | whole_dollar (DOUBLE) |
|---|---|---|---|---|---|
| 512.3 | 512.4 | 512.3 | 512.4 | 512.35 | 512 |

(1 row)

**Example: A stop-loss 2 × ATR below the close, as a price the exchange accepts** (sample data: sample)

```sql
SELECT symbol, close, atr5, round(close - 2 * atr5, 4) AS raw_stop, floor_tick(close - 2 * atr5) AS stop_price
FROM (SELECT time, symbol, close, atr(high, low, close, 5) OVER (PARTITION BY symbol ORDER BY time) AS atr5
      FROM ochl_day) t
WHERE time IN '2026-09-10'
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | atr5 (DOUBLE) | raw_stop (DOUBLE) | stop_price (DOUBLE) |
|---|---|---|---|---|
| CITY | 504.9 | 7.65324002169651 | 489.5935 | 489.5 |
| COAST | 376.1 | 9.98787632660481 | 356.1242 | 356.1 |
| VOLT | 191.2 | 7.42858372551475 | 176.3428 | 176.3 |

(3 rows)

**Example: The tick size must be more than 0** (sample data: analysis-finance; shows an error)

```sql
SELECT round_tick(512.34, 0);
```

Result:

Error: `line 1, column 8: round_tick: the tick size must be more than 0`

<a id="pivot_point"></a>

## pivot_point

Syntax:

```sql
pivot_point(high, low, close)
pivot_point(high, low, close, method)
```

The **pivot point** of the next day, made from the high, low and close of one day. Day traders draw it as a line on the chart. When the price is above the pivot, they see the day as strong (bullish); below, weak (bearish). The other lines, **support** (a price where falls often stop) and **resistance** (a price where rises often stop), come from [pivot_level](#pivot_level).

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the high of the day (usually yesterday) |
| `low` | number | the low of that day |
| `close` | number | the close of that day |
| `method` | text | `'classic'` (default; `'standard'` is the same), `'fibonacci'` (or `'fib'`), `'camarilla'` or `'woodie'` (any case) |

- **Returns:** `DOUBLE`: `(high + low + close) / 3`; for `'woodie'` `(high + low + 2 × close) / 4`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** an unknown method is an error. Round the result with [round_tick](#round_tick) to get a real price.

**Example** (sample data: analysis-finance)

```sql
SELECT round(pivot_point(507.0, 500.7, 504.9), 2) AS classic,
       round(pivot_point(507.0, 500.7, 504.9, 'fibonacci'), 2) AS fibonacci,
       round(pivot_point(507.0, 500.7, 504.9, 'woodie'), 3) AS woodie;
```

Result:

| classic (DOUBLE) | fibonacci (DOUBLE) | woodie (DOUBLE) |
|---|---|---|
| 504.2 | 504.2 | 504.375 |

(1 row)

<a id="pivot_level"></a>

## pivot_level

Syntax:

```sql
pivot_level(high, low, close, level)
pivot_level(high, low, close, level, method)
```

One line of the **pivot point** system: the pivot `'p'`, the resistance lines `'r1'`, `'r2'`, `'r3'` above it, or the support lines `'s1'`, `'s2'`, `'s3'` below it. `r1` and `s1` are close to the pivot; `r3` and `s3` are far away and are only reached on days with big moves.

| Argument | Type | Meaning |
|---|---|---|
| `high`, `low`, `close` | numbers | the candle of one day (usually yesterday) |
| `level` | text | `'p'` (also `'pp'`, `'pivot'`), `'r1'`, `'r2'`, `'r3'`, `'s1'`, `'s2'`, `'s3'`; `'camarilla'` also has `'r4'` and `'s4'` (any case) |
| `method` | text | `'classic'` (default, or `'standard'`), `'fibonacci'` (or `'fib'`), `'camarilla'`, `'woodie'` |

The lines, with `P` = the pivot and `range = high - low`:

| Method | R1 / S1 | R2 / S2 | R3 / S3 | R4 / S4 |
|---|---|---|---|---|
| classic, woodie | `2P - low` / `2P - high` | `P ± range` | `high + 2(P - low)` / `low - 2(high - P)` | none |
| fibonacci | `P ± 0.382 × range` | `P ± 0.618 × range` | `P ± range` | none |
| camarilla | `close ± range × 1.1/12` | `close ± range × 1.1/6` | `close ± range × 1.1/4` | `close ± range × 1.1/2` |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** a level that the method does not have (like `'r4'` for classic) and an unknown method are errors. Woodie uses its own pivot `(high + low + 2 × close) / 4` in the classic formulas.

**Example: Today's pivot lines for every symbol, from yesterday's candle** (sample data: sample)

```sql
SELECT symbol,
       round_tick(pivot_level(high, low, close, 's2')) AS s2,
       round_tick(pivot_level(high, low, close, 's1')) AS s1,
       round_tick(pivot_point(high, low, close)) AS pivot,
       round_tick(pivot_level(high, low, close, 'r1')) AS r1,
       round_tick(pivot_level(high, low, close, 'r2')) AS r2
FROM ochl_day
WHERE time IN '2026-09-09'
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | s2 (DOUBLE) | s1 (DOUBLE) | pivot (DOUBLE) | r1 (DOUBLE) | r2 (DOUBLE) |
|---|---|---|---|---|---|
| CITY | 498.6 | 501.6 | 507 | 510 | 515.4 |
| COAST | 366.4 | 373.3 | 386 | 392.9 | 405.6 |
| VOLT | 178.4 | 182.8 | 186.2 | 190.6 | 194 |

(3 rows)

**Example: Did the price stop at yesterday's lines? Today's high and low next to R1 and S1** (sample data: sample)

```sql
SELECT symbol, time, low, high, s1, r1,
       CASE WHEN high >= r1 THEN 'broke R1' WHEN low <= s1 THEN 'broke S1' ELSE 'stayed between' END AS result
FROM (SELECT time, symbol, low, high,
             round_tick(pivot_level(prev_high, prev_low, prev_close, 's1')) AS s1,
             round_tick(pivot_level(prev_high, prev_low, prev_close, 'r1')) AS r1
      FROM (SELECT time, symbol, low, high,
                   lag(high) OVER (PARTITION BY symbol ORDER BY time) AS prev_high,
                   lag(low) OVER (PARTITION BY symbol ORDER BY time) AS prev_low,
                   lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev_close
            FROM ochl_day) c) t
WHERE time IN '2026-09-10'
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | time (TIMESTAMP) | low (DOUBLE) | high (DOUBLE) | s1 (DOUBLE) | r1 (DOUBLE) | result (STRING) |
|---|---|---|---|---|---|---|
| CITY | 2026-09-10T00:00:00.000Z | 500.7 | 507 | 501.6 | 510 | broke S1 |
| COAST | 2026-09-10T00:00:00.000Z | 373.2 | 382 | 373.3 | 392.9 | broke S1 |
| VOLT | 2026-09-10T00:00:00.000Z | 184.2 | 192.1 | 182.8 | 190.6 | broke R1 |

(3 rows)

**Example: The four methods side by side (CITY, 2026-09-10 candle)** (sample data: sample)

```sql
SELECT m.method,
       round(pivot_level(d.high, d.low, d.close, 's1', m.method), 2) AS s1,
       round(pivot_level(d.high, d.low, d.close, 'p', m.method), 2) AS pivot,
       round(pivot_level(d.high, d.low, d.close, 'r1', m.method), 2) AS r1
FROM ochl_day d
CROSS JOIN (SELECT 'classic' AS method UNION ALL SELECT 'fibonacci' UNION ALL SELECT 'camarilla' UNION ALL SELECT 'woodie') m
WHERE d.symbol = 'CITY' AND d.time IN '2026-09-10'
ORDER BY s1;
```

Result:

| method (STRING) | s1 (DOUBLE) | pivot (DOUBLE) | r1 (DOUBLE) |
|---|---|---|---|
| classic | 501.4 | 504.2 | 507.7 |
| woodie | 501.75 | 504.38 | 508.05 |
| fibonacci | 501.79 | 504.2 | 506.61 |
| camarilla | 504.32 | 504.2 | 505.48 |

(4 rows)

**Example: Classic pivots have no R4** (sample data: analysis-finance; shows an error)

```sql
SELECT pivot_level(507.0, 500.7, 504.9, 'r4');
```

Result:

Error: `line 1, column 8: pivot_level: level must be p, r1, r2, r3, s1, s2 or s3 for classic pivots, got 'r4'`
