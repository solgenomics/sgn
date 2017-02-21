#!/usr/bin/env perl

=head1

load_composed_cvprops.pl

=head1 SYNOPSIS

load_composed_cvprops.pl -H [dbhost] -D [dbname]  -T [trait_ontology cv name] -c [composed_trait_ontology cv name] -o [object_ontology cv name] -a [attribute_ontology cv name] -m [method_ontology cv name] -u [unit_ontology cv name] -t [time_ontology cv name]

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name

 optional:
 -T [trait_ontology cv name]
 -c [composed_trait_ontology cv name]
 -o [object_ontology cv name]
 -a [attribute_ontology cv name]
 -m [method_ontology cv name]
 -u [unit_ontology cv name]
 -t [time_ontology cv name]

=head2 DESCRIPTION


=head2 AUTHOR

Bryan Ellerbrock (bje24@cornell.edu)

Feb 2017

=cut

use strict;
use warnings;
use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::DB::Connection;
use Try::Tiny;

our ($opt_H, $opt_D, $opt_T, $opt_c, $opt_o, $opt_a, $opt_m, $opt_u, $opt_t);
getopts('H:D:Tcoamut');


sub print_help {
  print STDERR "A script to load composed cvprops\nUsage: load_composed_cvprops.pl -H [dbhost] -D [dbname]  -T [trait_ontology cv name] -c [composed_trait_ontology cv name] -o [object_ontology cv name] -a [attribute_ontology cv name] -m [method_ontology cv name] -u [unit_ontology cv name] -t [time_ontology cv name] \n";
}


if (!$opt_D || !$opt_H) {
  print_help();
  die("Exiting: options missing\n");
}

my $dbh = CXGN::DB::InsertDBH
  ->new({
	 dbname => $opt_D,
	 dbhost => $opt_H,
	 dbargs => {AutoCommit => 1,
		    RaiseError => 1},
	});

my $chado_schema = Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );

my $coderef = sub {

my $composable_cvtypes = $schema->resultset("Cv::Cv")->find(
  { name => 'composable_cvtypes'
  });

my %cvprop_hash = (
  trait_ontology => $opt_T,
  composed_trait_ontology => $opt_c,
  object_ontology => $opt_o,
  attribute_ontology => $opt_a,
  method_ontology => $opt_m,
  unit_ontology => $opt_u,
  time_ontology => $opt_t
)

while (my($key, $value) = each %cvprop_hash) {

my $ontology = $schema->resultset("Cv::Cv")->find(
  { name => $value
  });

my $ontology_cvtype = $schema->resultset("Cv::Cvterm")->find(
  { name => $key,
    cv_id => $composable_cvtypes->cv_id()
  });

my $new_ontology_cvprop= $schema->resultset("Cv::Cvprop")->find_or_create(
  { cv_id  =>$ontology->cv_id(),
    type_id   => $ontology_cvtype->cvterm_id()
  });
}
};

try {
    $schema->txn_do($coderef);

} catch {
    die "Load failed! " . $_ .  "\n" ;
};

print "You're done! Composed cvprops were loaded.\n";



INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'cassava_trait' AND cvterm.name = 'trait_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'composed_trait' AND cvterm.name = 'composed_trait_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'cass_tissue_ontology' AND cvterm.name = 'entity_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'chebi_ontology' AND cvterm.name = 'quality_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'cass_units_ontology' AND cvterm.name = 'unit_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'cass_time_ontology' AND cvterm.name = 'time_ontology';
