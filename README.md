dedupe-flac

An amalgam of bash and SQLite to enable definitive detection of folders containing identical FLAC audio content.  

Basis:
All specification compliant FLAC files have an embedded md5sum of the audio stream embedded in the file's metadata. As this md5sum pertains only to the audio stream contained within the file, differences in metadata, compression ratios and file sizes do not hamper one's ability to definitively identify folders who's FLAC file contents is identical.

The code compares the concatenated sorted md5sum of all FLAC files within a individual folder against the same for all other individual folders containing one or more FLAC files. This method makes filenames, storage location, metadata, file size etc. irrelevant to the comparison.

What it does not do:
- consider albums to be duplicated if they're different releases (because the md5sum of the audio stream will differ)
- check FLAC files for a valid md5sum.  If you have any FLAC files in your library with no md5sum included you need to re-encode them in order for the code to generate valid results and avoid false postitives.  I generally use "find -type f -name \*.flac -print0 | xargs -0 -n1 -P8 flac -f -8 --preserve-modtime --verify --no-padding" when re-encoding files in a directory tree.  Refer FLAC documentation if the meaning of the parameters is not clear.
