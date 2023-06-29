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

    
#my $schema = $c->dbic_schema("Bio::Chado::Schema");
    #my $audit_result_table = $c->req->param('audit_result_table');
    #my $q = "SELECT ".$drop_menu_option." FROM audit.stock_audit";
sub retrieve_results : Path('/ajax/audit/retrieve_results'){
    my $self = shift;
    my $c = shift;
    my $drop_menu_option = $c->req->param('db_table_list_id');
    my $q = "select * from audit.".$drop_menu_option.";";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute();
    my @audit_ts;
    my @operation;
    my @logged_in_user;
    my @before;
    my @after;
    my @audits = [@audit_ts, @operation, @logged_in_user, @before, @after];
    while (my ($audit_ts, $operation, $logged_in_user, $before, $after) = $h->fetchrow_array) {
        push @audit_ts, $audit_ts;
        push @operation, $operation;
        push @logged_in_user, $logged_in_user;
        push @before, $before;
        push @after, $after;
        
        push @audits, ($audit_ts, $operation, $logged_in_user, $before, $after);
    };
    my $json_string = new JSON;
    my $jsonts = new JSON;
    my $jsonop = new JSON;
    my $jsonuser = new JSON;
    my $jsonbef = new JSON;
    my $jsonaft = new JSON;
    
    $json_string = encode_json(\@audits);
    $jsonts = encode_json(\@audit_ts);
    $jsonop = encode_json(\@operation);
    $jsonuser = encode_json(\@logged_in_user);
    $jsonbef = encode_json(\@before);
    $jsonaft = encode_json(\@after);

    $c->stash->{rest} = {
        result3 => $json_string,
        json_audit_ts => $jsonts,
        json_operation => $jsonop,
        json_logged_in_user => $jsonuser,
        json_before => $jsonbef,
        json_after => $jsonaft,

        audit_ts => @audit_ts,
        operation => @operation,
        logged_in_user => @logged_in_user,
        before => @before,
        after => @after,
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