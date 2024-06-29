/*# code snippet to identify various releases of the same album in filesystem, based on db of imported tags populated by tags2db.py
# */


/* populate table of __dirpaths (where __dirpath represents and album releas) selecting any having [ or ( in album name and concatenating albumartist with the stripped album title */
DROP TABLE IF EXISTS brackets_removed;

CREATE TABLE brackets_removed AS 
SELECT DISTINCT 
    __dirpath,
    lower(trim(
        CASE
            WHEN instr(albumartist || ' - ' || album, '(') > 0 THEN 
                substr(albumartist || ' - ' || album, 0, instr(albumartist || ' - ' || album, '('))
            WHEN instr(albumartist || ' - ' || album, '[') > 0 THEN 
                substr(albumartist || ' - ' || album, 0, instr(albumartist || ' - ' || album, '['))
            ELSE 
                albumartist || ' - ' || album
        END
    )) AS trimalb
FROM alib
WHERE __dirname NOT LIKE 'cd%'
ORDER BY trimalb;

/* get list of all releases where the trimalb entry appears more than 1x */
SELECT *
  FROM brackets_removed
 WHERE trimalb IN (
           SELECT trimalb
             FROM brackets_removed
            GROUP BY trimalb
           HAVING count( * ) > 1
       )
 ORDER BY trimalb,
          __dirpath;

/* get just the distinct albums list, ommitting the various releases */
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
            ORDER BY trimalb,
                     __dirpath
       );
