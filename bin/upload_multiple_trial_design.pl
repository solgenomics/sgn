#!/usr/bin/perl

=head1

upload_multiple_trial_design.pl

=head1 SYNOPSIS

    upload_multiple_trial_design.pl  -H [dbhost] -D [dbname] -P [dbpass] -w [basepath] -U [dbuser] -b [breeding program name]  -i infile -un [username] -e [email address] -r [temp_file_nd_experiment_id]

=head1 COMMAND-LINE OPTIONS
ARGUMENTS
 -H host name (required) Ex: "breedbase_db"
 -D database name (required) Ex: "breedbase"
 -P database userpass (required) Ex: "postgres"
 -w basepath (required) Ex: /home/production/cxgn/sgn
 -i path to infile (required)
 -U username  (required) Ex: "postgres"
 -b breeding program name (required)  Ex: test
 -t test run . Rolling back at the end
 -e email address of the user
 -l name of the user
 -r temp_file_nd_experiment_id (required) Ex: /temp/delete_nd_experiment_ids.txt
if loading trial data from metadata file, phenotypes + layout from infile 

=head2 DESCRIPTION

perl bin/upload_multiple_trial_design.pl -h breedbase_db -d breedbase -p postgres -w /home/cxgn/sgn/ -u postgres -i ~/Desktop/test_multi.xlsx -b test -n janedoe -e 'sk2783@cornell.edu' -l 'sri' -r /tmp/delete_nd_experiment_ids.txt

This script will parse and validate the input file. If there are any warnings or errors during validation it will send a error message to the provided email.
If there are no warnings(or errors) during validation it will then store the data.
The input file should be either .xlsx or .xls format.

CHECK cvterms for trial metadata!!

################################################
Minimal metadata requirements are
    trial_name
    trial_description (can also be built from the trial name, type, year, location)
    trial_type (read from an input file)
    trial_location geo_description ( must be in the database - nd_geolocation.description - can  be read from metadata file)
    year (can be read from the metadata file )
    design (defaults to 'RCBD' )
    breeding_program (provide with option -b )


Other OPTIONAL trial metadata (projectprops)

project planting date
project fertilizer date
project harvest date
project sown plants
project harvested plants

=head1 AUTHOR

Srikanth (sk2783@cornell.edu)

=cut

use strict;
use Getopt::Long;
use CXGN::Tools::File::Spreadsheet;
use Spreadsheet::ParseXLSX;
use Spreadsheet::ParseExcel;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Carp qw /croak/ ;
use Try::Tiny;
use DateTime;
use Pod::Usage;
use List::Util qw(max);
use List::Util qw(first);
use List::Util qw(uniq);
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::People::Person;
use Data::Dumper;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Trial; # add project metadata 
#use CXGN::BreedersToolbox::Projects; # associating a breeding program
use CXGN::Trial::TrialCreate;
use CXGN::Tools::Run;
use Email::MIME;
use Email::Sender::Simple;
use Email::Sender::Simple qw /sendmail/;
use CXGN::Trial::ParseUpload;
use CXGN::TrialStatus;
use CXGN::Calendar;
use CXGN::UploadFile;
use File::Path qw(make_path);
use File::Spec;

my ( $help, $dbhost, $dbname, $basepath, $dbuser, $dbpass, $infile, $sites, $types, $username, $breeding_program_name, $email_address, $logged_in_name, $temp_file_nd_experiment_id);
GetOptions(
    'dbhost|H=s'         => \$dbhost,
    'dbname|D=s'         => \$dbname,
    'dbpass|P=s'         => \$dbpass,
    'basepath|w=s'       => \$basepath,
    'dbuser|U=s'         => \$dbuser,
    'i=s'                => \$infile,
    'b=s'                => \$breeding_program_name,
    'user|un=s'          => \$username,
    'help'               => \$help,
    'email|e=s'          => \$email_address,
    # 'logged_in_user|l=s' => \$logged_in_name,
    'temp_file|r=s'      => \$temp_file_nd_experiment_id,
);

#Ensure the parent directory exists before creating the temporary file
my $parent_dir = File::Spec->catdir($basepath, 'static', 'documents', 'tempfiles', 'delete_nd_experiment_ids');
unless (-d $parent_dir) {
    make_path($parent_dir) or die "Failed to create directory $parent_dir: $!";
}

# Create the temporary file in the parent directory
my $temp_file_nd_experiment_id = File::Spec->catfile($parent_dir, 'fileXXXX');

pod2usage(1) if $help;
if (!$infile || !$breeding_program_name || !$username || !$dbname || !$dbhost ) { 
    pod2usage( { -msg => 'Error. Missing options!'  , -verbose => 1, -exitval => 1 } ) ;
}

my $dbh;

if ($dbpass) {
    print STDERR "Logging in with password\n";
    $dbh = DBI->connect("dbi:Pg:database=$dbname;host=$dbhost",
    $dbuser,
    $dbpass,
    {AutoCommit => 1,
    RaiseError => 1});
} else {
    $dbh = CXGN::DB::InsertDBH->new( {
        dbhost =>$dbhost,
        dbname =>$dbname,
        dbargs => {AutoCommit => 1,
        RaiseError => 1}
    });
}

print STDERR "Database connection ok!\n";

my $schema= Bio::Chado::Schema->connect(  sub { $dbh } ,  { on_connect_do => ['SET search_path TO  public, sgn, metadata, phenome;'] } );

# ################
# getting the last database ids for resetting at the end in case of rolling back
# ###############

# my $last_nd_experiment_id = $schema->resultset('NaturalDiversity::NdExperiment')->get_column('nd_experiment_id')->max;
# my $last_cvterm_id = $schema->resultset('Cv::Cvterm')->get_column('cvterm_id')->max;

# my $last_nd_experiment_project_id = $schema->resultset('NaturalDiversity::NdExperimentProject')->get_column('nd_experiment_project_id')->max;
# my $last_nd_experiment_stock_id = $schema->resultset('NaturalDiversity::NdExperimentStock')->get_column('nd_experiment_stock_id')->max;
# my $last_nd_experiment_phenotype_id = $schema->resultset('NaturalDiversity::NdExperimentPhenotype')->get_column('nd_experiment_phenotype_id')->max;
# my $last_phenotype_id = $schema->resultset('Phenotype::Phenotype')->get_column('phenotype_id')->max;
# my $last_stock_id = $schema->resultset('Stock::Stock')->get_column('stock_id')->max;
# my $last_stock_relationship_id = $schema->resultset('Stock::StockRelationship')->get_column('stock_relationship_id')->max;
# my $last_project_id = $schema->resultset('Project::Project')->get_column('project_id')->max;
# my $last_nd_geolocation_id = $schema->resultset('NaturalDiversity::NdGeolocation')->get_column('nd_geolocation_id')->max;
# my $last_geoprop_id = $schema->resultset('NaturalDiversity::NdGeolocationprop')->get_column('nd_geolocationprop_id')->max;
# my $last_projectprop_id = $schema->resultset('Project::Projectprop')->get_column('projectprop_id')->max;

# my %seq  = (
#     'nd_experiment_nd_experiment_id_seq' => $last_nd_experiment_id,
#     'cvterm_cvterm_id_seq' => $last_cvterm_id,
#     'nd_experiment_project_nd_experiment_project_id_seq' => $last_nd_experiment_project_id,
#     'nd_experiment_stock_nd_experiment_stock_id_seq' => $last_nd_experiment_stock_id,
#     'nd_experiment_phenotype_nd_experiment_phenotype_id_seq' => $last_nd_experiment_phenotype_id,
#     'phenotype_phenotype_id_seq' => $last_phenotype_id,
#     'stock_stock_id_seq'         => $last_stock_id,
#     'stock_relationship_stock_relationship_id_seq'  => $last_stock_relationship_id,
#     'project_project_id_seq'     => $last_project_id,
#     'nd_geolocation_nd_geolocation_id_seq'          => $last_nd_geolocation_id,
#     'nd_geolocationprop_nd_geolocationprop_id_seq'  => $last_geoprop_id,
#     'projectprop_projectprop_id_seq'                => $last_projectprop_id,
#     );


# ##############
# Breeding program for associating the trial/s ##
# ##############

my $breeding_program = $schema->resultset("Project::Project")->find(
    {'me.name'   => $breeding_program_name, 'type.name' => 'breeding_program'},
    { join       =>  { projectprops => 'type' }}
);

if (!$breeding_program) { die "Breeding program $breeding_program_name does not exist in the database. Check your input \n"; }
# print STDERR "Found breeding program $breeding_program_name " . $breeding_program->project_id . "\n";

my $sp_person_id= CXGN::People::Person->get_person_by_username($dbh, $username);
die "Need to have a user pre-loaded in the database! " if !$sp_person_id;

#Column headers for trial design/s
#plot_name	accession_name	plot_number	block_number	trial_name	trial_description	trial_location	year	trial_type	is_a_control	rep_number	range_number	row_number	col_number

#Parse the trials + designs first, then upload the phenotypes 

#new spreadsheet for design + phenotyping data ###
my $spreadsheet = CXGN::Tools::File::Spreadsheet->new($infile);

#Determine the type of file and setup workbook and worksheet
my ($xlsx_parser, $xls_parser, $workbook, $worksheet);
if ($infile =~ /\.xlsx$/i) {
    $xlsx_parser = Spreadsheet::ParseXLSX->new;
    $workbook = $xlsx_parser->parse($infile);
} elsif ($infile =~ /\.xls$/i) {
    $xls_parser = Spreadsheet::ParseExcel->new;
    $workbook = $xls_parser->parse($infile);
}

die "Could not parse file: $infile" if not defined $workbook;
$worksheet = $workbook->worksheet(0);

# Determine the last row with data to avoid processing empty rows
my $row_min = 1;
my $row_max = 0;

for my $row ($row_min .. $worksheet->row_range) {
    for my $col (0 .. $worksheet->col_range) {
        my $cell = $worksheet->get_cell($row, $col);
        if ($cell && $cell->value() =~ /\S/) {
            $row_max = $row;
        }
    }
}
# Populate trial rows and trial columns arrays based on the actual data-filled rows
my (@trial_rows, @trial_columns);
@trial_rows = map { my $cell = $worksheet->get_cell($_, 0); $cell ? $cell->value : '' } ($row_min .. $row_max);
@trial_columns = map { my $cell = $worksheet->get_cell(0, $_); $cell ? $cell->value : ''} (0 .. $worksheet->col_range);

# Map trial columns to parameters

my %trial_params = map { $_ => 1 } @trial_columns;
my %multi_trial_data;

for my $row ($row_min .. $row_max) {
    my $trial_name = $trial_rows[$row];
    next unless $trial_name;  # Skip rows with empty trial names

    my $trial_design    = first { $trial_columns[$_] eq 'design_type' } 0..@trial_columns;
    my $trial_year      = first { $trial_columns[$_] eq 'year' } 0..@trial_columns;
    my $location        = first { $trial_columns[$_] eq 'location' } 0..@trial_columns;
    my $accession_name  = first { $trial_columns[$_] eq 'accession_name' } 0..@trial_columns;
    my $plot_name       = first { $trial_columns[$_] eq 'plot_name' } 0..@trial_columns;
    my $plot_number     = first { $trial_columns[$_] eq 'plot_number' } 0..@trial_columns;

    my ($design_type, $year, $trial_location, $accessions, $plot_names, $plot_numbers);
    $design_type = $worksheet->get_cell($row, $trial_design) ? $worksheet->get_cell($row, $trial_design)->value : 'RCBD';
    $year = $worksheet->get_cell($row, $trial_year) ? $worksheet->get_cell($row, $trial_year)->value : undef;
    $trial_location = $worksheet->get_cell($row, $location) ? $worksheet->get_cell($row, $location)->value : undef;
    $accessions     = $worksheet->get_cell($row,$accession_name) ? $worksheet->get_cell($row, $accession_name)->value : undef;
    $plot_names     = $worksheet->get_cell($row, $plot_name) ? $worksheet->get_cell($row, $plot_name)->value : undef;
    $plot_numbers   = $worksheet->get_cell($row, $plot_number) ? $worksheet->get_cell($row, $plot_number)->value : undef;

    # print STDERR "Trial Name: $trial_name, Location: $trial_location, Design Type: $design_type, Year: $year\n";

    # Check if the location exists in the database
    my $location_rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search({
        description => { ilike => '%' . $trial_location . '%' },
    });
    if (scalar($location_rs) == 0) {
        die "ERROR: location must be pre-loaded in the database. Location name = '" . $trial_location . "'\n";
    }
    my $location_id = $location_rs->first->nd_geolocation_id;
    ######################################################

    #### optional params ######
    my ($planting_date, $fertilizer_date, $harvest_date, $sown_plants, $harvested_plants, $trial_type, $plot_width, $plot_length, $field_size);
    my $trial_description = $trial_name;
    # my %properties_hash;
    my $properties_hash;

    if (exists($trial_params{trial_description})) {
        $trial_description = $worksheet->get_cell($row, first { $trial_columns[$_] eq 'trial_description' } 0..$#trial_columns)->value;
    }

    # Store all data for the current trial
    $multi_trial_data{$trial_name}->{design_type}       = $design_type;
    $multi_trial_data{$trial_name}->{program}           = $breeding_program->name;
    $multi_trial_data{$trial_name}->{trial_year}        = $year;
    $multi_trial_data{$trial_name}->{trial_description} = $trial_description;
    $multi_trial_data{$trial_name}->{trial_location}    = $trial_location;
    $multi_trial_data{$trial_name}->{plot_name}         = $plot_names;
    $multi_trial_data{$trial_name}->{accession_name}    = $accessions;
}

print STDERR "unique trial names:\n";
foreach my $name(keys %multi_trial_data) {
    print"$name\n";
}

print STDERR "Reading phenotyping file:\n";
my %phen_params = map { if ($_ =~ m/^\w+\|(\w+:\d{7})$/ ) { $_ => $1 } } @trial_columns;
delete $phen_params{''};

my @traits = keys %phen_params;
print STDERR "Found traits: " . Dumper(\%phen_params) . "\n";

my %trial_design_hash;
my %phen_data_by_trial;

foreach my $plot_name (1 .. @trial_rows) {
    my ($trial_type, $plot_width, $plot_length, $field_size, $planting_date, $harvest_date, $is_a_control, $rep_number, $range_number, $row_number, $col_number, $seedlot_name, $num_seed_per_plot, $weight_gram_seed_per_plot, $plot_number, $trial_name);

    # Check if the corresponding cell values exist, and assign them if they do
    # $trial_type         = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'trial_type' } 0..@trial_columns)->value if exists $trial_params{'trial_type'}; #[1]
    # $plot_number        = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'plot_number' } 0..@trial_columns)->value if exists $trial_params{'plot_number'}; #[1]
    # $trial_name         = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'trial_name' } 0..@trial_columns)->value if exists $trial_params{'trial_name'}; #[1]
    # $plot_width         = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'plot_width' } 0..@trial_columns)->value if exists $trial_params{'plot_width'}; #[1]
    # $plot_length        = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'plot_length' } 0..@trial_columns)->value if exists $trial_params{'plot_length'}; #[1]
    # $field_size         = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'field_size' } 0..@trial_columns)->value if exists $trial_params{'field_size'}; #[1]
    # $planting_date      = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'planting_date' } 0..@trial_columns)->value if exists $trial_params{'planting_date'}; #[1]
    # $harvest_date       = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'harvest_date' } 0..@trial_columns)->value if exists $trial_params{'harvest_date'}; #[1]
    # $is_a_control       = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'is_a_control' } 0..@trial_columns)->value if exists $trial_params{'is_a_control'}; #[1]
    # $rep_number         = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'rep_number' } 0..@trial_columns)->value if exists $trial_params{'rep_number'}; #[1]
    # $range_number       = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'range_number' } 0..@trial_columns)->value if exists $trial_params{'range_number'}; #[1]
    # $row_number         = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'row_number' } 0..@trial_columns)->value if exists $trial_params{'row_number'}; #[1]
    # $col_number         = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'col_number' } 0..@trial_columns)->value if exists $trial_params{'col_number'}; #[1]

    $trial_type         = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'trial_type' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'trial_type' } 0..@trial_columns)->value : undef if exists $trial_params{'trial_type'};
    $plot_number        = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'plot_number' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'plot_number' } 0..@trial_columns)->value : undef if exists $trial_params{'plot_number'};
    $trial_name         = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'trial_name' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'trial_name' } 0..@trial_columns)->value : undef if exists $trial_params{'trial_name'};
    $plot_width         = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'plot_width' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'plot_width' } 0..@trial_columns)->value : undef if exists $trial_params{'plot_width'};
    $plot_length        = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'plot_length' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'plot_length' } 0..@trial_columns)->value : undef if exists $trial_params{'plot_length'};
    $field_size         = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'field_size' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'field_size' } 0..@trial_columns)->value : undef if exists $trial_params{'field_size'};
    $planting_date      = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'planting_date' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'planting_date' } 0..@trial_columns)->value : undef if exists $trial_params{'planting_date'};
    $harvest_date       = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'harvest_date' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'harvest_date' } 0..@trial_columns)->value : undef if exists $trial_params{'harvest_date'};
    $is_a_control       = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'is_a_control' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'is_a_control' } 0..@trial_columns)->value : undef if exists $trial_params{'is_a_control'};
    $rep_number         = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'rep_number' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'rep_number' } 0..@trial_columns)->value : undef if exists $trial_params{'rep_number'};
    $range_number       = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'range_number' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'range_number' } 0..@trial_columns)->value : undef if exists $trial_params{'range_number'};
    $row_number         = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'row_number' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'row_number' } 0..@trial_columns)->value : undef if exists $trial_params{'row_number'};
    $col_number         = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'col_number' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'col_number' } 0..@trial_columns)->value : undef if exists $trial_params{'col_number'};
    $seedlot_name       = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'seedlot_name' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'seedlot_name' } 0..@trial_columns)->value : undef if exists $trial_params{'seedlot_name'};
    $num_seed_per_plot  = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'num_seed_per_plot' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'num_seed_per_plot' } 0..@trial_columns)->value : undef if exists $trial_params{'num_seed_per_plot'};
    $weight_gram_seed_per_plot = defined $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'weight_gram_seed_per_plot' } 0..@trial_columns) ? $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'weight_gram_seed_per_plot' } 0..@trial_columns)->value : undef if exists $trial_params{'weight_gram_seed_per_plot'};

    # $plot_name # Check if plot_number is defined, if not, assign a default value
    if (!$plot_number) {
        $plot_number = 1;
        my @keys =(keys %{ $trial_design_hash{$trial_name}});
        my $max = max( @keys );
        if ( $max ) {
            $max++;
            $plot_number = $max;
        }
    }

    $trial_design_hash{$trial_name}{$plot_number} = {
        trial_name      => $trial_name,
        trial_type      => $trial_type,
        planting_date   => $planting_date,
        harvest_date    => $harvest_date,
        is_a_control    => $is_a_control,
        rep_number      => $rep_number,
        range_number    => $range_number,
        row_number      => $row_number,
        col_number      => $col_number,
        seedlot_name    => $seedlot_name,
        num_seed_per_plot => $num_seed_per_plot,
        weight_gram_seed_per_plot => $weight_gram_seed_per_plot,
    };

    ### Add the plot name into the multi trial data hashref of hashes ###
    push( @{ $multi_trial_data{$trial_name}->{plots} } , $plot_name );

    #parse the phenotype data
    my $timestamp;# timestamp value if storing those ##
    foreach my $trait_string (keys %phen_params) {
        my $phen_value = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq $trait_string } 0..@trial_columns);
        $phen_data_by_trial{$trial_name}{$plot_name}{$trait_string} = [$phen_value, $timestamp];
    }
}

print STDERR "multi trial hash:" . Dumper(\%multi_trial_data);
print STDERR "trial design " . Dumper(\%trial_design_hash);
print STDERR "Processed trials: " . scalar(keys %trial_design_hash) . "\n";
print STDERR "Phen data by trial: " . Dumper(\%phen_data_by_trial) . "\n";

#####create the design hash#####
print Dumper(\%trial_design_hash);
foreach my $trial_name (keys %trial_design_hash) {
   $multi_trial_data{$trial_name}->{design} = $trial_design_hash{$trial_name} ;
}

my $date = localtime();
my $parser;
my %parsed_data;
my $parse_errors;
my $parsed_data;
my $ignore_warnings;
my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();

####required phenotypeprops###
my %phenotype_metadata ;
$phenotype_metadata{'archived_file'} = $infile;
$phenotype_metadata{'archived_file_type'} = "spreadsheet phenotype file";
$phenotype_metadata{'operator'} = $username;
$phenotype_metadata{'date'} = $date;

#parse uploaded file with appropriate plugin
$parser = CXGN::Trial::ParseUpload->new(chado_schema => $schema, filename => $infile);
$parser->load_plugin('MultipleTrialDesignExcelFormat');
$parsed_data = $parser->parse();

if (!$parsed_data) {
    my $return_error = '';
    if (! $parser->has_parse_errors() ){
        die "could not get parsing erros\n";
    }else {
        $parse_errors = $parser->get_parse_errors();
        die $parse_errors->{'error_messages'};        
    }
}

if ($parser->has_parse_warnings()) {
    unless ($ignore_warnings) {
        my $warnings = $parser->get_parse_warnings();
        print "Warnings: " . join("\n", @{$warnings->{'warning_messages'}}) . "\n";
    }
}
# print STDERR "please check errors from here \n";


my %all_desings = %{$parsed_data};
my %save;
$save{'errors'} = [];

my $coderef= sub  {
    foreach my $trial_name (keys %multi_trial_data) {
        my $trial_location = $multi_trial_data{$trial_name}->{trial_location};
        my $trial_design_info = $all_desings{$trial_name};
        
        my %trial_info_hash = (
            chado_schema      => $schema,
            dbh               => $dbh,
            trial_year        => $trial_design_info->{'year'},
            trial_description => $trial_design_info->{'description'},
            trial_location    => $trial_design_info->{'location'},
            trial_name        => $trial_name,
            design_type       => $trial_design_info->{'design_type'},
            design            => $trial_design_info->{'design_details'},
            program           => $trial_design_info->{'breeding_program'},
            operator          => $username,
            owner_id          => $sp_person_id,
        );

        if ($trial_design_info->{'trial_type'}){
            $trial_info_hash{trial_type} = $trial_design_info->{'trial_type'};
        }
        if ($trial_design_info->{'plot_width'}){
            $trial_info_hash{plot_width} = $trial_design_info->{'plot_width'};
        }
        if ($trial_design_info->{'plot_length'}){
            $trial_info_hash{plot_length} = $trial_design_info->{'plot_length'};
        }
        if ($trial_design_info->{'field_size'}){
            $trial_info_hash{field_size} = $trial_design_info->{'field_size'};
        }
        if ($trial_design_info->{'planting_date'}){
            $trial_info_hash{planting_date} = $trial_design_info->{'planting_date'};
        }
        if ($trial_design_info->{'harvest_date'}){
            $trial_info_hash{harvest_date} = $trial_design_info->{'harvest_date'};
        }
        my $trial_create = CXGN::Trial::TrialCreate->new(%trial_info_hash);
        my $current_save = $trial_create->save_trial();

        if ($current_save->{error}){
            # $schema->txn_rollback();
            push @{$save{'errors'}}, $current_save->{'error'};
        } elsif ($current_save->{'trial_id'}) {
            my $trial_id = $current_save->{'trial_id'};
            my $timestamp = $time->ymd();
            my $calendar_funcs = CXGN::Calendar->new({});
            my $formatted_date = $calendar_funcs->check_value_format($timestamp);
            my $upload_date = $calendar_funcs->display_start_date($formatted_date);

            my %trial_activity;
            $trial_activity{'Trial Uploaded'}{'user_id'} = $sp_person_id;
            $trial_activity{'Trial Uploaded'}{'activity_date'} = $upload_date;

            my $trial_activity_obj = CXGN::TrialStatus->new({ bcs_schema => $schema });
            $trial_activity_obj->trial_activities(\%trial_activity);
            $trial_activity_obj->parent_id($trial_id);
            my $activity_prop_id = $trial_activity_obj->store();
        }

        print STDERR "TrialCreate object created for trial: $trial_name\n";

        my @plots = @{ $multi_trial_data{$trial_name}->{plots} };
        print STDERR "Trial Name = $trial_name\n";

        my %parsed_data = $phen_data_by_trial{$trial_name};
        if (scalar(@traits) > 0) {
            foreach my $pname (keys %parsed_data) {
	            print STDERR "PLOT = $pname\n";
	            my %trait_string_hash = $parsed_data{$pname};

	            foreach my $trait_string (keys %trait_string_hash ) {
		            print STDERR "trait = $trait_string\n";
		            print STDERR "value =  " . $trait_string_hash{$trait_string}[0] . "\n";
	            }
 	        }

	        # # after storing the trial desgin store the phenotypes
            my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh->get_actual_dbh() }, {on_connect_do => ['SET search_path TO metadata;'] } );
            my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh() } , {on_connect_do => ['SET search_path TO phenome, sgn, public;'] } );
            my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
                basepath                    => $basepath,
                dbhost                      => $dbhost,
                dbname                      => $dbname,
                dbuser                      => $dbuser,
                dbpass                      => $dbpass,
                temp_file_nd_experiment_id  => $temp_file_nd_experiment_id,
	            bcs_schema                  => $schema,
	            metadata_schema             => $metadata_schema,
	            phenome_schema              => $phenome_schema,
	            user_id                     => $sp_person_id,
	            stock_list                  => \@plots,
	            trait_list                  => \@traits,
	            values_hash                 => \%parsed_data,
	            has_timestamps              => 0,
	            overwrite_values            => 0,
	            metadata_hash               => \%phenotype_metadata,
            );

	        #store the phenotypes
	        my ($verified_warning, $verified_error) = $store_phenotypes->verify();
	        # print STDERR "Verified phenotypes. warning = $verified_warning, error = $verified_error\n";
	        my $stored_phenotype_error = $store_phenotypes->store();
	        # print STDERR "Stored phenotypes Error:" . Dumper($stored_phenotype_error). "\n";
        } else {
            print STDERR "No traits defined for these $trial_name\n";
        }
    }
};

my ($email_subject, $email_body);

try {
    $schema->txn_do($coderef);
    if ($email_address) {
        print "Transaction succeeded! Committing project and its metadata \n\n";

        $email_subject = "Multiple Trial Designs upload status";
        $email_body    = "Dear $logged_in_name,\n\nCongratulations, all the multiple trial designs have been successfully uploaded into the database\n\nThank you\nHave a nice day\n\n";

        my $email = Email::MIME->create(
            header_str => [
                From    => 'noreply@breedbase.org',
                To      => $email_address,
                Subject => $email_subject,
            ],
            attributes => {
                charset  => 'UTF-8',
                encoding => 'quoted-printable',  
            },
            body_str => $email_body,
        );

        my $email_string = $email->as_string; 
        sendmail($email_string);   
    }
} catch {
    # Transaction failed
    my $error_message = "An error occurred! Rolling back! $_\n";

    $email_subject = 'Error in Trial Upload';
    $email_body    = "Dear $logged_in_name,\n\n$error_message\nPlease correct these errors and upload again\n\nThank You\nHave a nice day\n";

    print STDERR $error_message;

    my $error_email = Email::MIME->create(
        header_str => [
            From    => 'noreply@breedbase.org',
            To      => $email_address,
            Subject => $email_subject,
        ],
        attributes => {
            charset  => 'UTF-8',
            encoding => 'quoted-printable',
        },
        body_str => $email_body,
    );

    my $error_email_string = $error_email->as_string;  
    sendmail($error_email_string);

};

1;