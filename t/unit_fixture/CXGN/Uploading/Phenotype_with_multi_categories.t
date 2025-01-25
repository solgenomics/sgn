
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
#use SimulateC;
use CXGN::UploadFile;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Trial;
use SGN::Model::Cvterm;
use DateTime;
use Data::Dumper;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BreederSearch;
use Spreadsheet::Read;
use CXGN::Trial::Download;
use DateTime;
use Test::WWW::Mechanize;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();

$f->dbh->{AutoCommit} = 0;
$f->dbh->{RaiseError} = 1;

# modify a variable to be multicat and have the correct definitions
# here we modify the variable term "cassava mosaic disease severity 1-month evaluation"
# (CO_334:0000191, cvterm_id 76740) and add the Multicat property for trait_format (type_id=76465)
#
my $cvtermprop_row_data = {
    cvterm_id => 76740,
    value => 'Multicat',
    type_id => 76465,
};

my $row = $f->bcs_schema->resultset("Cv::Cvtermprop")->find_or_create( $cvtermprop_row_data );

my $cvtermprop_row_data2 = {
    cvterm_id => 76740,
    value => '1/2/3/4/5',
    type_id => 76470,
};

my $row2 = $f->bcs_schema->resultset("Cv::Cvtermprop")->find_or_create( $cvtermprop_row_data2 );



my $extension = "xlsx";

my $bs = CXGN::BreederSearch->new( { dbh=> $f->dbh() });


# Upload file with errors to test error detection

my $filename = "t/data/trial/upload_phenotypin_spreadsheet_multicategories_with_errors.$extension";
my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();

# Test archive upload file
#
my $uploader = CXGN::UploadFile->new({
    tempfile => $filename,
    subdirectory => 'temp_fieldbook',
    archive_path => '/tmp',
    archive_filename => "upload_phenotypin_spreadsheet_multicategories.$extension",
    timestamp => $timestamp,
    user_id => 41,  # janedoe in fixture
    user_role => 'curator'
				     });

# archive filename
#
my $archived_filename_with_path = $uploader->archive();

print STDERR "ARCHIVED FILENAME WITH PATH: $archived_filename_with_path\n";

my $md5 = $uploader->get_md5($archived_filename_with_path);
ok($archived_filename_with_path, "check filename");
ok($md5, "check md5sum");

# Now parse phenotyping spreadsheet file using correct parser
#
my $parser = CXGN::Phenotypes::ParseUpload->new();
my $validate_file = $parser->validate('phenotype spreadsheet simple generic', $archived_filename_with_path, 1, 'plots', $f->bcs_schema);
ok($validate_file == 1, "Check if parse validate works for phenotype file");

my $parsed_file = $parser->parse('phenotype spreadsheet simple generic', $archived_filename_with_path, 1, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

print STDERR "PARSED FILE: ".Dumper $parsed_file;


my %phenotype_metadata;
$phenotype_metadata{'archived_file'} = $archived_filename_with_path;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_01:10:56";
my %parsed_data = %{$parsed_file->{'data'}};
my @plots = @{$parsed_file->{'units'}};
my @traits = @{$parsed_file->{'variables'}};

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$f->config->{basepath},
    dbhost=>$f->config->{dbhost},
    dbname=>$f->config->{dbname},
    dbuser=>$f->config->{dbuser},
    dbpass=>$f->config->{dbpass},
    temp_file_nd_experiment_id=>$f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>1,
    overwrite_values=>0,
    metadata_hash=>\%phenotype_metadata,
    composable_validation_check_name=>$f->config->{composable_validation_check_name}
    );
my ($verified_warning, $verified_error) = $store_phenotypes->verify();
my $expected_error = '<small>This trait value should be one of 1/2/3/4/5: <br/>Plot Name: KASESE_TP2013_669<br/>Trait Name: CO_334:0000191<br/>Value: a:b</small><hr>';
print STDERR "ERRORS DETECTED: ".Dumper($verified_error);

is($verified_error, $expected_error, "check error from store");


# do not try to store the previous data, is it is erroneous... instead load new file without errors
#

# Upload file without errors to store

$filename = "t/data/trial/upload_phenotypin_spreadsheet_multicategories_with_errors.$extension";
$time = DateTime->now();
$timestamp = $time->ymd()."_".$time->hms();

# Test archive upload file
#
$uploader = CXGN::UploadFile->new({
    tempfile => $filename,
    subdirectory => 'temp_fieldbook',
    archive_path => '/tmp',
    archive_filename => "upload_phenotypin_spreadsheet_multicategories.$extension",
    timestamp => $timestamp,
    user_id => 41,  # janedoe in fixture
    user_role => 'curator'
				     });

# Store uploaded temporary file in archive
#
$archived_filename_with_path = $uploader->archive();

print STDERR "ARCHIVED FILENAME WITH PATH: $archived_filename_with_path\n";

$md5 = $uploader->get_md5($archived_filename_with_path);
ok($archived_filename_with_path, "check filename");
ok($md5, "check md5sum");

# Now parse phenotyping spreadsheet file using correct parser
#
$parser = CXGN::Phenotypes::ParseUpload->new();
$validate_file = $parser->validate('phenotype spreadsheet simple generic', $archived_filename_with_path, 1, 'plots', $f->bcs_schema);
ok($validate_file == 1, "Check if parse validate works for phenotype file");

$parsed_file = $parser->parse('phenotype spreadsheet simple generic', $archived_filename_with_path, 1, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

print STDERR "PARSED FILE: ".Dumper $parsed_file;

%phenotype_metadata;
$phenotype_metadata{'archived_file'} = $archived_filename_with_path;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_01:10:56";
 %parsed_data = %{$parsed_file->{'data'}};
 @plots = @{$parsed_file->{'units'}};
 @traits = @{$parsed_file->{'variables'}};

$store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$f->config->{basepath},
    dbhost=>$f->config->{dbhost},
    dbname=>$f->config->{dbname},
    dbuser=>$f->config->{dbuser},
    dbpass=>$f->config->{dbpass},
    temp_file_nd_experiment_id=>$f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>1,
    overwrite_values=>0,
    metadata_hash=>\%phenotype_metadata,
    composable_validation_check_name=>$f->config->{composable_validation_check_name}
    );
($verified_warning, $verified_error) = $store_phenotypes->verify();

$expected_error = '';

print STDERR "ERRORS DETECTED: ".Dumper($verified_error);

my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store pheno spreadsheet works");

print STDERR "DONE WITH THIS TEST!\n";
$f->dbh()->rollback();
$f->clean_up_db();


done_testing();


