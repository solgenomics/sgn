
=head1

load_genotyping_plates.pl

=head1 SYNOPSIS

NOTE: You need to create the genotyping project in the database first. With the -g option, provide the name of genotyping project the plates should be associated with. Metadata such as year, location and breeding program will be loaded from the genotyping object directly.

load_genotyping_plates.pl  -H [dbhost] -D [dbname] -i inFile -u [username] -g genotyping_project [-t] -f format

=head1 COMMAND-LINE OPTIONS

=over 4

=item -H

host name

=item -D

database name

=item -i

infile 

=item -u 

username  (must be in the database) 

=item -t

Test run . Rolling back at the end.

=item -g

genotyping project name (the genotyping project to which this plate is associated)

=back

=head2 DESCRIPTION

Load genotyping plate layouts for many plates

The infile is a tab delimited file with the following columns:

=over 3

=item

Item	

=item 

Plate ID	

=item

Intertek plate/well ID	

=item 

accession name

=item

Breeder ID

=back

=head2 AUTHORS

Based on a script for loading trial data by Naama Menda <nm249@cornell.edu>, November 2016

Modifications for genotype plate loading, Lukas Mueller <lam87@cornell.edu>, August 2021

=cut


#!/usr/bin/perl
use strict;
use Getopt::Long;
use CXGN::Tools::File::Spreadsheet;

use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Carp qw /croak/ ;
use Try::Tiny;
use DateTime;
use Pod::Usage;

use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::People::Person;
use Data::Dumper;
use CXGN::Phenotypes::StorePhenotypes;

use CXGN::Trial; # add project metadata 
#use CXGN::BreedersToolbox::Projects; # associating a breeding program

use CXGN::Trial::TrialCreate;

my ( $help, $dbhost, $dbname, $infile, $sites, $types, $test, $username, $genotyping_project, $format );
GetOptions(
    'i=s'        => \$infile,
    'g=s'        => \$genotyping_project,
    't'          => \$test,
    'f=s'        => \$format,
    'user|u=s'   => \$username,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost,
    'help'       => \$help,
);



pod2usage(1) if $help;
if (!$infile || !$username || !$dbname || !$dbhost ) {
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


# check if genotyping project exists
#
my $genotyping_project_row = $schema->resultset("Project::Project")->find(
    {
	'name' => $genotyping_project,
#	    'type.name' => 'genotyping_project_name',
    } );

if (! $genotyping_project_row) { die "Please enter a valid genotyping project. You may have to create it before running this script."; }

my $genotyping_project_id = $genotyping_project_row->project_id();
    
if (!$format) {
    $format = "standard";
}

my $sp_person_id= CXGN::People::Person->get_person_by_username($dbh, $username);

print STDERR "SP_PERSON_ID = $sp_person_id\n";
##Column headers for trial design/s
#plot_name	accession_name	plot_number	block_number	trial_name	trial_description	trial_location	year	trial_type	is_a_control	rep_number	range_number	row_number	col_number

###################
#trial metadata can be loaded from a separate data sheet
###################



##Parse the trials + designs first, then upload the phenotypes 

#new spreadsheet for design + phenotyping data ###
my $spreadsheet=CXGN::Tools::File::Spreadsheet->new($infile);
my @trial_rows = $spreadsheet->row_labels();
my @trial_columns = $spreadsheet->column_labels();
print "Trial design columns = " . Dumper(\@trial_columns);

my %multi_trial_data;



print "Reading phenotyping file:\n";
my %phen_params = map { if ($_ =~ m/^\w+\|(\w+:\d{7})$/ ) { $_ => $1 } } @trial_columns  ;
delete $phen_params{''};

my %trial_design_hash; #multi-level hash of hashes of hashrefs 
my %phen_data_by_trial; # 

# CIP format:
# Item	Plate ID	Intertek plate/well ID	CIP Number	Breeder ID

# standard format:
# Item	Plate ID	Intertek plate/well ID	accession name	Breeder ID

my $operator;

foreach my $plot_name (@trial_rows) {

    my $accession;
    my $plot_number;
    my $block_number;
    my $trial_name;
    my $is_a_control;
    my $rep_number;
    my $range_number;
    my $row_number;
    my $col_number;
    
    if ($format eq 'CIP') {
	$accession = $spreadsheet->value_at($plot_name, "CIP Number");
	$plot_number = $spreadsheet->value_at($plot_name, "Intertek plate/well ID");
	$trial_name = $spreadsheet->value_at($plot_name, "Plate ID");
        $operator = $spreadsheet->value_at($plot_name, "Breeder ID");

	if (! $accession) {
	    print STDERR "Ignoring entry for plot_number $plot_number as accession is empty - presumably a check?\n";
	    next;
	} # some plates have empty wells - ignore
	
	if ($plot_number =~ m/^([A-Ha-h])(\d+)$/) {
	    $row_number = $1;
	    $col_number = $2;
	}

	$is_a_control = 0;
	if ($accession eq "") {
	    $is_a_control = 1;
	}

	if (! $row_number ) { die "Weird well number: $plot_number\n"; }

	$trial_design_hash{$trial_name}{$plot_number}->{plot_number} = $plot_number;
	$trial_design_hash{$trial_name}{$plot_number}->{stock_name} = $accession;
	$trial_design_hash{$trial_name}{$plot_number}->{plot_name} = $plot_name;
	$trial_design_hash{$trial_name}{$plot_number}->{row_number} = $row_number;
	$trial_design_hash{$trial_name}{$plot_number}->{col_number} = $col_number;
    }
    else {

	$accession = $spreadsheet->value_at($plot_name, "accession name");
	$plot_number = $spreadsheet->value_at($plot_name, "Intertek plate/well ID");
	$trial_name = $spreadsheet->value_at($plot_name, "Plate ID");
        $operator = $spreadsheet->value_at($plot_name, "Breeder ID");
		
	if (! $accession) {
	    print STDERR "Ignoring entry for plot_number $plot_number as accession is empty - presumably a check?\n";
	    next;
	} # some plates have empty wells - ignore

	if ($plot_number =~ m/^([A-Ha-h])(\d+)$/) {
	    $row_number = $1;
	    $col_number = $2;
	}

	$is_a_control = 0;
	if ($accession eq "") {
	    $is_a_control = 1;
	}

	if (! $row_number ) { die "Weird well number: $plot_number\n"; }

	$trial_design_hash{$trial_name}{$plot_number}->{plot_number} = $plot_number;
	$trial_design_hash{$trial_name}{$plot_number}->{stock_name} = $accession;
	$trial_design_hash{$trial_name}{$plot_number}->{plot_name} = $plot_name;
	$trial_design_hash{$trial_name}{$plot_number}->{row_number} = $row_number;
	$trial_design_hash{$trial_name}{$plot_number}->{col_number} = $col_number;

    }
    
    # Add the plot name into the multi trial data hashref of hashes
    #
    push( @{ $multi_trial_data{$trial_name}->{plots} } , $plot_name ); 
}

#####create the design hash#####
#print Dumper(\%trial_design_hash);
#foreach my $trial_name (keys %trial_design_hash) {
#    $multi_trial_data{$trial_name}->{design} = $trial_design_hash{$trial_name} ;
#}

my $date = localtime();

####required phenotypeprops###
my %phenotype_metadata ;
$phenotype_metadata{'archived_file'} = $infile;
$phenotype_metadata{'archived_file_type'} = "genotyping file";
$phenotype_metadata{'operator'} = $username;
$phenotype_metadata{'date'} = $date;

 
#######

my $coderef= sub  {

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $genotyping_project_id });
    my $location_data = $trial->get_location();
    my $location_name = $location_data->[1];
    my $description = $trial->get_description();
    my $genotyping_facility = $trial->get_genotyping_facility();
    my $plate_year = $trial->get_year();
    
    my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });
    my $breeding_program_data = $program_object->get_breeding_programs_by_trial($genotyping_project_id);
    my $breeding_program_name = $breeding_program_data->[0]->[1];

    print STDERR "Working with genotyping project name $genotyping_project\n";
    foreach my $trial_name (keys %multi_trial_data ) { 
	
	my $trial_create = CXGN::Trial::TrialCreate->new(
	    {
		chado_schema      => $schema,
		dbh               => $dbh,
		design_type       => 'genotyping_plate',
		design            => $trial_design_hash{$trial_name},
		program           => $breeding_program_name,
		trial_year        => $plate_year,
		trial_description => $description,
		trial_location    => $location_name,
		trial_name        => $trial_name,
		operator          => $operator,
		owner_id           => $sp_person_id,
		is_genotyping      => 1,
		genotyping_user_id => $sp_person_id,
		genotyping_plate_format => $format,
		genotyping_plate_sample_type => 'accession',
		genotyping_project_id => $genotyping_project_id,
		genotyping_facility => $genotyping_facility,
	    });
	
	try {
	    $trial_create->save_trial();
	} catch {
	    print STDERR "ERROR SAVING TRIAL! $_\n";
	};
    }
};

try {
    $schema->txn_do($coderef);
    if (!$test) { print "Transaction succeeded! Commiting project and its metadata \n\n"; }
} catch {
    die "An error occured! Rolling back  and reseting database sequences!" . $_ . "\n";
};

