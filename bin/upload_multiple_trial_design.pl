#!/usr/bin/perl

=head1

upload_multiple_trial_design.pl

=head1 SYNOPSIS

    upload_multiple_trial_design.pl  -H [dbhost] -D [dbname] -P [dbpass] -w [basepath] -U [dbuser] -b [breeding program name]  -i infile -un [username] -e [email address] -eo [email_option_enabled] -r [temp_file_nd_experiment_id]

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
use File::Basename;
use CXGN::File::Parse;
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
use CXGN::Contact;
use CXGN::Trial::ParseUpload;
use CXGN::TrialStatus;
use CXGN::Calendar;
use CXGN::UploadFile;
use File::Path qw(make_path);
use File::Spec;
use JSON::MaybeXS qw(encode_json);

# sub print_json_error {
#     my ($message) = @_;
#     my $error_response = {
#         status  => 'error',
#         message => $message,
#     };
#     print header('application/json');
#     print encode_json($error_response);
#     exit;
# }

sub print_json_response {
    my ($status, $message) = @_;
    my $response = {
        status  => $status,
        message => $message,
    };
    print encode_json($response);
    exit;
}

my ( $help, $dbhost, $dbname, $basepath, $dbuser, $dbpass, $infile, $sites, $types, $username, $breeding_program_name, $email_address, $logged_in_name, $email_option_enabled, $temp_file_nd_experiment_id);
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
    'email_option_enabled|eo=s' => \$email_option_enabled,
);

#Ensure the parent directory exists before creating the temporary file
my $parent_dir = File::Spec->catdir($basepath, 'static', 'documents', 'tempfiles', 'delete_nd_experiment_ids');
unless (-d $parent_dir) {
    # make_path($parent_dir) or die "Failed to create directory $parent_dir: $!";
    print_json_response('error', "Failed to create directory $parent_dir: $!");
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

if (!$breeding_program) {
    print_json_response('error', "Breeding program $breeding_program_name does not exist in the database. Check your input");
}
    # die "Breeding program $breeding_program_name does not exist in the database. Check your input \n"; }
# print STDERR "Found breeding program $breeding_program_name " . $breeding_program->project_id . "\n";

my $sp_person_id= CXGN::People::Person->get_person_by_username($dbh, $username);
if (!$sp_person_id) {
    print_json_response('error', "Need to have a user pre-loaded in the database!");
}
# die "Need to have a user pre-loaded in the database! " if !$sp_person_id;

#Column headers for trial design/s
#plot_name	accession_name	plot_number	block_number	trial_name	trial_description	trial_location	year	trial_type	is_a_control	rep_number	range_number	row_number	col_number entry_numbers

#parse file using the generic file parser
my $parser = CXGN::File::Parse->new(
    file => $infile,
    required_columns => ['trial_name', 'accession_name', 'plot_number', 'block_number', 'location', 'year'],
);

# warn "Starting to parse the file...\n";
my $parsed = $parser->parse();
# warn "Parsed data = " . Dumper($parsed);
if (scalar(@{$parsed->{errors}}) > 0) {
    print_json_response('error', "Error parsing file: " . join(',', @{$parsed->{errors}}));
}
# die "Error parsing file: " . join(',', @{$parsed->{errors}}) if scalar(@{$parsed->{errors}}) > 0;

if (exists $parsed->{warnings}) {
    print "Warnings: " . join("\n", @{$parsed->{warnings}}) . "\n";
}
# #parse the file
# my $parsed = $parser->parse();

# if (scalar(@{$parsed->{errors}}) > 0) {
#     die "Error parsing file:  ".join(',', @{$parsed->{errors}});
# }

my @traits;
my %multi_trial_data;
my %metadata_fields = map { $_ => 1 } qw(trial_name accession_name plot_number block_number location year design_type trial_description);

foreach my $row (@{$parsed->{data}}) {
    my $trial_name = $row->{trial_name};
    next unless $trial_name;  # Skip rows with empty trial names

    # Check if the location exists in the database
    my $trial_location = $row->{location};
    my $location_rs    = $schema->resultset("NaturalDiversity::NdGeolocation")->search({
        description => { ilike => '%' . $trial_location . '%' },
    });
    if (scalar($location_rs) == 0) {
        print_json_response('error', "ERROR: location must be pre-loaded in the database. Location name = '" . $trial_location . "'");
        # die "ERROR: location must be pre-loaded in the database. Location name = '" . $trial_location . "'\n";
    }
    my $location_id = $location_rs->first->nd_geolocation_id;
    ######################################################

    # # Store all data for the current trial
    $multi_trial_data{$trial_name} = {
        trial_location    => $row->{location},
        trial_year        => $row->{year},
        design_type       => $row->{design_type},
        trial_description => $row->{description},
        program           => $breeding_program->name,
        plot_name         => $row->{plot_name},
        accession_name    => $row->{accession_name},
        plots            => [],
    };

    foreach my $col (@{$parsed->{columns}}) {
        next if exists $metadata_fields{$col};
    }
}

print STDERR "unique trial names:\n";
foreach my $name(keys %multi_trial_data) {
    print"$name\n";
}

print STDERR "Reading phenotyping file:\n";
my %phen_params = map { if ($_ =~ m/^\w+\|(\w+:\d{7})$/ ) { $_ => $1 } } @traits;
delete $phen_params{''};

# my @traits = keys %phen_params;
print STDERR "Found traits: " . Dumper(\%phen_params) . "\n";


foreach my $trial_name (keys %multi_trial_data) {
    $multi_trial_data{$trial_name}->{design} = $multi_trial_data{$trial_name};

}

my %trial_design_hash;
my %phen_data_by_trial;

foreach my $row (@{$parsed->{data}}) {
    my $trial_name = $row->{trial_name};
    next unless $trial_name;

    my $plot_number = $row->{plot_number};
    my $plot_name = $row->{plot_name};
    $trial_design_hash{$trial_name}{$plot_number} = {
        trial_name                => $trial_name,
        trial_type                => $row->{trial_type},
        planting_date             => $row->{planting_date},
        harvest_date              => $row->{harvest_date},
        entry_numbers             => $row->{entry_numbers},
        is_a_control              => $row->{is_a_control},
        rep_number                => $row->{rep_number},
        range_number              => $row->{range_number},
        row_number                => $row->{row_number},
        col_number                => $row->{col_number},
        seedlot_name              => $row->{seedlot_name},
        num_seed_per_plot         => $row->{num_seed_per_plot},
        weight_gram_seed_per_plot => $row->{weight_gram_seed_per_plot},
    };

    foreach my $trait_string (keys %phen_params) {
       my $phen_value = $row->{$trait_string};
       $phen_data_by_trial{$trial_name}{$plot_name}{$trait_string} = [$phen_value, DateTime->now->datetime];
    }
}

print STDERR "multi trial hash:" . Dumper(\%multi_trial_data);
print STDERR "trial design " . Dumper(\%trial_design_hash);
print STDERR "Processed trials: " . scalar(keys %trial_design_hash) . "\n";
print STDERR "Phen data by trial: " . Dumper(\%phen_data_by_trial) . "\n";

#####create the design hash#####
print Dumper(keys %trial_design_hash);
foreach my $trial_name (keys %trial_design_hash) {
   $multi_trial_data{$trial_name}->{design} = $trial_design_hash{$trial_name} ;
}

my $date = localtime();
my $parser;
my %parsed_data;
my $parse_errors;
my @errors;
my $parsed_data;
my $ignore_warnings;
my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();

my %phenotype_metadata = {
    'archived_file'      => $infile,
    'archived_file_type' => 'spreadsheet phenotype file',
    'operator'           => $username,
    'date'               => $date,
};

#parse uploaded file with appropriate plugin
$parser = CXGN::Trial::ParseUpload->new(chado_schema => $schema, filename => $infile);
$parser->load_plugin('MultipleTrialDesignExcelFormat');
$parsed_data = $parser->parse();


if (!$parsed_data) {
    my $return_error = '';

    if (! $parser->has_parse_errors() ){
        # die "could not get parsing errors\n";
        print_json_response('error', "could not get parsing errors\n");
    }else {
        $parse_errors = $parser->get_parse_errors();
        # die $parse_errors->{'error_messages'};
        print_json_response('error', $parse_errors->{'error_messages'});
    }

    print_json_response('error', $return_error);
}

if ($parser->has_parse_warnings()) {
    unless ($ignore_warnings) {
        my $warnings = $parser->get_parse_warnings();
        print "Warnings: " . join("\n", @{$warnings->{'warning_messages'}}) . "\n";
    }
}


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

        # my $entry_numbers = $trial_design->{'entry_numbers'};

        if ($trial_design_info->{'entry_numbers'}){
            $trial_info_hash{trial_type} = $trial_design_info->{'entry_numbers'};
        }
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

        # save entry numbers, if provided
        my $entry_numbers;
        if ($entry_numbers = $trial_design_info->{'entry_numbers'}) {
            if (scalar(keys %$entry_numbers) > 0 && $current_save->{'trial_id'} ) {
                my %entry_numbers_prop;
                my @stock_names = keys %$entry_numbers;

                # Convert stock names from parsed trial template to stock ids for data storage
                my $stocks = $schema->resultset('Stock::Stock')->search({ uniquename=>{-in=>\@stock_names} });
                while (my $s = $stocks->next()) {
                    $entry_numbers_prop{$s->stock_id} = $entry_numbers->{$s->uniquename};
                }

                # Lookup synonyms of accession names
                my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
                my $acc_synonym_rs = $schema->resultset("Stock::Stock")->search({
                    'me.is_obsolete' => { '!=' => 't' },
                    'stockprops.value' => { -in => \@stock_names},
                    'stockprops.type_id' => $synonym_cvterm_id
                },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});
                while (my $r=$acc_synonym_rs->next) {
                    if ( exists($entry_numbers->{$r->get_column('synonym')}) ) {
                        $entry_numbers_prop{$r->stock_id} = $entry_numbers->{$r->get_column('synonym')};
                    }
                }

                # store entry numbers
                my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $current_save->{'trial_id'} });
                $trial->set_entry_numbers(\%entry_numbers_prop);
            }
        }

        print STDERR "TrialCreate object created for trial: $trial_name\n";

        my @plots = @{$multi_trial_data{$trial_name}->{plots} // []};
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

    if ($email_option_enabled == 1 && $email_address) {
        print "Transaction succeeded! Committing project and its metadata \n\n";
        
        $email_subject = "Multiple Trial Designs upload status";
        $email_body    = "Dear $username,\n\nCongratulations, all the multiple trial designs have been successfully uploaded into the database\n\nThank you\nHave a nice day\n\n";
        
        CXGN::Contact::send_email($email_subject, $email_body, $email_address);
    }
} catch {
    # Transaction failed
    my $error_message = "An error occurred! Rolling back! $_\n";
    # push @errors, $error_message;
    # push @{$save{'errors'}}, $error_message;
    # print STDERR $error_message;

    if ($email_option_enabled == 1 && $email_address) {
        $email_subject = 'Error in Trial Upload';
        $email_body    = "Dear $username,\n\n$error_message\n\nThank You\nHave a nice day\n";

        # print STDERR $error_message;

        CXGN::Contact::send_email($email_subject, $email_body, $email_address);
    }
};

1;