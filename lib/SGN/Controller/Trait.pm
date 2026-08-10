package SGN::Controller::Trait;

use Moose;
use Data::Dumper;
use CXGN::Onto;
use CXGN::Cvterm;

BEGIN { extends 'Catalyst::Controller'; }

sub trait_design_page : Path('/traits/design/') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{template} = '/site/error/permission_denied.mas';
        return;
    }

    my $ontology_obj = CXGN::Onto->new({
        schema => $schema
    });
    my @root_nodes = $ontology_obj->get_root_nodes('trait_ontology');

    my @db_names;

    my @root_terms = map {{name => $_->[1] =~ s/\w+:\d+ //r, cv_id => $_->[0], db_name => $_->[1] =~ s/:.*//r}} @root_nodes;
    foreach my $term (@root_terms) { 
        push @db_names, $term->{db_name};
    }

    my $editable_ontologies_str = $c->config->{allow_trait_edits}; #this can be 1 or a list of dbnames

    if ($editable_ontologies_str == 1) { #just give the first hit
        $c->stash(
            template => '/tools/trait_designer.mas',
            db_names => $db_names[0]
        );
    } else { #need to actually check if trait ontology is editable
        my @editable_ontologies = split(",", $editable_ontologies_str);
        my @editable_dbnames;
        foreach my $term (@root_terms) { 
            if (grep {$_ eq $term->{db_name}} @editable_ontologies) { #if this root term is editable per the config, add it to the list
                push @editable_dbnames, $term->{db_name};
            }
        }
        if (scalar(@editable_dbnames > 0)) {
            $c->stash(
                template => '/tools/trait_designer.mas',
                db_names => join(",",@editable_dbnames)
            );
        } else {
            $c->stash->{template} = '/site/error/permission_denied.mas';
        }
    }
}

1;