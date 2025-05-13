
use strict;

use lib 't/lib';
use Data::Dumper;
use File::Basename;
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::UploadFile;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Trial;

my $f = SGN::Test::Fixture->new();

my $filename = "t/data/trial/upload_phenotypin_spreadsheet_exact_repeats1.xlsx";

my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();

# create cvterms with a "multiple" property 

my @terms = ("dry matter content percentage", "fresh root weight", "fresh shoot weight measurement in kg", "harvest index variable");
my @term_ids;

my $trait_repeat_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema(), "trait_repeat_type", "trait_property")->cvterm_id();

foreach my $t (@terms) {
    print STDERR "Enabling multiple for term $t...\n";
    my $term_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema(), $t, "cassava_trait")->cvterm_id();

    my $row_data = {
	cvterm_id => $term_id,
	type_id => $trait_repeat_type_cvterm_id,
	value => "multiple",
    };

    print STDERR "INSERTING ROW : ".Dumper($row_data);
    my $prop_row = $f->bcs_schema()->resultset('Cv::Cvtermprop')->create($row_data);
}

my $basename = basename($filename);
print STDERR "BASENAME: $basename\n";

my $uploader = CXGN::UploadFile->new(
    {
	tempfile => $filename,
	subdirectory => 'temp_fieldbook',
	archive_path => '/tmp',
	archive_filename => $timestamp."_".$basename,
	timestamp => $timestamp,
	user_id => 41, #janedoe in fixture
	user_role => 'curator'
    });

## Store uploaded temporary file in archive
my $archived_filename_with_path = $uploader->archive();

print STDERR "ARCHIVED FILENAME: $archived_filename_with_path\n";

my $md5 = $uploader->get_md5($archived_filename_with_path);
print STDERR "MD5SUM: ".Dumper($md5);

ok($archived_filename_with_path);
ok($md5);


#Now parse phenotyping spreadsheet file using correct parser
my $parser = CXGN::Phenotypes::ParseUpload->new();

my $validate_file = $parser->validate('phenotype spreadsheet simple generic', $archived_filename_with_path, 1, 'plots', $f->bcs_schema);

print STDERR "VALIDATE FILE = ".Dumper($validate_file);
ok($validate_file == 1, "Check if parse validate works for phenotype file");

if (ref($validate_file) && exists($validate_file->{error})) {
    die "parse did not validate\n";
}

my $parsed_file = $parser->parse('phenotype spreadsheet simple generic', $archived_filename_with_path, 1, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse phenotype spreadsheet works");

print STDERR "PARSED FILE: ".Dumper($parsed_file);

my %phenotype_metadata;
$phenotype_metadata{'archived_file'} = $archived_filename_with_path;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2025-04-12_22:00:00";
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
    overwrite_values=>1,
    metadata_hash=>\%phenotype_metadata,
    composable_validation_check_name=>$f->config->{composable_validation_check_name}
    );

my ($verified_warning, $verified_error) = $store_phenotypes->verify();
ok(!$verified_error);

print STDERR "VERIFIED WARNING: ".Dumper($verified_warning)."\n";
print STDERR "VERIFIED ERROR: ".Dumper($verified_error)."\n";

my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store pheno spreadsheet works 1");

ok($store_success, "store success check");

print STDERR "STORED PHENO ERROR: ".Dumper($stored_phenotype_error_msg)."\n";

my $q = "SELECT phenotype_id, value, collect_date FROM phenotype WHERE value=? and collect_date=?";

my $h = $f->dbh()->prepare($q);
$h->execute(22.22, '2025-05-12 21:19:00');
my ($phenotype_id) = $h->fetchrow_array();
print STDERR "PHENOTYPE ID FOUND: $phenotype_id\n";
print STDERR "FOUND ENTRY AT PHENOTYPE_ID = $phenotype_id\n";
ok($phenotype_id, "Find multiple phenotype entry 1");

$h->execute(33.33, '2025-05-12 21:20:00');
($phenotype_id) = $h->fetchrow_array();
print STDERR "PHENOTYPE ID FOUND: $phenotype_id\n";
print STDERR "FOUND ANOTHER ENTRY AT PHENOTYPE_ID= $phenotype_id\n";
ok($phenotype_id, "FInd multiple phenotype entry 2");

$h->execute(44.44, '2025-05-12 21:21:00');
($phenotype_id) = $h->fetchrow_array();
print STDERR "PHENOTYPE ID FOUND: $phenotype_id\n";
print STDERR "FOUND ANOTHER ENTRY AT PHENOTYPE_ID= $phenotype_id\n";
ok($phenotype_id, "FInd multiple phenotype entry 3");
print STDERR "PHENOTYPE ID FOUND: $phenotype_id\n";

###
### TEST OVERWRITE VALUES AND REMOVE VALUES
###
$filename = "t/data/trial/upload_phenotypin_spreadsheet_exact_repeats2.xlsx";

$validate_file = $parser->validate('phenotype spreadsheet simple generic', $filename, 1, 'plots', $f->bcs_schema);

print STDERR "VALIDATE FILE = ".Dumper($validate_file);
ok($validate_file == 1, "Check if parse validate works for phenotype file");

if (ref($validate_file) && exists($validate_file->{error})) {
    die "parse did not validate\n";
}

$parsed_file = $parser->parse('phenotype spreadsheet simple generic', $filename, 1, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse phenotype spreadsheet works");

print STDERR "PARSED FILE: ".Dumper($parsed_file);

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
    overwrite_values=>1,
    metadata_hash=>\%phenotype_metadata,
    composable_validation_check_name=>$f->config->{composable_validation_check_name}
    );

($verified_warning, $verified_error) = $store_phenotypes->verify();
ok(!$verified_error);

print STDERR "VERIFIED WARNING: ".Dumper($verified_warning)."\n";
print STDERR "VERIFIED ERROR: ".Dumper($verified_error)."\n";

($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store pheno spreadsheet works 2");

print STDERR "STORED PHENO ERROR 2: ".Dumper($stored_phenotype_error_msg)."\n";

ok($store_success, "store success check 2");

$h->execute(55.55, '2025-05-12 21:19:00');
my ($phenotype_id) = $h->fetchrow_array();

print STDERR "FOUND ENTRY AT PHENOTYPE_ID = $phenotype_id\n";
ok($phenotype_id, "Find multiple phenotype entry 9");

$h->execute(33.33, '2025-05-12 21:20:00');
my @phenotype_ids;
while (my ($phenotype_id) = $h->fetchrow_array()) {
    push @phenotype_ids, $phenotype_id;
}

is(scalar(@phenotype_ids), 1, "check number of phenotypes retrieved");

print STDERR "FOUND ANOTHER ENTRY AT PHENOTYPE_ID= $phenotype_id\n";
ok($phenotype_ids[0], "FInd multiple phenotype entry 10");

$h->execute(77.77, '2025-05-12 21:21:00');
($phenotype_id) = $h->fetchrow_array();

$h->execute(22.22, '2025-05-12 21:19:00');
($phenotype_id) = $h->fetchrow_array();

print STDERR "FOUND ANOTHER ENTRY AT PHENOTYPE_ID= $phenotype_id\n";
ok(!$phenotype_id, "Find multiple phenotype entry 12");




done_testing();

$f->clean_up_db();
