-- ============================================================
-- Metro Vancouver SkyTrain Ridership and Network Demand Analysis
-- SQL Analysis
-- ============================================================


-- 1. Annual Ridership by Line and Year

SELECT
    calendar_year,
    mode,
    ROUND(annual_boardings::numeric, 0) AS annual_boardings
FROM line_ridership
ORDER BY calendar_year, mode;


-- 2. Annual Ridership YoY Growth by Line

SELECT
    calendar_year,
    mode,
    ROUND(annual_boardings::numeric, 0) AS annual_boardings,
    ROUND(
        (
            (annual_boardings - LAG(annual_boardings) OVER (
                PARTITION BY mode
                ORDER BY calendar_year
            ))
            /
            LAG(annual_boardings) OVER (
                PARTITION BY mode
                ORDER BY calendar_year
            )
            * 100
        )::numeric,
        2
    ) AS yoy_growth_pct
FROM line_ridership
ORDER BY mode, calendar_year;


-- 3. Total SkyTrain Annual Ridership

SELECT
    calendar_year,
    ROUND(SUM(annual_boardings)::numeric, 0) AS total_annual_boardings
FROM line_ridership
GROUP BY calendar_year
ORDER BY calendar_year;


-- 4. Total SkyTrain Ridership YoY Growth

WITH yearly_ridership AS (
    SELECT
        calendar_year,
        SUM(annual_boardings) AS total_boardings
    FROM line_ridership
    GROUP BY calendar_year
)

SELECT
    calendar_year,
    ROUND(total_boardings::numeric, 0) AS total_annual_boardings,
    ROUND(
        (
            (total_boardings - LAG(total_boardings) OVER (
                ORDER BY calendar_year
            ))
            /
            LAG(total_boardings) OVER (
                ORDER BY calendar_year
            )
            * 100
        )::numeric,
        2
    ) AS yoy_growth_pct
FROM yearly_ridership
ORDER BY calendar_year;


-- 5. Top 10 Busiest Stations - 2025

SELECT
    station_name,
    ROUND(annual_station_brdgs::numeric, 0) AS annual_boardings
FROM station_year
WHERE calendar_year = 2025
ORDER BY annual_station_brdgs DESC
LIMIT 10;


-- 6. Top 10 Fastest-Growing Stations - 2023 to 2025

SELECT
    s23.station_name,
    ROUND(s23.annual_station_brdgs::numeric, 0) AS boardings_2023,
    ROUND(s25.annual_station_brdgs::numeric, 0) AS boardings_2025,
    ROUND(
        (
            (s25.annual_station_brdgs - s23.annual_station_brdgs)
            / s23.annual_station_brdgs * 100
        )::numeric,
        2
    ) AS growth_pct
FROM station_year s23
JOIN station_year s25
    ON s23.station_name = s25.station_name
WHERE s23.calendar_year = 2023
  AND s25.calendar_year = 2025
ORDER BY growth_pct DESC
LIMIT 10;


-- 7. Top 10 Stations by Ridership Decline - 2023 to 2025

SELECT
    s23.station_name,
    ROUND(s23.annual_station_brdgs::numeric, 0) AS boardings_2023,
    ROUND(s25.annual_station_brdgs::numeric, 0) AS boardings_2025,
    ROUND(
        (
            (s25.annual_station_brdgs - s23.annual_station_brdgs)
            / s23.annual_station_brdgs * 100
        )::numeric,
        2
    ) AS growth_pct
FROM station_year s23
JOIN station_year s25
    ON s23.station_name = s25.station_name
WHERE s23.calendar_year = 2023
  AND s25.calendar_year = 2025
ORDER BY growth_pct ASC
LIMIT 10;


-- 8. Top 3 Peak Ridership Hours by Day Type - 2025

WITH hourly_totals AS (
    SELECT
        day_type,
        hour_24,
        SUM(average_daily_station_boardings) AS total_boardings
    FROM hourly_station
    WHERE calendar_year = 2025
    GROUP BY day_type, hour_24
),
ranked_hours AS (
    SELECT
        day_type,
        hour_24,
        total_boardings,
        ROW_NUMBER() OVER (
            PARTITION BY day_type
            ORDER BY total_boardings DESC
        ) AS peak_rank
    FROM hourly_totals
)

SELECT
    day_type,
    peak_rank,
    hour_24,
    total_boardings
FROM ranked_hours
WHERE peak_rank <= 3
ORDER BY day_type, peak_rank;


-- 9. Top 10 Busiest SkyTrain Segments - 2025 Full Station Names

WITH station_lookup AS (
    SELECT DISTINCT
        from_stn_short AS station_code,
        from_stn_long AS station_name
    FROM rolling_hour
    WHERE from_stn_short IS NOT NULL

    UNION

    SELECT DISTINCT
        to_stn_short AS station_code,
        to_stn_long AS station_name
    FROM rolling_hour
    WHERE to_stn_short IS NOT NULL
)

SELECT
    b.seg_mode,
    b.day_type,
    b.time_period,
    f.station_name AS from_station,
    t.station_name AS to_station,
    b.hour_24,
    b.minute_15,
    ROUND(b.avg_hrly_vol::numeric, 0) AS avg_hourly_volume
FROM busiest_segments b
LEFT JOIN station_lookup f
    ON b.trav_from_stn = f.station_code
LEFT JOIN station_lookup t
    ON b.trav_to_stn = t.station_code
WHERE b.trav_year = 2025
ORDER BY b.avg_hrly_vol DESC
LIMIT 10;


-- 10. Top 10 Weekday Segments by Daily Volume - 2025

SELECT
    seg_mode,
    day_type,
    from_stn_long,
    to_stn_long,
    seg_dir,
    ROUND(avg_daily_vol::numeric, 0) AS avg_daily_volume
FROM daily_segments
WHERE trav_year = 2025
  AND day_type = 'Weekday'
ORDER BY avg_daily_vol DESC
LIMIT 10;


-- 11. Top 10 Fastest-Growing Weekday Segments - 2023 to 2025

SELECT
    s23.seg_mode,
    s23.from_stn_long AS from_station,
    s23.to_stn_long AS to_station,
    s23.seg_dir,
    ROUND(s23.avg_daily_vol::numeric, 0) AS volume_2023,
    ROUND(s25.avg_daily_vol::numeric, 0) AS volume_2025,
    ROUND(
        (
            (s25.avg_daily_vol - s23.avg_daily_vol)
            / s23.avg_daily_vol * 100
        )::numeric,
        2
    ) AS growth_pct
FROM daily_segments s23
JOIN daily_segments s25
    ON s23.seg_i_d = s25.seg_i_d
    AND s23.seg_dir = s25.seg_dir
    AND s23.day_type = s25.day_type
WHERE s23.trav_year = 2023
  AND s25.trav_year = 2025
  AND s23.day_type = 'Weekday'
ORDER BY growth_pct DESC
LIMIT 10;


-- 12. SkyTrain Ridership by Day Type - 2025

SELECT
    day_type,
    SUM(average_daily_station_boardings) AS avg_daily_boardings
FROM hourly_station
WHERE calendar_year = 2025
GROUP BY day_type
ORDER BY avg_daily_boardings DESC;


-- 13. Top 10 Stations During Weekday PM Peak - 2025

SELECT
    station_name,
    average_daily_station_boardings AS boardings,
    average_daily_station_alightings AS alightings,
    average_daily_station_boardings
        + average_daily_station_alightings AS total_station_activity
FROM hourly_station
WHERE calendar_year = 2025
  AND day_type = 'Weekday'
  AND hour_24 = 16
ORDER BY total_station_activity DESC
LIMIT 10;


-- 14. Top 10 Commuter-Oriented Stations - 2025

SELECT
    station_name,
    ROUND(avg_station_brdgs_m_f::numeric, 0) AS weekday_boardings,
    ROUND(
        ((avg_station_brdgs_sat + avg_station_brdgs_sun_hol) / 2)::numeric,
        0
    ) AS avg_weekend_boardings,
    ROUND(
        (
            (
                avg_station_brdgs_m_f -
                ((avg_station_brdgs_sat + avg_station_brdgs_sun_hol) / 2)
            )
            / avg_station_brdgs_m_f * 100
        )::numeric,
        2
    ) AS weekend_drop_pct
FROM station_year
WHERE calendar_year = 2025
ORDER BY weekend_drop_pct DESC
LIMIT 10;