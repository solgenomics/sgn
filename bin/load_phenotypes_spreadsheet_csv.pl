#!/usr/bin/perl

=head1

load_phenotypes_spreadsheet_csv.pl - backend script for loading phenotypes into cxgn databases from a spreadsheet csv file. uses same process as online interface.

=head1 SYNOPSIS

    load_phenotypes_spreadsheet_csv.pl -H [dbhost] -D [dbname] -U [dbuser] -P [dbpass] -b [basepath] -i [infile] -a [archive path on server] -d [datalevel] -u [username] -t [timestamps included] -o [overwrite previous values] -r [temp_file_nd_experiment_id]

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -U database username (required)
 -P database userpass (required)
 -b basepath (required) e.g. "/home/me/cxgn/sgn"
 -r temp_file_nd_experiment_id (required) e.g. "/tmp/delete_nd_experiment_ids.txt"
 -i path to infile (required)
 -a archive path (required) e.g. /export/prod/archive/
 -d datalevel (required) must be plots or plants
 -u username (required) username in database of peron uploading phenotypes
 -t timestamps included (optional) 1 or 0
 -o overwrite previous values (optional) 1 or 0

=head1 DESCRIPTION

perl bin/load_phenotypes_spreadsheet_csv.pl -D cass -H localhost -U postgres -P postgres -b /home/me/cxgn/sgn -u nmorales -i ~/Downloads/combined_counts.csv -a /export/prod/archive/ -d plants -r /tmp/delete_nd_experiment_ids.txt

This script will parse and validate the input file. If there are any warnings or errors during validation it will die.
If there are no warnings or errors during validation it will then store the data.

input file should be a spreadsheet csv file. All fields should be quoted.
header line should be: "studyYear","studyDbId","studyName","studyDesign","locationDbId","locationName","germplasmDbId","germplasmName","germplasmSynonyms","observationLevel","observationUnitDbId","observationUnitName","replicate","blockNumber","plotNumber" followed by all measured traits

To include timestamps, values should be "value,YYYY-MM-DD 13:45:01+0004".

=head1 AUTHOR

 Nicolas Morales (nm529@cornell.edu)

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use DateTime;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Phenotypes::ParseUpload;
use CXGN::UploadFile;
use File::Basename;

our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_b, $opt_i, $opt_a, $opt_d, $opt_u, $opt_t, $opt_o, $opt_r);

getopts('H:D:U:P:b:i:a:d:u:t:o:r:');

if (!$opt_H || !$opt_D || !$opt_U ||!$opt_P || !$opt_b || !$opt_i || !$opt_a || !$opt_d || !$opt_u || !$opt_r) {
    die "Must provide options -H (hostname), -D (database name), -U (database user), -P (database password), -b (basepath), -i (input file), -a (archive path), -d (datalevel), -u (username in db), -r (temp_file_nd_experiment_id)\n";
}

my $schema = Bio::Chado::Schema->connect(
    "dbi:Pg:database=$opt_D;host=$opt_H", # DSN Line
    $opt_U,                    # Username
    $opt_P           # Password
);
my $metadata_schema = CXGN::Metadata::Schema->connect(
    "dbi:Pg:database=$opt_D;host=$opt_H", # DSN Line
    $opt_U,                    # Username
    $opt_P           # Password
);
$metadata_schema->storage->dbh->do('SET search_path TO metadata');

my $phenome_schema = CXGN::Phenome::Schema->connect(
    "dbi:Pg:database=$opt_D;host=$opt_H", # DSN Line
    $opt_U,                    # Username
    $opt_P           # Password
);
$phenome_schema->storage->dbh->do('SET search_path TO phenome');

my $dbh = CXGN::DB::InsertDBH->new({ 
	dbhost=>$opt_H,
	dbname=>$opt_D,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});
$dbh->do('SET search_path TO public,sgn');

my $q = "SELECT sp_person_id from sgn_people.sp_person where username = '$opt_u';";
my $h = $dbh->prepare($q);
$h->execute();
my ($sp_person_id) = $h->fetchrow_array();
if (!$sp_person_id){
    die "Not a valid -u\n";
}

my $timestamp_included;
if ($opt_t == 1){
    $timestamp_included = 1;
}

my $parser = CXGN::Phenotypes::ParseUpload->new();
my $subdirectory = "spreadsheet_csv_phenotype_upload";
my $validate_type = "phenotype spreadsheet csv";
my $metadata_file_type = "spreadsheet csv phenotype file";
my $upload = $opt_i;
my $data_level = $opt_d;

my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();

my $uploader = CXGN::UploadFile->new({
   tempfile => $upload,
   subdirectory => $subdirectory,
   archive_path => $opt_a,
   archive_filename => basename($upload),
   timestamp => $timestamp,
   user_id => $sp_person_id,
   user_role => 'curator'
});
my $archived_filename_with_path = $uploader->archive();
my $md5 = $uploader->get_md5($archived_filename_with_path);
if (!$archived_filename_with_path) {
    die "Could not archive file!\n";
} else {
    print STDERR "File saved in archive.\n";
}

my %phenotype_metadata;
$phenotype_metadata{'archived_file'} = $archived_filename_with_path;
$phenotype_metadata{'archived_file_type'} = $metadata_file_type;
$phenotype_metadata{'operator'} = $opt_u;
$phenotype_metadata{'date'} = $timestamp;

my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, undef, undef);
if (!$validate_file) {
    die "Input file itself not valid.\n";
}
if ($validate_file == 1){
    print STDERR "File itself valid. Will now parse.\n";
} else {
    if ($validate_file->{'error'}) {
        die $validate_file->{'error'}."\n";
    }
}

my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, undef, $sp_person_id, undef, undef);
if (!$parsed_file) {
    die "Error parsing file.\n";
}
if ($parsed_file->{'error'}) {
    die $parsed_file->{'error'},"\n";
}

print STDERR "File parsed. Will now validate contents.\n";

my %parsed_data;
my @plots;
my @traits;
if ($parsed_file && !$parsed_file->{'error'}) {
    %parsed_data = %{$parsed_file->{'data'}};
    @plots = @{$parsed_file->{'units'}};
    @traits = @{$parsed_file->{'variables'}};
}

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$opt_b,
    dbhost=>$opt_H,
    dbname=>$opt_D,
    dbuser=>$opt_U,
    dbpass=>$opt_P,
    temp_file_nd_experiment_id=>$opt_r,
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    user_id=>$sp_person_id,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>$timestamp_included,
    metadata_hash=>\%phenotype_metadata,
);

my ($verified_warning, $verified_error) = $store_phenotypes->verify();
if ($verified_error) {
    die $verified_error."\n";
}
if ($verified_warning && !$opt_o) {
    die $verified_warning."\n";
}

print STDERR "Done validating. Now storing\n";

my ($stored_phenotype_error, $stored_Phenotype_success) = $store_phenotypes->store();
if ($stored_phenotype_error) {
    die $stored_phenotype_error."\n";
}
print STDERR $stored_Phenotype_success."\n";
print STDERR "Script Complete.\n";
