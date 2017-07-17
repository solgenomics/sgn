#!/usr/bin/perl

use Getopt::Std;
use CXGN::DB::InsertDBH;
use Bio::Chado::Schema;
use Data::Dumper;
use CXGN::Trial;

use vars qw | $opt_H $opt_D |;

getopts('H:D:');

my $dbh = CXGN::DB::InsertDBH->new( {
    dbhost => $opt_H,
    dbname => $opt_D,
    } );



my $schema = Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() } );

my $q = "SELECT distinct(project_id), nd_geolocation.nd_geolocation_id, nd_geolocation.description FROM  nd_experiment_project JOIN nd_experiment USING (nd_experiment_id) JOIN nd_geolocation USING (nd_geolocation_id)  ";
my $h = $dbh->prepare($q);
$h->execute();
while (my ($project_id, $location_id, $description) = $h->fetchrow_array()) {
    my $trial = CXGN::Trial->new( { bcs_schema=> $schema, trial_id=>$project_id });

    print STDERR "Adding location $description ($location_id) to trial $project_id... ";

    my $current_location = $trial->get_location();
   if ( $current_location->[0]) { # whatever it is
	print STDERR " (already associated) ";
}
    else {
	$trial->set_location($location_id);
    }
    print STDERR "Done.\n";

}

$dbh->commit();
