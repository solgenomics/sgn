
=head1 NAME

check_tool_compatibility.pl - script to determine tool compatibility of a dataset based on dataset definition

=head1 SYNOPSIS

perl check_tool_compatibility.pl -d dataset_id -H [host] -D [dbname]

=head1 OPTIONS

=over 3

=item -d

The ID of the dataset, as stored in the database

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

