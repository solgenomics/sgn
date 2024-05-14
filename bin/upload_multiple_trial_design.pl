=head1

upload_multiple_trial_design.pl

=head1 SYNOPSIS

    #upload_multiple_trial_design.pl  -H [dbhost] -D [dbname] -i infile -b [breeding program name] -u [username] -m [trial metadata file] [-t] -e [email address] -l [logged in user]
    upload_multiple_trial_design.pl  -H [dbhost] -D [dbname] -i infile -b [breeding program name] -u [username] -e [email address] -l [logged in user]

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name
 -i infile 
 -u username  (must be in the database) 
 -b breeding program name (must be in the database)  
 #-t  Test run . Rolling back at the end.
 #-m trial metadata file - if loading metadata from separate file
 -e email address of the user
 -l name of the user
if loading trial data from metadata file, phenotypes + layout from infile 


=head2 DESCRIPTION

    # Load multi-trial data - trial layout + minimal metadata + phenotype data for each trial
    load multi-trial data - trial design file only

##CHECK cvterms for trial metadata!! 


################################################
# Minimal metadata requirements are
#     trial_name
#     trial_description (can also be built from the trial name, type, year, location)
#     trial_type (read from an input file)
#     trial_location geo_description ( must be in the database - nd_geolocation.description - can  be read from metadata file) 
#     year (can be read from the metadata file )
#     design (defaults to 'RCBD' )
#     breeding_program (provide with option -b )


# Other OPTIONAL trial metadata (projectprops)
 
#  project planting date
#  project fertilizer date
#  project harvest date
#  project sown plants
#  project harvested plants


Srikanth (sk2783@cornell.edu)

=cut


#!/usr/bin/perl
use strict;
use Getopt::Long;
use CXGN::Tools::File::Spreadsheet;
use Text::CSV; #this module si for handling the csv files
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

my ( $help, $dbhost, $dbname, $infile, $sites, $types, $test, $username, $breeding_program_name, $metadata_file, $email_address, $logged_in_name);
GetOptions(
    'i=s'        => \$infile,
    'b=s'        => \$breeding_program_name,
    #'m=s'        => \$metadata_file,
    #'t'          => \$test,
    'user|u=s'   => \$username,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost,
    'help'       => \$help,
    'email|e=s'  => \$email_address,
    # 'results_url|r=s' => \$results_url,
    'logged_in_user|l=s' => \$logged_in_name,
);



pod2usage(1) if $help;
if (!$infile || !$breeding_program_name || !$username || !$dbname || !$dbhost ) {
    pod2usage( { -msg => 'Error. Missing options!'  , -verbose => 1, -exitval => 1 } ) ;
}


my $dbh = CXGN::DB::InsertDBH->new( {
    dbhost=>$dbhost,
    dbname=>$dbname,
    dbargs => {AutoCommit => 1,
    RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } ,  { on_connect_do => ['SET search_path TO  public;'] } );


my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh->get_actual_dbh() } , {on_connect_do => ['SET search_path TO metadata;'] } );

my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh() } , {on_connect_do => ['SET search_path TO phenome;'] } );

#################
#getting the last database ids for resetting at the end in case of rolling back
################

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


###############
#Breeding program for associating the trial/s ##
###############

my $breeding_program = $schema->resultset("Project::Project")->find(
    {'me.name'   => $breeding_program_name, 'type.name' => 'breeding_program'},
    { join       =>  { projectprops => 'type' }}
);

if (!$breeding_program) { die "Breeding program $breeding_program_name does not exist in the database. Check your input \n"; }
print "Found breeding program $breeding_program_name " . $breeding_program->project_id . "\n";

my $sp_person_id= CXGN::People::Person->get_person_by_username($dbh, $username);
my $operator_username = CXGN::People::Person->get_person_by_username($dbh, $username);
my $temp_file_nd_experiment_id = 0;

##Column headers for trial design/s
#plot_name	accession_name	plot_number	block_number	trial_name	trial_description	trial_location	year	trial_type	is_a_control	rep_number	range_number	row_number	col_number

###################
#trial metadata can be loaded from a separate data sheet
###################

##Parse the trials + designs first, then upload the phenotypes 

##new spreadsheet for design + phenotyping data ###
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

# print STDERR "Trial design rows    = " . Dumper(\@trial_rows);
# print "Trial design columns = " . Dumper(\@trial_columns);

# Map trial columns to parameters

my %trial_params = map { $_ => 1 } @trial_columns;
my %multi_trial_data;

for my $row ($row_min .. $row_max) {
    my $trial_name = $trial_rows[$row];
    next unless $trial_name;  # Skip rows with empty trial names

    my $trial_design = first { $trial_columns[$_] eq 'design_type' } 0..@trial_columns;
    my $trial_year = first { $trial_columns[$_] eq 'year' } 0..@trial_columns;
    my $location = first { $trial_columns[$_] eq 'location' } 0..@trial_columns;

    my ($design_type, $year, $trial_location);
    $design_type = $worksheet->get_cell($row, $trial_design) ? $worksheet->get_cell($row, $trial_design)->value : 'RCBD';
    $year = $worksheet->get_cell($row, $trial_year) ? $worksheet->get_cell($row, $trial_year)->value : undef;
    $trial_location = $worksheet->get_cell($row, $location) ? $worksheet->get_cell($row, $location)->value : undef;
    
    print STDERR "Row: $row, Trial Name: $trial_name, Location: $trial_location, Design Type: $design_type, Year: $year\n";

    # print "Trial = $trial_name, design = $design_type, year = $year, location = $trial_location\n";
    # print STDERR "Trial name: $trial_name\n";
    # print STDERR "Trial locations: $trial_location\n";

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
    my ($planting_date, $fertilizer_date, $harvest_date, $sown_plants, $harvested_plants);
    my $trial_description = $trial_name;
    my %properties_hash;
    foreach my $param (qw(planting_date fertilizer_date harvest_date sown_plants harvested_plants trial_description)) {
        if (exists($trial_params{$param})) {
            my $param_index = first { $trial_columns[$_] eq $param } 0..@trial_columns;
            next unless defined $param_index;
            my $cell_value = $worksheet->get_cell($row, $param_index);
            if ($cell_value) {
                $properties_hash{"project $param"} = $cell_value->value;
            }
        }
    }

    # Store all data for the current trial
    $multi_trial_data{$trial_name} = {
        design_type       => $design_type,
        program           => $breeding_program->name,
        trial_year        => $year,
        trial_location    => $trial_location,
        trial_description => $trial_description, #$properties_hash{'trial_description'} // $trial_name,
        trial_properties  => \%properties_hash,
    };

    if (exists $multi_trial_data{$trial_name}) {
        print STDERR "Warning: Key 'trial_name' exists in %multi_trial_data hash.\n";
    }
};

# Print all trial location names to check if they are stored correctly
print STDERR "All trial location names:\n";
foreach my $trial_name (keys %multi_trial_data) {
    my $trial_location = $multi_trial_data{$trial_name}->{trial_location};
    if (defined $trial_location) {
        print STDERR "Trial Name: $trial_name, Location: $trial_location\n";
    } else {
        print STDERR "Trial Name: $trial_name, Location is undef\n";
    }
}

# print STDERR "Trial design rows     = " . Dumper(\@trial_rows); #print the array of trial rows from the infile
# print STDERR "Trial design columns  = " . Dumper(\@trial_columns); #print the array of trial columns from the infile
# print STDERR "Processed trials      : " . scalar(keys %multi_trial_data) . "\n"; #print the number of unique trials
# print STDERR "Trial data details    : " . Dumper(\%multi_trial_data) . "\n";

# print STDERR "unique trial names:\n";
# foreach my $name(keys %multi_trial_data) {
#     print"$name\n";
# }

# Now read the design + phenotypes file
print STDERR "Reading phenotyping file:\n";
my %phen_params = map { if ($_ =~ m/^\w+\|(\w+:\d{7})$/ ) { $_ => $1 } } @trial_columns;
delete $phen_params{''};

my @traits = keys %phen_params;
# print STDERR "Found traits: " . Dumper(\%phen_params) . "\n";

my %trial_design_hash;
my %phen_data_by_trial;

foreach my $plot_name (1 .. @trial_rows) {
    my $accession    = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'accession_name' } 0..@trial_columns)->value;
    my $plot_number  = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'plot_number' } 0..@trial_columns)->value;
    my $block_number = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'block_number' } 0..@trial_columns)->value;
    my $trial_name   = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'trial_name' } 0..@trial_columns)->value;
    my $is_a_control = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'is_a_control' } 0..@trial_columns)->value;
    my $rep_number   = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'rep_number' } 0..@trial_columns)->value;
    my $range_number = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'range_number' } 0..@trial_columns)->value;
    my $row_number   = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'row_number' } 0..@trial_columns)->value;
    my $col_number   = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq 'col_number' } 0..@trial_columns)->value;

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
        plot_number => $plot_number,
        stock_name  => $accession,
        plot_name   => $plot_name,
        block_number=> $block_number,
        is_a_control=> $is_a_control,
        rep_number  => $rep_number,
        range_number=> $range_number,
        row_number  => $row_number,
        col_number  => $col_number,
    };

    ### Add the plot name into the multi trial data hashref of hashes ###
    push( @{ $multi_trial_data{$trial_name}->{plots} } , $plot_name );

    #parse the phenotype data
    my $timestamp;# timestamp value if storing those ##
    foreach my $trait_string (keys %phen_params) {
        my $phen_value = $worksheet->get_cell($plot_name, first { $trial_columns[$_] eq $trait_string } 0..@trial_columns);
        $phen_data_by_trial{$trial_name}{$plot_name}{$trait_string} = [$phen_value, $timestamp];
    }
    ###########
}

print STDERR "multi trial hash:" . Dumper(\%multi_trial_data);
# print STDERR "trial design " . Dumper(\%trial_design_hash);
# print STDERR "Processed trials: " . scalar(keys %trial_design_hash) . "\n";
# print STDERR "Trial design hash: " . Dumper(\%trial_design_hash) . "\n";
# print STDERR "Phen data by trial: " . Dumper(\%phen_data_by_trial) . "\n";

#####create the design hash#####
#print Dumper(\%trial_design_hash);
#foreach my $trial_name (keys %trial_design_hash) {
#    $multi_trial_data{$trial_name}->{design} = $trial_design_hash{$trial_name} ;
#}

my $date = localtime();

####required phenotypeprops###
my %phenotype_metadata ;
$phenotype_metadata{'archived_file'} = $infile;
$phenotype_metadata{'archived_file_type'} = "spreadsheet phenotype file";
$phenotype_metadata{'operator'} = $username;
$phenotype_metadata{'date'} = $date;

my $coderef= sub  {
    my $hash_undefined_locations = 0;
    foreach my $trial_name (keys %multi_trial_data) {
        my $trial_location = $multi_trial_data{$trial_name}->{trial_location};
        # if (!defined $trial_location) {
        #     $hash_undefined_locations = 1;
        #     print STDERR "Trial location is undefined for these trials: $trial_name. Skipping this trial creation.\n";
        #     next;
        # }

        # # Printing all the trial names from the multi_trial_data hash
        # print STDERR "All trial names:\n";
        # foreach my $trial_name (keys %multi_trial_data) {
        #     print STDERR "$trial_name\n";
        # }

        # # Printing all the trial locations in the multi_trial_data hash
        # print STDERR "All trial location names:\n";
        # foreach my $trial_name (keys %multi_trial_data) {
        #     my $location = $multi_trial_data{$trial_name}->{trial_location};
        #     if (defined $location) {
        #         print STDERR "Trial Name: $trial_name, Location: $location\n";
        #     } else {
        #         $hash_undefined_locations = 1;
        #         print STDERR "Trial location is undefined: $trial_name\n";
        #     }
        # }


        # print STDERR "Creating trial: $trial_name\n";  # Debug statement
        # print STDERR "Trial details:\n";
        # print STDERR "Design Type: " . ($multi_trial_data{$trial_name}->{design_type} || 'RCBD') . "\n";
        # print STDERR "Program: " . $breeding_program->name() . "\n";
        # print STDERR "Year: " . $multi_trial_data{$trial_name}->{trial_year} . "\n";
        # print STDERR "Description: " . $multi_trial_data{$trial_name}->{trial_description} . "\n";
        # print STDERR "Location: " . $trial_location . "\n";

        my $trial_create = CXGN::Trial::TrialCreate->new({
            chado_schema      => $schema,
            dbh               => $dbh,
            design_type       => $multi_trial_data{$trial_name}->{design_type} || 'RCBD',
            design            => $trial_design_hash{$trial_name},
            program           => $breeding_program->name(),
            trial_year        => $multi_trial_data{$trial_name}->{trial_year},
            trial_description => $multi_trial_data{$trial_name}->{trial_description},
            trial_location    => $trial_location,
            trial_name        => $trial_name,
            operator          => $operator_username,
            owner_id          => $sp_person_id,
        });

        print STDERR "TrialCreate object created for trial: $trial_name\n";  # Debug statement

        try {
            $trial_create->save_trial();
            print STDERR "Trial '$trial_name' saved successfully.\n";
        } catch {
            print STDERR "ERROR SAVING TRIAL!: $_\n";
            print STDERR "Error details: Trial Name = $trial_name, Location = $trial_location\n";  # Debug statement
        };
 
        my @plots = @{ $multi_trial_data{$trial_name}->{plots} };
        print STDERR "Trial Name = $trial_name\n";

        my %parsed_data = $phen_data_by_trial{$trial_name};
        foreach my $pname (keys %parsed_data) {
	        print STDERR "PLOT = $pname\n";
	        my %trait_string_hash = $parsed_data{$pname};

	        foreach my $trait_string (keys %trait_string_hash ) {
		        print STDERR "trait = $trait_string\n";
		        print STDERR "value =  " . $trait_string_hash{$trait_string}[0] . "\n";
	        }
 	    }

	    #print Dumper(\%parsed_data);
	    # after storing the trial desgin store the phenotypes
	    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
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
            temp_file_nd_experiment_id  => $temp_file_nd_experiment_id,
            # dbpass                     => $dbpass ### what attribute should i set 
	    );

	    #validate, store, add project_properties from %properties_hash
	    #store the phenotypes
	    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
	    print STDERR "Verified phenotypes. warning = $verified_warning, error = $verified_error\n";
	    my $stored_phenotype_error = $store_phenotypes->store();
	    print STDERR "Stored phenotypes. Error = $stored_phenotype_error \n";
    }
};

my ($email_subject, $email_body);

try {
    $schema->txn_do($coderef);
    if (!$test) {
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
    $email_body    = "Dear $logged_in_name,\n\n$error_message\nPlease correct these errors and try uploading again\n\nThank You\nHave a nice day\n";

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