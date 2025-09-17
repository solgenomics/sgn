
package CXGN::Stock::RelatedStocks;

use strict;
use warnings;
use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'dbic_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'stock_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);

has 'trial_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);



sub get_trial_related_stock {
    my $self = shift;
    my $stock_id = $self->stock_id;
    my $schema = $self->dbic_schema();
    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $subplot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot_of', 'stock_relationship')->cvterm_id();
    my $plant_of_subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of_subplot', 'stock_relationship')->cvterm_id();
#    my $seed_transaction_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seed transaction', 'stock_relationship')->cvterm_id();
    my $tissue_sample_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship
            INNER JOIN stock ON (stock_relationship.subject_id = stock.stock_id)
            INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
            WHERE stock_relationship.object_id = ? AND (stock_relationship.type_id = ?
            OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? )

            UNION ALL

            SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship
            INNER JOIN stock ON (stock_relationship.object_id = stock.stock_id)
            INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
            WHERE stock_relationship.subject_id = ? AND (stock_relationship.type_id = ?
            OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? ) ";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($stock_id, $plot_of_type_id, $plant_of_type_id, $subplot_of_type_id, $plant_of_subplot_type_id, $tissue_sample_of_type_id, $stock_id, $plot_of_type_id, $plant_of_type_id, $subplot_of_type_id, $plant_of_subplot_type_id, $tissue_sample_of_type_id);

    my @trial_related_stock =();
    while(my($stock_id, $stock_name, $cvterm_name) = $h->fetchrow_array()){

      push @trial_related_stock, [$stock_id, $stock_name, $cvterm_name]
    }

    return\@trial_related_stock;
}


sub get_progenies {
    my $self = shift;
    my $stock_id = $self->stock_id;
    my $schema = $self->dbic_schema();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $q = "SELECT cvterm.name, stock.stock_id, stock.uniquename, stock_relationship.value FROM stock_relationship
             INNER JOIN stock ON (stock_relationship.object_id = stock.stock_id)
             INNER JOIN cvterm ON (stock_relationship.type_id =cvterm.cvterm_id)
             WHERE stock_relationship.subject_id = ? AND(stock_relationship.type_id =?
             OR stock_relationship.type_id = ?) AND stock.type_id = ? ORDER BY cvterm.name DESC, stock.uniquename ASC";

    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($stock_id, $female_parent_type_id, $male_parent_type_id, $accession_type_id);

    my @progenies =();
        while(my($cvterm_name, $stock_id, $stock_name, $cross_type) = $h->fetchrow_array()){
        push @progenies, [$cvterm_name, $stock_id, $stock_name, $cross_type]
        }

        return\@progenies;

}


sub get_group_and_member {
    my $self = shift;
    my $stock_id = $self->stock_id;
    my $schema = $self->dbic_schema();
    my $member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();
    my $offspring_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'offspring_of', 'stock_relationship')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship INNER JOIN stock
             ON (stock_relationship.object_id = stock.stock_id) INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
             WHERE stock_relationship.subject_id = ? and stock_relationship.type_id = ?

             UNION ALL

             SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship INNER JOIN stock
             ON (stock_relationship.subject_id = stock.stock_id) INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
             WHERE stock_relationship.object_id = ? and stock_relationship.type_id = ?

             UNION ALL

             SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship INNER JOIN stock
             ON (stock_relationship.object_id = stock.stock_id) INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
             WHERE stock_relationship.subject_id = ? and stock_relationship.type_id = ?

             ";

    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($stock_id, $member_of_type_id, $stock_id, $member_of_type_id, $stock_id, $offspring_of_type_id);

    my @group =();
        while(my($stock_id, $stock_name, $cvterm_name) = $h->fetchrow_array()){
        push @group, [$stock_id, $stock_name, $cvterm_name]
        }

        return\@group;

}


sub get_stock_for_tissue {
    my $self = shift;
    my $stock_id = $self->stock_id;
    my $schema = $self->dbic_schema();
    my $tissue_sample_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
    my $q = "SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship INNER JOIN stock
             ON (stock_relationship.object_id = stock.stock_id) INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
             WHERE stock_relationship.subject_id = ? and stock_relationship.type_id = ?

             UNION ALL

             SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship INNER JOIN stock
             ON (stock_relationship.subject_id = stock.stock_id) INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
             WHERE stock_relationship.object_id = ? and stock_relationship.type_id = ?

             ";

    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($stock_id, $tissue_sample_of_type_id, $stock_id, $tissue_sample_of_type_id);

    my @tissue_stocks =();
        while(my($stock_id, $stock_name, $cvterm_name) = $h->fetchrow_array()){
        push @tissue_stocks, [$stock_id, $stock_name, $cvterm_name]
        }

        return\@tissue_stocks;

}


sub get_cross_of_progeny {
    my $self = shift;
    my $progeny_name = shift;
    my $schema = shift;
    my $offspring_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'offspring_of', 'stock_relationship')->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

    my $q = "SELECT cross_stock.stock_id, cross_stock.uniquename FROM stock
            JOIN stock_relationship ON (stock.stock_id = stock_relationship.subject_id) AND stock_relationship.type_id = ?
            JOIN stock AS cross_stock on (stock_relationship.object_id = cross_stock.stock_id) AND cross_stock.type_id = ?
            WHERE stock.uniquename = ?
            ";

    my $h = $schema->storage->dbh->prepare($q);
             $h->execute($offspring_of_type_id, $cross_type_id, $progeny_name);

             my @cross =();
            while(my($stock_id, $stock_name) = $h->fetchrow_array()){
                 push @cross, [$stock_id, $stock_name]
            }

            return\@cross;
}


sub get_plot_plant_related_seedlots {
    my $self = shift;
    my $stock_id = $self->stock_id;
    my $schema = $self->dbic_schema();
    my $seed_transaction_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seed transaction', 'stock_relationship')->cvterm_id();

    my @related_seedlots;

    my $q1 = "SELECT distinct(stock.stock_id), stock.uniquename, cvterm.name FROM stock_relationship
            INNER JOIN stock ON (stock_relationship.subject_id = stock.stock_id)
            INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
            WHERE stock_relationship.object_id = ? AND stock_relationship.type_id = ? ";

    my $h1 = $schema->storage->dbh()->prepare($q1);

    $h1->execute($stock_id, $seed_transaction_type_id);

    while(my($stock_id, $stock_name, $stock_type) = $h1->fetchrow_array()){
      push @related_seedlots, ['source of', $stock_type, $stock_id, $stock_name]
    }

    my $q2 = "SELECT distinct(stock.stock_id), stock.uniquename, cvterm.name FROM stock_relationship
            INNER JOIN stock ON (stock_relationship.object_id = stock.stock_id)
            INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
            WHERE stock_relationship.subject_id = ? AND stock_relationship.type_id = ? ";

    my $h2 = $schema->storage->dbh()->prepare($q2);

    $h2->execute($stock_id, $seed_transaction_type_id);

    while(my($stock_id, $stock_name, $stock_type) = $h2->fetchrow_array()){
      push @related_seedlots, ['derived from', $stock_type, $stock_id, $stock_name]
    }

    return\@related_seedlots;

}


sub get_vector_related_accessions {
    my $self = shift;
    my $stock_id = $self->stock_id;
    my $schema = $self->dbic_schema();

    my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $vector_construct_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct", "stock_type")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $transformant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformant_of', 'stock_relationship')->cvterm_id();
    my $number_of_insertions_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'number_of_insertions', 'stock_property')->cvterm_id();
    my $expression_data_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transgene_expression_data', 'stock_property')->cvterm_id();

    my $q = "SELECT transformant.stock_id, transformant.uniquename, plant.stock_id, plant.uniquename, transformation.stock_id, transformation.uniquename, stockprop.value, expression.value
        FROM stock AS transformant
        JOIN stock_relationship AS plant_relationship ON (plant_relationship.object_id = transformant.stock_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (vector_relationship.object_id = transformant.stock_id) AND vector_relationship.type_id = ?
        JOIN stock as vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stock_relationship AS transformation_relationship ON (transformation_relationship.subject_id = transformant.stock_id) AND transformation_relationship.type_id = ?
        LEFT JOIN stock AS transformation ON (transformation_relationship.object_id = transformation.stock_id) AND transformation.type_id = ?
        LEFT JOIN stockprop ON (transformant.stock_id = stockprop.stock_id) AND stockprop.type_id = ?
        LEFT JOIN stockprop AS expression ON (transformant.stock_id = expression.stock_id) AND expression.type_id = ?
        WHERE vector.stock_id = ? AND transformant.is_obsolete = 'F' ORDER BY transformation.uniquename, transformant.uniquename";

    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($female_parent_type_id, $accession_type_id, $male_parent_type_id, $vector_construct_type_id,  $transformant_of_type_id, $transformation_type_id, $number_of_insertions_type_id, $expression_data_type_id, $stock_id);

    my @related_stocks =();
    while(my($transformant_id, $transformant_name, $plant_id, $plant_name, $transformation_id, $transformation_name, $number_of_insertions, $expression_data) = $h->fetchrow_array()){
        push @related_stocks, [$transformant_id, $transformant_name, $plant_id, $plant_name, $transformation_id, $transformation_name, $number_of_insertions, $expression_data]
    }

    return \@related_stocks;

}


sub get_vector_obsoleted_accessions {
    my $self = shift;
    my $stock_id = $self->stock_id;
    my $schema = $self->dbic_schema();

    my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $vector_construct_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct", "stock_type")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $transformant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformant_of', 'stock_relationship')->cvterm_id();

    my $q = "SELECT transformant.stock_id, transformant.uniquename, plant.stock_id, plant.uniquename, transformation.stock_id, transformation.uniquename, metadata.md_metadata.obsolete_note, metadata.md_metadata.modification_note, phenome.stock_owner.sp_person_id
        FROM stock AS transformant
        JOIN phenome.stock_owner ON (transformant.stock_id = phenome.stock_owner.stock_id)
        JOIN metadata.md_metadata ON (phenome.stock_owner.metadata_id = metadata.md_metadata.metadata_id)
        JOIN stock_relationship AS plant_relationship ON (plant_relationship.object_id = transformant.stock_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (vector_relationship.object_id = transformant.stock_id) AND vector_relationship.type_id = ?
        JOIN stock as vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stock_relationship AS transformation_relationship ON (transformation_relationship.subject_id = transformant.stock_id) AND transformation_relationship.type_id = ?
        LEFT JOIN stock AS transformation ON (transformation_relationship.object_id = transformation.stock_id) AND transformation.type_id = ?
        WHERE vector.stock_id = ? AND transformant.is_obsolete != 'F' ORDER BY transformation.uniquename, transformant.uniquename";

    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($female_parent_type_id, $accession_type_id, $male_parent_type_id, $vector_construct_type_id,  $transformant_of_type_id, $transformation_type_id, $stock_id);

    my @obsoleted_accessions =();
    while(my($transformant_id, $transformant_name, $plant_id, $plant_name, $transformation_id, $transformation_name, $obsolete_note, $obsolete_date, $sp_person_id) = $h->fetchrow_array()){
        push @obsoleted_accessions, [$transformant_id, $transformant_name, $plant_id, $plant_name, $transformation_id, $transformation_name, $obsolete_note, $obsolete_date, $sp_person_id]
    }

    return \@obsoleted_accessions;

}


sub get_plots_and_plants {
    my $self = shift;
    my $stock_id = $self->stock_id;
    my $trial_id = $self->trial_id;
    my $schema = $self->dbic_schema();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $field_layout_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "field_layout", "experiment_type")->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename
        FROM nd_experiment_project join nd_experiment on (nd_experiment_project.nd_experiment_id=nd_experiment.nd_experiment_id) AND nd_experiment.type_id= ?
        JOIN nd_experiment_stock ON (nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
        JOIN stock_relationship on (nd_experiment_stock.stock_id = stock_relationship.subject_id) AND stock_relationship.object_id = ?
        JOIN stock on (stock_relationship.subject_id = stock.stock_id) AND stock.type_id IN (?,?)
        WHERE nd_experiment_project.project_id= ? ";

    my $h = $schema->storage->dbh->prepare($q);

    $h->execute($field_layout_typeid, $stock_id, $plot_type_id, $plant_type_id, $trial_id, );

    my @related_stocks = ();
    while(my ($stock_id, $stock_name) = $h->fetchrow_array()){
        push @related_stocks, [$stock_id, $stock_name];
    }

    return\@related_stocks;
}




1;
