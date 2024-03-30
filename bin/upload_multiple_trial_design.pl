
=head1

load_cxgn_multi_trials.pl

=head1 SYNOPSIS

    upload_multiple_trial_design.pl  -H [dbhost] -D [dbname] -i inFile -b [breeding program name] -u [username] -m [trial metadata file] [-t] -e [email address] -l [logged in user]

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name
 -i infile 
 -u username  (must be in the database) 
 -b breeding program name (must be in the database)  
 -t  Test run . Rolling back at the end.
 -m trial metadata file - if loading metadata from separate file 
if loading trial data from metadata file, phenotypes + layout from infile 


=head2 DESCRIPTION

    Load multi-trial data - trial layout + minimal metadata + phenotype data for each trial


##CHECK cvterms for trial metadata!! 


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



Srikanth (sk2783@cornell.edu)

    November 2016

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
    'm=s'        => \$metadata_file,
    't'          => \$test,
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


my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
						 RaiseError => 1}
				  }
				    );
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
            {
                'me.name'   => $breeding_program_name,
		'type.name' => 'breeding_program',
	    }, 
    {
    join =>  { projectprops => 'type' } , 
    } ) ;

if (!$breeding_program) { die "Breeding program $breeding_program_name does not exist in the database. Check your input \n"; }
print "Found breeding program $breeding_program_name " . $breeding_program->project_id . "\n";

my $sp_person_id= CXGN::People::Person->get_person_by_username($dbh, $username);

##Column headers for trial design/s
#plot_name	accession_name	plot_number	block_number	trial_name	trial_description	trial_location	year	trial_type	is_a_control	rep_number	range_number	row_number	col_number

###################
#trial metadata can be loaded from a separate data sheet
###################



##Parse the trials + designs first, then upload the phenotypes 

##new spreadsheet for design + phenotyping data ###
my $spreadsheet = CXGN::Tools::File::Spreadsheet->new($infile);
my @trial_rows = $spreadsheet->row_labels();
my @trial_columns = $spreadsheet->column_labels();

if ($infile =~ /\.xlsx$/i) {
    my $xlsx_parser = Spreadsheet::ParseXLSX->new;
    my $xlsx_workbook = $xlsx_parser->parse($infile);
    my $xlsx_worksheet = $xlsx_workbook->worksheet(0);

    # Populate trial rows and columns
    @trial_rows = map { $_ ? $_->value : '' } map { $xlsx_worksheet->get_cell($_, 0) } (0 .. $xlsx_worksheet->row_range);
    @trial_columns = map { $_ ? $_->value : '' } map { $xlsx_worksheet->get_cell(0, $_) } (0 .. $xlsx_worksheet->col_range);
}
# reading the XLS files
elsif ($infile =~ /\.xls$/i) {
    my $xls_parser = Spreadsheet::ParseExcel->new;
    my $xls_workbook = $xls_parser->parse($infile);
    my $xls_worksheet = $xls_workbook->worksheet(0);

    # Populate trial rows and columns
    @trial_rows = map { $_ ? $_->value : '' } map { $xls_worksheet->get_cell($_, 0) } (0 .. $xls_worksheet->row_range);
    @trial_columns = map { $_ ? $_->value : '' } map { $xls_worksheet->get_cell(0, $_) } (0 .. $xls_worksheet->col_range);
} 
# print "Trial design columns = " . Dumper(\@trial_columns);


my %multi_trial_data;

#should be fixed for each file: breeding program 
my ($trial_metadata, @metadata_rows, @metadata_columns ) ;

if ($metadata_file =~ /\.xlsx$/i) {
    my $xlsx_parser    = Spreadsheet::ParseXLSX->new;
    my $xlsx_workbook  = $xlsx_parser->parse($metadata_file);
    my $xlsx_worksheet = $xlsx_workbook->worksheet(0);

    # Populate metadata rows and columns
    @metadata_rows = map { $xlsx_worksheet->get_cell($_, 0)->value } 1..$xlsx_worksheet->row_range;
    @metadata_columns = map { $xlsx_worksheet->get_cell(0, $_)->value } $xlsx_worksheet->col_range;
} elsif ($metadata_file =~ /\.xls$/i) {
    my $xls_parser    = Spreadsheet::ParseExcel->new;
    my $xls_workbook  = $xls_parser->parse($metadata_file);
    my $xls_worksheet = $xls_workbook->worksheet(0);
    
    # Populate metadata rows and columns
    @metadata_rows    = map { $xls_worksheet->get_cell($_, 0)->value } 1..$xls_worksheet->row_range;
    @metadata_columns = map { $xls_worksheet->get_cell(0, $_)->value } $xls_worksheet->col_range;
} else {
#     $trial_metadata   = CXGN::Tools::File::Spreadsheet->new( $metadata_file ) ;
#     @metadata_rows    = $trial_metadata->row_labels();
#     @metadata_columns = $trial_metadata->column_labels();
#     print "Trial metadata column labels = " . Dumper(\@metadata_columns);
}


print "Trial metadata rows: @metadata_rows\n";
print "Trial metadata columns: @metadata_columns\n";


###################
##foreach trial assign: design_hash, year, trial_name, trial_description, trial_location


#########################
## Parse trial metadata 
#########################
    #trial_name
    #trial_description (can also be built from the trial name, type, year, location)
    #trial_type (read from an input file)
    #trial_location geo_description ( must be in the database - nd_geolocation.description - can  be read from metadata file) 
    #year (can be read from the metadata file ) 
    #design (defaults to 'RCBD' ) 
    

#Other OPTIONAL trial metadata (projectprops) 
 
# project planting date
# project fertilizer date
# project harvest date
# project sown plants
# project harvested plants
############################################

my %trial_params = map { $_ => 1 } @metadata_columns;
foreach my $trial_name (@metadata_rows) { 
    my $design_type    = $trial_metadata->value_at($trial_name, "design") || 'RCBD' ;
    my $year           = $trial_metadata->value_at($trial_name, "year");
    my $trial_location = $trial_metadata->value_at($trial_name, "trial_location");
    print "Trial = $trial_name, design = $design_type, year = $year\n";
    ########
    #check that the location exists in the database
    ########
    my $location_rs =  $schema->resultset("NaturalDiversity::NdGeolocation")->search( 
	{ description => { ilike => '%' . $trial_location . '%' }, }
	);
    if (scalar($location_rs) == 0 ) { 
	die "ERROR: location must be pre-loaded in the database. Location name = '" . $trial_location . "'\n";
    }
    my $location_id = $location_rs->first->nd_geolocation_id;
    #########


    ####################################################
    ###optional params
    my ($planting_date, $fertilizer_date, $harvest_date, $sown_plants, $harvested_plants);
    #trial_description defaults to $trial_name
    my $trial_description = $trial_name;
    my $properties_hash;
    if(exists($trial_params{trial_description} )) { 
	$trial_description = $trial_metadata->value_at($trial_name, "trial_description");
    }
    
    if(exists($trial_params{planting_date} )) { 
	$planting_date = $trial_metadata->value_at($trial_name, "planting_date");
	$properties_hash->{"project planting date"} = $planting_date;
    }

    if(exists($trial_params{fertilizer_date} )) { 
	$fertilizer_date = $trial_metadata->value_at($trial_name, "fertilizer_date");
	$properties_hash->{"project fertilizer date"} = $fertilizer_date;
    }

    if(exists($trial_params{harvest_date} )) { 
	$harvest_date = $trial_metadata->value_at($trial_name, "harvest_date");
	$properties_hash->{"project harvest date"} = $harvest_date;
    }
    
    if(exists($trial_params{sown_plants} )) { 
	$sown_plants = $trial_metadata->value_at($trial_name, "sown_plants");
	$properties_hash->{"project sown plants"} = $sown_plants;
    }

    if(exists($trial_params{harvested_plants} )) { 
	$harvested_plants = $trial_metadata->value_at($trial_name, "harvested_plants");
	$properties_hash->{"project harvested plants"} = $harvested_plants ;
    }
    #####################################################


    $multi_trial_data{$trial_name}->{design_type} = $design_type;
    $multi_trial_data{$trial_name}->{program} = $breeding_program->name;
    $multi_trial_data{$trial_name}->{trial_year} = $year;
    $multi_trial_data{$trial_name}->{trial_description} = $trial_description;
    $multi_trial_data{$trial_name}->{trial_location} = $trial_location;
    $multi_trial_data{$trial_name}->{trial_properties} = $properties_hash;
}


## Now read the design + phenotypes file 
print "Reading phenotyping file:\n";
my %phen_params = map { if ($_ =~ m/^\w+\|(\w+:\d{7})$/ ) { $_ => $1 } } @trial_columns  ;
delete $phen_params{''};

my @traits = (keys %phen_params) ;
print "Found traits " . Dumper(\%phen_params) . "\n" ; 
#foreach my $trait_string ( keys %phen_params ) {
#    my ($trait_name, $trait_accession) = split "|", $col_header ;
#    my ($db_name, $dbxref_accession) = split ":" , $trait_accession ;
#}


my %trial_design_hash; #multi-level hash of hashes of hashrefs 
my %phen_data_by_trial; # 

#plot_name	accession_name	plot_number	block_number	trial_name	trial_description	trial_location	year	trial_type	is_a_control	rep_number	range_number	row_number	col_number


foreach my $plot_name (@trial_rows) {
    my ($accession, $plot_number, $block_number, $trial_name, $is_a_control, $rep_number, $range_number, $row_number, $col_number);
    my ($file_extension);

    if ($file_extension eq 'XLSX' || $file_extension eq 'XLS') {
        my $parser = ($file_extension eq 'XLSX') ? Spreadsheet::XLSX->new('file.xlsx') : Spreadsheet::ParseExcel->new()->parse('file.xls');
        my $worksheet = ($file_extension eq 'XLSX') ? $parser->worksheet(0) : $parser->worksheet(0);

        # Access data from XLSX or XLS file
        $accession    = $worksheet->value_at($plot_name, "accession_name");
        $plot_number  = $worksheet->value_at($plot_name, "plot_number");
        $block_number = $worksheet->value_at($plot_name, "block_number");
        $trial_name   = $worksheet->value_at($plot_name, "trial_name");
        $is_a_control = $worksheet->value_at($plot_name, "is_a_control");
        $rep_number   = $worksheet->value_at($plot_name, "rep_number");
        $range_number = $worksheet->value_at($plot_name, "range_number");
        $row_number   = $worksheet->value_at($plot_name, "row_number");
        $col_number   = $worksheet->value_at($plot_name, "col_number");

        if (!$plot_number) {
            $plot_number = 1;
            use List::Util qw(max);
            my @keys = (keys %{ $trial_design_hash{$trial_name} });
            my $max = max(@keys);
            if ($max) {
                $max++;
                $plot_number = $max;
            }
        }

        $trial_design_hash{$trial_name}{$plot_number}->{plot_number}    = $plot_number;
        $trial_design_hash{$trial_name}{$plot_number}->{stock_name}     = $accession;
        $trial_design_hash{$trial_name}{$plot_number}->{plot_name}      = $plot_name;
        $trial_design_hash{$trial_name}{$plot_number}->{block_number}   = $block_number;
        $trial_design_hash{$trial_name}{$plot_number}->{rep_number}     = $rep_number;
        $trial_design_hash{$trial_name}{$plot_number}->{is_a_control}   = $is_a_control;
        $trial_design_hash{$trial_name}{$plot_number}->{range_number}   = $range_number;
        $trial_design_hash{$trial_name}{$plot_number}->{row_number}     = $row_number;
        $trial_design_hash{$trial_name}{$plot_number}->{col_number}     = $col_number;

        ###add the plot name into the multi trial data hashref of hashes ###
        push(@{ $multi_trial_data{$trial_name}->{plots}}, $plot_name);

        ###parse the phenotype data 
        my $timestamp; ## add here timestamp value if storing those ##
        foreach my $trait_string (keys %phen_params) {
            my $phen_value = $parser->value_at($plot_name, $trait_string);
            $phen_data_by_trial{$trial_name}{$plot_name}{$trait_string} = [$phen_value, $timestamp];
        }
    }
};

# #####create the design hash#####
# #print Dumper(\%trial_design_hash);
# #foreach my $trial_name (keys %trial_design_hash) {
# #    $multi_trial_data{$trial_name}->{design} = $trial_design_hash{$trial_name} ;
# #}
# };

my $date = localtime();

####required phenotypeprops###
my %phenotype_metadata ;
$phenotype_metadata{'archived_file'} = $infile;
$phenotype_metadata{'archived_file_type'} = "spreadsheet phenotype file";
$phenotype_metadata{'operator'} = $username;
$phenotype_metadata{'date'} = $date;

# #######

my $coderef= sub  {
    foreach my $trial_name (keys %multi_trial_data ) {
        # print "Trial Name: $trial_name\n";
        # print "Inspecting \$multi_trial_data{\$trial_name} before attempting to use it as a hash reference:\n"; 
        # print Dumper($multi_trial_data{$trial_name});
	
	my $trial_create = CXGN::Trial::TrialCreate->new({
	    chado_schema      => $schema,
	    dbh               => $dbh,
	    design_type       => $multi_trial_data{$trial_name}->{design_type} ||  'RCBD',
	    design            => $trial_design_hash{$trial_name}, #$multi_trial_data{$trial_name}->{design},
	    program           => $breeding_program->name(),
	    trial_year        => $multi_trial_data{$trial_name}->{trial_year} ,
	    trial_description => $multi_trial_data{$trial_name}->{trial_description},
	    trial_location    => $multi_trial_data{$trial_name}->{trial_location},
	    trial_name        => $trial_name,
    });
	
	try {
	    my $trial_create->save_trial();
	} catch {
	    print STDERR "ERROR SAVING TRIAL!\n";
	};
	
	my @plots = @{ $multi_trial_data{$trial_name}->{plots} };
	print "TRIAL NAME = $trial_name\n";
	my %parsed_data = $phen_data_by_trial{$trial_name} ; #hash of keys = plot name, values = hash of trait strings as keys
	foreach my $pname (keys %parsed_data) {
	    print "PLOT = $pname\n";
	    my %trait_string_hash = $parsed_data{$pname};
	  
	    foreach my $trait_string (keys %trait_string_hash ) { 
		print "trait = $trait_string\n";
		print "value =  " . $trait_string_hash{$trait_string}[0] . "\n";
	    }
	}
	
	#my $value_array = $plot_trait_value{$plot_name}->{$trait_name};
	
	#my $trait_value = $value_array->[0];
	#$phen_data_by_trial{$trial_name}{$plot_name}->{$trait_string} = [ $phen_value, $timestamp ] ;

	
	#print Dumper(\%parsed_data);
	# after storing the trial desgin store the phenotypes 
	my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
	    bcs_schema=>$schema,
	    metadata_schema=>$metadata_schema,
	    phenome_schema=>$phenome_schema,
	    user_id=>$sp_person_id,
	    stock_list=>\@plots,
	    trait_list=>\@traits,
	    values_hash=>\%parsed_data,
	    has_timestamps=>0,
	    overwrite_values=>0,
	    metadata_hash=>\%phenotype_metadata
	    );
	
	
	#validate, store, add project_properties from %properties_hash
	
	#store the phenotypes
	my ($verified_warning, $verified_error) = $store_phenotypes->verify();
	print "Verified phenotypes. warning = $verified_warning, error = $verified_error\n";
	my $stored_phenotype_error = $store_phenotypes->store();
	print "Stored phenotypes. Error = $stored_phenotype_error \n";
	
}
};


my ($email_subject, $email_body);
try {
    $schema->txn_do($coderef);
    if (!$test) {
        print "Transaction succeeded! Committing project and its metadata \n\n";

        $email_subject = "Multiple Trial Designs upload status";
        $email_body    = "Dear $logged_in_name,\n\nCongratulations, all the multiple trial designs have been successfully uploaded into the database";

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
    $email_body    = "Dear $logged_in_name,\n\n$error_message\nPlease correct these errors and try uploading again\n";

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