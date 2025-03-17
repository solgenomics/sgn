
=head1 NAME

check_tool_compatibility.pl - script to determine tool compatibility of a dataset based on dataset definition

=head1 SYNOPSIS

perl check_tool_compatibility.pl -d dataset_id -G [default genotyping protocol] -H [host] -D [dbname]

=head1 OPTIONS

=over 3

=item -d

The ID of the dataset, as stored in the database

=item -G

The default genotyping protocol of this site. Used only if no genotyping protocol available in dataset.

=item -H

The database hostname

=item -D

Database name

=back

=head1 AUTHOR

Ryan Preble, rsp98@cornell.edu

=cut

use strict;
use warnings;

use Getopt::Std;
use CXGN::Dataset;
use Try::Tiny;
use CXGN::DB::InsertDBH;
use Bio::Chado::Schema;
use CXGN::People::Schema;

our ($opt_d, $opt_G, $opt_H, $opt_D);

getopts('d:G:H:D');

my $dataset_id = $opt_d || die "Dataset ID is required for tool compatibility calculation.";
my $genotyping_protocol = $opt_G;
my $dbhost = $opt_H;
my $dbname = $opt_D;

my $dbh = CXGN::DB::InsertDBH->new(
    { 
        dbhost=>$dbhost,
		dbname=>$dbname,
		dbargs => {
            AutoCommit => 0,
			RaiseError => 1
        }
	}
);

my $people_schema = CXGN::People::Schema->connect(  sub { $dbh->get_actual_dbh() } );
my $bcs_schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );

my $dataset = CXGN::Dataset->new({
    people_schema => $people_schema,
    schema => $bcs_schema,
    sp_dataset_id => $dataset_id
}); 

$dataset->update_tool_compatibility($genotyping_protocol);

1; 