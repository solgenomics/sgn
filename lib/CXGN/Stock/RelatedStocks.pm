
package CXGN::Stock::RelatedStocks;

use strict;
use warnings;
use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::Stock::Seedlot;

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

    my $q = "SELECT transformant.stock_id, transformant.uniquename, plant.stock_id, plant.uniquename, transformation.stock_id, transformation.uniquename, stockprop.value
        FROM stock AS transformant
        JOIN stock_relationship AS plant_relationship ON (plant_relationship.object_id = transformant.stock_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (vector_relationship.object_id = transformant.stock_id) AND vector_relationship.type_id = ?
        JOIN stock as vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stock_relationship AS transformation_relationship ON (transformation_relationship.subject_id = transformant.stock_id) AND transformation_relationship.type_id = ?
        LEFT JOIN stock AS transformation ON (transformation_relationship.object_id = transformation.stock_id) AND transformation.type_id = ?
        LEFT JOIN stockprop ON (transformant.stock_id = stockprop.stock_id) AND stockprop.type_id = ?
        WHERE vector.stock_id = ? AND transformant.is_obsolete = 'F' ORDER BY transformation.uniquename, transformant.uniquename";

    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($female_parent_type_id, $accession_type_id, $male_parent_type_id, $vector_construct_type_id,  $transformant_of_type_id, $transformation_type_id, $number_of_insertions_type_id, $stock_id);

    my @related_stocks =();
    while(my($transformant_id, $transformant_name, $plant_id, $plant_name, $transformation_id, $transformation_name, $number_of_insertions) = $h->fetchrow_array()){
        push @related_stocks, [$transformant_id, $transformant_name, $plant_id, $plant_name, $transformation_id, $transformation_name, $number_of_insertions]
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


sub get_stock_related_seedlots_1 {
    my $self = shift;
    my $schema = $self->dbic_schema();
    my $stock_id = $self->stock_id();

    my $collection_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'collection_of', 'stock_relationship')->cvterm_id();
    my $stock_seedlot_relationships = $schema->resultset("Stock::StockRelationship")->search( { subject_id => $stock_id, type_id => $collection_of_type_id } );

    my @stock_seedlots = ();
    foreach my $seedlot ($stock_seedlot_relationships->all()) {
        my $seedlot_stock_id = $seedlot->object_id();
        my $seedlot_obj = CXGN::Stock::Seedlot->new( schema => $schema, seedlot_id => $seedlot_stock_id);
        my $seedlot_name = $seedlot_obj->uniquename();
        my $accession = $seedlot_obj->accession();
        my $accession_stock_id = $accession->[0];
        my $accession_name = $accession->[1];
        my $cross = $seedlot_obj->cross();
        my $cross_stock_id = $cross->[0];
        my $cross_name = $cross->[1];
        my $box_name = $seedlot_obj->box_name();
        my $count = $seedlot_obj->get_current_count_property();
        my $weight_gram = $seedlot_obj->get_current_weight_property();
        my $material_type = $seedlot_obj->material_type();
        my $quality = $seedlot_obj->quality();
        my $breeding_program_name = $seedlot_obj->breeding_program_name();
        my $location_code = $seedlot_obj->location_code();

        push @stock_seedlots, {
            seedlot_stock_id => $seedlot_stock_id,
            seedlot_stock_uniquename => $seedlot_name,
            accession_stock_id => $accession_stock_id,
            accession_name => $accession_name,
            cross_stock_id => $cross_stock_id,
            cross_name => $cross_name,
            box_name => $box_name,
            count => $count,
            weight_gram => $weight_gram,
            material_type => $material_type,
            seedlot_quality => $quality,
            breeding_program_name => $breeding_program_name,
            location => $location_code
        }

    }

    return \@stock_seedlots
}

sub get_stock_related_seedlots {
    my $self = shift;
    my $schema = $self->dbic_schema();
    my $stock_id = $self->stock_id();

    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();
    my $current_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "current_count", "stock_property")->cvterm_id();
    my $current_weight_gram_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "current_weight_gram", "stock_property")->cvterm_id();
    my $seedlot_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot_experiment", "experiment_type")->cvterm_id();
    my $seedlot_quality_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot_quality", "stock_property")->cvterm_id();
    my $location_code_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "location_code", "stock_property")->cvterm_id();
    my $material_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "material_type", "stock_property")->cvterm_id();

    my $q = "SELECT seedlot.stock_id, seedlot.uniquename, content.stock_id, content.uniquename, cvterm.name, nd_geolocation.description, project.name, box_name.value, count.value, weight_gram.value, seedlot_quality.value, material_type.value
        FROM stock_relationship
        JOIN stock AS content ON (stock_relationship.subject_id = content.stock_id) AND content.type_id IN (?,?)
        JOIN cvterm ON (cvterm.cvterm_id = content.type_id)
        JOIN stock AS seedlot ON (stock_relationship.object_id = seedlot.stock_id) AND stock_relationship.type_id = ?
        JOIN nd_experiment_stock ON (seedlot.stock_id = nd_experiment_stock.stock_id) AND nd_experiment_stock.type_id = ?
        JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id)
        JOIN nd_geolocation ON (nd_experiment.nd_geolocation_id = nd_geolocation.nd_geolocation_id)
        JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id)
        JOIN project ON (nd_experiment_project.project_id = project.project_id)
        JOIN stockprop AS box_name ON (box_name.stock_id = seedlot.stock_id) AND box_name.type_id = ?
        LEFT JOIN stockprop AS count ON (count.stock_id = seedlot.stock_id) AND count.type_id = ?
        LEFT JOIN stockprop AS weight_gram ON (weight_gram.stock_id = seedlot.stock_id) AND weight_gram.type_id = ?
        LEFT JOIN stockprop AS seedlot_quality ON (seedlot_quality.stock_id = seedlot.stock_id) AND seedlot_quality.type_id = ?
        LEFT JOIN stockprop AS material_type ON (material_type.stock_id = seedlot.stock_id) AND material_type.type_id = ?
        WHERE content.stock_id = ? ";

    my $h = $schema->storage->dbh->prepare($q);

    $h->execute($cross_cvterm_id, $accession_cvterm_id, $collection_of_cvterm_id, $seedlot_experiment_cvterm_id, $location_code_cvterm_id, $current_count_cvterm_id,$current_weight_gram_cvterm_id, $seedlot_quality_cvterm_id, $material_type_cvterm_id, $stock_id);

    my @stock_seedlots = ();
    while(my ($seedlot_id, $seedlot_name, $content_stock_id, $content_name, $content_stock_type, $location, $breeding_program_name, $boxname, $count, $weight_gram, $seedlot_quality, $material_type) = $h->fetchrow_array()){
        my $accession_stock_id = '';
        my $accession_name = '';
        my $cross_stock_id = '';
        my $cross_name = '';
        if ($content_stock_type eq 'accession') {
            $accession_stock_id = $content_stock_id;
            $accession_name = $content_name;
        } elsif ($content_stock_type eq 'cross') {
            $cross_stock_id = $content_stock_id;
            $cross_name = $content_name;
        }
        push @stock_seedlots, {
            seedlot_stock_id => $seedlot_id,
            seedlot_stock_uniquename => $seedlot_name,
            accession_stock_id => $accession_stock_id,
            accession_name => $accession_name,
            cross_stock_id => $cross_stock_id,
            cross_name => $cross_name,
            box_name => $boxname,
            count => $count,
            weight_gram => $weight_gram,
            material_type => $material_type,
            seedlot_quality => $seedlot_quality,
            breeding_program_name => $breeding_program_name,
            location => $location
        }
    }

    return \@stock_seedlots
}


sub get_derived_accession_relationship {
    my $self = shift;
    my $stock_id = $self->stock_id;
    my $schema = $self->dbic_schema();
    my $derived_from_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'derived_from', 'stock_relationship')->cvterm_id();

    my $q = "SELECT derived_from.stock_id, derived_from.uniquename, cvterm.name, derived_accession.stock_id, derived_accession.uniquename
        FROM stock AS derived_from
        JOIN cvterm ON (derived_from.type_id = cvterm.cvterm_id)
        JOIN stock_relationship ON (stock_relationship.object_id = derived_from.stock_id) AND stock_relationship.type_id = ?
        JOIN stock AS derived_accession ON (stock_relationship.subject_id = derived_accession.stock_id)
        WHERE derived_from.stock_id = ? OR derived_accession.stock_id = ? ";

    my $h = $schema->storage->dbh->prepare($q);

    $h->execute($derived_from_type_id, $stock_id, $stock_id);

    my @derived_accession_relationship_info = ();
    while(my ($derived_from_stock_id, $derived_from_stock_name, $derived_from_stock_type, $derived_accession_stock_id, $derived_accession_name) = $h->fetchrow_array()){
        push @derived_accession_relationship_info, [$derived_from_stock_id, $derived_from_stock_name, $derived_from_stock_type, $derived_accession_stock_id, $derived_accession_name];
    }

    return\@derived_accession_relationship_info;
}

sub get_original_derived_from_stock {
    my $self = shift;
    my $stock_id = $self->stock_id;
    my $schema = $self->dbic_schema();
    my %original_stock_info;

    my $accession_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $cross_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $family_name_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'family_name', 'stock_type')->cvterm_id();
    my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, cvterm.name
        FROM stock_relationship
        JOIN stock ON (stock_relationship.object_id = stock.stock_id) AND stock_relationship.type_id IN (?,?)
        JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
        WHERE stock_relationship.subject_id = ? AND stock.type_id IN (?,?,?) ";

    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($plant_of_cvterm_id, $tissue_sample_of_cvterm_id, $stock_id, $accession_cvterm_id, $cross_cvterm_id, $family_name_cvterm_id);
    my ($original_stock_id, $original_stock_name, $original_stock_type) = $h->fetchrow_array();

    $original_stock_info{'original_stock_id'} = $original_stock_id;
    $original_stock_info{'original_stock_name'} = $original_stock_name;
    $original_stock_info{'original_stock_type'} = $original_stock_type;

    return \%original_stock_info;
}


1;
