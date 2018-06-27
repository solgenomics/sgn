package CXGN::Genotype::StoreVCFGenotypes;

=head1 NAME

CXGN::Genotype::StoreVCFGenotypes - an object to handle storing genotypes in genotypeprop from VCF file

=head1 USAGE

my $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new(
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    vcf_input_file=>$vcf_input_file,
    observation_unit_type_name=>'tissue_sample',
    project_year=>'2018',
    project_location_name=>$location_name,
    project_name=>'VCF2018',
    protocol_name=>'SNP2018',
    organism_genus=>$organism_genus,
    organism_species=>$organism_species,
    create_missing_observation_units_as_accessions=>0,
    igd_numbers_included=>0
);
my $verified_errors = $store_genotypes->validate();
my ($stored_genotype_error, $stored_genotype_success) = $store_genotypes->store();

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use Digest::MD5;
use CXGN::List::Validate;
use Data::Dumper;
use CXGN::UploadFile;
use SGN::Model::Cvterm;
use CXGN::GenotypeIO;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
    required => 1,
);

has 'phenome_schema' => (
    isa => 'CXGN::Phenome::Schema',
    is => 'rw',
    required => 1,
);

has 'vcf_input_file' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'observation_unit_type_name' => ( #Can be accession, plot, plant, tissue_sample
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'project_year' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'project_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'project_location_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'protocol_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'organism_genus' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'organism_species' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'create_missing_observation_units_as_accessions' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);

has 'igd_numbers_included' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);

sub validate {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh;
    my $opt_p = $self->project_name;
    my $opt_y = $self->project_year;
    my $map_protocol_name = $self->protocol_name;
    my $location = $self->project_location_name;
    my $organism_genus = $self->organism_genus;
    my $organism_species = $self->organism_species;
    my $file = $self->vcf_input_file;
    my @error_messages;

    print STDERR "Reading genotype information for protocolprop storage...\n";
    my $gtio = CXGN::GenotypeIO->new( { file => $file, format => "vcf" });

    my $header = $gtio->header;
    if ($header->[0] ne 'CHROM'){
        push @error_messages, 'Column 1 header must be "CHROM".';
    }
    if ($header->[1] ne 'POS'){
        push @error_messages, 'Column 2 header must be "POS".';
    }
    if ($header->[2] ne 'ID'){
        push @error_messages, 'Column 3 header must be "ID".';
    }
    if ($header->[3] ne 'REF'){
        push @error_messages, 'Column 4 header must be "REF".';
    }
    if ($header->[4] ne 'ALT'){
        push @error_messages, 'Column 5 header must be "ALT".';
    }
    if ($header->[5] ne 'QUAL'){
        push @error_messages, 'Column 6 header must be "QUAL".';
    }
    if ($header->[6] ne 'FILTER'){
        push @error_messages, 'Column 7 header must be "FILTER".';
    }
    if ($header->[7] ne 'INFO'){
        push @error_messages, 'Column 8 header must be "INFO".';
    }
    if ($header->[8] ne 'FORMAT'){
        push @error_messages, 'Column 9 header must be "FORMAT".';
    }

    my $observation_unit_names = $gtio->observation_unit_names();
    my $number_observation_units = scalar(@$observation_unit_names);
    print STDERR "Number observation units: $number_observation_units...\n";

    my $stock_type = $self->observation_unit_type_name;
    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type, 'stock_type')->cvterm_id();
    my $stock_rs = $schema->resultset("Stock::Stock")->search({
        uniquename => {-in => $observation_unit_names},
        type_id => $stock_type_id
    });
    my %found_stock_names;
    while(my $r = $stock_rs->next){
        $found_stock_names{$r->uniquename}++;
    }
    my @missing_stocks;
    foreach (@$observation_unit_names){
        if (!$found_stock_names{$_}){
            push @error_messages, "$_ is not a valid $stock_type.";
            push @missing_stocks, $_;
        }
    }
    return { error_messages => \@error_messages, missing_stocks => \@missing_stocks };
}

sub store {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh;
    my $opt_p = $self->project_name;
    my $opt_y = $self->project_year;
    my $map_protocol_name = $self->protocol_name;
    my $location = $self->project_location_name;
    my $organism_genus = $self->organism_genus;
    my $organism_species = $self->organism_species;
    my $file = $self->vcf_input_file;
    my $opt_z = $self->igd_numbers_included;
    my $opt_a = $self->create_missing_observation_units_as_accessions;
    $dbh->do('SET search_path TO public,sgn');

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $igd_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'igd number', 'genotype_property')->cvterm_id();
    my $snp_genotypingprop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();
    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $snp_genotype_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'snp genotyping', 'genotype_property')->cvterm_id();
    my $vcf_map_details_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();

    #store a project
    my $project = $schema->resultset("Project::Project")->find_or_create({
        name => $opt_p,
        description => $opt_p,
    });
    my $project_id = $project->project_id();
    $project->create_projectprops( { 'project year' => $opt_y }, { autocreate => 1 } );

    #store Map name using protocol
    my $protocol_row = $schema->resultset("NaturalDiversity::NdProtocol")->find_or_create({
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

    if( !$protocol_row->in_storage ) {
        $protocol_row->insert;
        $protocol_id = $protocol_row->nd_protocol_id();

        print STDERR "Reading genotype information for protocolprop storage...\n";
        my $gtio = CXGN::GenotypeIO->new( { file => $file, format => "vcf" });

        my %protocolprop_json;

        my $observation_unit_names = $gtio->observation_unit_names();
        my $number_observation_units = scalar(@$observation_unit_names);
        print STDERR "Number observation units: $number_observation_units...\n";

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

    my $observation_unit_names = $gtio->observation_unit_names();

    my %genotypeprop_observation_units;

    my $number_observation_units = scalar(@$observation_unit_names);
    print STDERR "Number observation units: $number_observation_units...\n";

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
        #As it goes down the rows, it contructs a separate json object for each observation unit column. They are all stored in the %genotypeprop_observation_units. Later this hash is iterated over and actually stores the json object in the database.
        for (my $i = 0; $i < $number_observation_units; $i++ ) {
            my @fvalues = split /:/, $values->[$i];
            my %value;
            #for (my $fv = 0; $fv < scalar(@format); $fv++ ) {
            #    $value{@format[$fv]} = @fvalues[$fv];
            #}
            @value{@format} = @fvalues;
            $genotypeprop_observation_units{$observation_unit_names->[$i]}->{$marker_name} = \%value;
        }
    }

    print STDERR "Genotypeprop observation units hash created\n";

    foreach (@$observation_unit_names) {

        my ($observation_unit_name, $igd_number) = split(/:/, $_);

        #print STDERR "Looking for observation unit $observation_unit_name\n";
        my $stock;
        my $stock_rs = $schema->resultset("Stock::Stock")->search({ 'me.uniquename' => $observation_unit_name, organism_id => $organism_id });

        if ($stock_rs->count() == 1) {
            $stock = $stock_rs->first();
        }

        if ($stock_rs->count ==0)  {

            #store the observation_unit_name in the stock table as an accession if $opt_a
            if (!$opt_a) {
                print STDERR "WARNING! Observation unit name $observation_unit_name not found.\n";
                print STDERR "Use option -a to add automatically.\n";
                next();
            } else {
                $stock = $schema->resultset("Stock::Stock")->create({
                    organism_id => $organism_id,
                    name       => $observation_unit_name,
                    uniquename => $observation_unit_name,
                    type_id     => $accession_cvterm_id,
                });
            }
        }
        my $stock_name = $stock->name();
        my $stock_id = $stock->stock_id();

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
        my $genotypeprop_json = $genotypeprop_observation_units{$_};
        #print STDERR Dumper \%genotypeprop_observation_units;
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
            my %igd_number = ('igd_number' => $igd_number);
            my $json_obj = JSON::Any->new;
            my $json_string = $json_obj->encode(\%igd_number);
            my $add_genotypeprop = $schema->resultset("Genetic::Genotypeprop")->create({ genotype_id => $genotype_id, type_id => $igd_number_cvterm_id, value => $json_string });
        }
        undef $genotypeprop_json;
        undef $json_string;
        undef $new_genotypeprop_sql;
        #undef $add_genotypeprop;

        #link the genotype to the nd_experiment
        my $nd_experiment_genotype = $experiment->create_related('nd_experiment_genotypes', { genotype_id => $genotype->genotype_id() } );
    }

}

1;
