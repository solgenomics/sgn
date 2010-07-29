#!/usr/bin/env perl


=head1 NAME

[ this script name ].pl

=head1 SYNOPSIS

  this_script.pl [options]

  Options:

    -D <dbname> (mandatory)
      dbname to load into

    -H <dbhost> (mandatory)
      dbhost to load into

    -p <script_executor_user> (mandatory)
      username to run the script

    -F force to run this script and don't stop it by 
       missing previous db_patches

  Note: If the first time that you run this script, obviously
        you have no previous dbversion row in the md_dbversion
        table, so you need to force the execution of this script 
        using -F

=head1 DESCRIPTION

remove the tigrtc tracking tables

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


use strict;
use warnings;

use Bio::Chado::Schema;
use Pod::Usage;
use Getopt::Std;
use CXGN::DB::InsertDBH;
use CXGN::Metadata::Dbversion;   ### Module to interact with the metadata.md_dbversion table


## Declaration of the parameters used to run the script

our ($opt_H, $opt_D, $opt_p, $opt_F, $opt_h);
getopts("H:D:p:Fh");

## If is used -h <help> or none parameters is detailed print pod

if (!$opt_H && !$opt_D && !$opt_p && !$opt_F && !$opt_h) {
    print STDOUT "No optionas passed. Printing help\n\n";
    pod2usage(1);
} 
elsif ($opt_h) {
    pod2usage(1);
} 


## Declaration of the name of the script and the description

my $patch_name = '0001_load_tomato_gen_pubs.pl';
my $patch_descr = 'This script stores pubprop for the tomato genome publications. It assumes these are ALREADY STORED in the database. The best way to load first the publications is by using the web interface ';

print STDOUT "\n+--------------------------------------------------------------------------------------------------+\n";
print STDOUT "Executing the patch:\n   $patch_name.\n\nDescription:\n  $patch_descr.\n\nExecuted by:\n  $opt_p.";
print STDOUT "\n+--------------------------------------------------------------------------------------------------+\n\n";

## And the requeriments if you want not use all
##
my @previous_requested_patches = (   ## ADD HERE
   ); 

## Specify the mandatory parameters

if (!$opt_H || !$opt_D) {
    print STDOUT "\nMANDATORY PARAMETER ERROR: -D <db_name> or/and -H <db_host> parameters has not been specified for $patch_name.\n";
} 

if (!$opt_p) {
    print STDOUT "\nMANDATORY PARAMETER ERROR: -p <script_executor_user> parameter has not been specified for $patch_name.\n";
}

## Create the $schema object for the db_version object
## This should be replace for CXGN::DB::DBICFactory as soon as it can use CXGN::DB::InsertDBH

my $db =  CXGN::DB::InsertDBH->new(
                                     { 
					 dbname => $opt_D, 
					 dbhost => $opt_H 
				     }
                                   );
my $dbh = $db->get_actual_dbh();

print STDOUT "\nCreating the Metadata Schema object.\n";

my $metadata_schema = CXGN::Metadata::Schema->connect(   
                                                       sub { $dbh },
                                                      { on_connect_do => ['SET search_path TO metadata;'] },
                                                      );

print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

### Now it will check if you have runned this patch or the previous patches

my $dbversion = CXGN::Metadata::Dbversion->new($metadata_schema)
                                         ->complete_checking( { 
					                         patch_name  => $patch_name,
							         patch_descr => $patch_descr, 
							         prepatch_req => \@previous_requested_patches,
							         force => $opt_F 
							      } 
                                                             );


### CREATE AN METADATA OBJECT and a new metadata_id in the database for this data

my $metadata = CXGN::Metadata::Metadbdata->new($metadata_schema, $opt_p);

### Get a new metadata_id (if you are using store function you only need to supply $metadbdata object)

my $metadata_id = $metadata->store()
                           ->get_metadata_id();

### Now you can insert the data using different options:
##
##  1- By sql queryes using $dbh->do(<<EOSQL); and detailing in the tag the queries
##
##  2- Using objects with the store function
##
##  3- Using DBIx::Class first level objects
##

## In this case we will use the SQL tag

print STDERR "\nExecuting the SQL commands.\n";

$db->do("drop table $_") for qw(
  sgn.tigrtc_index
  sgn.tigrtc_tracking
  sgn.tigrtc_membership
);

## Now it will add this new patch information to the md_version table.  It did the dbversion object before and
## set the patch_name and the patch_description, so it only need to store it.

$dbversion->store($metadata);

print STDOUT "DONE!\n";

$dbh->commit;

__END__

