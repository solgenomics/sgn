use CatalystX::GlobalContext qw( $c );
use strict;
use warnings;

use SGN::Controller::Clone::Genomic;
SGN::Controller::Clone::Genomic->new->clone_annot_download( $c );
