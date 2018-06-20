#!/usr/bin/perl

=head1
load_genotypes_vcf_cxgn_postgres.pl - loading genotypes into cxgn databases, based on the load_cassava_snps.pl script by Naama.

=head1 SYNOPSIS
    perl bin/load_genotypes_vcf_cxgn_postgres.pl -H localhost -D fixture -i /home/vagrant/Documents/cassava_subset_108KSNP_10acc.vcf -g "test_pop_01" -p "test_project_01" -y 2016 -l "BTI" -m "test_protocol_01_new" -o "Manihot" -q "Manihot esculenta"

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -i path to infile (required)
 -p project name (required) e.g. "SNP genotyping 2012 Cornell Biotech".  Will be found or created in Project table.
 -y project year (required) e.g. "2012".  Will be saved as a Projectprop.
 -g population name (required) e.g. "NaCRRI training population"
 -m protocol name (required) e.g. "GBS ApeKI Cassava genome v6"
 -l location name (required) e.g. "Cornell Biotech".  Will be found or created in NdGeolocation table.
 -o organism genus name (required) e.g. "Manihot".  Along with organism species name, this will be found or created in Organism table.
 -q organism species name (required) e.g. "Manihot esculenta".

  FLAGS
 -x delete old genotypes for accessions that have new genotypes
 -a add accessions that are not in the database
 -z if accession names include an IGD number. Accession names are in format 'accession_name:IGD_number'. The IGD number will be parsed and stored as a genotypeprop.
 -t Test run . Rolling back at the end.


=head1 DESCRIPTION
This script loads genotype data into the Chado genotype table it encodes the genotype + marker name in a json format in the genotyope.uniquename field for easy parsing by a Perl program. The genotypes are linked to the relevant stock using nd_experiment_genotype. Each column in the spreadsheet, which represents a single accession (stock) is stored as a single genotype entry and linked to the stock via nd_experiment_genotype. Stock names are stored in the stock table if cannot be found, and linked to a population stock with the name supplied in opt_g. Map details (chromosome, position, ref, alt, qual, filter, info, and format) are stored in json format in the protocolprop table.

=head1 AUTHOR
 Nicolas Morales (nm529@cornell.edu) May 2016
=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use JSON::Any;
use JSON::PP;
use Carp qw /croak/ ;
use Try::Tiny;
use Pod::Usage;

use Bio::Chado::Schema;
use CXGN::People::Person;
use CXGN::DB::InsertDBH;
use CXGN::Genotype;
use CXGN::GenotypeIO;
use Sort::Versions;
use SGN::Model::Cvterm;

our ($opt_H, $opt_D, $opt_i, $opt_t, $opt_p, $opt_y, $opt_g, $opt_a, $opt_x, $opt_v, $opt_s, $opt_m, $opt_l, $opt_o, $opt_q, $opt_z);

getopts('H:i:tD:p:y:g:axsm:l:o:q:z');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $file = $opt_i;
my $project_name = $opt_p;
my $project_year = $opt_y;
my $population_name = $opt_g;
my $map_protocol_name = $opt_m;
my $location = $opt_l;
my $organism_genus = $opt_o;
my $organism_species = $opt_q;


print STDERR "Input file: $file\n";
print STDERR "DB host: $dbhost\n";
print STDERR "DB name: $dbname\n";
print STDERR "Population name: $population_name\n";
print STDERR "Project year: $opt_y\n";
print STDERR "Add missing accessions: $opt_a\n";
print STDERR "Delete old duplicate phenotypes: $opt_x\n";
print STDERR "Rollback: $opt_t\n";

if (!$opt_H || !$opt_D || !$opt_i || !$opt_g) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file) , -g (populations name for associating accessions in your SNP file), -p (project name), -y (project year), -l (location of project), -m (map protocol name), -o (organism genus), -q (organism species) \n");
}

#print "Password for $opt_H / $opt_D: \n";
#my $pw = <>;
#chomp($pw);
my $pw='postgres';

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $schema = Bio::Chado::Schema->connect($dsn, "postgres", $pw);
my $dbh = DBI->connect($dsn, "postgres", $pw);
$dbh->do('SET search_path TO public,sgn');

my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
my $population_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'training population', 'stock_type')->cvterm_id();
my $igd_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'igd number', 'genotype_property')->cvterm_id();
my $snp_genotypingprop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();
my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
my $snp_genotype_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'snp genotyping', 'genotype_property')->cvterm_id();
my $population_members_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();

my $vcf_map_details = $schema->resultset("Cv::Cvterm")->create_with({
    name => 'vcf_map_details',
    cv   => 'protocol_property',
});
my $vcf_map_details_id = $vcf_map_details->cvterm_id();

#store a project
my $project = $schema->resultset("Project::Project")->find_or_create({
    name => $opt_p,
    description => $opt_p,
});
my $project_id = $project->project_id();
$project->create_projectprops( { 'project year' => $opt_y }, { autocreate => 1 } );

#store Map name using protocol
my $protocol_row = $schema->resultset("NaturalDiversity::NdProtocol")->find_or_new({
    name => $map_protocol_name,
    type_id => $geno_cvterm_id
});
my $protocol_id = $protocol_row->nd_protocol_id();

#store location info
my $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")->find_or_create({
    description =>$location,
});
my $nd_geolocation_id = $geolocation->nd_geolocation_id();

#store organism info
my $organism = $schema->resultset("Organism::Organism")->find_or_create({
    genus   => $organism_genus,
    species => $organism_species,
});
my $organism_id = $organism->organism_id();

my $population_stock = $schema->resultset("Stock::Stock")->find_or_create({
    organism_id => $organism_id,
    name       => $population_name,
    uniquename => $population_name,
    type_id => $population_cvterm_id,
});
my $population_stock_id = $population_stock->stock_id();

if( !$protocol_row->in_storage ) {
    $protocol_row->insert;
    $protocol_id = $protocol_row->nd_protocol_id();

    print STDERR "Reading genotype information for protocolprop storage...\n";
    my $gtio = CXGN::GenotypeIO->new( { file => $file, format => "vcf" });

    my %protocolprop_json;

    my $accessions = $gtio->accessions();
    my $number_accessions = scalar(@$accessions);
    print STDERR "Number accessions: $number_accessions...\n";

    while (my ($marker_info, $values) = $gtio->next_vcf_row() ) {

        #print STDERR Dumper $marker_info;
        my $marker_name;
        my $marker_info_p2 = $marker_info->[2];
        my $marker_info_p8 = $marker_info->[8];
        if ($marker_info_p2 eq '.') {
            $marker_name = $marker_info->[0]."_".$marker_info->[1];
        } else {
            $marker_name = $marker_info_p2;
        }

        #As it goes down the rows, it appends the info from cols 0-8 into the protocolprop json object.
        my %marker = (
            chrom => $marker_info->[0],
            pos => $marker_info->[1],
            ref => $marker_info->[3],
            alt => $marker_info->[4],
            qual => $marker_info->[5],
            filter => $marker_info->[6],
            info => $marker_info->[7],
            format => $marker_info_p8,
        );
        $protocolprop_json{$marker_name} = \%marker;
    }
    print STDERR "Protocol hash created...\n";

    #Save the protocolprop. This json string contains the details for the maarkers used in the map.
    my $json_obj = JSON::Any->new;
    my $json_string = $json_obj->encode(\%protocolprop_json);
    my $last_protocolprop_rs = $schema->resultset("NaturalDiversity::NdProtocolprop")->search({}, {order_by=> { -desc => 'nd_protocolprop_id' }, rows=>1});
    my $last_protocolprop = $last_protocolprop_rs->first();
    my $new_protocolprop_id;
    if ($last_protocolprop) {
        $new_protocolprop_id = $last_protocolprop->nd_protocolprop_id() + 1;
    } else {
        $new_protocolprop_id = 1;
    }
    my $new_protocolprop_sql = "INSERT INTO nd_protocolprop (nd_protocolprop_id, nd_protocol_id, type_id, value) VALUES ('$new_protocolprop_id', '$protocol_id', '$vcf_map_details_id', '$json_string');";
    $dbh->do($new_protocolprop_sql) or die "DBI::errstr";

    #my $add_protocolprop = $schema->resultset("NaturalDiversity::NdProtocolprop")->create({ nd_protocol_id => $protocol_id, type_id => $vcf_map_details->cvterm_id(), value => $json_string });
    undef %protocolprop_json;
    undef $json_string;
    #undef $add_protocolprop;
    undef $new_protocolprop_sql;

    print STDERR "Protocolprop stored...\n";
}
$protocol_id = $protocol_row->nd_protocol_id();

print STDERR "Reading genotype information for genotyeprop...\n";
my $gtio = CXGN::GenotypeIO->new( { file => $file, format => "vcf" });

my $accessions = $gtio->accessions();

my %genotypeprop_accessions;

my $number_accessions = scalar(@$accessions);
print STDERR "Number accessions: $number_accessions...\n";

while (my ($marker_info, $values) = $gtio->next_vcf_row() ) {

    #print STDERR Dumper $marker_info;
    my $marker_name;
    my $marker_info_p2 = $marker_info->[2];
    my $marker_info_p8 = $marker_info->[8];
    if ($marker_info_p2 eq '.') {
        $marker_name = $marker_info->[0]."_".$marker_info->[1];
    } else {
        $marker_name = $marker_info_p2;
    }

    my @format =  split /:/,  $marker_info_p8;
    #As it goes down the rows, it contructs a separate json object for each accession column. They are all stored in the %genotypeprop_accessions. Later this hash is iterated over and actually stores the json object in the database.
    for (my $i = 0; $i < $number_accessions; $i++ ) {
        my @fvalues = split /:/, $values->[$i];
        my %value;
        #for (my $fv = 0; $fv < scalar(@format); $fv++ ) {
        #    $value{@format[$fv]} = @fvalues[$fv];
        #}
        @value{@format} = @fvalues;
        $genotypeprop_accessions{$accessions->[$i]}->{$marker_name} = \%value;
    }
}

print STDERR "Genotypeprop accessions hash created\n";

foreach (@$accessions) {

    my ($accession_name, $igd_number) = split(/:/, $_);

    #print STDERR "Looking for accession $accession_name\n";
    my $stock;
    my $stock_rs = $schema->resultset("Stock::Stock")->search({ 'lower(me.uniquename)' => { like => lc($accession_name) }, organism_id => $organism_id });

    if ($stock_rs->count() == 1) {
        $stock = $stock_rs->first();
    }

    if ($stock_rs->count ==0)  {
        #print STDERR "No synonym was found for $accession_name\n";

        #store the plant accession in the stock table if $opt_a
        if (!$opt_a) {
            print STDERR "WARNING! Accession $accession_name (using: $accession_name) not found.\n";
            print STDERR "Use option -a to add automatically.\n";
            next();
        } else {
            $stock = $schema->resultset("Stock::Stock")->create({
                organism_id => $organism_id,
                name       => $accession_name,
                uniquename => $accession_name,
                type_id     => $accession_cvterm_id,
            });
        }
    }
    my $stock_name = $stock->name();
    my $stock_id = $stock->stock_id();

    $stock->create_related('stock_relationship_objects', {
        type_id => $population_members_id,
        subject_id => $stock_id,
        object_id => $population_stock_id,
    });

    print STDERR "Stock name = " . $stock_name . "\n";
    my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
        nd_geolocation_id => $nd_geolocation_id,
        type_id => $geno_cvterm_id,
    });
    my $nd_experiment_id = $experiment->nd_experiment_id();

    #print STDERR "Linking to protocol...\n";
    my $nd_experiment_protocol = $schema->resultset('NaturalDiversity::NdExperimentProtocol')->create({
        nd_experiment_id => $nd_experiment_id,
        nd_protocol_id => $protocol_id,
    });

    #link to the project
    $experiment->create_related('nd_experiment_projects', {
        project_id => $project_id
    });

    #link the experiment to the stock
    $experiment->create_related('nd_experiment_stocks' , {
        stock_id => $stock_id,
        type_id  =>  $geno_cvterm_id,
    });

    print STDERR "Storing new genotype for stock " . $stock_name . " \n";
    my $genotype = $schema->resultset("Genetic::Genotype")->create({
            name        => $stock_name . "|" . $nd_experiment_id,
            uniquename  => $stock_name . "|" . $nd_experiment_id,
            description => "SNP genotypes for stock " . "(name = " . $stock_name . ", id = " . $stock_id . ")",
            type_id     => $snp_genotype_id,
    });
    my $genotype_id = $genotype->genotype_id();

    my $json_obj = JSON::Any->new;
    my $genotypeprop_json = $genotypeprop_accessions{$_};
    #print STDERR Dumper \%genotypeprop_accessions;
    my $json_string = $json_obj->encode($genotypeprop_json);

    #Store json for genotype. Has all markers and scores for this stock.
    my $last_genotypeprop_rs = $schema->resultset("Genetic::Genotypeprop")->search({}, {order_by=> { -desc => 'genotypeprop_id' }, rows=>1});
    my $last_genotypeprop = $last_genotypeprop_rs->first();
    my $new_genotypeprop_id;
    if ($last_genotypeprop) {
        $new_genotypeprop_id = $last_genotypeprop->genotypeprop_id() + 1;
    } else {
        $new_genotypeprop_id = 1;
    }
    my $new_genotypeprop_sql = "INSERT INTO genotypeprop (genotypeprop_id, genotype_id, type_id, value) VALUES ('$new_genotypeprop_id', '$genotype_id', '$snp_genotypingprop_cvterm_id', '$json_string');";
    $dbh->do($new_genotypeprop_sql) or die "DBI::errstr";
    #my $add_genotypeprop = $schema->resultset("Genetic::Genotypeprop")->create({ genotype_id => $genotype_id, type_id => $snp_genotypingprop_cvterm_id, value => $json_string });

    #Store IGD number if the option is given.
    if ($opt_z) {
        my $add_genotypeprop = $schema->resultset("Genetic::Genotypeprop")->create({ genotype_id => $genotype_id, type_id => $igd_number_cvterm_id, value => $igd_number });
    }
    undef $genotypeprop_json;
    undef $json_string;
    undef $new_genotypeprop_sql;
    #undef $add_genotypeprop;

    #link the genotype to the nd_experiment
    my $nd_experiment_genotype = $experiment->create_related('nd_experiment_genotypes', { genotype_id => $genotype->genotype_id() } );

}

print STDERR "Complete!\n";
