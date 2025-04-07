#!/usr/bin/env perl

=head1 NAME

check_tool_compatibility.pl - script to determine tool compatibility of a dataset based on dataset definition

=head1 SYNOPSIS

perl check_tool_compatibility.pl -i dataset_id -G [default genotyping protocol] -H [host] -D [dbname] -U [dbuser] -P [dbpassword] 

=head1 OPTIONS

=over 3

=item -i

The ID of the dataset, as stored in the database

=item -G

The default genotyping protocol of this site. Used only if no genotyping protocol available in dataset.

=item -H

The database hostname

=item -D

Database name

=item -U

Database user (postgres by default)

=item -P 

Database password

=back

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

use strict;
use warnings;

use Getopt::Std;
use CXGN::Dataset;
use Try::Tiny;
use CXGN::DB::InsertDBH;
use Bio::Chado::Schema;
use CXGN::People::Schema;

our ($opt_i, $opt_G, $opt_H, $opt_D, $opt_P, $opt_U);

getopts('i:G:H:D:U:P');

my $dataset_id = $opt_i || die "Dataset ID is required for tool compatibility calculation.\n";
print STDERR "Starting tool compatibility check for ID $dataset_id.\n";
my $genotyping_protocol = $opt_G;
if (!$genotyping_protocol) {
    $genotyping_protocol = `cat /home/production/volume/cxgn/sgn/sgn_local.conf | grep default_genotyping_protocol | sed -r 's/\\w+\\s//'`;
}
my $dbhost = $opt_H || die "Need db host.\n";
my $dbname = $opt_D || die "Need db name.\n";
my $user = $opt_U ? $opt_U : "postgres";
my $password = $opt_P || die "Need db password.\n";

print STDERR "Connecting to DB.x\n";

my $dbh = CXGN::DB::Connection->new(
    { 
        dbhost=>$dbhost,
		dbname=>$dbname,
        dbuser=>$user,
        #dbpass=>$password,
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

eval {
    $dataset->update_tool_compatibility($genotyping_protocol);
};
if ($@) {
    $dbh->rollback();
    die "Tool compatibility failed.$@\n";
}

$dbh->commit();
$dbh->disconnect();

1; 