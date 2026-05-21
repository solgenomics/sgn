=head1 NAME

CXGN::Transformation::Transformant - an object representing transformant info in the database

=head1 DESCRIPTION

=head1 AUTHORS

    Titima Tantikanjana <tt15@cornell.edu>

=head1 METHODS

=cut

package CXGN::Transformation::Transformant;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;
use CXGN::Stock::Vector;

has 'schema' => (
    isa => 'DBIx::Class::Schema',
    is => 'rw',
    required => 1,
);

has 'dbh' => (
    is  => 'rw',
    required => 1,
);

has 'transformant_stock_id' => (
    isa => "Int",
    is => 'rw',
);

has 'vector_construct' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy => 1,
    builder => '_get_vector_construct',
);

has 'plant_material' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy => 1,
    builder => '_get_plant_material',
);

has 'transgenes' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy => 1,
    builder => '_get_transgenes',
);

has 'transformation_identifier' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy => 1,
    builder => '_get_transformation_identifier',
);

sub get_transformant_qPCR_data {
    my $self = shift;
    my $schema = $self->schema();
    my $transformant_stock_id = $self->transformant_stock_id();
    my $transgenes = $self->transgenes();
    my $expression_data_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transgene_expression_data', 'stock_property')->cvterm_id();
    my $data = $schema->resultset("Stock::Stockprop")->find( {
        stock_id => $transformant_stock_id,
        type_id => $expression_data_cvterm_id,
    });

    my @qPCR_data = ();
    if ($data) {
        my $expression_data_string = $data->value();
        if ($expression_data_string) {
            my $expression_data = decode_json $expression_data_string;
            foreach my $tissue_type (keys %$expression_data) {
                my $tissue_type_data = $expression_data->{$tissue_type};
                foreach my $assay_date (keys %$tissue_type_data) {
                    my @gene_relative_values = ();
                    foreach my $gene_name (@$transgenes) {
                        my $number_of_replicates = "";
                        my $standard_deviation = "";
                        my @details = ();
                        my $detail_string = "";
                        my $qPCR_relative_values = $tissue_type_data->{$assay_date}->{$gene_name}->{'relative_expression_values'};
                        if ($qPCR_relative_values) {
                            push @details, $qPCR_relative_values->{'relative_expression'};

                            if (($qPCR_relative_values->{'relative_expression'}) ne 'ND') {
                                $number_of_replicates = $qPCR_relative_values->{'number_of_replicates'};
                                if ($number_of_replicates == 1) {
                                    push @details, $number_of_replicates."replicate";
                                } else {
                                    push @details, $number_of_replicates."replicates";
                                }
                                $standard_deviation = $qPCR_relative_values->{'stdevp'};
                                push @details, "stdevp: ". $standard_deviation;
                            }

                            $detail_string = join("<br>", @details);
                            push @gene_relative_values, $detail_string;
                        } else {
                            push @gene_relative_values, $detail_string;
                        }
                    }
                    push @qPCR_data, [$tissue_type, $assay_date, @gene_relative_values ]
                }
            }
        }
    }
    return \@qPCR_data;
}

sub _get_transformation_identifier {
    my $self = shift;
    my $schema = $self->schema();
    my $transformant_stock_id = $self->transformant_stock_id();
    my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
    my $transformant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformant_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename
        FROM stock_relationship
        JOIN stock ON (stock_relationship.object_id = stock.stock_id) and stock_relationship.type_id = ?
        WHERE stock_relationship.subject_id = ? AND stock.type_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($transformant_of_type_id, $transformant_stock_id, $transformation_type_id);
    my @transformation_identifier = $h->fetchrow_array();

    $self->vector_construct(\@transformation_identifier);
}

sub _get_vector_construct {
    my $self = shift;
    my $schema = $self->schema();
    my $transformant_stock_id = $self->transformant_stock_id();
    my $vector_construct_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct", "stock_type")->cvterm_id();
    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'male_parent', 'stock_relationship')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename
        FROM stock_relationship
        JOIN stock ON (stock_relationship.subject_id = stock.stock_id) and stock_relationship.type_id = ?
        WHERE stock_relationship.object_id = ? AND stock.type_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($male_parent_type_id, $transformant_stock_id, $vector_construct_type_id);
    my @vector_construct = $h->fetchrow_array();

    $self->vector_construct(\@vector_construct);
}

sub _get_plant_material {
    my $self = shift;
    my $schema = $self->schema();
    my $transformant_stock_id = $self->transformant_stock_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'female_parent', 'stock_relationship')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename
        FROM stock_relationship
        JOIN stock ON (stock_relationship.subject_id = stock.stock_id) and stock_relationship.type_id = ?
        where stock_relationship.object_id = ? and stock.type_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($female_parent_type_id, $transformant_stock_id, $accession_type_id);
    my @plant_material = $h->fetchrow_array();

    $self->plant_material(\@plant_material);
}

sub _get_transgenes {
    my $self = shift;
    my $schema = $self->schema();
    my $vector_construct = $self->vector_construct();
    my @transgenes = ();
    if ($vector_construct) {
        my $vector_stock_id = $vector_construct->[0];
        if ($vector_stock_id) {
            my $vector_construct = CXGN::Stock::Vector->new(schema=>$schema, stock_id=>$vector_stock_id);
            my $vector_related_genes = $vector_construct->Gene;
            if ($vector_related_genes) {
                my @genes_array = ();
                @genes_array = split ',',$vector_related_genes;
                foreach my $gene (@genes_array) {
                    $gene =~ s/^\s+|\s+$//g;
                    push @transgenes, $gene;
                }
            }
        }
    }

    $self->transgenes(\@transgenes);
}


sub get_progeny_info {
    my $self = shift;
    my $schema = $self->schema();
    my $transformant_stock_id = $self->transformant_stock_id();

    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $number_of_insertions_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'number_of_insertions', 'stock_property')->cvterm_id();
    my $transgenic_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'transgenic', 'stock_property')->cvterm_id();
    my $T_generation_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'T_generation', 'stock_property')->cvterm_id();

    my $q = "SELECT progeny.stock_id, progeny.uniquename, transgenic.value, number_of_insertions.value, T_generation.value
        FROM stock
        JOIN stock_relationship ON (stock.stock_id = stock_relationship.subject_id) AND stock_relationship.type_id = ? AND stock_relationship.value = 'self'
        JOIN stock AS progeny ON (progeny.stock_id = stock_relationship.object_id) AND progeny.type_id = ?
        LEFT JOIN stockprop AS transgenic ON (transgenic.stock_id = progeny.stock_id) AND transgenic.type_id = ?
        LEFT JOIN stockprop AS number_of_insertions ON (number_of_insertions.stock_id = progeny.stock_id) AND number_of_insertions.type_id = ?
        LEFT JOIN stockprop AS T_generation ON (T_generation.stock_id = progeny.stock_id) AND T_generation.type_id = ?
        WHERE stock.stock_id = ? ORDER BY progeny.stock_id ASC";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($female_parent_type_id, $accession_type_id, $transgenic_type_id, $number_of_insertions_type_id, $T_generation_type_id, $transformant_stock_id);

    my @progeny_info = ();
    while (my ($progeny_id,  $progeny_name, $transgenic_info, $number_of_insertions, $T_generation) = $h->fetchrow_array()){
        push @progeny_info, [$progeny_id,  $progeny_name, $transgenic_info, $number_of_insertions, $T_generation]
    }

    return \@progeny_info;

}

###
1;
###
