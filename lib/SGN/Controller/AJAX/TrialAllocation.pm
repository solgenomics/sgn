package SGN::Controller::AJAX::Allocation;

use Moose;

use Data::Dumper;
use File::Slurp;
use File::Spec qw | catfile |;
use File::Path qw(rmtree);
use JSON::Any;
use File::Basename qw | basename |;
use DateTime;
use Bio::Chado::Schema;
use CXGN::Dataset::File;
use CXGN::Phenotypes::File;
use CXGN::MixedModels;
use SGN::Controller::AJAX::Dataset;
use JSON;


BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );
1;