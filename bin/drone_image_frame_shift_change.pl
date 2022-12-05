#!/usr/bin/perl

=head1

drone_image_frame_shift_change.pl

=head1 SYNOPSIS

    load_locations.pl -H [dbhost] -D [dbname] -i [infile] -j [drone run id]

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -i path to infile (required)
 -j drone run project id (required)

=head1 DESCRIPTION

The format is .csv

=head1 AUTHOR

 Nicolas Morales (nm529@cornell.edu)

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::DroneImagery::ImagesSearch;

our ($opt_H, $opt_D, $opt_i, $opt_j);

getopts('H:D:i:j:');

if (!$opt_H || !$opt_D || !$opt_i || !$opt_j) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file) \n");
}

my $dbhost = $opt_H;
my $dbname = $opt_D;

my $dbh = CXGN::DB::InsertDBH->new({ 
	dbhost=>$dbhost,
	dbname=>$dbname,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

my $q = "UPDATE phenome.stock_image SET stock_id = ? WHERE stock_image_id = ?;";
my $q2 = "UPDATE metadata.md_image SET obsolete='t' WHERE image_id = ?;";
my $h = $schema->storage->dbh()->prepare($q);
my $h2 = $schema->storage->dbh()->prepare($q2);

open(my $F, "<", $opt_i) || die " Can't open file $opt_i\n";
while (my $line = <$F>) { 
    chomp $line;
    my @row = split ',', $line;
    my $plot_name_old = $row[0];
    my $plot_name_new = $row[1];

    my $old_plot_id = $schema->resultset("Stock::Stock")->find({uniquename=>$plot_name_old})->stock_id();
    #my $new_plot_id = $schema->resultset("Stock::Stock")->find({uniquename=>$plot_name_new})->stock_id();

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>[$opt_j],
        stock_id_list=>[$old_plot_id]
    });
    my ($result, $total_count) = $images_search->search();

    foreach (@$result) {
        print STDERR Dumper $_->{drone_run_band_project_name};
        print STDERR Dumper $_->{project_image_type_name};
        print STDERR Dumper $_->{stock_uniquename};
        
        my $image_id = $_->{image_id};
        my $stock_image_id = $_->{stock_image_id};
        $h->execute($new_plot_id, $stock_image_id);
        #$h2->execute($image_id);
    }
}
close($F);

print STDERR "Script Complete.\n";
