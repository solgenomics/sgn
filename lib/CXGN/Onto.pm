package CXGN::Onto;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use JSON::Any;
use Try::Tiny;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;

has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
    );

=head2 get_terms

parameters: namespace

returns: terms in namespace

Side Effects: none

=cut

sub get_terms {
      my $self = shift;
      my $cv_id = shift;

      my $query = "SELECT cvterm_id, dbxref.accession, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS name
                  FROM cvterm
                  JOIN dbxref USING(dbxref_id)
                  JOIN db USING(db_id)
                  LEFT JOIN cvterm_relationship is_subject ON cvterm.cvterm_id = is_subject.subject_id
                  LEFT JOIN cvterm_relationship is_object ON cvterm.cvterm_id = is_object.object_id
                  WHERE cv_id = ?
                  GROUP BY 1,2,3
                  ORDER BY 2,1";

      my $h = $self->schema->storage->dbh->prepare($query);
      $h->execute($cv_id);

      my @results;
      while (my ($id, $accession, $name) = $h->fetchrow_array()) {
	  if ($accession +0 != 0) {
	      push @results, [$id, $name];
	  }
      }

      return @results;
}

sub get_root_nodes {
      my $self = shift;
      my $cv_type = shift;

      my $query = "SELECT cv.cv_id, (((db.name::text || ':'::text) || dbxref.accession::text) || ' '::text) || cvterm.name AS name
                    FROM cv
                    JOIN cvprop ON(cv.cv_id = cvprop.cv_id AND cvprop.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = ?))
                    JOIN cvterm on(cvprop.cv_id = cvterm.cv_id)
                    JOIN dbxref USING(dbxref_id)
                    JOIN db USING(db_id)
                    LEFT JOIN cvterm_relationship ON(cvterm.cvterm_id=cvterm_relationship.subject_id)
                    WHERE cvterm_relationship.subject_id IS NULL AND cvterm.is_obsolete= 0 AND cvterm.is_relationshiptype = 0";

      my $h = $self->schema->storage->dbh->prepare($query);
      $h->execute($cv_type);

      my @results;
      while (my ($id, $name) = $h->fetchrow_array()) {
        push @results, [$id, $name];
      }

      return @results;
}


sub store_composed_term {
    my $self = shift;
    my $new_trait_names = shift;
    #print STDERR Dumper $new_trait_names;

    my $schema = $self->schema();
    my $dbh = $schema->storage->dbh;

    my $contains_relationship = $schema->resultset("Cv::Cvterm")->find({ name => 'contains' });
    my $variable_relationship = $schema->resultset("Cv::Cvterm")->find({ name => 'VARIABLE_OF' });

    my @new_terms;
    foreach my $name (sort keys %$new_trait_names){
        my $ids = $new_trait_names->{$name};
        my @component_ids = split ',', $ids;

        if (scalar(@component_ids)<2){
            die "Should not save postcomposed term with less than 2 components\n";
        }

        my $existing_trait_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, \@component_ids);
        if ($existing_trait_id) {
            print STDERR "Skipping: This trait already exists $name with the following component_ids".Dumper(\@component_ids)."\n";
            next;
        }

        my $db = $schema->resultset("General::Db")->find_or_create({ name => 'COMP' });
        my $cv= $schema->resultset('Cv::Cv')->find_or_create( { name => 'composed_trait' });

        my $accession_query = "SELECT nextval('composed_trait_ids')";
        my $h = $dbh->prepare($accession_query);
        $h->execute();
        my $accession = $h->fetchrow_array();

      my $new_term_dbxref =  $schema->resultset("General::Dbxref")->create(
      {   db_id     => $db->get_column('db_id'),
		      accession => sprintf("%07d",$accession)
		  });

      my $parent_term= $schema->resultset("Cv::Cvterm")->find(
        { cv_id  =>$cv->cv_id(),
          name   => 'Composed traits',
      });

    #print STDERR "Parent cvterm_id = " . $parent_term->cvterm_id();

    my $new_term = $schema->resultset('Cv::Cvterm')->find({ name=>$name });
    if ($new_term){
        print STDERR "Cvterm with name $name already exists... so components must be new\n";
    } else {
        $new_term= $schema->resultset("Cv::Cvterm")->create({
            cv_id  =>$cv->cv_id(),
            name   => $name,
            dbxref_id  => $new_term_dbxref-> dbxref_id()
        });
    }


    #print STDERR "New term cvterm_id = " . $new_term->cvterm_id();

        my $variable_rel = $schema->resultset('Cv::CvtermRelationship')->find_or_create({
            subject_id => $new_term->cvterm_id(),
            object_id  => $parent_term->cvterm_id(),
            type_id    => $variable_relationship->cvterm_id()
        });

        foreach my $component_id (@component_ids) {
            my $contains_rel = $schema->resultset('Cv::CvtermRelationship')->find_or_create({
                subject_id => $component_id,
                object_id  => $new_term->cvterm_id(),
                type_id    => $contains_relationship->cvterm_id()
            });
        }

        push @new_terms, [$new_term->cvterm_id, $new_term->name().'|COMP:'.sprintf("%07d",$accession)];
    }

    #Takes long on cassavabase.. instead the materialized view is refreshed automatically in a background ajax process.
    #my $refresh1 = "REFRESH MATERIALIZED VIEW traits";
    #my $h = $dbh->prepare($refresh1);
    #$h->execute();

    #my $refresh2 = "REFRESH MATERIALIZED VIEW trait_componentsXtraits";
    #$h = $dbh->prepare($refresh2);
    #$h->execute();

    return \@new_terms;
}

sub store_ontology_identifier {
    my $self = shift;
    my $ontology_name = shift;
    my $ontology_description = shift;
    my $ontology_identifier = shift;
    my $ontology_type = shift;
    my $schema = $self->schema();
    my $dbh = $schema->storage->dbh;

    my $cv_check = $schema->resultset("Cv::Cv")->find({name=>$ontology_name});
    if ($cv_check) {
        return {
            error => "The ontology name $ontology_name has already been used!"
        };
    }

    my $db_check = $schema->resultset("General::Db")->find({name=>$ontology_name});
    if ($db_check) {
        return {
            error => "The ontology identifier $ontology_identifier has already been used!"
        };
    }

    my $cv_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $ontology_type, 'composable_cvtypes')->cvterm_id();

    my $coderef = sub {
        my $cv_rs = $schema->resultset("Cv::Cv")->create({
            name => $ontology_name,
            definition => $ontology_description
        });
        my $new_cv_id = $cv_rs->cv_id();

        my $new_ontology_cvprop = $schema->resultset("Cv::Cvprop")->create({
            cv_id   => $new_cv_id,
            type_id => $cv_type_id
        });

        my $db_rs = $schema->resultset("General::Db")->create({
            name => $ontology_identifier
        });
        my $new_db_id = $db_rs->db_id();

        my $dbxref_rs = $schema->resultset("General::Dbxref")->create({
            db_id => $new_db_id,
            accession => "0000000"
        });
        my $new_dbxref_id = $dbxref_rs->dbxref_id();

        my $cvterm_rs = $schema->resultset("Cv::Cvterm")->create({
            name => $ontology_name,
            definition => $ontology_description,
            dbxref_id => $new_dbxref_id,
            cv_id => $new_cv_id
        });

        return {
            success => 1,
            new_term => [$cvterm_rs->cvterm_id(), $cvterm_rs->name()]
        };
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        return {
            error => $@
        };
    };
}

sub store_observation_variable_trait_method_scale {
    my $self = shift;
    my $selected_observation_variable_db_id = shift;
    my $new_observation_variable_name = shift;
    my $new_observation_variable_definition = shift;
    my $selected_trait_db_id = shift;
    my $selected_trait_cvterm_id = shift;
    my $new_trait_name = shift;
    my $new_trait_definition = shift;
    my $selected_method_db_id = shift;
    my $selected_method_cvterm_id = shift;
    my $new_method_name = shift;
    my $new_method_definition = shift;
    my $selected_scale_db_id = shift;
    my $selected_scale_cvterm_id = shift;
    my $new_scale_name = shift;
    my $new_scale_definition = shift;
    my $new_scale_format = shift;
    my $new_scale_minumum = shift;
    my $new_scale_maximum = shift;
    my $new_scale_default = shift;
    my $new_scale_categories = shift;

    my $schema = $self->schema();
    my $dbh = $schema->storage->dbh;
    my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';

    my $new_observation_variable_cvterm_check = $schema->resultset("Cv::Cvterm")->search({
        name => $new_observation_variable_name,
    });
    if ($new_observation_variable_cvterm_check->count() > 0) {
        return { error => "The observation variable $new_observation_variable_name already exists in the database!" };
    }

    if (!$selected_trait_cvterm_id) {
        my $new_trait_cvterm_check = $schema->resultset("Cv::Cvterm")->search({
            name => $new_trait_name,
        });
        if ($new_trait_cvterm_check->count() > 0) {
            return { error => "The trait $new_trait_name already exists in the database!" };
        }
    }

    if (!$selected_method_cvterm_id) {
        my $new_method_cvterm_check = $schema->resultset("Cv::Cvterm")->search({
            name => $new_method_name,
        });
        if ($new_method_cvterm_check->count() > 0) {
            return { error => "The method $new_method_name already exists in the database!" };
        }
    }

    if (!$selected_scale_cvterm_id) {
        my $new_scale_cvterm_check = $schema->resultset("Cv::Cvterm")->search({
            name => $new_scale_name,
        });
        if ($new_scale_cvterm_check->count() > 0) {
            return { error => "The scale $new_scale_name already exists in the database!" };
        }
    }

    my $coderef = sub {
        my $observation_variable_db_q = "SELECT db.name, dbxref.accession, cv.name, cv.cv_id FROM dbxref JOIN db USING(db_id) JOIN cvterm USING(dbxref_id) JOIN cv USING(cv_id) WHERE db_id=$selected_observation_variable_db_id AND dbxref.accession ~ '$numeric_regex' ORDER BY dbxref.accession::int DESC LIMIT 1;";
        my $observation_variable_db_sth = $dbh->prepare($observation_variable_db_q);
        $observation_variable_db_sth->execute();
        my ($observation_variable_db_name, $observation_variable_last_accession, $observation_variable_cv_name, $observation_variable_cv_id) = $observation_variable_db_sth->fetchrow_array();
        my $observation_variable_new_accession = sprintf("%07d", $observation_variable_last_accession + 1);

        my $parent_observation_variable_cvterm_q = "SELECT cvterm.cvterm_id, cvterm.name FROM dbxref JOIN cvterm USING(dbxref_id) JOIN cv USING(cv_id) WHERE db_id=$selected_observation_variable_db_id AND dbxref.accession ~ '$numeric_regex' ORDER BY dbxref.accession::int ASC LIMIT 1;";
        my $parent_observation_variable_cvterm_sth = $dbh->prepare($parent_observation_variable_cvterm_q);
        $parent_observation_variable_cvterm_sth->execute();
        my ($parent_observation_variable_cvterm_id, $parent_observation_variable_cvterm_name) = $parent_observation_variable_cvterm_sth->fetchrow_array();

        my $new_term_observation_variable_dbxref = $schema->resultset("General::Dbxref")->create({
            db_id => $selected_observation_variable_db_id,
            accession => $observation_variable_new_accession
        });

        my $new_observation_variable_cvterm = $schema->resultset("Cv::Cvterm")->create({
            cv_id => $observation_variable_cv_id,
            name => $new_observation_variable_name,
            definition => $new_observation_variable_definition,
            dbxref_id => $new_term_observation_variable_dbxref->dbxref_id()
        });

        my $is_a_relationship = $schema->resultset("Cv::Cvterm")->search({ name => 'is_a' })->first();
        my $contains_relationship = $schema->resultset("Cv::Cvterm")->search({ name => 'contains' })->first();
        my $variable_relationship = $schema->resultset("Cv::Cvterm")->search({ name => 'VARIABLE_OF' })->first();

        my $variable_rel = $schema->resultset('Cv::CvtermRelationship')->create({
            subject_id => $new_observation_variable_cvterm->cvterm_id(),
            object_id  => $parent_observation_variable_cvterm_id,
            type_id    => $variable_relationship->cvterm_id()
        });

        if (!$selected_trait_cvterm_id) {

            my $trait_db_q = "SELECT db.name, dbxref.accession, cv.name, cv.cv_id FROM dbxref JOIN db USING(db_id) JOIN cvterm USING(dbxref_id) JOIN cv USING(cv_id) WHERE db_id=$selected_trait_db_id AND dbxref.accession ~ '$numeric_regex' ORDER BY dbxref.accession::int DESC LIMIT 1;";
            my $trait_db_sth = $dbh->prepare($trait_db_q);
            $trait_db_sth->execute();
            my ($trait_db_name, $trait_last_accession, $trait_cv_name, $trait_cv_id) = $trait_db_sth->fetchrow_array();
            my $trait_new_accession = sprintf("%07d", $trait_last_accession + 1);

            my $parent_trait_cvterm_q = "SELECT cvterm.cvterm_id, cvterm.name FROM dbxref JOIN cvterm USING(dbxref_id) JOIN cv USING(cv_id) WHERE db_id=$selected_trait_db_id AND dbxref.accession ~ '$numeric_regex' ORDER BY dbxref.accession::int ASC LIMIT 1;";
            my $parent_trait_cvterm_sth = $dbh->prepare($parent_trait_cvterm_q);
            $parent_trait_cvterm_sth->execute();
            my ($parent_trait_cvterm_id, $parent_trait_cvterm_name) = $parent_trait_cvterm_sth->fetchrow_array();

            my $new_term_trait_dbxref = $schema->resultset("General::Dbxref")->create({
                db_id => $selected_trait_db_id,
                accession => $trait_new_accession
            });

            my $new_trait_cvterm = $schema->resultset("Cv::Cvterm")->create({
                cv_id => $trait_cv_id,
                name => $new_trait_name,
                definition => $new_trait_definition,
                dbxref_id => $new_term_trait_dbxref->dbxref_id()
            });
            $selected_trait_cvterm_id = $new_trait_cvterm->cvterm_id();

            my $trait_rel = $schema->resultset('Cv::CvtermRelationship')->create({
                subject_id => $new_trait_cvterm->cvterm_id(),
                object_id  => $parent_trait_cvterm_id,
                type_id    => $is_a_relationship->cvterm_id()
            });
        }

        my $observation_variable_to_trait_contains_rel = $schema->resultset('Cv::CvtermRelationship')->create({
            subject_id => $selected_trait_cvterm_id,
            object_id  => $new_observation_variable_cvterm->cvterm_id(),
            type_id    => $contains_relationship->cvterm_id()
        });

        if (!$selected_method_cvterm_id) {
            my $method_db_q = "SELECT db.name, dbxref.accession, cv.name, cv.cv_id FROM dbxref JOIN db USING(db_id) JOIN cvterm USING(dbxref_id) JOIN cv USING(cv_id) WHERE db_id=$selected_method_db_id AND dbxref.accession ~ '$numeric_regex' ORDER BY dbxref.accession::int DESC LIMIT 1;";
            my $method_db_sth = $dbh->prepare($method_db_q);
            $method_db_sth->execute();
            my ($method_db_name, $method_last_accession, $method_cv_name, $method_cv_id) = $method_db_sth->fetchrow_array();
            my $method_new_accession = sprintf("%07d", $method_last_accession + 1);

            my $parent_method_cvterm_q = "SELECT cvterm.cvterm_id, cvterm.name FROM dbxref JOIN cvterm USING(dbxref_id) JOIN cv USING(cv_id) WHERE db_id=$selected_method_db_id AND dbxref.accession ~ '$numeric_regex' ORDER BY dbxref.accession::int ASC LIMIT 1;";
            my $parent_method_cvterm_sth = $dbh->prepare($parent_method_cvterm_q);
            $parent_method_cvterm_sth->execute();
            my ($parent_method_cvterm_id, $parent_method_cvterm_name) = $parent_method_cvterm_sth->fetchrow_array();

            my $new_term_method_dbxref = $schema->resultset("General::Dbxref")->create({
                db_id => $selected_method_db_id,
                accession => $method_new_accession
            });

            my $new_method_cvterm = $schema->resultset("Cv::Cvterm")->create({
                cv_id => $method_cv_id,
                name => $new_method_name,
                definition => $new_method_definition,
                dbxref_id => $new_term_method_dbxref->dbxref_id()
            });
            $selected_method_cvterm_id = $new_method_cvterm->cvterm_id();

            my $method_rel = $schema->resultset('Cv::CvtermRelationship')->create({
                subject_id => $new_method_cvterm->cvterm_id(),
                object_id  => $parent_method_cvterm_id,
                type_id    => $is_a_relationship->cvterm_id()
            });
        }

        my $observation_variable_to_method_contains_rel = $schema->resultset('Cv::CvtermRelationship')->create({
            subject_id => $selected_method_cvterm_id,
            object_id  => $new_observation_variable_cvterm->cvterm_id(),
            type_id    => $contains_relationship->cvterm_id()
        });

        if (!$selected_scale_cvterm_id) {
            my $scale_db_q = "SELECT db.name, dbxref.accession, cv.name, cv.cv_id FROM dbxref JOIN db USING(db_id) JOIN cvterm USING(dbxref_id) JOIN cv USING(cv_id) WHERE db_id=$selected_scale_db_id AND dbxref.accession ~ '$numeric_regex' ORDER BY dbxref.accession::int DESC LIMIT 1;";
            my $scale_db_sth = $dbh->prepare($scale_db_q);
            $scale_db_sth->execute();
            my ($scale_db_name, $scale_last_accession, $scale_cv_name, $scale_cv_id) = $scale_db_sth->fetchrow_array();
            my $scale_new_accession = sprintf("%07d", $scale_last_accession + 1);

            my $parent_scale_cvterm_q = "SELECT cvterm.cvterm_id, cvterm.name FROM dbxref JOIN cvterm USING(dbxref_id) JOIN cv USING(cv_id) WHERE db_id=$selected_scale_db_id AND dbxref.accession ~ '$numeric_regex' ORDER BY dbxref.accession::int ASC LIMIT 1;";
            my $parent_scale_cvterm_sth = $dbh->prepare($parent_scale_cvterm_q);
            $parent_scale_cvterm_sth->execute();
            my ($parent_scale_cvterm_id, $parent_scale_cvterm_name) = $parent_scale_cvterm_sth->fetchrow_array();

            my $new_term_scale_dbxref = $schema->resultset("General::Dbxref")->create({
                db_id => $selected_scale_db_id,
                accession => $scale_new_accession
            });

            my $scale_categories_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trait_categories', 'trait_property')->cvterm_id();
            my $scale_default_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trait_default_value', 'trait_property')->cvterm_id();
            my $scale_format_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trait_format', 'trait_property')->cvterm_id();
            my $scale_maximum_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trait_maximum', 'trait_property')->cvterm_id();
            my $scale_minimum_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trait_minimum', 'trait_property')->cvterm_id();

            my @cvtermprops;
            if ($new_scale_format) {
                push @cvtermprops, {type_id => $scale_format_cvterm_id, value => $new_scale_format};
            }
            if ($new_scale_minumum) {
                push @cvtermprops, {type_id => $scale_minimum_cvterm_id, value => $new_scale_minumum};
            }
            if ($new_scale_maximum) {
                push @cvtermprops, {type_id => $scale_maximum_cvterm_id, value => $new_scale_maximum};
            }
            if ($new_scale_default) {
                push @cvtermprops, {type_id => $scale_default_cvterm_id, value => $new_scale_default};
            }
            if ($new_scale_categories) {
                push @cvtermprops, {type_id => $scale_categories_cvterm_id, value => $new_scale_categories};
            }

            my $new_scale_cvterm = $schema->resultset("Cv::Cvterm")->create({
                cv_id => $scale_cv_id,
                name => $new_scale_name,
                definition => $new_scale_definition,
                dbxref_id => $new_term_scale_dbxref->dbxref_id(),
                cvtermprops => \@cvtermprops
            });
            $selected_scale_cvterm_id = $new_scale_cvterm->cvterm_id();

            my $scale_rel = $schema->resultset('Cv::CvtermRelationship')->create({
                subject_id => $new_scale_cvterm->cvterm_id(),
                object_id  => $parent_scale_cvterm_id,
                type_id    => $is_a_relationship->cvterm_id()
            });
        }

        my $observation_variable_to_scale_contains_rel = $schema->resultset('Cv::CvtermRelationship')->create({
            subject_id => $selected_scale_cvterm_id,
            object_id  => $new_observation_variable_cvterm->cvterm_id(),
            type_id    => $contains_relationship->cvterm_id()
        });

        return {
            success => 1,
            new_term => [$new_observation_variable_cvterm->cvterm_id(), $new_observation_variable_cvterm->name()]
        };
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        return {
            error => $@
        };
    };
}

1;
