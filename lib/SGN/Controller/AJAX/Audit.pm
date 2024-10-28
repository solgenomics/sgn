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

    while (my ($audit_ts, $operation, $username, $logged_in_user, $before, $after, $transactioncode, $primary_key, $is_undo) = $h->fetchrow_array) {
        $all_audits[$counter] = [$audit_ts, $operation, $username, $logged_in_user, $before, $after, $transactioncode, $primary_key, $is_undo];
        $counter++;
        };


    my $json_string;
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
    my $json_string;
    $json_string = encode_json(\@ids);
    $c->stash->{rest} = {
        result1 => $json_string,
        };
};

sub retrieve_stock_audits : Path('/ajax/audit/retrieve_stock_audits'){
    my $self = shift;
    my $c = shift;
    my $stock_uniquename = $c->req->param('stock_uniquename');
    my $q = "SELECT * FROM audit.stock_audit;";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute();
    my @all_audits;
    my @before;
    my @after;
    my $counter = 0;

    while (my ($audit_ts, $operation, $username, $logged_in_user, $before, $after, $transactioncode, $primary_key, $is_undo) = $h->fetchrow_array) {
        $after[$counter] = $after;
        $before[$counter] = $before;
        $all_audits[$counter] = [$audit_ts, $operation, $username, $logged_in_user, $before, $after, $transactioncode, $primary_key, $is_undo];
        $counter++;
        }

    
    my @matches;
    for (my $i = 0; $i<$counter; $i++){
        my $operation = $all_audits[$i][1];
        my $stock_json_string;
	eval {
            if ($operation eq "DELETE"){
                $stock_json_string = decode_json($before[$i]);
            } else {
                $stock_json_string = decode_json($after[$i]);
            }
	};
	if ($@) {
	    warn "Failed to decode JSON at index $i: $@";
            next; # Skip this iteration in case of error
        }
        my $desired_uniquename = $stock_json_string->{'uniquename'};
        if($stock_uniquename eq $desired_uniquename){
            push @matches, $all_audits[$i];
        }
    }

    my $stock_match_json;
    $stock_match_json = encode_json(\@matches);

    $c->stash->{rest} = {
        stock_match_after => $stock_match_json,
    }
};


sub retrieve_trial_audits : Path('/ajax/audit/retrieve_trial_audits'){
    my $self = shift;
    my $c = shift;
    my $trial_id = $c->req->param('trial_id');
    my $q = "SELECT * FROM audit.project_audit;";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute();
    my @all_audits;
    my @before;
    my @after;
    my $counter = 0;

    while (my ($audit_ts, $operation, $username, $logged_in_user, $before, $after, $transactioncode, $primary_key, $is_undo) = $h->fetchrow_array) {
        $after[$counter] = $after;
        $before[$counter] = $before;
        $all_audits[$counter] = [$audit_ts, $operation, $username, $logged_in_user, $before, $after, $transactioncode, $primary_key, $is_undo];
        $counter++;
        }

    
    my @matches;
    my $num_matches = 0; #this is to make sure only matched audits go into the matches array

    for (my $i = 0; $i<$counter; $i++){
        my $operation = $all_audits[$i][1];
        my $json_string;
        if($operation eq "DELETE"){
            $json_string = decode_json($before[$i]);
        }else{
            $json_string = decode_json($after[$i]);
        }
        my $desired_trial_id = $json_string->{'project_id'};
        
        if($trial_id eq $desired_trial_id){
        

            $matches[$num_matches] = $all_audits[$i];
            $num_matches++;

        }
    }

    my $match_trial_json;
    $match_trial_json = encode_json(\@matches);

    $c->stash->{rest} = {
        match_project => $match_trial_json,
        }
};
