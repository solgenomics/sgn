
=head1

load_genotyping_plates.pl

=head1 SYNOPSIS

load_genotyping_plates.pl  -H [dbhost] -D [dbname] -i inFile -b [breeding program name] -u [username] -l location [-t]

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

=item -b 

breeding program name (must be in the database)  

=item -t

Test run . Rolling back at the end.

=item -l 

location

=item -y 

year

=back

=head2 DESCRIPTION

Load genotyping plate layouts for many plates

Minimal metadata requirements are

=over 3

=item 

trial_name

=item

trial_description (can also be built from the trial name, type, year, location)

=item

trial_type (read from an input file)

=item 

trial_location geo_description ( must be in the database - nd_geolocation.description - can  be read from metadata file) 

=item

year (can be read from the metadata file ) 

=item

breeding_program (provide with option -b ) 

=back

The infile is an Excel file (.xls format) with the following columns:

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

my ( $help, $dbhost, $dbname, $infile, $sites, $types, $test, $username, $breeding_program_name, $metadata_file, $location, $year, $format );
GetOptions(
    'i=s'        => \$infile,
    'b=s'        => \$breeding_program_name,
    'l=s'        => \$location,
    'y=s'        => \$year,
    't'          => \$test,
    'f=s'        => \$format,
    'user|u=s'   => \$username,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost,
    'help'       => \$help,
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


# Breeding program for associating the trial/s ##
#

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

if (!$format) {
    die "Please specify format (-f) as CIP. No other format is supported right now\n";
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

my @traits = (keys %phen_params) ;
print "Found traits " . Dumper(\%phen_params) . "\n" ; 
#foreach my $trait_string ( keys %phen_params ) {
#    my ($trait_name, $trait_accession) = split "|", $col_header ;
#    my ($db_name, $dbxref_accession) = split ":" , $trait_accession ;
#}


my %trial_design_hash; #multi-level hash of hashes of hashrefs 
my %phen_data_by_trial; # 

#plot_name	accession_name	plot_number	block_number	trial_name	trial_description	trial_location	year	trial_type	is_a_control	rep_number	range_number	row_number	col_number


# CIP format:
## Item	Plate ID	Intertek plate/well ID	CIP Number	Breeder ID

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
	$accession    = $spreadsheet->value_at($plot_name, "accession_name");
	$plot_number  = $spreadsheet->value_at($plot_name, "plot_number");
	$block_number = $spreadsheet->value_at($plot_name, "block_number");
	$trial_name   = $spreadsheet->value_at($plot_name, "trial_name");
	$is_a_control = $spreadsheet->value_at($plot_name, "is_a_control");
	$rep_number   = $spreadsheet->value_at($plot_name, "rep_number");
	$range_number = $spreadsheet->value_at($plot_name, "range_number");
	$row_number   = $spreadsheet->value_at($plot_name, "row_number");
	$col_number   = $spreadsheet->value_at($plot_name, "col_number");
    
	if (!$plot_number) {
	    $plot_number = 1;
	    use List::Util qw(max);
	    my @keys = (keys %{ $trial_design_hash{$trial_name} } );
	    my $max = max( @keys );
	    if ( $max ) {
		$max++;
		$plot_number = $max ;
	    }
	}

	$trial_design_hash{$trial_name}{$plot_number}->{plot_number} = $plot_number;
	$trial_design_hash{$trial_name}{$plot_number}->{stock_name} = $accession;
	$trial_design_hash{$trial_name}{$plot_number}->{plot_name} = $plot_name;
	$trial_design_hash{$trial_name}{$plot_number}->{block_number} = $block_number;
	$trial_design_hash{$trial_name}{$plot_number}->{rep_number} = $rep_number;
	$trial_design_hash{$trial_name}{$plot_number}->{is_a_control} = $is_a_control;
	$trial_design_hash{$trial_name}{$plot_number}->{range_number} = $range_number;
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
    foreach my $trial_name (keys %multi_trial_data ) { 
	
	my $trial_create = CXGN::Trial::TrialCreate->new({
	    chado_schema      => $schema,
	    dbh               => $dbh,
	    design_type       => 'genotyping_plate',
	    design            => $trial_design_hash{$trial_name},
	    program           => $breeding_program->name(),
	    trial_year        => $year,
	    trial_description => $trial_name,
	    trial_location    => $location,
	    trial_name        => $trial_name,
            operator          => $operator,
	    owner_id           => $sp_person_id,
	    is_genotyping      => 1,
	    genotyping_user_id => $sp_person_id,
	    genotyping_plate_format => 96,
	    genotyping_plate_sample_type => 'accession',
	    

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
    # Transaction failed
#    foreach my $value ( sort  keys %seq ) {
#        my $maxval= $seq{$value} || 0;
#        if ($maxval) { $dbh->do("SELECT setval ('$value', $maxval, true)") ;  }
#        else {  $dbh->do("SELECT setval ('$value', 1, false)");  }
#    }
    die "An error occured! Rolling back  and reseting database sequences!" . $_ . "\n";
};

