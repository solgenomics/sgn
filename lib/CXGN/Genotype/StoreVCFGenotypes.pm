package CXGN::Genotype::StoreVCFGenotypes;

=head1 NAME

CXGN::Genotype::StoreVCFGenotypes - an object to handle storing genotypes in genotypeprop from VCF file

=head1 USAGE

Genotyping project is a top level project for saving results from related genotyping runs under.
Protocol is for saving all the marker info, top header lines, and reference_genome_name for the uploaded file. Many files can be uploaded under the same protocol if the data contained in the separate files is actually the same protocol. If data is separated into many files, but belongs to the same identical protocol, make sure that marker info is identical across different files, however the files can have different sample names.
For sample names that contain IGD numbers (with : separation) e.g. ABC:9292:9:c19238, make sure to use the igd_numbers_included flag.
For sample names that contain Lab numbers (with . separation) e.g. ABC.A238, make sure to use the lab_numbers_included flag.

protocol_info shold be a hashref with the following:
notice that the info in the markers and markers_array keys are identical, just in two different representations.

{
    'reference_genome_name' => 'Mesculenta_511_v7',
    'species_name' => 'Manihot esculenta',
    'header_information_lines' => [
        '##fileformat=VCFv4.0',
        '##Tassel=<ID=GenotypeTable,Version=5,Description="Reference allele is not known. The major allele was used as reference allele">',
        '##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">'
    ],
    'sample_observation_unit_type_name' => 'tissue_sample',
    'marker_names' => ['marker1', 'marker2'],
    'markers' => {
        'marker1' => {
            'name' => 'marker1',
            'chrom' => '2',
            'pos' => '20032',
            'alt' => 'G',
            'ref' => 'C',
            'qual' => '99',
            'filter' => 'PASS',
            'info' => 'AR2=0.29;DR2=0.342;AF=0.375',
            'format' => 'GT:AD:DP:GQ:DS:PL'
        },
        'marker2' => {
            'name' => 'marker2',
            'chrom' => '2',
            'pos' => '20033',
            'alt' => 'G',
            'ref' => 'C',
            'qual' => '99',
            'filter' => 'PASS',
            'info' => 'AR2=0.29;DR2=0.342;AF=0.375',
            'format' => 'GT:AD:DP:GQ:DS:PL'
        }
    },
    'markers_array' => [
        {
            'name' => 'marker1',
            'chrom' => '2',
            'pos' => '20032',
            'alt' => 'G',
            'ref' => 'C',
            'qual' => '99',
            'filter' => 'PASS',
            'info' => 'AR2=0.29;DR2=0.342;AF=0.375',
            'format' => 'GT:AD:DP:GQ:DS:PL'
        },
        {
            'name' => 'marker2',
            'chrom' => '2',
            'pos' => '20033',
            'alt' => 'G',
            'ref' => 'C',
            'qual' => '99',
            'filter' => 'PASS',
            'info' => 'AR2=0.29;DR2=0.342;AF=0.375',
            'format' => 'GT:AD:DP:GQ:DS:PL'
        }
    ]
}

genotype_info shold be a hashref with the following (though the inner object keys are whatever is in the VCF format):
notice that the top level keys are all the sample names, and the next keys are marker names
{
    'samplename1' => {
        'marker1' => {
            'GT' => '0/0',
            'AD' => '9,0',
            'DP' => '9',
            'GQ' => '99',
            'DS'=> '0',
            'PL' => '0,27,255'
        },
        'marker2' => {
            'GT' => '0/0',
            'AD' => '9,0',
            'DP' => '9',
            'GQ' => '99',
            'DS'=> '0',
            'PL' => '0,27,255'
        }
    },
    'samplename2' => {
        'marker1' => {
            'GT' => '0/0',
            'AD' => '9,0',
            'DP' => '9',
            'GQ' => '99',
            'DS'=> '0',
            'PL' => '0,27,255'
        },
        'marker2' => {
            'GT' => '0/0',
            'AD' => '9,0',
            'DP' => '9',
            'GQ' => '99',
            'DS'=> '0',
            'PL' => '0,27,255'
        }
    }
}

For storing genotyping data from a brand new genotyping project and protocol:
my $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new(
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    protocol_info => \%protocol_info,
    genotype_info => \%genotype_info,
    observation_unit_uniquenames => \@sample_uniquenames,
    observation_unit_type_name=>'tissue_sample',
    breeding_program_id=>101,
    genotyping_facility=>'IGD',
    project_year=>'2018',
    project_location_id=>$location_id,
    project_name=>'VCF2018',
    project_description=>'description',
    protocol_name=>'SNP2018',
    protocol_description=>'protocol description',
    organism_id=>$organism_id,
    user_id => 41,
    igd_numbers_included=>0,
    lab_numbers_included=>0,
    archived_filename => $archived_file,
    archived_file_type => 'genotype_vcf'  #can be 'genotype_vcf' or 'genotype_dosage'
);
my $verified_errors = $store_genotypes->validate();
my $return = $store_genotypes->store();

---------------------------------------------------------------

For storing genotyping data from a new protocol in a previously created genotyping project, use project_id:
my $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new(
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    protocol_info => \%protocol_info,
    genotype_info => \%genotype_info,
    observation_unit_uniquenames => \@sample_uniquenames,
    observation_unit_type_name=>'tissue_sample',
    project_location_id=>$location_id,
    project_id=>123,
    protocol_name=>'SNP2018',
    protocol_description=>'protocol description',
    organism_id=>$organism_id,
    user_id => 41,
    igd_numbers_included=>0,
    lab_numbers_included=>0,
    archived_filename => $archived_file,
    archived_file_type => 'genotype_vcf'  #can be 'genotype_vcf' or 'genotype_dosage'
);
my $verified_errors = $store_genotypes->validate();
my $return = $store_genotypes->store();

---------------------------------------------------------------

For storing genotyping data from a previously saved protocol in a new project, use protocol_id:
my $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new(
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    protocol_info => \%protocol_info,
    genotype_info => \%genotype_info,
    observation_unit_uniquenames => \@sample_uniquenames,
    observation_unit_type_name=>'tissue_sample',
    breeding_program_id=>101,
    genotyping_facility=>'IGD',
    project_year=>'2018',
    project_location_id=>$location_id,
    project_name=>'VCF2018',
    project_description=>'description',
    protocol_id => 23,
    organism_id=>$organism_id,
    user_id => 41,
    igd_numbers_included=>0,
    lab_numbers_included=>0,
    archived_filename => $archived_file,
    archived_file_type => 'genotype_vcf'  #can be 'genotype_vcf' or 'genotype_dosage'
);
my $verified_errors = $store_genotypes->validate();
my $return = $store_genotypes->store();

---------------------------------------------------------------

For storing genotying data from a previously saved protocol in a previously saved project, use project_id and protocol_id:
my $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new(
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    protocol_info => \%protocol_info,
    genotype_info => \%genotype_info,
    observation_unit_uniquenames => \@sample_uniquenames,
    observation_unit_type_name=>'tissue_sample',
    project_location_id=>$location_id,
    project_id=>123,
    protocol_id=>23,
    organism_id=>$organism_id,
    user_id => 41,
    igd_numbers_included=>0,
    lab_numbers_included=>0,
    archived_filename => $archived_file,
    archived_file_type => 'genotype_vcf'  #can be 'genotype_vcf' or 'genotype_dosage'
);
my $verified_errors = $store_genotypes->validate();
my $return = $store_genotypes->store();

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
use JSON;
use CXGN::Trial;

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

has 'protocol_info' => (
    isa => 'HashRef',
    is => 'rw',
    required => 1
);

has 'genotype_info' => (
    isa => 'HashRef',
    is => 'rw',
    required => 1
);

has 'observation_unit_uniquenames' => (
    isa => 'ArrayRef',
    is => 'rw',
    required => 1
);

has 'observation_unit_type_name' => ( #Can be accession, plot, plant, tissue_sample
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'breeding_program_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'genotyping_facility' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'project_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'project_year' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'project_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'project_description' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'project_location_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'protocol_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'protocol_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'protocol_description' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'organism_id' => (
    isa => 'Int',
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

has 'archived_filename' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'archived_file_type' => ( #can be 'genotype_vcf' or 'genotype_dosage' to disntiguish genotyprop between old dosage only format and more info vcf format
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'igd_numbers_included' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);

has 'lab_numbers_included' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);

sub BUILD {
    my $self = shift;
}

sub validate {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh;
    my $organism_id = $self->organism_id;
    my $observation_unit_uniquenames = $self->observation_unit_uniquenames;
    my $protocol_info = $self->protocol_info;
    my $genotype_info = $self->genotype_info;
    my $include_igd_numbers = $self->igd_numbers_included;
    my $include_lab_numbers = $self->lab_numbers_included;
    my @error_messages;
    my @warning_messages;

    #to disntiguish genotyprop between old dosage only format and more info vcf format
    if ($self->archived_file_type ne 'genotype_vcf' && $self->archived_file_type ne 'genotype_dosage'){
        push @error_messages, 'Archived filetype must be either genotype_vcf or genotype_dosage';
        return {error_messages => \@error_messages};
    }

    #check if sample names are in the database.
    if (scalar(@$observation_unit_uniquenames) == 0){
        push @error_messages, "No observtaion_unit_names in file";
    }

    #remove extra numbers, such as igd after : symbol
    my @observation_unit_uniquenames_stripped;
    foreach (@$observation_unit_uniquenames) {
	print STDERR "Now dealing with observation unit $_...\n";
        $_ =~ s/^\s+|\s+$//g;
        if ($include_igd_numbers){
            my ($observation_unit_name_with_accession_name, $igd_number) = split(/:/, $_, 2);
            $observation_unit_name_with_accession_name =~ s/^\s+|\s+$//g;
            my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $observation_unit_name_with_accession_name);
            push @observation_unit_uniquenames_stripped, $observation_unit_name;
        }
        elsif ($include_lab_numbers){
            my ($observation_unit_name_with_accession_name, $lab_number) = split(/\./, $_, 2);
            $observation_unit_name_with_accession_name =~ s/^\s+|\s+$//g;
            my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $observation_unit_name_with_accession_name);
            push @observation_unit_uniquenames_stripped, $observation_unit_name;
        }
        else {
            my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $_);
            push @observation_unit_uniquenames_stripped, $observation_unit_name;
        }
    }

    my $stock_type = $self->observation_unit_type_name;
    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type, 'stock_type')->cvterm_id();
    my @missing_stocks;
    my $validator = CXGN::List::Validate->new();
    if ($stock_type eq 'tissue_sample'){
        @missing_stocks = @{$validator->validate($schema,'tissue_samples',\@observation_unit_uniquenames_stripped)->{'missing'}};
    } elsif ($stock_type eq 'accession'){
        @missing_stocks = @{$validator->validate($schema,'accessions',\@observation_unit_uniquenames_stripped)->{'missing'}};

        my %all_names;
        my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
        my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
        my $q = "SELECT stock.stock_id, stock.uniquename, stockprop.value, stockprop.type_id FROM stock LEFT JOIN stockprop USING(stock_id) WHERE stock.type_id=$accession_type_id AND stock.is_obsolete = 'F';";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute();
        while (my ($stock_id, $uniquename, $synonym, $type_id) = $h->fetchrow_array()) {
            $all_names{$uniquename}++;
            if ($type_id) {
                if ($type_id == $synonym_type_id) {
                    #if (exists($all_names{$synonym})){
                     #   my $previous_use = $all_names{$synonym};
                     #   push @error_messages, "DATABASE PROBLEM: The synonym $synonym is being used in $previous_use AND $uniquename. PLEASE RESOLVE THIS NOW OR CONTACT US!";
                    #}
                    #$all_names{$synonym} = $uniquename;
                }
            }
        }
    } else {
        push @error_messages, "You can only upload genotype data for a tissue_sample OR accession (including synonyms)!"
    }

    my %unique_stocks;
    foreach (@missing_stocks){
        $unique_stocks{$_}++;
    }

    @missing_stocks = sort keys %unique_stocks;
    if (scalar(@missing_stocks)>0){
        push @error_messages, "The following stocks are not in the database: ".join(',',@missing_stocks);
    }

    #check if protocol_info is correct
    while (my ($marker_name, $marker_info) = each %{$protocol_info->{markers}}){
        if (!$marker_name || !$marker_info){
            push @error_messages, "No genotype info provided";
        }
        foreach (keys %$marker_info){
            if ($_ ne 'name' && $_ ne 'chrom' && $_ ne 'pos' && $_ ne 'ref' && $_ ne 'alt' && $_ ne 'qual' && $_ ne 'filter' && $_ ne 'info' && $_ ne 'format' && $_ ne 'intertek_name'){
                push @error_messages, "protocol_info key not recognized: $_";
            }
        }
        if(!exists($marker_info->{'name'})){
            push @error_messages, "protocol_info missing name key";
        }
        if(!exists($marker_info->{'chrom'})){
            push @error_messages, "protocol_info missing chrom key";
        }
        if(!exists($marker_info->{'pos'})){
            push @error_messages, "protocol_info missing pos key";
        }
        if(!exists($marker_info->{'ref'})){
            push @error_messages, "protocol_info missing ref key";
        }
        if(!exists($marker_info->{'alt'})){
            push @error_messages, "protocol_info missing alt key";
        }
        if(!exists($marker_info->{'qual'})){
            push @error_messages, "protocol_info missing qual key";
        }
        if(!exists($marker_info->{'filter'})){
            push @error_messages, "protocol_info missing filter key";
        }
        if(!exists($marker_info->{'info'})){
            push @error_messages, "protocol_info missing info key";
        }
        if(!exists($marker_info->{'format'})){
            push @error_messages, "protocol_info missing format key";
        }
    }
    if (scalar(@{$protocol_info->{marker_names}}) == 0){
        push @error_messages, "No marker info in file";
    }
    if (scalar(@{$protocol_info->{marker_names}}) != scalar(@{$protocol_info->{markers_array}})){
        push @error_messages, "In protocol_info the markers_array is not equal in length to marker_names!";
    }

    #check if genotype_info is correct

    print STDERR Dumper($genotype_info);
    
    while (my ($observation_unit_name, $marker_result) = each %$genotype_info){
        if (!$observation_unit_name || !$marker_result){
            push @error_messages, "No geno info in genotype_info";
        }
    }

    my $previous_genotypes_exist;
    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $snp_genotype_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'snp genotyping', 'genotype_property')->cvterm_id();
    my $previous_genotypes_rs = $schema->resultset("Stock::Stock")->search({
        'me.uniquename' => {-in => \@observation_unit_uniquenames_stripped},
        'me.type_id' => $stock_type_id,
        'me.organism_id' => $organism_id,
        'nd_experiment.type_id' => $geno_cvterm_id,
        'genotype.type_id' => $snp_genotype_id
    }, {
        join => {'nd_experiment_stocks' => {'nd_experiment' => [ {'nd_experiment_genotypes' => 'genotype'}, {'nd_experiment_protocols' => 'nd_protocol'}, {'nd_experiment_projects' => 'project'} ] } },
        '+select' => ['nd_protocol.nd_protocol_id', 'nd_protocol.name', 'project.project_id', 'project.name'],
        '+as' => ['protocol_id', 'protocol_name', 'project_id', 'project_name'],
        order_by => 'genotype.genotype_id'
    });
    while(my $r = $previous_genotypes_rs->next){
	print STDERR "PREVIOUS GENOTYPES ".join (",", ($r->get_column('uniquename'), $r->get_column('protocol_name'), $r->get_column('project_name')))."\n";
        my $uniquename = $r->uniquename;
        my $protocol_name = $r->get_column('protocol_name');
        my $project_name = $r->get_column('project_name');
        push @warning_messages, "$uniquename in your file has already has genotype stored using the protocol $protocol_name in the project $project_name.";
        $previous_genotypes_exist = 1;
    }

    return {
        error_messages => \@error_messages,
        warning_messages => \@warning_messages,
        missing_stocks => \@missing_stocks,
        previous_genotypes_exist => $previous_genotypes_exist
    };
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
    my $map_protocol_description = $self->protocol_description;
    my $location_id = $self->project_location_id;
    my $igd_numbers_included = $self->igd_numbers_included;
    my $lab_numbers_included = $self->lab_numbers_included;
    my $stock_type = $self->observation_unit_type_name;
    my $organism_id = $self->organism_id;
    my $observation_unit_uniquenames = $self->observation_unit_uniquenames;
    $dbh->do('SET search_path TO public,sgn');

    my $population_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $igd_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'igd number', 'genotype_property')->cvterm_id();
    my $snp_vcf_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();
    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $snp_genotype_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'snp genotyping', 'genotype_property')->cvterm_id();
    my $vcf_map_details_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $population_members_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();
    my $design_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property');
    my $project_year_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property');
    my $genotyping_facility_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_facility', 'project_property');
    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type, 'stock_type')->cvterm_id();

    #for differentiating between genotypeprop info stored in the 'old' format of only storing dosage in json, and genotypeprop data stored in the expanded json form
    my $snp_genotypingprop_cvterm_id;
    if ($self->archived_file_type eq 'genotype_vcf'){
        $snp_genotypingprop_cvterm_id = $snp_vcf_cvterm_id;
    } elsif ($self->archived_file_type eq 'genotype_dosage'){
        $snp_genotypingprop_cvterm_id = $snp_genotype_id;
    }

    #when project_id is provided, a new project is not created
    my $project_id;
    my $project_check = $schema->resultset("Project::Project")->find({
        project_id => $self->project_id
    });
    if ($project_check){
        $project_id = $project_check->project_id;
    } else {
        my $project = $schema->resultset("Project::Project")->find_or_create({
            name => $opt_p,
            description => $project_description,
        });
        $project_id = $project->project_id();
        $project->create_projectprops( { $project_year_cvterm->name() => $opt_y } );
        $project->create_projectprops( { $genotyping_facility_cvterm->name() => $genotype_facility } );
        $project->create_projectprops( { $design_cvterm->name() => 'genotype_data_project' } );

        my $t = CXGN::Trial->new({
            bcs_schema => $schema,
            trial_id => $project_id
        });
        $t->set_breeding_program($self->breeding_program_id);
        $t->set_location($location_id);
    }

    #if population name given and samples are actually accession names
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

    #When protocol_id provided, a new protocol is not created
    my $protocol_id;
    my $protocol_row_check = $schema->resultset("NaturalDiversity::NdProtocol")->find({
        nd_protocol_id => $self->protocol_id
    });
    if ($protocol_row_check){
        $protocol_id = $protocol_row_check->nd_protocol_id;
    } else {
        my $protocol_row = $schema->resultset("NaturalDiversity::NdProtocol")->find_or_create({
            name => $map_protocol_name,
            type_id => $geno_cvterm_id
        });
        $protocol_id = $protocol_row->nd_protocol_id();

        my $q = "UPDATE nd_protocol SET description = ? WHERE nd_protocol_id = ?;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($map_protocol_description, $protocol_id);

        #Save the protocolprop. This json string contains the details for the maarkers used in the map.
        my $json_string = encode_json $self->protocol_info;
        my $new_protocolprop_sql = "INSERT INTO nd_protocolprop (nd_protocol_id, type_id, value) VALUES (?, ?, ?);";
        my $h_protocolprop = $schema->storage->dbh()->prepare($new_protocolprop_sql);
        $h_protocolprop->execute($protocol_id, $vcf_map_details_id, $json_string);

        print STDERR "Protocolprop stored...\n";
    }

    #preparing insertion of new genotypes and genotype props
    my $genotypeprop_observation_units = $self->genotype_info;
    my $new_genotypeprop_sql = "INSERT INTO genotypeprop (genotype_id, type_id, value) VALUES (?, ?, ?);";
    my $h_genotypeprop = $schema->storage->dbh()->prepare($new_genotypeprop_sql);
    my %nd_experiment_ids;
    my $stock_relationship_schema = $schema->resultset("Stock::StockRelationship");
    my $nd_experiment_schema = $schema->resultset('NaturalDiversity::NdExperiment');
    my $genotype_schema = $schema->resultset("Genetic::Genotype");
    my $genotypeprop_schema = $schema->resultset("Genetic::Genotypeprop");

    #remove extra numbers, such as igd after : symbol
    my @observation_unit_uniquenames_stripped;
    foreach (@$observation_unit_uniquenames) {
        $_ =~ s/^\s+|\s+$//g;
        if ($igd_numbers_included){
            my ($observation_unit_name_with_accession_name, $igd_number) = split(/:/, $_, 2);
            my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $observation_unit_name_with_accession_name);
            push @observation_unit_uniquenames_stripped, $observation_unit_name;
        }
        elsif ($lab_numbers_included){
            my ($observation_unit_name_with_accession_name, $lab_number) = split(/\./, $_, 2);
            my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $observation_unit_name_with_accession_name);
            push @observation_unit_uniquenames_stripped, $observation_unit_name;
        }
        else {
            my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $_);
            push @observation_unit_uniquenames_stripped, $observation_unit_name;
        }
    }

    my %all_names;
    my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $tissue_sample_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $q = "SELECT stock.stock_id, stock.uniquename, stockprop.value, stockprop.type_id FROM stock LEFT JOIN stockprop USING(stock_id) WHERE stock.type_id IN ($accession_type_id,$tissue_sample_type_id) AND stock.is_obsolete = 'F';";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %stock_lookup;
    while (my ($stock_id, $uniquename, $synonym, $type_id) = $h->fetchrow_array()) {
        $stock_lookup{$uniquename} = $stock_id;
        if ($type_id) {
            if ($type_id == $synonym_type_id) {
                $stock_lookup{$synonym} = $stock_id;
            }
        }
    }

    foreach (@$observation_unit_uniquenames) {
        $_ =~ s/^\s+|\s+$//g;
        my $observation_unit_name_with_accession_name;
        my $observation_unit_name;
        my $accession_name;
        my $igd_number;
        my $lab_number;
        if ($igd_numbers_included){
            ($observation_unit_name_with_accession_name, $igd_number) = split(/:/, $_, 2);
            $observation_unit_name_with_accession_name =~ s/^\s+|\s+$//g;
            ($observation_unit_name, $accession_name) = split(/\|\|\|/, $observation_unit_name_with_accession_name);
        } elsif ($lab_numbers_included) {
            ($observation_unit_name_with_accession_name, $lab_number) = split(/\./, $_, 2);
            $observation_unit_name_with_accession_name =~ s/^\s+|\s+$//g;
            ($observation_unit_name, $accession_name) = split(/\|\|\|/, $observation_unit_name_with_accession_name);
        } else {
            ($observation_unit_name, $accession_name) = split(/\|\|\|/, $_);
        }
        #print STDERR Dumper $observation_unit_name;
        my $stock_id = $stock_lookup{$observation_unit_name};

        if ($self->accession_population_name && $self->observation_unit_type_name eq 'accession'){
            my $pop_rs = $stock_relationship_schema->find_or_create({
                type_id => $population_members_id,
                subject_id => $stock_id,
                object_id => $population_stock_id,
            });
        }

        my $experiment = $nd_experiment_schema->create({
            nd_geolocation_id => $location_id,
            type_id => $geno_cvterm_id,
            nd_experiment_projects => [ {project_id => $project_id} ],
            nd_experiment_stocks => [ {stock_id => $stock_id, type_id => $geno_cvterm_id} ],
            nd_experiment_protocols => [ {nd_protocol_id => $protocol_id} ]
        });
        my $nd_experiment_id = $experiment->nd_experiment_id();

        print STDERR "Storing new genotype for stock " . $observation_unit_name . " \n";
        my $genotype = $genotype_schema->create({
            name        => $observation_unit_name . "|" . $nd_experiment_id,
            uniquename  => $observation_unit_name . "|" . $nd_experiment_id,
            description => "SNP genotypes for stock " . "(name = " . $observation_unit_name . ", id = " . $stock_id . ")",
            type_id     => $snp_genotype_id,
        });
        my $genotype_id = $genotype->genotype_id();

        my $genotypeprop_json = $genotypeprop_observation_units->{$_};
        my $json_string = encode_json $genotypeprop_json;

        #Store json for genotype. Has all markers and scores for this stock.
        $h_genotypeprop->execute($genotype_id, $snp_genotypingprop_cvterm_id, $json_string);

        #Store IGD number if the option is given.
        if ($igd_numbers_included) {
            my %igd_number = ('igd_number' => $igd_number);
            my $json_obj = JSON::Any->new;
            my $json_string = $json_obj->encode(\%igd_number);
            my $add_genotypeprop = $genotypeprop_schema->create({ genotype_id => $genotype_id, type_id => $igd_number_cvterm_id, value => $json_string });
        }

        #link the genotype to the nd_experiment
        my $nd_experiment_genotype = $experiment->create_related('nd_experiment_genotypes', { genotype_id => $genotype->genotype_id() } );
        $nd_experiment_ids{$nd_experiment_id}++;
    }

    #create relationship between nd_experiment and originating archived file
    my $file = $self->archived_filename;
    my $md_row = $self->metadata_schema->resultset("MdMetadata")->create({create_person_id => $self->user_id});
    $md_row->insert();
    my $upload_file = CXGN::UploadFile->new();
    my $md5 = $upload_file->get_md5($file);
    my $md5checksum = $md5->hexdigest();
    my $file_row = $self->metadata_schema->resultset("MdFiles")->create({
        basename => basename($file),
        dirname => dirname($file),
        filetype => $self->archived_file_type,
        md5checksum => $md5checksum,
        metadata_id => $md_row->metadata_id(),
    });
    foreach my $nd_experiment_id (keys %nd_experiment_ids) {
        my $experiment_files = $self->phenome_schema->resultset("NdExperimentMdFiles")->create({
            nd_experiment_id => $nd_experiment_id,
            file_id => $file_row->file_id(),
        });
    }

    my %response = (
        success => 1,
        nd_protocol_id => $protocol_id,
        project_id => $project_id
    );

    return \%response;
}

1;
