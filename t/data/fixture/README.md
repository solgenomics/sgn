# Say Hello to the Fixture's New Home!
In order to keep testing data up to date with written tests, the fixture sql dump has been merged into the sgn repo! This means no more git-pulling your local fixture repo before running tests. Instead, fixture changes will be controlled by adding patches to `sgn/t/data/fixture/patches/`.
# Instructions for Modifying the Fixture

## _**IMPORTANT: do not replace or modify the fixture sql dump!**_

Fixture-specific patches are used to modify data stored in the fixture. These are different from db patches (in the sgn/db/ dir), which change the database structure. **A fixture-specific patch should never change the databse structure (e.g. adding tables or adding a column).**

Fixture patches should also never be run on production databases, ONLY on fixtures.

Fixture patches should be written based on the same template as db patches, as available from `sgn/db/template/`.

In order to play nicely with db patches, fixture patches should abide by the following directory structure:
`sgn/t/data/fixture/patches/$LAST_DB_PATCH/$DDDDD/$PATCHNAME.pm` where
- `$LAST_DB_PATCH` is the name of the most recent db patch folder in `sgn/db/`, and 
- `$DDDDD` is a sequential five-digit ID for your patch folder. 

For example if the last dbpatch folder is `sgn/db/00085/` then your patch would be located at `sgn/t/data/fixture/patches/00085/00001/$PATCHNAME.pm`. It is important this is correct as `sgn/t/test_fixture.pl` and `sgn/t/data/fixture/patches/run_fixture_and_db_patches.pl` rely on this structure to determine in what order the db and fixture patches need to be applied.
<!-- ********************************************* -->
<!-- ********************************************* -->
## _**Reminder: do not replace or modify the fixture sql dump!**_ 
<!-- ********************************************* -->
<!-- ********************************************* -->
**Doing so will create _serious merging issues._** Instead, all your changes to the fixture should occur as patches! Keep in mind that structural changes (additions of columns, etc.) to the fixture should always occur in parallel with the production databases. In order to facillitate this, the test script will automatically run the patches from `sgn/db`, so there is no need to add your patch to `t/data/fixture/patches` if it is already present there! Only fixture-specific patches should reside in `t/data/fixture/patches`. **Fixture-specific patches should only add and remove entries from tables, not modify the tables themselves.** 

### Update the SQL Dump Periodically but Never in Parallel
In order to keep the number of patches low, it _is_ actually benificial to update the dump of the fixture occasionally. This is will work fine as long as no changes are made to it in parallel. Simply load up the fixture, run all the patches it is behind on, then completely replace the old dump with the new. Resist modifying the fixture in any way besides running patches, changes made directly will not have a paper trail. PRs with changes to the fixture dump should be rejected if they contain any other changes in the repo.
