#!/usr/bin/perl

=head1
ODK/ODK_ONA_get_crosses.pl 

=head1 SYNOPSIS
ODK_ONA_get_crosses.pl  

=head1 COMMAND-LINE OPTIONS
ARGUMENTS

=head1 DESCRIPTION

=head1 AUTHOR
 Nicolas Morales (nm529@cornell.edu)
=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use CXGN::ODK::Crosses;
use JSON;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;

our ($opt_u, $opt_i, $opt_r, $opt_a, $opt_d, $opt_t, $opt_n, $opt_m, $opt_o, $opt_f, $opt_l, $opt_c, $opt_q, $opt_y, $opt_D, $opt_U, $opt_p, $opt_H);

getopts('u:i:r:a:d:t:n:m:o:w:f:l:c:q:y:D:U:p:H:');

if (!$opt_u || !$opt_i || !$opt_r || !$opt_a || !$opt_d ||!$opt_t || !$opt_n || !$opt_m || !$opt_o || !$opt_f || !$opt_l || !$opt_c || !$opt_q || !$opt_y || !$opt_D || !$opt_U || !$opt_p || !$opt_H) {
    die "Must provide options -u (sp_person_id) -i (sp_person_username )-r (sp_role) -a (archive_path) -d (temp_files_dir) -t (temp_file_path) -n (ODK username) -m (ODK password) -o (ODK form_id) -f (odk cross progress tree file dir) -l (ODK URL) -c (allowed cross properties) -q (temp cross wishlist file path for dl from ONA) -y (temp germplasm info file path for dl from ONA) -D (database name) -U (db user) -p (dbpass) -H (dbhost) \n";
}

my $bcs_schema = Bio::Chado::Schema->connect(
    "dbi:Pg:database=$opt_D;host=$opt_H", # DSN Line
    $opt_U,                    # Username
    $opt_p           # Password
);
my $metadata_schema = CXGN::Metadata::Schema->connect(
    "dbi:Pg:database=$opt_D;host=$opt_H", # DSN Line
    $opt_U,                    # Username
    $opt_p           # Password
);
my $phenome_schema = CXGN::Phenome::Schema->connect(
    "dbi:Pg:database=$opt_D;host=$opt_H", # DSN Line
    $opt_U,                    # Username
    $opt_p           # Password
);

my $odk_crosses = CXGN::ODK::Crosses->new({
    bcs_schema=>$bcs_schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    sp_person_id=>$opt_u,
    sp_person_username=>$opt_i,
    sp_person_role=>$opt_r,
    archive_path=>$opt_a,
    temp_file_dir=>$opt_d,
    temp_file_path=>$opt_t,
    allowed_cross_properties=>$opt_c,
    cross_wishlist_temp_file_path=>$opt_q,
    germplasm_info_temp_file_path=>$opt_y,
    odk_crossing_data_service_url=>$opt_l,
    odk_crossing_data_service_username=>$opt_n,
    odk_crossing_data_service_password=>$opt_m,
    odk_crossing_data_service_form_id=>$opt_o,
    odk_cross_progress_tree_file_dir=>$opt_f
});
my $result = $odk_crosses->save_ona_cross_info();

