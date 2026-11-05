/*

----    DDL / DML for 4 dimension tables, 2 fact tables

*/

/*
---
    -- DS_ARTIST table
---
*/
CREATE OR REPLACE TABLE DS_ARTIST (
    ARTIST_MBID  VARCHAR PRIMARY KEY,
    ARTIST_NAME  VARCHAR
);

INSERT INTO DS_ARTIST
SELECT DISTINCT ARTIST_MBID, ARTIST_NAME
FROM DS_SETLIST_DATA_RAW;

select *
from ds_artist;

/*
---
    -- DS_VENUE table
---
*/
CREATE OR REPLACE TABLE DS_VENUE (
    VENUE_ID  VARCHAR PRIMARY KEY,
    VENUE_NAME  VARCHAR,
    CITY_NAME  VARCHAR,
    STATE_NAME  VARCHAR,
    STATE_CODE  VARCHAR,
    COUNTRY_CODE VARCHAR,
    COUNTRY_NAME VARCHAR,
    LATITUDE FLOAT,
    LONGITUDE FLOAT
);

INSERT INTO DS_VENUE
SELECT
    v:id::STRING,
    v:name::STRING,
    v:city:name::STRING,
    v:city:state::STRING,
    v:city:stateCode::STRING,
    v:city:country:code::STRING,
    v:city:country:name::STRING,
    v:city:coords:lat::FLOAT,
    v:city:coords:long::FLOAT
FROM (SELECT TRY_PARSE_JSON(TO_VARCHAR(VENUE_JSON)) AS v FROM DS_SETLIST_DATA_RAW)
WHERE v:id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY v:id::STRING ORDER BY v:name::STRING) = 1;


/*
---
    -- DS_ALBUM table
---
*/

CREATE OR REPLACE TABLE DS_ALBUM (
    ALBUM_ID                VARCHAR PRIMARY KEY,  --MusicBrainz release_group_id
    ARTIST_MBID             VARCHAR REFERENCES DS_ARTIST(ARTIST_MBID),
    ALBUM_TITLE             VARCHAR,
    RELEASE_DATE            DATE,
    ALBUM_CATEGORY          VARCHAR,
    STUDIO_ALBUM_NUMBER     NUMBER, 
    IS_LATEST_STUDIO_ALBUM  BOOLEAN
);

INSERT INTO DS_ALBUM
WITH core AS (
    SELECT column1 AS album_id, column2 AS album_category
    FROM VALUES
        --Bruno Mars albums
        ('b3d1fbf7-dd1c-4119-a16e-58c2feb5bcb0','Studio'),   -- Doo-Wops & Hooligans
        ('978d88db-60ec-41d9-ade7-beea020941b0','Studio'),   -- Unorthodox Jukebox
        ('80ea43b7-2c32-4a79-9fb0-8ff1761ebe09','Studio'),   -- 24K Magic
        ('a868464a-2e60-484b-bacd-aaeaee71284e','Studio'),   -- The Romantic
        --Mac DeMarco albums
        ('3ba00670-7a00-46d9-b9f4-80625438c058','Studio'),  -- 2
        ('99c195d6-0247-48d0-83ab-640ecca7a74f','Studio'),  -- Salad Days
        ('a3ff689c-aa04-4771-adcb-1e32a3c8197c','Studio'),  -- Another One
        ('f48b5c40-6343-4d94-b306-3591d294caeb','Studio'),  -- This Old Dog
        ('e3319d41-37c3-442c-bfe9-e8d55537a7ad','Studio'),  -- Here Comes the Cowboy
        ('ea5be93c-ed2d-4c8a-8bcc-250b2909fb44','Studio'),  -- Guitar
        --Kendrick Lamar albums
        ('ceccd668-a928-4041-a3c3-99a5ce880de9','Studio'), -- Section.80
        ('499c19c8-0dab-4824-884b-6191d145e95b','Studio'),   -- good kid, m.A.A.d city
        ('d9103c72-3807-4378-9ce7-b6f3e8fdd547','Studio'),  -- To Pimp a Butterfly
        ('4e44335c-3f2b-4874-a6c3-71b5e65f75d5','Compilation'), -- untitled unmastered.
        ('b88655ba-7469-48b8-a296-b9011ab73ef3','Studio'),     -- DAMN.
        ('4e317e28-e6b2-46d7-81f7-306e349b3dd4','Soundtrack'),-- Black Panther: The Album
        ('6bd70eee-bd46-4738-851a-f50c19d8d6db','Studio'),    -- Mr. Morale & the Big Steppers
        ('32cb822c-a14e-49ce-a169-f209c5f31e0f','Studio'),    -- GNX
        --Sabrina Carpenter albums
        ('098b431c-7e67-42ff-841a-ca79cac99a09','Studio'),  -- Eyes Wide Open
        ('d3b429d5-e066-4e4a-8729-49c60a041425','Studio'),  -- EVOLution
        ('f2f2f9fe-f3ee-479b-99c3-f63f3b8230d2','Studio'),  -- Singular: Act I
        ('5fbab65e-737a-4883-8162-850eae076393','Studio'),  -- Singular: Act II
        ('6bbcb652-6188-4a5c-9125-b745d16e1f27','Studio'),  -- emails i can't send
        ('c8bea388-c195-4177-bf9b-7469f6e695a1','Studio'),  -- Short n' Sweet
        ('192a95dc-d993-4768-9f77-4496b6460400','Studio'),  -- Man's Best Friend
        --Daniel Caesar albums
        ('ba660007-8e88-4301-ba89-5574d06d29cc','Studio'), --Freudian
        ('1741c2a5-7014-4fb7-97b4-fcb673809259','Studio'), --Case Study 01
        ('65f5ca68-6dcd-4cc9-8f3c-09d9aaa56bfb','Studio'), --NEVER ENOUGH
        ('6ac79a31-8873-4fe5-83ae-7407e6a97cb2','Studio')  --Son of Spergy
),
albums AS (
    SELECT
        g.RELEASE_GROUP_ID AS album_id,
        g.ARTIST_MBID,
        g.ALBUM_TITLE,
        CASE LENGTH(TO_VARCHAR(g.FIRST_RELEASE_DATE)) -- MusicBrainz dates can be YYYY or YYYY-MM, need to parse that!
            WHEN 4 THEN TRY_TO_DATE(TO_VARCHAR(g.FIRST_RELEASE_DATE) || '-01-01')
            WHEN 7 THEN TRY_TO_DATE(TO_VARCHAR(g.FIRST_RELEASE_DATE) || '-01')
            ELSE TRY_TO_DATE(TO_VARCHAR(g.FIRST_RELEASE_DATE))
        END AS release_date,
        c.album_category
    FROM DS_RELEASE_GROUPS_RAW g
    JOIN core c ON c.album_id = g.RELEASE_GROUP_ID
)
SELECT
    album_id,
    ARTIST_MBID,
    ALBUM_TITLE,
    release_date,
    album_category,
    CASE WHEN album_category = 'Studio'
         THEN ROW_NUMBER() OVER (PARTITION BY ARTIST_MBID, album_category = 'Studio' ORDER BY release_date)
    END,
    album_category = 'Studio'
      AND release_date = MAX(CASE WHEN album_category = 'Studio' AND release_date <= CURRENT_DATE()
                                  THEN release_date END) OVER (PARTITION BY ARTIST_MBID)
FROM albums;

/*
---
    -- DS_SONG table
---
*/
CREATE OR REPLACE TABLE DS_SONG (
    SONG_ID         VARCHAR PRIMARY KEY,  --artist_mbid|song_key
    ARTIST_MBID     VARCHAR REFERENCES DS_ARTIST(ARTIST_MBID),
    SONG_KEY        VARCHAR,  --normalized title used for matching
    SONG_TITLE      VARCHAR,
    ALBUM_ID        VARCHAR REFERENCES DS_ALBUM(ALBUM_ID),    -- null = not on a core album
    SONG_SOURCE     VARCHAR,   --Album / Cover / Non-album
    IS_BONUS_TRACK  BOOLEAN       -- deluxe-only track
);

INSERT INTO DS_SONG
WITH album_tracks AS (
    SELECT
        t.ARTIST_MBID,
        a.ALBUM_ID,
        a.RELEASE_DATE,
        t.RELEASE_ID,
        t.TRACK_TITLE,
        TRIM(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(
            REPLACE(LOWER(t.TRACK_TITLE), '&', ' and '),
            '\\s*[\\(\\[][^\\)\\]]*[\\)\\]]', ''), '[^a-z0-9 ]', ''), '\\s+', ' ')) AS song_key
    FROM DS_TRACKS_RAW t
    JOIN DS_ALBUM a ON a.ALBUM_ID = t.RELEASE_GROUP_ID
),
editions AS (
    SELECT ALBUM_ID, COUNT(DISTINCT RELEASE_ID) AS n_editions
    FROM album_tracks
    GROUP BY ALBUM_ID
),
song_album AS (
    SELECT
        tr.ARTIST_MBID,
        tr.song_key,
        tr.ALBUM_ID,
        MIN(tr.RELEASE_DATE) AS release_date,
        MIN(tr.TRACK_TITLE)  AS song_title,
        COUNT(DISTINCT tr.RELEASE_ID) / MAX(e.n_editions) < 0.5 AS is_bonus_track
    FROM album_tracks tr
    JOIN editions e ON e.ALBUM_ID = tr.ALBUM_ID
    WHERE tr.song_key <> ''
    GROUP BY tr.ARTIST_MBID, tr.song_key, tr.ALBUM_ID
),
home_album AS (
    SELECT * FROM song_album
    QUALIFY ROW_NUMBER() OVER (PARTITION BY ARTIST_MBID, song_key ORDER BY release_date, ALBUM_ID) = 1
),
setlist_songs AS (
    SELECT
        r.ARTIST_MBID,
        sg.value:name::STRING     AS song_title,
        sg.value:cover IS NOT NULL AS is_cover,
        TRIM(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(
            REPLACE(LOWER(sg.value:name::STRING), '&', ' and '),
            '\\s*[\\(\\[][^\\)\\]]*[\\)\\]]', ''), '[^a-z0-9 ]', ''), '\\s+', ' ')) AS song_key
    FROM DS_SETLIST_DATA_RAW r,
         LATERAL FLATTEN(input => TRY_PARSE_JSON(TO_VARCHAR(r.SETS_JSON)):set) st,
         LATERAL FLATTEN(input => st.value:song) sg
    WHERE NOT COALESCE(sg.value:tape::BOOLEAN, FALSE)
)
SELECT ARTIST_MBID || '|' || song_key, ARTIST_MBID, song_key, song_title, ALBUM_ID, 'Album', is_bonus_track
FROM home_album

UNION ALL

SELECT
    s.ARTIST_MBID || '|' || s.song_key,
    s.ARTIST_MBID,
    s.song_key,
    MIN(s.song_title),
    NULL,
    IFF(BOOLOR_AGG(s.is_cover), 'Cover', 'Non-album'),
    FALSE
FROM setlist_songs s
LEFT JOIN home_album h
       ON h.ARTIST_MBID = s.ARTIST_MBID AND h.song_key = s.song_key
WHERE h.song_key IS NULL
  AND s.song_key <> ''
GROUP BY s.ARTIST_MBID, s.song_key;

/*
---
    -- DS_SHOW table
---
*/
CREATE OR REPLACE TABLE DS_SHOW (
    SETLIST_ID         VARCHAR PRIMARY KEY,
    ARTIST_MBID        VARCHAR REFERENCES DS_ARTIST(ARTIST_MBID),
    VENUE_ID           VARCHAR REFERENCES DS_VENUE(VENUE_ID),
    EVENT_DATE         DATE,
    TOUR_NAME          VARCHAR,
    CYCLE_ALBUM_ID     VARCHAR REFERENCES DS_ALBUM(ALBUM_ID),
    SONGS_PLAYED       NUMBER,
    CYCLE_ALBUM_SONGS  NUMBER,
    CYCLE_ALBUM_SHARE  FLOAT,
    IS_STUB            BOOLEAN,                           
    SETLIST_URL        VARCHAR
);

INSERT INTO DS_SHOW
WITH shows AS (
    SELECT
        SETLIST_ID,
        ARTIST_MBID,
        TRY_PARSE_JSON(TO_VARCHAR(VENUE_JSON)):id::STRING                     AS venue_id, --try to parse json out here
        TRY_TO_DATE(TO_VARCHAR(EVENT_DATE), 'DD-MM-YYYY')                     AS event_date,
        NULLIF(TRIM(TRY_PARSE_JSON(TO_VARCHAR(TOUR_JSON)):name::STRING), '')  AS tour_name,
        TRY_PARSE_JSON(TO_VARCHAR(SETS_JSON))                                 AS sets,
        SETLIST_URL
    FROM DS_SETLIST_DATA_RAW
    QUALIFY ROW_NUMBER() OVER (PARTITION BY SETLIST_ID ORDER BY LAST_UPDATED DESC) = 1
),
cycle AS ( --cycle meaning an album cycle, when that album releases to when they stop touring
    SELECT s.SETLIST_ID, a.ALBUM_ID AS cycle_album_id
    FROM shows s
    JOIN DS_ALBUM a
      ON a.ARTIST_MBID = s.ARTIST_MBID
     AND a.ALBUM_CATEGORY = 'Studio'
     AND a.RELEASE_DATE <= s.event_date
    QUALIFY ROW_NUMBER() OVER (PARTITION BY s.SETLIST_ID ORDER BY a.RELEASE_DATE DESC) = 1
),
song_rows AS (
    SELECT s.SETLIST_ID, s.ARTIST_MBID, sg.value:name::STRING AS song_title
    FROM shows s,
         LATERAL FLATTEN(input => s.sets:set) st,
         LATERAL FLATTEN(input => st.value:song) sg
    WHERE NOT COALESCE(sg.value:tape::BOOLEAN, FALSE)
      AND COALESCE(TRIM(sg.value:name::STRING), '') <> ''
),
show_counts AS (
    SELECT
        r.SETLIST_ID,
        COUNT(*)                                  AS songs_played,
        COUNT_IF(d.ALBUM_ID = c.cycle_album_id)   AS cycle_album_songs
    FROM song_rows r
    LEFT JOIN DS_SONG d
           ON d.SONG_ID = r.ARTIST_MBID || '|' ||
              TRIM(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(
                  REPLACE(LOWER(r.song_title), '&', ' and '),
                  '\\s*[\\(\\[][^\\)\\]]*[\\)\\]]', ''), '[^a-z0-9 ]', ''), '\\s+', ' '))
    LEFT JOIN cycle c ON c.SETLIST_ID = r.SETLIST_ID
    GROUP BY r.SETLIST_ID
)
SELECT
    s.SETLIST_ID,
    s.ARTIST_MBID,
    s.venue_id,
    s.event_date,
    s.tour_name,
    c.cycle_album_id,
    COALESCE(sc.songs_played, 0),
    COALESCE(sc.cycle_album_songs, 0),
    sc.cycle_album_songs / NULLIF(sc.songs_played, 0),
    COALESCE(sc.songs_played, 0) = 0,
    s.SETLIST_URL
FROM shows s
LEFT JOIN cycle       c  ON c.SETLIST_ID  = s.SETLIST_ID
LEFT JOIN show_counts sc ON sc.SETLIST_ID = s.SETLIST_ID
WHERE s.event_date <= CURRENT_DATE();          -- drop future shows

/*
---
    -- DS_SONG_PERFORMANCE table
---
*/
CREATE OR REPLACE TABLE DS_SONG_PERFORMANCE (
    SETLIST_ID           VARCHAR REFERENCES DS_SHOW(SETLIST_ID),
    POSITION_IN_SHOW     NUMBER,
    ARTIST_MBID          VARCHAR REFERENCES DS_ARTIST(ARTIST_MBID),
    SONG_ID              VARCHAR REFERENCES DS_SONG(SONG_ID),
    ALBUM_ID             VARCHAR REFERENCES DS_ALBUM(ALBUM_ID),
    EVENT_DATE           DATE,
    SONG_TITLE           VARCHAR,                              -- as logged on setlist.fm
    SET_NUMBER           NUMBER,
    IS_ENCORE            BOOLEAN,
    IS_COVER             BOOLEAN,
    GUEST_ARTIST         VARCHAR,
    SONG_INFO            VARCHAR,
    IS_CYCLE_ALBUM_SONG  BOOLEAN,
    PRIMARY KEY (SETLIST_ID, POSITION_IN_SHOW)
);

INSERT INTO DS_SONG_PERFORMANCE
WITH song_rows AS (
    SELECT
        r.SETLIST_ID,
        r.ARTIST_MBID,
        st.index                                   AS set_index,
        sg.index                                   AS song_index,
        COALESCE(st.value:encore::INT, 0) > 0      AS is_encore,
        sg.value:name::STRING                      AS song_title,
        COALESCE(sg.value:tape::BOOLEAN, FALSE)    AS is_tape,
        sg.value:cover IS NOT NULL                 AS is_cover,
        sg.value:with:name::STRING                 AS guest_artist,
        NULLIF(sg.value:info::STRING, '')          AS song_info
    FROM DS_SETLIST_DATA_RAW r,
         LATERAL FLATTEN(input => TRY_PARSE_JSON(TO_VARCHAR(r.SETS_JSON)):set) st,
         LATERAL FLATTEN(input => st.value:song) sg
)
SELECT
    sr.SETLIST_ID,
    ROW_NUMBER() OVER (PARTITION BY sr.SETLIST_ID ORDER BY sr.set_index, sr.song_index),
    sr.ARTIST_MBID,
    d.SONG_ID,
    d.ALBUM_ID,
    fs.EVENT_DATE,
    sr.song_title,
    sr.set_index + 1,
    sr.is_encore,
    sr.is_cover,
    sr.guest_artist,
    sr.song_info,
    COALESCE(d.ALBUM_ID = fs.CYCLE_ALBUM_ID, FALSE)
FROM song_rows sr
JOIN DS_SHOW fs ON fs.SETLIST_ID = sr.SETLIST_ID -- past shows only
LEFT JOIN DS_SONG d
       ON d.SONG_ID = sr.ARTIST_MBID || '|' ||
          TRIM(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(
              REPLACE(LOWER(sr.song_title), '&', ' and '),
              '\\s*[\\(\\[][^\\)\\]]*[\\)\\]]', ''), '[^a-z0-9 ]', ''), '\\s+', ' '))
WHERE NOT sr.is_tape
  AND COALESCE(TRIM(sr.song_title), '') <> '';


/*
----Tests to check data!
*/
SELECT COUNT(*) FROM DS_ALBUM;                                         -- 29
SELECT COUNT(*), COUNT_IF(IS_STUB), COUNT_IF(EVENT_DATE IS NULL)        -- bad dates should be 0
FROM DS_SHOW;

-- Song match rate by artist
SELECT a.ARTIST_NAME,
       COUNT(*)                                  AS songs_played,
       ROUND(COUNT_IF(f.ALBUM_ID IS NOT NULL) / COUNT(*), 3) AS album_match_rate
FROM DS_SONG_PERFORMANCE f
JOIN DS_ARTIST a ON a.ARTIST_MBID = f.ARTIST_MBID
GROUP BY 1;

select distinct song_key
from ds_song;


//checking out tables
select *
from ds_show;







