
# Breedbase DB_patches

This directory contains dbpatches. Look in the template/ directory for an example.

Each dbpatch is a Perl module, should have a 5 digit number and reside in a directory of that name.


# Integration of ImageBreed DB_Patches into BreedBase

## Overview

This repository contains the db patches that were used to create the ImageBreed database.

In order to integrate the ImageBreed patches, all the patch entries were analyzed to determined where the fork happened. Patches that were identified to be the same were the duplicated. Preference was given to keep the BreedBase patch identifier when duplicates were found (they were compared with diff).

After this analysis the ImageBreed patches in the range (`00132` - `00165`) were kept for integration into BreedBase. To maintain clarity and separation from the original BreedBase, the ImageBreed patched were renamed with a new `10xxx` prefix. This prefix was used to remap the ImageBreed patches (`00132` to `00165`) to a unique identifier ranging from `10001` to `10033`.
