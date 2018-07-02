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
    project_location_id=>$location_id,
    project_name=>'VCF2018',
    project_description=>'description',
    protocol_name=>'SNP2018',
    organism_genus=>$organism_genus,
    organism_species=>$organism_species,
    user_id => 41,
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
use JSON;

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

has 'breeding_program_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'genotyping_facility' => (
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

has 'project_description' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'project_location_id' => (
    isa => 'Int',
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

has 'reference_genome_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'accession_population_name' => (
    isa => 'Str',
    is => 'rw',
    required => 0,
);

has 'user_id' => (
    isa => 'Int',
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
    print STDERR "Genotype VCF validate\n";

    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh;
    my $opt_p = $self->project_name;
    my $project_description = $self->project_description;
    my $opt_y = $self->project_year;
    my $map_protocol_name = $self->protocol_name;
    my $location_id = $self->project_location_id;
    my $organism_genus = $self->organism_genus;
    my $organism_species = $self->organism_species;
    my $file = $self->vcf_input_file;
    my $opt_z = $self->igd_numbers_included;
    my @error_messages;

    print STDERR "Reading genotype information for protocolprop storage...\n";
    my $gtio = CXGN::GenotypeIO->new( { file => $file, format => "vcf" });

    my $header = $gtio->header;
    if ($header->[0] ne '#CHROM'){
        push @error_messages, 'Column 1 header must be "#CHROM".';
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

    if ($opt_z){
        my @observation_units_names_trim;
        foreach (@$observation_unit_names){
            my ($observation_unit_name, $igd_number) = split(/:/, $_);
            push @observation_units_names_trim, $observation_unit_name;
        }
        $observation_unit_names = \@observation_units_names_trim;
    }

    #store organism info
    my $organism = $schema->resultset("Organism::Organism")->find_or_create({
        genus   => $organism_genus,
        species => $organism_species,
    });
    my $organism_id = $organism->organism_id();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $stock_type = $self->observation_unit_type_name;
    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type, 'stock_type')->cvterm_id();
    my $stock_rs = $schema->resultset("Stock::Stock")->search({
        uniquename => {-in => $observation_unit_names},
        type_id => $stock_type_id,
        organism_id => $organism_id
    });
    my %found_stock_names;
    while(my $r = $stock_rs->next){
        $found_stock_names{$r->uniquename}++;
    }
    my %missing_stocks;
    foreach (@$observation_unit_names){
        if (!$found_stock_names{$_}){
            $missing_stocks{$_}++;
        }
    }
    my @missing_stocks = keys %missing_stocks;
    my @missing_stocks_return;
    foreach (@missing_stocks){
        if (!$self->create_missing_observation_units_as_accessions){
            push @error_messages, "$_ is not a valid $stock_type.";
            push @missing_stocks_return, $_;
        } else {
            my $stock = $schema->resultset("Stock::Stock")->create({
                organism_id => $organism_id,
                name       => $_,
                uniquename => $_,
                type_id     => $accession_cvterm_id,
            });
        }
    }
    
    return { error_messages => \@error_messages, missing_stocks => \@missing_stocks_return };
}

sub store {
    my $self = shift;
    print STDERR "Genotype VCF store\n";

    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh;
    my $genotype_facility = $self->genotyping_facility;
    my $opt_p = $self->project_name;
    my $project_description = $self->project_description;
    my $opt_y = $self->project_year;
    my $map_protocol_name = $self->protocol_name;
    my $reference_genome_name = $self->reference_genome_name;
    my $location_id = $self->project_location_id;
    my $organism_genus = $self->organism_genus;
    my $organism_species = $self->organism_species;
    my $file = $self->vcf_input_file;
    my $opt_z = $self->igd_numbers_included;
    my $opt_a = $self->create_missing_observation_units_as_accessions;
    $dbh->do('SET search_path TO public,sgn');

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $population_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $igd_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'igd number', 'genotype_property')->cvterm_id();
    my $snp_genotypingprop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();
    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $snp_genotype_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'snp genotyping', 'genotype_property')->cvterm_id();
    my $vcf_map_details_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $population_members_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();
    my $design_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property');
    my $project_year_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property');
    my $genotyping_facility_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_facility', 'project_property');

    #store a project
    my $project_id;
    my $project_check = $schema->resultset("Project::Project")->find({
        name => $opt_p
    });
    if ($project_check){
        $project_id = $project_check->project_id;
    } else {
        my $project = $schema->resultset("Project::Project")->create({
            name => $opt_p,
            description => $project_description,
        });
        $project_id = $project->project_id();
        $project->create_projectprops( { $project_year_cvterm->name() => $opt_y } );
        $project->create_projectprops( { $genotyping_facility_cvterm->name() => $genotype_facility } );
        $project->create_projectprops( { $design_cvterm->name() => 'genotype_data_project' } );
    }

    #store organism info
    my $organism = $schema->resultset("Organism::Organism")->find_or_create({
        genus   => $organism_genus,
        species => $organism_species,
    });
    my $organism_id = $organism->organism_id();

    my $population_stock;
    my $population_stock_id;
    if ($self->accession_population_name && $self->observation_unit_type_name eq 'accession'){
        $population_stock = $schema->resultset("Stock::Stock")->find_or_create({
            organism_id => $organism_id,
            name       => $self->accession_population_name,
            uniquename => $self->accession_population_name,
            type_id => $population_cvterm_id,
        });
        $population_stock_id = $population_stock->stock_id();
    }

    my $protocol_id;
    my $protocol_row_check = $schema->resultset("NaturalDiversity::NdProtocol")->find({
        name => $map_protocol_name
    });
    if ($protocol_row_check){
        $protocol_id = $protocol_row_check->nd_protocol_id;
    } else {
        print STDERR "Reading genotype information for protocolprop storage...\n";
        my $gtio = CXGN::GenotypeIO->new( { file => $file, format => "vcf" });

        my %protocolprop_json;

        my $observation_unit_names = $gtio->observation_unit_names();
        my $number_observation_units = scalar(@$observation_unit_names);
        print STDERR "Number observation units: $number_observation_units...\n";

        my $header_info_lines = $gtio->header_information_lines();
        $protocolprop_json{'header_information_lines'} = $header_info_lines;
        $protocolprop_json{'reference_genome_name'} = $reference_genome_name;

        while (my ($marker_info, $values) = $gtio->next_vcf_row() ) {

            if ($marker_info){
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
                $protocolprop_json{'markers'}->{$marker_name} = \%marker;
            }
        }
        #print STDERR Dumper \%protocolprop_json;
        print STDERR "Protocol hash created...\n";

        my $protocol_row = $schema->resultset("NaturalDiversity::NdProtocol")->create({
            name => $map_protocol_name,
            type_id => $geno_cvterm_id
        });
        $protocol_id = $protocol_row->nd_protocol_id();

        #Save the protocolprop. This json string contains the details for the maarkers used in the map.
        my $json_string = encode_json \%protocolprop_json;
        my $new_protocolprop_sql = "INSERT INTO nd_protocolprop (nd_protocol_id, type_id, value) VALUES (?, ?, ?);";
        my $h = $schema->storage->dbh()->prepare($new_protocolprop_sql);
        $h->execute($protocol_id, $vcf_map_details_id, $json_string);

        undef %protocolprop_json;
        undef $json_string;
        undef $new_protocolprop_sql;

        print STDERR "Protocolprop stored...\n";
    }

    print STDERR "Reading genotype information for genotyeprop...\n";
    my $gtio = CXGN::GenotypeIO->new( { file => $file, format => "vcf" });

    my $observation_unit_names = $gtio->observation_unit_names();

    my %genotypeprop_observation_units;

    my $number_observation_units = scalar(@$observation_unit_names);
    print STDERR "Number observation units: $number_observation_units...\n";

    while (my ($marker_info, $values) = $gtio->next_vcf_row() ) {

        if ($marker_info){
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
    }
    #print STDERR Dumper \%genotypeprop_observation_units;

    print STDERR "Genotypeprop observation units hash created\n";

    my $stock_type = $self->observation_unit_type_name;
    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type, 'stock_type')->cvterm_id();

    my $new_genotypeprop_sql = "INSERT INTO genotypeprop (genotype_id, type_id, value) VALUES (?, ?, ?);";
    my $h = $schema->storage->dbh()->prepare($new_genotypeprop_sql);

    my %nd_experiment_ids;

    foreach (@$observation_unit_names) {

        my ($observation_unit_name, $igd_number) = split(/:/, $_);

        #print STDERR "Looking for observation unit $observation_unit_name\n";
        my $stock;
        my $stock_rs = $schema->resultset("Stock::Stock")->search({
            uniquename => $observation_unit_name,
            organism_id => $organism_id,
            type_id => $stock_type_id
        });

        if ($stock_rs->count() == 1) {
            $stock = $stock_rs->first();
        }

        if ($stock_rs->count ==0)  {

            #store the observation_unit_name in the stock table as an accession if $opt_a
            if (!$opt_a) {
                print STDERR "WARNING! Observation unit name $observation_unit_name not found for stock type $stock_type.\n";
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

        if ($self->accession_population_name && $self->observation_unit_type_name eq 'accession'){
            my $pop_rs = $stock->find_or_create_related('stock_relationship_subjects', {
                type_id => $population_members_id,
                subject_id => $stock_id,
                object_id => $population_stock_id,
            });
        }

        print STDERR "Stock name = " . $stock_name . "\n";
        my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
            nd_geolocation_id => $location_id,
            type_id => $geno_cvterm_id,
            nd_experiment_projects => [ {project_id => $project_id} ],
            nd_experiment_stocks => [ {stock_id => $stock_id, type_id => $geno_cvterm_id} ],
            nd_experiment_protocols => [ {nd_protocol_id => $protocol_id} ]
        });
        my $nd_experiment_id = $experiment->nd_experiment_id();

        print STDERR "Storing new genotype for stock " . $stock_name . " \n";
        my $genotype = $schema->resultset("Genetic::Genotype")->create({
                name        => $stock_name . "|" . $nd_experiment_id,
                uniquename  => $stock_name . "|" . $nd_experiment_id,
                description => "SNP genotypes for stock " . "(name = " . $stock_name . ", id = " . $stock_id . ")",
                type_id     => $snp_genotype_id,
        });
        my $genotype_id = $genotype->genotype_id();

        my $genotypeprop_json = $genotypeprop_observation_units{$_};
        my $json_string = encode_json $genotypeprop_json;

        #Store json for genotype. Has all markers and scores for this stock.
        $h->execute($genotype_id, $snp_genotypingprop_cvterm_id, $json_string);

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
        $nd_experiment_ids{$nd_experiment_id}++;
    }

    my $md_row = $self->metadata_schema->resultset("MdMetadata")->create({create_person_id => $self->user_id});
    $md_row->insert();
    my $upload_file = CXGN::UploadFile->new();
    my $md5 = $upload_file->get_md5($file);
    my $md5checksum = $md5->hexdigest();
    my $file_row = $self->metadata_schema->resultset("MdFiles")->create({
        basename => basename($file),
        dirname => dirname($file),
        filetype => 'genotype_vcf',
        md5checksum => $md5checksum,
        metadata_id => $md_row->metadata_id(),
    });

    foreach my $nd_experiment_id (keys %nd_experiment_ids) {
        my $experiment_files = $self->phenome_schema->resultset("NdExperimentMdFiles")->create({
            nd_experiment_id => $nd_experiment_id,
            file_id => $file_row->file_id(),
        });
    }
    return 1;
}

1;
