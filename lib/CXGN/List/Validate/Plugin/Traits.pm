
package CXGN::List::Validate::Plugin::Traits;

use Moose;
use Data::Dumper;

sub name {
    return "traits";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;
    my @missing = ();

#    print STDERR "LIST: ".Data::Dumper::Dumper($list);

    foreach my $term (@$list) {
        my ($trait_name, $full_accession) = split (/\|/, $term);
        my ($db_name, $accession) = split ":", $full_accession;

        if ($accession) {
            $accession =~ s/\s+$//;
            $accession =~ s/^\s+//;
        }
        if ($db_name) {
            $db_name  =~ s/\s+$//;
            $db_name  =~ s/^\s+//;
        }

        my $db_rs = $schema->resultset("General::Db")->search( { 'me.name' => $db_name });
        if ($db_rs->count() == 0) {
            push @missing, $_;
        } else {
            my $db = $db_rs->first();
            my $rs = $schema->resultset("Cv::Cvterm")->search( {
            'dbxref.db_id' => $db->db_id(),
            'dbxref.accession'=>$accession }, {
                'join' => 'dbxref' }
            );

            if ($rs->count == 0) {
                push @missing, $_;
            } else {
            #        my $rs_var = $rs->search_related('cvterm_relationship_subjects', {'type.name' => 'VARIABLE_OF'}, { 'join' => 'type'});
            #        if ($rs_var->count == 0) {
            #            push @missing, $_;
            #        }
            
            if ($db->name eq 'COMP'){

                my $object_ont_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'object_ontology', 'composable_cvtypes')->cvterm_id;
                my $attribute_ont_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'attribute_ontology', 'composable_cvtypes')->cvterm_id;
                my $method_ont_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'method_ontology', 'composable_cvtypes')->cvterm_id;
                my $trait_ont_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trait_ontology', 'composable_cvtypes')->cvterm_id;
                my $unit_ont_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'unit_ontology', 'composable_cvtypes')->cvterm_id;
                my $time_ont_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'time_ontology', 'composable_cvtypes')->cvterm_id;
                my %cvtypes = { $object_ont_cvterm_id => 1, $attribute_ont_cvterm_id => 1, $method_ont_cvterm_id => 1, $trait_ont_cvterm_id => 1, $unit_ont_cvterm_id => 1, $time_ont_cvterm_id => 1};

                my $cvterm_rs = $schema->resultset("Cv::Cvterm")->search({ name => $term });
                if ($cvterm_rs->count == 0){
                    push @missing, $term;
                }
                if ($cvterm_rs->count > 1){
                    die "ERROR: $term has been stored multiple times in cvterm!!\n";
                }

                my $contains_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'contains', 'relationship')->cvterm_id();

                my $component_rs = $cvterm_rs->first->search_related('cvterm_relationship_objects', {'cvterm_relationship_objects.type_id' => $contains_cvterm_id});
                while(my $r = $component_rs->next){
                    my $component_cvterm = $r->subject();
                    my $component_cvprops = $component_cvterm->cv_props;
                    while(my $cvprop = $component_cvprops->next){
                        if (!exists($cvtypes{$cvprop->type_id})){
                            print STDERR "Component not part of allowed cv ontologies\n";
                            push @missing, $term;
                        }
                    }
                }

            }
        }

    }
    return { missing => \@missing };
}

1;
