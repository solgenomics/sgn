use strict;
use warnings;

package SGN::Controller::AJAX::Audit;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
use File::Slurp;
use File::Spec qw | catfile|;
use File::Basename qw | basename |;
use File::Copy;
use CXGN::Dataset;
use CXGN::Dataset::File;
use CXGN::Tools::Run;
use Cwd qw(cwd);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );


sub retrieve_results : Path('/ajax/audit/retrieve_results'){
    my $self = shift;
    my $c = shift;
    my $temp_result = "result one from Perl module";
    my $other_result = "other result from Perl ";
    my $drop_menu_option = $c->req->param('db_table_list_id');
    my $combined_result = $temp_result.$drop_menu_option;
    $c->stash->{rest} = {
        result1 => $temp_result,
        result2 => $other_result,
        result3 => $combined_result,
    };
}