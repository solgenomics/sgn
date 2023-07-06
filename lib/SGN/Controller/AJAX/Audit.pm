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

    while (my ($audit_ts, $operation, $username, $logged_in_user, $before, $after) = $h->fetchrow_array) {
        $after[$counter] = $after;
        $all_audits[$counter] = [$audit_ts, $operation, $username, $logged_in_user, $before, $after];
        $counter++;
        }

    
   # $json_after_string = encode_json(\@after);
  #  print STDERR Dumper(@after)."\n";
  #  my $parsed_after = decode_json($json_after_string);


   # my $tempo = decode_json($after[0]);
   # my $temp_des_uniquename = $tempo->{'uniquename'};
  #  print STDERR Dumper($tempo)."\n";
  #  print STDERR Dumper($temp_des_uniquename)."\n";
    my @match_after;

    for (my $i = 0; $i<@after.length; $i++){
        my $json_after_string = new JSON;
        $json_after_string = decode_json($after[$i]);
        my $desired_uniquename = $json_after_string->{'uniquename'};
        if($stock_uniquename eq $desired_uniquename){
            $match_after[$i] = $all_audits[$i];
        }
    }

    print STDERR Dumper(@match_after)."\n";

    my $match_json = new JSON;
    $match_json = encode_json(\@match_after);
    print STDERR Dumper(decode_json($match_json))."\n";

    $c->stash->{rest} = {
        match_after => $match_json,
        }
    
        
    #for ($after in $json__after_string){
       # my $uniq = $after.uniquename;
        #if ($uniq eq $uniquename_from_mason){
           # my $uniquename = $uniq;
        #}
    #}

    #my $json_before_string = new JSON;
    #$json_before_string = encode_json(\@before);
    #my $parsed_before = JSON.parse($json_before_string);

   

    

    
     #  if ($operation eq "UPDATE" || $operation eq "DELETE"){
  #      my $uniquename = $json_before_string.uniquename;
  #  } 
   # if ($operation eq "INSERT"){
   #     my $uniquename = $json_after_string.uniquename;
   # }

    

};
}