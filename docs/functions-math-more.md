# Trigonometry and probability

> Sine, cosine, tangent and their inverses, hyperbolic functions, and the normal distribution (chance, bell height and inverse).

- Category: Functions — math
- Keywords: trigonometry, angle, radian, degree, circle, cycle, wave, seasonality, sine, cosine, tangent, cotangent, arc sine, arcsin, arc cosine, arccos, arc tangent, arctan, arctan2, trend angle, hyperbolic, squash, fisher transform, normal distribution, bell curve, gaussian, probability, chance, z-score, cumulative distribution, norm.dist, NORMSDIST, density, norm.inv, NORMSINV, quantile of normal, confidence level
- See also: [Math functions](functions-math.md), [Statistics functions](functions-statistics.md), [Returns and risk](functions-returns-risk.md), [Finance and price functions](functions-finance.md)

These functions work with **angles** and with **chances**.

**Angles.** An angle can be measured in **degrees** (a full circle is 360°) or in **radians** (a full circle is 2π, about 6.28). All functions here use **radians**. Change degrees to radians with [radians](functions-math.md#radians), and back with [degrees](functions-math.md#degrees): `sin(radians(30))` is `0.5`.

**Rules**

- A `NULL` argument gives `NULL`.
- A value outside the allowed range gives `NULL`, not an error: `asin(2)` is `NULL`.
- Text is an error: `sin('a')`. Use `CAST` for text that holds a number.
- They return `DOUBLE`. Results like `sin(pi())` are a tiny number instead of exactly `0`: use `round(x, 10)` to clean them.

**Example: Angles in degrees and radians, with sine and cosine** (sample data: sample)

```sql
SELECT deg, round(radians(deg), 4) AS rad, round(sin(radians(deg)), 4) AS sin, round(cos(radians(deg)), 4) AS cos
FROM (SELECT 0 AS deg UNION ALL SELECT 30 UNION ALL SELECT 45 UNION ALL SELECT 90 UNION ALL SELECT 180) t
ORDER BY deg;
```

Result:

| deg (LONG) | rad (DOUBLE) | sin (DOUBLE) | cos (DOUBLE) |
|---|---|---|---|
| 0 | 0 | 0 | 1 |
| 30 | 0.5236 | 0.5 | 0.866 |
| 45 | 0.7854 | 0.7071 | 0.7071 |
| 90 | 1.5708 | 1 | 0 |
| 180 | 3.1416 | 0 | -1 |

(5 rows)

## sin

Syntax:

```sql
sin(x)
```

The **sine** of the angle `x` (in radians). As the angle goes round the circle, the sine goes smoothly up and down between `-1` and `1`, like a wave. Use it to make a cycle: `sin(2 × π × day / 8)` repeats every 8 days.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | an angle in radians |

- **Returns:** `DOUBLE` from `-1` to `1`.
- **NULL:** `NULL` in, `NULL` out.

**Example** (sample data: sample)

```sql
SELECT sin(0) AS a, sin(pi() / 2) AS b, round(sin(radians(30)), 4) AS c, round(sin(pi()), 10) AS d;
```

Result:

| a (DOUBLE) | b (DOUBLE) | c (DOUBLE) | d (DOUBLE) |
|---|---|---|---|
| 0 | 1 | 0.5 | 0 |

(1 row)

**Example: An 8-day wave next to CITY's close** (sample data: sample)

```sql
SELECT time, close, round(sin(2 * pi() * row_number() / 8), 3) AS wave
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-02'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | wave (DOUBLE) |
|---|---|---|
| 2026-09-02T00:00:00.000Z | 496.4 | 0.707 |
| 2026-09-03T00:00:00.000Z | 497.9 | 1 |
| 2026-09-06T00:00:00.000Z | 499 | 0.707 |
| 2026-09-07T00:00:00.000Z | 498.7 | 0 |
| 2026-09-08T00:00:00.000Z | 497.5 | -0.707 |
| 2026-09-09T00:00:00.000Z | 504.6 | -1 |
| 2026-09-10T00:00:00.000Z | 504.9 | -0.707 |

(7 rows)

## cos

Syntax:

```sql
cos(x)
```

The **cosine** of the angle `x` (in radians): the same wave as `sin`, a quarter circle earlier. `cos(0)` is `1`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | an angle in radians |

- **Returns:** `DOUBLE` from `-1` to `1`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** `sin` and `cos` together put a month on a circle, so December (12) and January (1) come out close to each other. This is useful for **seasonality** (patterns that repeat every year) in reports and models.

**Example** (sample data: sample)

```sql
SELECT cos(0) AS a, round(cos(pi() / 2), 10) AS b, cos(pi()) AS c, round(cos(radians(60)), 4) AS d;
```

Result:

| a (DOUBLE) | b (DOUBLE) | c (DOUBLE) | d (DOUBLE) |
|---|---|---|---|
| 1 | 0 | -1 | 0.5 |

(1 row)

**Example: Months on a circle: December is next to January, July is far away** (sample data: sample)

```sql
SELECT m AS month,
       round(sin(2 * pi() * (m - 1) / 12), 3) AS month_sin,
       round(cos(2 * pi() * (m - 1) / 12), 3) AS month_cos
FROM (SELECT 1 AS m UNION ALL SELECT 4 UNION ALL SELECT 7 UNION ALL SELECT 12) t
ORDER BY m;
```

Result:

| month (LONG) | month_sin (DOUBLE) | month_cos (DOUBLE) |
|---|---|---|
| 1 | 0 | 1 |
| 4 | 1 | 0 |
| 7 | 0 | -1 |
| 12 | -0.5 | 0.866 |

(4 rows)

## tan

Syntax:

```sql
tan(x)
```

The **tangent** of the angle `x` (in radians): `sin(x) / cos(x)`. It is the **slope** of a line with that angle: how much it goes up for one step to the right. `tan(radians(45))` is `1`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | an angle in radians |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** near 90° the tangent becomes very big.

**Example: Rise per step for a line at 10, 30, 45 and 60 degrees** (sample data: sample)

```sql
SELECT deg, round(tan(radians(deg)), 4) AS rise_per_step
FROM (SELECT 10 AS deg UNION ALL SELECT 30 UNION ALL SELECT 45 UNION ALL SELECT 60) t
ORDER BY deg;
```

Result:

| deg (LONG) | rise_per_step (DOUBLE) |
|---|---|
| 10 | 0.1763 |
| 30 | 0.5774 |
| 45 | 1 |
| 60 | 1.7321 |

(4 rows)

## cot

Syntax:

```sql
cot(x)
```

The **cotangent** of the angle `x` (in radians): `1 / tan(x)`, or `cos(x) / sin(x)`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | an angle in radians |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out. `cot(0)` is `NULL` (it would be a division by zero).

**Example** (sample data: sample)

```sql
SELECT round(cot(radians(45)), 4) AS a, round(cot(radians(60)), 4) AS b, round(1 / tan(radians(60)), 4) AS same, cot(0) AS zero;
```

Result:

| a (DOUBLE) | b (DOUBLE) | same (DOUBLE) | zero (STRING) |
|---|---|---|---|
| 1 | 0.5774 | 0.5774 | NULL |

(1 row)

## asin

Syntax:

```sql
asin(x)
```

The **arc sine**: the angle whose sine is `x`. It undoes `sin`. `asin(1)` is π/2 (90°).

| Argument | Type | Meaning |
|---|---|---|
| `x` | number from `-1` to `1` | a sine value |

- **Returns:** `DOUBLE`, an angle in radians from -π/2 to π/2.
- **NULL:** `NULL` in, `NULL` out. `x` below `-1` or above `1` gives `NULL`.

**Example** (sample data: sample)

```sql
SELECT asin(1) AS a, degrees(asin(0.5)) AS b_degrees, degrees(asin(-1)) AS c_degrees, asin(2) AS out_of_range;
```

Result:

| a (DOUBLE) | b_degrees (DOUBLE) | c_degrees (DOUBLE) | out_of_range (STRING) |
|---|---|---|---|
| 1.5707963267949 | 30 | -90 | NULL |

(1 row)

## acos

Syntax:

```sql
acos(x)
```

The **arc cosine**: the angle whose cosine is `x`. It undoes `cos`. `acos(1)` is `0`, `acos(-1)` is π (180°).

| Argument | Type | Meaning |
|---|---|---|
| `x` | number from `-1` to `1` | a cosine value |

- **Returns:** `DOUBLE`, an angle in radians from 0 to π.
- **NULL:** `NULL` in, `NULL` out. `x` below `-1` or above `1` gives `NULL`.

**Example** (sample data: sample)

```sql
SELECT acos(1) AS a, degrees(acos(0.5)) AS b_degrees, degrees(acos(-1)) AS c_degrees, acos(-2) AS out_of_range;
```

Result:

| a (DOUBLE) | b_degrees (DOUBLE) | c_degrees (DOUBLE) | out_of_range (STRING) |
|---|---|---|---|
| 0 | 60 | 180 | NULL |

(1 row)

## atan

Syntax:

```sql
atan(x)
```

The **arc tangent**: the angle whose tangent is `x`. It undoes `tan`, and turns a **slope** into an angle. `degrees(atan(1))` is `45`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | a tangent value (a slope) |

- **Returns:** `DOUBLE`, an angle in radians between -π/2 and π/2 (-90° and 90°).
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** a chart angle depends on the scale of the chart. Measure the slope in **percent per candle**: then a rise of 1% per day is 45°.

**Example** (sample data: sample)

```sql
SELECT atan(0) AS a, degrees(atan(1)) AS b_degrees, degrees(atan(-1)) AS c_degrees, round(degrees(atan(1000000)), 3) AS almost_90;
```

Result:

| a (DOUBLE) | b_degrees (DOUBLE) | c_degrees (DOUBLE) | almost_90 (DOUBLE) |
|---|---|---|---|
| 0 | 45 | -45 | 90 |

(1 row)

**Example: Trend angle of VOLT: the rise over 4 days, in % per day, as an angle** (sample data: sample)

```sql
SELECT time, close, pct_per_day, round(degrees(atan(pct_per_day)), 1) AS angle_degrees
FROM (SELECT time, close, round((close / lag(close, 4) - 1) * 100 / 4, 3) AS pct_per_day
      FROM ochl_day
      WHERE symbol = 'VOLT' AND time >= '2026-08-23') t
WHERE time >= '2026-09-06'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | pct_per_day (DOUBLE) | angle_degrees (DOUBLE) |
|---|---|---|---|
| 2026-09-06T00:00:00.000Z | 180.1 | 1.086 | 47.4 |
| 2026-09-07T00:00:00.000Z | 176.9 | 1.169 | 49.5 |
| 2026-09-08T00:00:00.000Z | 182.4 | 1.589 | 57.8 |
| 2026-09-09T00:00:00.000Z | 187.3 | 1.605 | 58.1 |
| 2026-09-10T00:00:00.000Z | 191.2 | 1.541 | 57 |

(5 rows)

## atan2

Syntax:

```sql
atan2(y, x)
```

The angle of the point (`x`, `y`) as seen from (0, 0). Unlike `atan(y / x)`, it knows which quarter of the circle the point is in, and it works when `x` is `0`. Note the order: `y` comes first.

| Argument | Type | Meaning |
|---|---|---|
| `y` | any number | the up-down position |
| `x` | any number | the left-right position |

- **Returns:** `DOUBLE`, an angle in radians from -π to π (-180° to 180°).
- **NULL:** `NULL` when an argument is `NULL`. `atan2(0, 0)` is `0`.

**Example: The angle of four points, one in each quarter** (sample data: sample)

```sql
SELECT x, y, round(degrees(atan2(y, x)), 1) AS angle_degrees, round(degrees(atan(y / x)), 1) AS atan_of_ratio
FROM (SELECT 1 AS x, 1 AS y UNION ALL SELECT -1, 1 UNION ALL SELECT -1, -1 UNION ALL SELECT 1, -1) t;
```

Result:

| x (LONG) | y (LONG) | angle_degrees (DOUBLE) | atan_of_ratio (DOUBLE) |
|---|---|---|---|
| 1 | 1 | 45 | 45 |
| -1 | 1 | 135 | -45 |
| -1 | -1 | -135 | 45 |
| 1 | -1 | -45 | -45 |

(4 rows)

<a id="sinh"></a>

## sinh, cosh, tanh

Syntax:

```sql
sinh(x)
cosh(x)
tanh(x)
```

The **hyperbolic** sine, cosine and tangent. They are made from `exp`: `sinh(x) = (e^x - e^-x) / 2`, `cosh(x) = (e^x + e^-x) / 2`, `tanh(x) = sinh(x) / cosh(x)`. The most useful one for data is `tanh`: it **squashes** any number into the range `-1` to `1`. Small values stay almost the same; very big values come close to `1` (or `-1`).

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value |

- **Returns:** `DOUBLE`. `tanh` is from `-1` to `1`; `cosh` is `1` or more.
- **NULL:** `NULL` in, `NULL` out. A result too big for a `DOUBLE` (like `sinh(1000)`) is `NULL`.

**Example** (sample data: sample)

```sql
SELECT sinh(0) AS sinh_0, round(sinh(1), 4) AS sinh_1, cosh(0) AS cosh_0, round(tanh(1), 4) AS tanh_1, round(tanh(5), 4) AS tanh_5, round(tanh(-5), 4) AS tanh_minus_5, sinh(1000) AS too_big;
```

Result:

| sinh_0 (DOUBLE) | sinh_1 (DOUBLE) | cosh_0 (DOUBLE) | tanh_1 (DOUBLE) | tanh_5 (DOUBLE) | tanh_minus_5 (DOUBLE) | too_big (STRING) |
|---|---|---|---|---|---|---|
| 0 | 1.1752 | 1 | 0.7616 | 0.9999 | -0.9999 | NULL |

(1 row)

**Example: A signal from -1 to 1: tanh of the daily % change** (sample data: sample)

```sql
SELECT time, symbol, round(chg, 2) AS change_pct, round(tanh(chg), 3) AS signal
FROM (SELECT time, symbol, pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS chg
      FROM ochl_day
      WHERE time >= '2026-09-06') t
WHERE time IN '2026-09-09'
ORDER BY symbol;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | change_pct (DOUBLE) | signal (DOUBLE) |
|---|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 1.43 | 0.891 |
| 2026-09-09T00:00:00.000Z | COAST | 0.77 | 0.646 |
| 2026-09-09T00:00:00.000Z | VOLT | 2.69 | 0.991 |

(3 rows)

<a id="asinh"></a>

## asinh, acosh, atanh

Syntax:

```sql
asinh(x)
acosh(x)
atanh(x)
```

The inverse hyperbolic functions: they undo `sinh`, `cosh` and `tanh`.

| Function | Allowed `x` | Use |
|---|---|---|
| `asinh(x)` | any number | like a logarithm that also works for `0` and negative numbers: good to shrink big profits and losses for a chart |
| `acosh(x)` | `1` or more | undoes `cosh` |
| `atanh(x)` | more than `-1` and less than `1` | undoes `tanh`; it is the **Fisher transform** that traders use to make turning points of an oscillator sharper |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out. A value outside the allowed range gives `NULL`: `acosh(0.5)`, `atanh(1)`.

**Example** (sample data: sample)

```sql
SELECT round(asinh(1), 4) AS asinh_1, acosh(1) AS acosh_1, round(atanh(0.5), 4) AS atanh_half, round(atanh(tanh(0.3)), 4) AS back_to_0_3, acosh(0.5) AS out_of_range, atanh(1) AS atanh_1;
```

Result:

| asinh_1 (DOUBLE) | acosh_1 (DOUBLE) | atanh_half (DOUBLE) | back_to_0_3 (DOUBLE) | out_of_range (STRING) | atanh_1 (STRING) |
|---|---|---|---|---|---|
| 0.8814 | 0 | 0.5493 | 0.3 | NULL | NULL |

(1 row)

**Example: Shrink profits and losses with asinh (works for 0 and minus)** (sample data: sample)

```sql
SELECT pnl, round(asinh(pnl), 2) AS scaled
FROM (SELECT -100000 AS pnl UNION ALL SELECT -500 UNION ALL SELECT 0 UNION ALL SELECT 500 UNION ALL SELECT 100000) t
ORDER BY pnl;
```

Result:

| pnl (LONG) | scaled (DOUBLE) |
|---|---|
| -100000 | -12.21 |
| -500 | -6.91 |
| 0 | 0 |
| 500 | 6.91 |
| 100000 | 12.21 |

(5 rows)

<a id="normal_cdf"></a>

## normal_cdf

Syntax:

```sql
normal_cdf(x)
normal_cdf(x, mean, stddev)
```

Many values spread around their average like a **bell**: most values are near the average, few are far away. The **normal distribution** is this bell shape. It is described by two numbers: the **mean** (the middle) and the **standard deviation** (how wide the bell is; see [stddev](functions-statistics.md#stddev)).

`normal_cdf` gives the **chance** that a value is **at or below** `x`, as a number from 0 to 1. For example, if CITY's daily return has mean -0.04% and standard deviation 0.75%, `normal_cdf(-2, -0.04, 0.75)` is the chance of a day worse than -2%.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value |
| `mean` | any number | the middle of the bell; default `0` |
| `stddev` | number, more than 0 | the width of the bell; default `1` |

- **Returns:** `DOUBLE` from 0 to 1 (`0.025` means 2.5%).
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** `stddev` of 0 or less is an error. With the defaults, `x` is a **z-score** (how many standard deviations from the mean): `normal_cdf(1.96)` is 0.975. Careful: real prices have more big jumps than the bell says, so treat the result as a rough guide. Like Excel `NORM.DIST(x, mean, sd, TRUE)`.

**Example** (sample data: sample)

```sql
SELECT normal_cdf(0) AS at_mean, round(normal_cdf(1.96), 4) AS z_1_96, round(normal_cdf(-1), 4) AS z_minus_1, round(normal_cdf(110, 100, 10), 4) AS one_sd_above;
```

Result:

| at_mean (DOUBLE) | z_1_96 (DOUBLE) | z_minus_1 (DOUBLE) | one_sd_above (DOUBLE) |
|---|---|---|---|
| 0.5 | 0.975 | 0.1587 | 0.8413 |

(1 row)

**Example: Chance of a day worse than -2%, from each share's daily returns** (sample data: sample)

```sql
SELECT symbol, count(chg) AS days,
       round(avg(chg), 3) AS mean_pct,
       round(stddev(chg), 3) AS stddev_pct,
       round(normal_cdf(-2, avg(chg), stddev(chg)) * 100, 1) AS chance_pct
FROM (SELECT symbol, pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS chg
      FROM ochl_day
      WHERE time >= '2026-08-23') t
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | days (LONG) | mean_pct (DOUBLE) | stddev_pct (DOUBLE) | chance_pct (DOUBLE) |
|---|---|---|---|---|
| CITY | 14 | -0.04 | 0.746 | 0.4 |
| COAST | 14 | -0.271 | 1.145 | 6.5 |
| VOLT | 14 | 0.409 | 1.885 | 10.1 |

(3 rows)

**Example: The standard deviation must be more than 0** (sample data: sample; shows an error)

```sql
SELECT normal_cdf(1, 0, 0);
```

Result:

Error: `line 1, column 8: normal_cdf: the standard deviation must be more than 0`

<a id="normal_pdf"></a>

## normal_pdf

Syntax:

```sql
normal_pdf(x)
normal_pdf(x, mean, stddev)
```

The **height of the bell** at `x` (the "density"). It is highest at the mean and gets lower far from it. The height itself is not a chance; compare two heights to see which value is more usual.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value |
| `mean` | any number | the middle of the bell; default `0` |
| `stddev` | number, more than 0 | the width of the bell; default `1` |

- **Returns:** `DOUBLE`, more than 0.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** `stddev` of 0 or less is an error. Like Excel `NORM.DIST(x, mean, sd, FALSE)`.

**Example: The bell is highest at the mean** (sample data: sample)

```sql
SELECT z, round(normal_pdf(z), 4) AS height, round(normal_pdf(z) / normal_pdf(0), 3) AS compared_to_mean
FROM (SELECT 0 AS z UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) t
ORDER BY z;
```

Result:

| z (LONG) | height (DOUBLE) | compared_to_mean (DOUBLE) |
|---|---|---|
| 0 | 0.3989 | 1 |
| 1 | 0.242 | 0.607 |
| 2 | 0.054 | 0.135 |
| 3 | 0.0044 | 0.011 |

(4 rows)

**Example** (sample data: sample)

```sql
SELECT round(normal_pdf(100, 100, 10), 5) AS at_mean, round(normal_pdf(120, 100, 10), 5) AS two_sd_away;
```

Result:

| at_mean (DOUBLE) | two_sd_away (DOUBLE) |
|---|---|
| 0.03989 | 0.0054 |

(1 row)

<a id="normal_inv"></a>

## normal_inv

Syntax:

```sql
normal_inv(p)
normal_inv(p, mean, stddev)
```

The opposite of `normal_cdf`: the value `x` that has a chance `p` of being at or below it. `normal_inv(0.975)` is about `1.96`. Use it to find a level that is crossed only a small part of the time, for example the daily return that is worse only 5% of the days (a simple **value at risk**; see also [value_at_risk](functions-returns-risk.md#value_at_risk)).

| Argument | Type | Meaning |
|---|---|---|
| `p` | number, more than 0 and less than 1 | the chance |
| `mean` | any number | the middle of the bell; default `0` |
| `stddev` | number, more than 0 | the width of the bell; default `1` |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** `p` of 0 or 1 or outside that range is an error, and so is a `stddev` of 0 or less. Like Excel `NORM.INV(p, mean, sd)`.

**Example: z-scores for 90%, 95% and 99% confidence** (sample data: sample)

```sql
SELECT round(normal_inv(0.95), 3) AS z_90_two_sided, round(normal_inv(0.975), 3) AS z_95_two_sided, round(normal_inv(0.995), 3) AS z_99_two_sided, normal_inv(0.5, 100, 10) AS middle;
```

Result:

| z_90_two_sided (DOUBLE) | z_95_two_sided (DOUBLE) | z_99_two_sided (DOUBLE) | middle (DOUBLE) |
|---|---|---|---|
| 1.645 | 1.96 | 2.576 | 100 |

(1 row)

**Example: The daily return that is worse only 5% of the days** (sample data: sample)

```sql
SELECT symbol, round(avg(chg), 3) AS mean_pct, round(stddev(chg), 3) AS stddev_pct,
       round(normal_inv(0.05, avg(chg), stddev(chg)), 2) AS worst_5pct_day
FROM (SELECT symbol, pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS chg
      FROM ochl_day
      WHERE time >= '2026-08-23') t
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | mean_pct (DOUBLE) | stddev_pct (DOUBLE) | worst_5pct_day (DOUBLE) |
|---|---|---|---|
| CITY | -0.04 | 0.746 | -1.27 |
| COAST | -0.271 | 1.145 | -2.15 |
| VOLT | 0.409 | 1.885 | -2.69 |

(3 rows)

**Example: p must be more than 0 and less than 1** (sample data: sample; shows an error)

```sql
SELECT normal_inv(1);
```

Result:

Error: `line 1, column 8: normal_inv: the probability must be more than 0 and less than 1`
