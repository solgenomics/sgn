package CXGN::Genotype::Protocol;

=head1 NAME

CXGN::Genotype::Protocol - an object to handle genotyping protocols (breeding data)

To get info for a specific protocol:

my $protocol = CXGN::Genotype::Protocol->new({
    bcs_schema => $schema,
    nd_protocol_id => $protocol_id
});
And then use Moose attributes to retrieve markers, refrence name, etc

----------------

To get a list of protocols and their info:
my $protocol_list = CXGN::Genotype::Protocol::list($schema);
This can take search params in, like protocol_ids, accessions, etc

=head1 USAGE

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use JSON;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'nd_protocol_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'protocol_name' => (
    isa => 'Str',
    is => 'rw',
);

has 'protocol_description' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'markers' => (
    isa => 'HashRef',
    is => 'rw',
);

has 'marker_names' => (
    isa => 'ArrayRef',
    is => 'rw'
);

has 'header_information_lines' => (
    isa => 'ArrayRef',
    is => 'rw'
);

has 'reference_genome_name' => (
    isa => 'Str',
    is => 'rw'
);

has 'species_name' => (
    isa => 'Str',
    is => "rw"
);

has 'sample_observation_unit_type_name' => (
    isa => 'Str',
    is => 'rw'
);

has 'create_date' => (
    isa => 'Str',
    is => 'rw'
);

sub BUILD {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $protocol_vcf_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();

    my $protocol_rs = $schema->resultset('NaturalDiversity::NdProtocol')->search({
        'me.nd_protocol_id'=>$self->nd_protocol_id,
        'me.type_id'=>$geno_cvterm_id,
        #'nd_protocolprops.type_id'=>$protocol_vcf_details_cvterm_id
    }, {
        join => 'nd_protocolprops',
        '+select' => ['nd_protocolprops.value'],
        '+as' => ['value']
    });
    if ($protocol_rs->count != 1){
        print STDERR "Not a valide nd_protocol_id\n";
        return;
    }
    my $protocol = $protocol_rs->first;
    my $map_details = $protocol->get_column('value') ? decode_json $protocol->get_column('value') : {};
    my $markers = $map_details->{markers} || {};
    my $marker_names = $map_details->{marker_names} || [];
    my $header_information_lines = $map_details->{header_information_lines} || [];
    my $reference_genome_name = $map_details->{reference_genome_name} || 'Not set. Please reload these genotypes using new genotype format!';
    my $species_name = $map_details->{species_name} || 'Not set. Please reload these genotypes using new genotype format!';
    my $sample_observation_unit_type_name = $map_details->{sample_observation_unit_type_name} || 'Not set. Please reload these genotypes using new genotype format!';
    $self->markers($markers);
    $self->marker_names($marker_names);
    $self->protocol_name($protocol->name);
    $self->header_information_lines($header_information_lines);
    $self->reference_genome_name($reference_genome_name);
    $self->species_name($species_name);
    $self->sample_observation_unit_type_name($sample_observation_unit_type_name);

    my $q = "SELECT create_date, description FROM nd_protocol WHERE nd_protocol_id = ?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($self->nd_protocol_id);
    my ($create_date, $description) = $h->fetchrow_array();
    $create_date = $create_date || 'Not set. Please reload these genotypes using new genotype format!';
    $self->create_date($create_date);
    $self->protocol_description($description);

    return;
}

#class method
sub list {
    my $schema = shift;
    my $protocol_list = shift;
    my $accession_list = shift;
    my $tissue_sample_list = shift;
    my $limit = shift;
    my $offset = shift;
    my $genotyping_data_project_list = shift;
    my @where_clause;

    my $vcf_map_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();

    #push @where_clause, "nd_protocolprop.type_id = $vcf_map_details_cvterm_id";

    if ($protocol_list && scalar(@$protocol_list)>0) {
        my $protocol_sql = join ("," , @$protocol_list);
        push @where_clause, "nd_protocol.nd_protocol_id in ($protocol_sql)";
    }
    if ($genotyping_data_project_list && scalar(@$genotyping_data_project_list)>0) {
        my $sql = join ("," , @$genotyping_data_project_list);
        push @where_clause, "project.project_id in ($sql)";
    }
    if ($accession_list && scalar(@$accession_list)>0) {
        my $accession_sql = join ("," , @$accession_list);
        push @where_clause, "stock.stock_id in ($accession_sql)";
        push @where_clause, "stock.type_id = $accession_cvterm_id";
    }
    if ($tissue_sample_list && scalar(@$tissue_sample_list)>0) {
        my $stock_sql = join ("," , @$tissue_sample_list);
        push @where_clause, "stock.stock_id in ($stock_sql)";
        push @where_clause, "stock.type_id = $tissue_sample_cvterm_id";
    }
    
    my $offset_clause = '';
    my $limit_clause = '';
    if ($limit){
        $limit_clause = " LIMIT $limit ";
    }
    if ($offset){
        $offset_clause = " OFFSET $offset ";
    }
    my $where_clause = scalar(@where_clause) > 0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, nd_protocol.create_date, nd_protocolprop.value, project.project_id, project.name, count(nd_protocol.nd_protocol_id) OVER() AS full_count
        FROM stock
        JOIN cvterm AS stock_cvterm ON(stock.type_id = stock_cvterm.cvterm_id)
        JOIN nd_experiment_stock USING(stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_protocol USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        JOIN nd_protocol USING(nd_protocol_id)
        LEFT JOIN nd_protocolprop ON(nd_protocolprop.nd_protocol_id = nd_protocol.nd_protocol_id)
        JOIN project USING(project_id)
        $where_clause
        GROUP BY (nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, nd_protocol.create_date, nd_protocolprop.value, project.project_id, project.name)
        ORDER BY nd_protocol.nd_protocol_id ASC
        $limit_clause
        $offset_clause;";

    print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    
    my @results;
    while (my ($protocol_id, $protocol_name, $protocol_description, $create_date, $protocolprop_json, $project_id, $project_name, $sample_count) = $h->fetchrow_array()) {
        my $protocol = $protocolprop_json ? decode_json $protocolprop_json : {};
        my $marker_set = $protocol->{markers} || {};
        my $marker_names = $protocol->{marker_names} || [];
        my $header_information_lines = $protocol->{header_information_lines} || [];
        my $reference_genome_name = $protocol->{reference_genome_name} || 'Not set. Please reload these genotypes using new genotype format!';
        my $species_name = $protocol->{species_name} || 'Not set. Please reload these genotypes using new genotype format!';
        my $sample_observation_unit_type_name = $protocol->{sample_observation_unit_type_name} || 'Not set. Please reload these genotypes using new genotype format!';
        $create_date = $create_date || 'Not set. Please reload these genotypes using new genotype format!';
        push @results, {
            protocol_id => $protocol_id,
            protocol_name => $protocol_name,
            protocol_description => $protocol_description,
            markers => $marker_set,
            marker_names => $marker_names,
            header_information_lines => $header_information_lines,
            reference_genome_name => $reference_genome_name,
            species_name => $species_name,
            sample_observation_unit_type_name => $sample_observation_unit_type_name,
            project_name => $project_name,
            project_id => $project_id,
            create_date => $create_date,
            observation_unit_count => $sample_count
        };
    }
    #print STDERR Dumper \@results;
    return \@results;
}

#class method
sub list_simple {
    my $schema = shift;
    my @where_clause;

    my $vcf_map_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, nd_protocol.create_date, nd_protocolprop.value, project.project_id, project.name
        FROM nd_protocol
        LEFT JOIN nd_protocolprop ON(nd_protocolprop.nd_protocol_id = nd_protocol.nd_protocol_id)
        JOIN nd_experiment_protocol ON(nd_protocol.nd_protocol_id = nd_experiment_protocol.nd_protocol_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        JOIN project USING(project_id)
        GROUP BY (nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, nd_protocol.create_date, nd_protocolprop.value, project.project_id, project.name)
        ORDER BY nd_protocol.nd_protocol_id ASC;";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my @results;
    while (my ($protocol_id, $protocol_name, $protocol_description, $create_date, $protocolprop_json, $project_id, $project_name) = $h->fetchrow_array()) {
        my $protocol = $protocolprop_json ? decode_json $protocolprop_json : {};
        my $marker_set = $protocol->{markers} || {};
        my $marker_names = $protocol->{marker_names} || [];
        my $header_information_lines = $protocol->{header_information_lines} || [];
        my $reference_genome_name = $protocol->{reference_genome_name} || 'Not set. Please reload these genotypes using new genotype format!';
        my $species_name = $protocol->{species_name} || 'Not set. Please reload these genotypes using new genotype format!';
        my $sample_observation_unit_type_name = $protocol->{sample_observation_unit_type_name} || 'Not set. Please reload these genotypes using new genotype format!';
        my $protocol_description = $protocol_description || 'Not set. Please reload these genotypes using new genotype format!';
        $create_date = $create_date || 'Not set. Please reload these genotypes using new genotype format!';
        push @results, {
            protocol_id => $protocol_id,
            protocol_name => $protocol_name,
            protocol_description => $protocol_description,
            markers => $marker_set,
            marker_names => $marker_names,
            header_information_lines => $header_information_lines,
            reference_genome_name => $reference_genome_name,
            species_name => $species_name,
            sample_observation_unit_type_name => $sample_observation_unit_type_name,
            project_name => $project_name,
            project_id => $project_id,
            create_date => $create_date
        };
    }
    #print STDERR Dumper \@results;
    return \@results;
}

1;

