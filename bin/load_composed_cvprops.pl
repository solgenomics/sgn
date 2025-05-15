#!/usr/bin/env perl

=head1

load_composed_cvprops.pl

=head1 SYNOPSIS

load_composed_cvprops.pl -H [dbhost] -D [dbname]  -T [trait_ontology cv name] -c [composed_trait_ontology cv name] -o [object_ontology cv name] -a [attribute_ontology cv name] -m [method_ontology cv name] -u [unit_ontology cv name] -t [time_ontology cv name]
-d [metadata_ontology]

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name

 optional:
 -T [trait_ontology cv name] cassava_trait - the main trait ontology for the database 
 -c [composed_trait_ontology cv name] composed_trait
 -o [object_ontology cv name] cxgn_plant_section | cxgn_plant_level_ontology
 -a [attribute_ontology cv name]  cxgn_plant_treatment | cxgn_plant_cycle
 -m [method_ontology cv name]
 -u [unit_ontology cv name] cxgn_units_ontology
 -t [time_ontology cv name] cxgn_time_ontology
 -d [metadata_ontology cv name] cxgn_metadata

=head2 DESCRIPTION


=head2 AUTHOR

Bryan Ellerbrock (bje24@cornell.edu)

Feb 2017

=cut

use strict;
use warnings;
use Data::Dumper;
use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::DB::Connection;
use Try::Tiny;

our ( $opt_H, $opt_D, $opt_T, $opt_c, $opt_o, $opt_a, $opt_m, $opt_u, $opt_t, $opt_d );
getopts('H:D:T:c:o:a:m:u:t:d:');

sub print_help {
    print STDERR
"A script to load composed cvprops\nUsage: load_composed_cvprops.pl -H [dbhost] -D [dbname]  -T [trait_ontology cv name] -c [composed_trait_ontology cv name] -o [object_ontology cv name] -a [attribute_ontology cv name] -m [method_ontology cv name] -u [unit_ontology cv name] -t [time_ontology cv name] -d [metadata_ontology cv name]\n";
}

if ( !$opt_D || !$opt_H ) {
    print_help();
    die("Exiting: -H [dbhost] and -D [dbname] options missing\n");
}

my $dbh = CXGN::DB::InsertDBH->new(
    {
        dbname => $opt_D,
        dbhost => $opt_H,
        dbargs => {
            AutoCommit => 1,
            RaiseError => 1
        },
    }
);

my $schema = Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() } );

my %cvprop_hash = (
    trait_ontology          => $opt_T,
    composed_trait_ontology => $opt_c,
    object_ontology         => $opt_o,
    attribute_ontology      => $opt_a,
    method_ontology         => $opt_m,
    unit_ontology           => $opt_u,
    time_ontology           => $opt_t,
    metadata_ontology       => $opt_d
);

my $coderef = sub {

    my $composable_cvtypes =
      $schema->resultset("Cv::Cv")->find( { name => 'composable_cvtypes' } );
    if ( !$composable_cvtypes ) {
        print STDERR
"No cv found for composable_cvtypes in database '$opt_D'.\n Run patch AddComposedCvtypeCv.pm on this database to load missing composable_cvtype cv.";
    }

    my ( $ontology, $ontology_cvtype, $new_ontology_cvprop );
    while ( my ( $key, $value ) = each %cvprop_hash ) {

        if ($value) {
            $ontology =
              $schema->resultset("Cv::Cv")->find( { name => $value } );

            if ( !$ontology ) {
                print STDERR
"No cv was found with the name '$value' in database '$opt_D'. Make sure all db patches were run\n";
            }

            $ontology_cvtype = $schema->resultset("Cv::Cvterm")->find(
                {
                    name  => $key,
                    cv_id => $composable_cvtypes->cv_id()
                }
            );

            if ( !$ontology_cvtype ) {
                print STDERR
"No term found for composable_cvtype '$key' in database '$opt_D'.\n Skipping cv '$value'.\n Run patch AddComposedCvtypeCv.pm on this database to load missing composable_cvtypes.\n";
                next;
            }

            $new_ontology_cvprop =
              $schema->resultset("Cv::Cvprop")->find_or_new(
                {
                    cv_id   => $ontology->cv_id(),
                    type_id => $ontology_cvtype->cvterm_id()
                }
              );

            if ( !$new_ontology_cvprop->in_storage ) {
                print STDERR
                  "Giving cv with name '$value' the cvprop '$key'... \n";
                $new_ontology_cvprop->insert;
            }
            else {
                print STDERR
"The Cv with name '$value' already has the cvprop '$key'... \n";
            }

        }
    }
};

try {
    $schema->txn_do($coderef);

}
catch {
    die "Load failed! " . $_ . "\n";
};

print "You're done!\n";
