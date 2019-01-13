# dedupe-flac
Bash and SQLite scripts to compare FLAC contents across different folders to find folders with identical FLAC content

All FLAC specification FLAC files have an embedded md5sum of the audio stream embedded in the metadata.  As this md5sum pertains only to the audio contents of the file, differences in metadata, compression ratios and file sizes to not hamper one's ability to definitively identify folders who's FLAC file contents is identical.

This is achieved by building a concatenated string comprising the md5sum of each of the FLAC files withing a directory.  To ensure the concatenated string is identical when comparing different folders the concatenation is done utilising the sorted md5sum strings within the folder, making filenames etc. irrelevant to the comparison.

bash scripts and the FLAC toolset are used to create a listing of all FLAC content and the folders they reside in.  This is then imported into a SQLite table and prococessed utilising SQLite scripts which generate a table showing the duplicated folders as well as a table listing folders whose FLAC content can be deleted, leaving behind only one folder containing that unique combination of FLAC files.

-- first import the text file produced from listing files, their path and FLAC md5sum using bash terminal:

find -type f -name \*.flac -print0 | xargs -0 -n1 metaflac --with-filename --show-md5sum >> md5sums.txt

-- add the necessary delimiters to be able to import the file into a sqlite table:
echo __path:__md5sig:__filename:__dirpath > import.csv
sed ':a;N;$!ba;s/\n/::\n/g' md5sums.txt >> import.csv

-- now import the text file produced from listing files, their path and FLAC md5sum

DROP TABLE IF EXISTS audio;
DROP TABLE IF EXISTS __dirpath_content_concat__md5sig;
DROP TABLE IF EXISTS __dirpaths_with_same_content;
DROP TABLE IF EXISTS __dirpaths_with_FLACs_to_kill;
CREATE TABLE audio (
    __path                     TEXT UNIQUE,
    __md5sig                   TEXT,
    __filename                 TEXT,
    __dirpath                  TEXT
);



-- start SQL processing
--
--

--
-- derive filename from the full file path

UPDATE audio
   SET __filename = [replace](__path, rtrim(__path, [replace](__path, "/", "") ), "");


--
-- derive __dirpath from the full file path

UPDATE audio
   SET __dirpath = substr(__path, 1, length(__path) - length([replace](__path, rtrim(__path, [replace](__path, "/", "") ), "") ) );


--
-- create table in which to store concatenated __md5sig for all __dirnames

DROP TABLE IF EXISTS __dirpath_content_concat__md5sig;

CREATE TABLE __dirpath_content_concat__md5sig (
    __dirpath      TEXT,
    concat__md5sig TEXT
);



--
-- populate table with __dirpath and concatenated __md5sig of all files associated with __dirpath (note order by __md5sig to ensure concatenated __md5sig is consistently generated irrespective of physical record sequence).

INSERT INTO __dirpath_content_concat__md5sig (
                                                 __dirpath,
                                                 concat__md5sig
                                             )
                                             SELECT __dirpath,
                                                    group_concat(__md5sig, "|") 
                                               FROM (
                                                        SELECT __dirpath,
                                                               __md5sig
                                                          FROM audio
                                                         ORDER BY __dirpath,
                                                                  __md5sig
                                                    )
                                              GROUP BY __dirpath;


--
-- create table in which to store all __dirnames with identical FLAC contents (i.e. the __md5sig of each FLAC in folder is concatenated and compared)

DROP TABLE IF EXISTS __dirpaths_with_same_content;
CREATE TABLE __dirpaths_with_same_content (
    __dirpath      TEXT,
    concat__md5sig TEXT
);


--
--now write the duplicate records into a separate table listing all __dirname's that have identical FLAC contents

INSERT INTO __dirpaths_with_same_content (
                                             __dirpath,
                                             concat__md5sig
                                         )
                                         SELECT __dirpath,
                                                concat__md5sig
                                           FROM __dirpath_content_concat__md5sig
                                          WHERE concat__md5sig IN (
                                                    SELECT concat__md5sig
                                                      FROM __dirpath_content_concat__md5sig
                                                     GROUP BY concat__md5sig
                                                    HAVING count( * ) > 1
                                                )
                                          ORDER BY concat__md5sig,
                                                   __dirpath;






--
-- create table for listing directories in which FLAC files should be deleted as they're duplicates

DROP TABLE IF EXISTS __dirpaths_with_FLACs_to_kill;

CREATE TABLE __dirpaths_with_FLACs_to_kill (
    __dirpath      TEXT,
    concat__md5sig TEXT
);

--
-- populate table listing directories in which FLAC files should be deleted as they're duplicates

INSERT INTO __dirpaths_with_FLACs_to_kill (
                                              __dirpath,
                                              concat__md5sig
                                          )
                                          SELECT __dirpath,
                                                 concat__md5sig
                                            FROM __dirpaths_with_same_content
                                           WHERE rowid NOT IN (
                                                     SELECT min(rowid) 
                                                       FROM __dirpaths_with_same_content
                                                      GROUP BY concat__md5sig
                                                 );
