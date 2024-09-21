/*
Develop code to create the versions analysis

PREMISE OF CODE
normalise all album names by stripping out stuff in brackets and saving to trimalb field in brackets_removed table.
whilst at it, populate each record with audio attributes, track count, dynamic range related to the folder contents
dynamic range is imported from DR14.txt files in each folder leveraging ~/dr14.sh and ~/getdr14.sh to pull them and write records to a CSV
*/

/* import drscores created by getdr14.sh */
CREATE TABLE drscores (
    __dirpath BLOB,
    dr_text   TEXT
);

/* before running next line, import the dr scores csv file */
ALTER TABLE drscores ADD album_dr INT;

UPDATE drscores
   SET album_dr = CAST (substr(dr_text, 3) AS INT);


/* populate table with all albums that have contents in ([ in album title, stripping the stuff including brackets */
DROP TABLE IF EXISTS brackets_removed;
/* deal with albumartists first */
/*CREATE TABLE brackets_removed AS SELECT DISTINCT __dirpath,
                                                 NULL AS confirmkill,
                                                 NULL AS killit,
                                                 0 AS track_count,
                                                 __bitspersample AS __bitspersample,
                                                 __frequency_num AS __frequency_num,
                                                 __channels AS __channels,
                                                 NULL AS album_dr,
                                                 lower(trim(CASE WHEN instr(albumartist || ' - ' || album, '(') > 0 THEN substr(albumartist || ' - ' || album, 0, instr(albumartist || ' - ' || album, '(') ) WHEN instr(albumartist || ' - ' || album, '[') > 0 THEN substr(albumartist || ' - ' || album, 0, instr(albumartist || ' - ' || album, '[') ) ELSE albumartist || ' - ' || album END) ) AS trimalb
                                   FROM alib
                                  WHERE __dirname NOT LIKE 'cd%'
                                  ORDER BY trimalb; */
CREATE TABLE brackets_removed AS SELECT DISTINCT lower(trim(CASE WHEN instr(albumartist || ' - ' || album, '(') > 0 THEN substr(albumartist || ' - ' || album, 0, instr(albumartist || ' - ' || album, '(') ) WHEN instr(albumartist || ' - ' || album, '[') > 0 THEN substr(albumartist || ' - ' || album, 0, instr(albumartist || ' - ' || album, '[') ) ELSE albumartist || ' - ' || album END) ) AS trimalb,
                                                 NULL AS confirmkill,
                                                 NULL AS killit,
                                                 CAST(0 AS INTEGER) AS track_count,
                                                 CAST(__bitspersample AS INTEGER) AS __bitspersample,
                                                 CAST(__frequency_num AS DECIMAL) AS __frequency_num,
                                                 CAST(__channels AS INTEGER) AS __channels,
                                                 CAST(0 AS INTEGER) AS album_dr,
                                                 __dirpath
                                   FROM alib
                                  WHERE __dirname NOT LIKE 'cd%'
                                  ORDER BY trimalb;


/* now get all versions */

DROP TABLE IF EXISTS versions;

CREATE TABLE versions AS SELECT *
                           FROM brackets_removed
                          WHERE trimalb IN (
                                    SELECT DISTINCT trimalb
                                      FROM (
                                               SELECT *
                                                 FROM brackets_removed
                                                WHERE trimalb IN (
                                                          SELECT trimalb
                                                            FROM brackets_removed
                                                           GROUP BY trimalb
                                                          HAVING count( * ) > 1
                                                      )
                                           )
                                )
                          ORDER BY trimalb,
                                   __channels,
                                   track_count,
                                   __bitspersample,
                                   __frequency_num,
                                   album_dr,
                                   __dirpath;



/* remove all duplicate __dirpath entries that arise due to mixed res albums (hence __dirpath making as many appearances as resolution variances) - these will need to be investigated manually via a 2nd round */

DELETE FROM versions
      WHERE __dirpath IN (
    SELECT __dirpath
      FROM versions
     GROUP BY __dirpath
    HAVING count( * ) > 1
);

/* remove all DSD albums on premise we'd like to preserve that and a WAV source */
DELETE FROM versions
      WHERE __bitspersample = 1;

/* Remove all albums that no longer appear > 1x */
DELETE FROM versions
      WHERE trimalb IN (
    SELECT trimalb
      FROM versions
     GROUP BY trimalb
    HAVING count( * ) = 1
);



/* get track counts for each __dirpath and update same into  versions */
DROP table IF EXISTS track_counts;

CREATE table track_counts AS SELECT __dirpath,
                                    COUNT( * ) AS track_count
                               FROM alib
                              WHERE __dirpath IN (
                                        SELECT __dirpath
                                          FROM versions
                                    )
                              GROUP BY __dirpath
                              ORDER BY __dirpath;


UPDATE versions
   SET track_count = track_counts.track_count
  FROM track_counts
 WHERE versions.__dirpath = track_counts.__dirpath;
 
/* load album DR into versions table */
UPDATE versions
   SET album_dr = drscores.album_dr
  FROM drscores
 WHERE versions.__dirpath = drscores.__dirpath;


/* fist process albums with identical track count
UPDATE versions
   SET killit = TRUE
 WHERE __dirpath IN (
    SELECT kill.__dirpath
      FROM (
               versions AS keep
               JOIN
               versions AS kill USING (
                   trimalb,
                   __channels
               )
           )
     WHERE kill.__dirpath <> keep.__dirpath AND 
           kill.track_count = keep.track_count AND 
           kill.__bitspersample <= keep.__bitspersample AND 
           kill.__frequency_num <= keep.__frequency_num AND 
           kill.album_dr <= keep.album_dr 
);  */



/* modified to meet my needs by taking into account track_count differences */
UPDATE versions
   SET killit = TRUE
 WHERE __dirpath IN (
    SELECT kill.__dirpath
      FROM (
               versions AS keep
               JOIN
               versions AS kill USING (
                   trimalb,
                   __channels
               )
           )
     WHERE kill.__dirpath <> keep.__dirpath AND 
           kill.track_count  <= keep.track_count AND 
           kill.__bitspersample  <= keep.__bitspersample AND 
           kill.__frequency_num  <= keep.__frequency_num AND 
           kill.album_dr <= keep.album_dr
);

/* now flag albums with identical everything for manual investigation */

UPDATE versions
   SET killit = 'Investigate'
 WHERE __dirpath IN (
    SELECT kill.__dirpath
      FROM (
               versions AS keep
               JOIN
               versions AS kill USING (
                   trimalb,
                   track_count,
                   __bitspersample,
                   __frequency_num,
                   __channels,
                   album_dr
               )
           )
     WHERE kill.__dirpath <> keep.__dirpath AND 
           kill.track_count  = keep.track_count  AND 
           kill.__bitspersample  = keep.__bitspersample AND 
           kill.__frequency_num  = keep.__frequency_num AND 
           kill.album_dr  = keep.album_dr 
);

/* and finally, ensure all audiofhile pressings are preserved */


UPDATE versions
   SET confirmkill = 'Audiophile Release'
 WHERE (__dirpath LIKE "%afz%" OR 
        __dirpath LIKE "%audio fidelity%" OR 
        __dirpath LIKE "%compact classics%" OR 
        __dirpath LIKE "%dcc%" OR 
        __dirpath LIKE "%fim%" OR 
        __dirpath LIKE "%gzs%" OR 
        __dirpath LIKE "%mfsl%" OR 
        __dirpath LIKE "%mobile fidelity%" OR 
        __dirpath LIKE "%mofi%" OR 
        __dirpath LIKE "%mastersound%" OR 
        __dirpath LIKE "%sbm%" OR 
        __dirpath LIKE "%xrcd%");


UPDATE versions
   SET confirmkill = '1'
 WHERE __dirpath LIKE "%vinyl%";




SELECT confirmkill,
       killit,
       __dirpath
  FROM versions
 WHERE (__dirpath LIKE "%afz%" OR 
        __dirpath LIKE "%audio fidelity%" OR 
        __dirpath LIKE "%compact classics%" OR 
        __dirpath LIKE "%dcc%" OR 
        __dirpath LIKE "%fim%" OR 
        __dirpath LIKE "%gzs%" OR 
        __dirpath LIKE "%mfsl%" OR 
        __dirpath LIKE "%mobile fidelity%" OR 
        __dirpath LIKE "%mofi%" OR 
        __dirpath LIKE "%mastersound%" OR 
        __dirpath LIKE "%sbm%" OR 
        __dirpath LIKE "%xrcd%") 
 ORDER BY __dirpath;








/* ------------------------------------------------------------------------------- */
SELECT *
  FROM versions
 WHERE killit IS NOT NULL
 ORDER BY trimalb, __dirpath;
 

UPDATE versions
   SET killit = NULL;
   
SELECT count( * ) 
  FROM versions
 WHERE killit = 1
 ORDER BY trimalb,
          __channels,
          track_count,
          __bitspersample,
          __frequency_num,
          album_dr,
          __dirpath;



SELECT *
  FROM versions
 WHERE trimalb < 'e'
 ORDER BY trimalb,
          __channels,
          track_count,
          __bitspersample,
          __frequency_num,
          album_dr,
          __dirpath;
