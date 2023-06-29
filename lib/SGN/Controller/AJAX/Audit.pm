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
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );

    
sub retrieve_results : Path('/ajax/audit/retrieve_results'){
    my $self = shift;
    my $c = shift;
    my $drop_menu_option = $c->req->param('db_table_list_id');
    my $q = "select * from audit.".$drop_menu_option.";";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute();
    my @all_audits;
    my $counter = 0;

    while (my ($audit_ts, $operation, $username, $logged_in_user, $before, $after) = $h->fetchrow_array) {
        $all_audits[$counter] = [$audit_ts, $operation, $username, $logged_in_user, $before, $after];
        $counter++;
        };


    my $json_string = new JSON;
    $json_string = encode_json(\@all_audits);
    $c->stash->{rest} = {
        result => $json_string,
        };
};

sub retrieve_table_names : Path('/ajax/audit/retrieve_table_names'){
    my $self = shift;
    my $c = shift;
    my $q = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'audit'";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute();
    my @ids;
    while (my ($drop_options) = $h->fetchrow_array) {
        push @ids, $drop_options;

    };
    my $json_string = new JSON;
    $json_string = encode_json(\@ids);
    $c->stash->{rest} = {
        result1 => $json_string,
        };

}