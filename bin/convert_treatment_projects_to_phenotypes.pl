=head1 NAME

convert_treatment_projects_to_phenotypes.pl - a script to take deprecated treatment/field_management_factor projects and turn them into treatment observations. Treatment projects will be deleted, and any treatments that are seen will be added to the treatment ontology.

=head1 SYNOPSIS

perl convert_treatment_projects_to_phenotypes.pl -H dbhost -D dbname -U user -P password

=over 4

=item -H

The host of the database.

=item -D

The name of the database. 

=item -U

The user executing this action (postgres by default)

=item -P

The database password.

=back

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

use strict;

use Getopt::Std;
use Pod::Usage;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Phenotypes::StorePhenotypes;

our ($opt_H, $opt_D, $opt_U, $opt_P);

getopts('F:d:H:o:n:vD:tp:us:r:g:')
    or pod2usage();