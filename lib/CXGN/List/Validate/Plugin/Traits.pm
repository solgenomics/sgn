
package CXGN::List::Validate::Plugin::Traits;

use Moose;
use Data::Dumper;
use CXGN::Onto;

sub name {
    return "traits";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;
    my $validator = shift;
    my $context = SGN::Context->new;
    my @missing;
    my @wrong_ids;
    my @not_variables;
    my @wrong_ontology;
    my @ambiguous;

    # Terms may only come from the root ontologies of these cv types
    my @root_nodes = CXGN::Onto->new({ schema => $schema })->get_root_nodes(['trait_ontology', 'composed_trait_ontology', 'experiment_treatment_ontology', 'composed_experiment_treatment_ontology']); # each entry is [ cv_id, "DB:accession Term name" ]
    my %allowed_db_names;
    foreach my $node (@root_nodes) {
        my ($root_db_name) = split /:/, $node->[1];
        $allowed_db_names{$root_db_name} = 1 if $root_db_name;
    }
    my @allowed_db_names = sort keys %allowed_db_names;

#    print STDERR "LIST: ".Data::Dumper::Dumper($list);

# Expects $terms to be full trait names e.g. root weight|CO_334:0000012
# For postcomposed terms expects full trait names e.g. tissue metabolite unit time|COMP:0000015

    foreach my $term (@$list) {
        #print STDERR $term."\n";

        my @parts = split (/\|/ , $term);
        my ($db_name, $accession) = split ":", pop @parts;
        my $trait_name = join '|', @parts;
        if(!$context->get_conf('list_trait_require_id')) {
            $trait_name = $term;
        }

        $accession =~ s/\s+$//;
        $accession =~ s/^\s+//;
        $db_name =~ s/\s+$//;
        $db_name =~ s/^\s+//;
        $trait_name =~ s/\s+$//;
        $trait_name =~ s/^\s+//;

        if (!$context->get_conf('list_trait_require_id') && ($db_name eq '' || $db_name eq $trait_name)) {
            # No db name given: find which of the allowed ontologies hold a term with this name
            my @matching_db_names = $schema->resultset("Cv::Cvterm")->search(
                {
                    'me.name' => $trait_name,
                    'db.name' => { -in => \@allowed_db_names },
                },
                {
                    'join' => { 'dbxref' => 'db' },
                    'distinct' => 1,
                }
            )->get_column('db.name')->all();

            if (scalar(@matching_db_names) == 0) {
                print STDERR "Problem found with term $term: not found in any allowed ontology (".join(', ', @allowed_db_names).")\n";
                push @missing, $term;
                push @wrong_ontology, { original_term => $term, allowed_db_names => \@allowed_db_names };
                next;
            }
            if (scalar(@matching_db_names) > 1) {
                print STDERR "Problem found with term $term: ambiguous, found in ontologies ".join(', ', @matching_db_names)."\n";
                push @missing, $term;
                push @ambiguous, { original_term => $term, matching_db_names => [ sort @matching_db_names ] };
                next;
            }
            $db_name = $matching_db_names[0];
        }
        elsif (!$allowed_db_names{$db_name}) {
            print STDERR "Problem found with term $term: db $db_name is not one of the allowed ontologies (".join(', ', @allowed_db_names).")\n";
            push @missing, $term;
            push @wrong_ontology, { original_term => $term, allowed_db_names => \@allowed_db_names };
            next;
        }

        my $db_rs = $schema->resultset("General::Db")->search( { 'me.name' => $db_name });
        if ($db_rs->count() == 0) {
            print STDERR "Problem found with term $term at db $db_name\n";
            push @missing, $term;
        } else {
            my $db = $db_rs->first();
            my $query = {
                'dbxref.db_id' => $db->db_id(),
            };

            if (!$context->get_conf('list_trait_require_id') && $accession eq '') {
                $query->{'me.name'} = $trait_name;
            } else {
                $query->{'dbxref.accession'} = $accession;
            }
            if ( ($db_name eq 'COMP' || $db_name eq 'COMP_EXP_TREATMENT') && $validator->{composable_validation_check_name} ) {
                $query->{'me.name'} = $trait_name;
            }
            my $rs = $schema->resultset("Cv::Cvterm")->search($query, {'join' => 'dbxref'});

            my $is_missing = 0;
            my $is_not_variable = 0;
            if ($rs->count == 0) {
                print STDERR "Problem found with term $term at cvterm rs from accession $accession point 2\n";
                push @missing, $term;
                $is_missing = 1;
            } else {
                my $rs_var = $rs->search_related('cvterm_relationship_subjects', {'type.name' => 'VARIABLE_OF'}, { 'join' => 'type'});
                if ($rs_var->count == 0) {
                    print STDERR "Problem found with term $term at variable check point 3\n";
                    push @missing, $term;
                    $is_missing = 1;
                    $is_not_variable = 1;
                }
            }

            # Try to find matching id and term by name for missing trait
            if( $is_missing ) {
                my $rs_match = $schema->resultset("Cv::Cvterm")->search(
                    {
                        'dbxref.db_id' => $db->db_id(),
                        'me.name' => $trait_name,
                        'type.name' => 'VARIABLE_OF'
                    },
                    {
                        'join' => [ 'dbxref', {'cvterm_relationship_subjects' => 'type'} ],
                        '+select' => 'dbxref.accession',
                        '+as' => 'accession'
                    }
                );
                if ( $rs_match->count == 1 ) {
                    my $m = $rs_match->first();
                    push @wrong_ids, {
                        original_term => $term,
                        matching_id => $db_name . ':' . $m->get_column('accession'),
                        matching_term => $trait_name . '|' . $db_name . ':' . $m->get_column('accession')
                    }
                }
            }

            # Try to find matching variable from a trait term
            if ( $is_not_variable ) {
                my $rs_var = $rs->search_related(
                    'cvterm_relationship_objects',
                    { 'type.name' => 'VARIABLE_OF' },
                    {
                        'join' => ['type', 'subject'],
                        '+select' => ['subject.cvterm_id', 'subject.name'],
                        '+as' => ['subject_id', 'subject_name']
                    }
                );
                if ( $rs_var->count > 0 ) {
                    while (my $m = $rs_var->next() ) {
                        my $cvterm_id = $m->subject_id();
                        my $dbxref_rs = $schema->resultset("Cv::Cvterm")->search({ cvterm_id => $cvterm_id })->search_related("dbxref")->first();
                        push @not_variables, {
                            original_term => $term,
                            matching_name => $m->get_column('subject_name'),
                            matching_id => $db_name . ':' . $dbxref_rs->get_column('accession'),
                            matching_term => $m->get_column('subject_name') . '|' . $db_name . ':' . $dbxref_rs->get_column('accession')
                        }
                    }
                }
            }
        }

    }
    print STDERR Dumper \@missing;
    print STDERR Dumper \@wrong_ids;
    return {
        missing => \@missing,
        wrong_ids => \@wrong_ids,
        not_variables => \@not_variables,
        wrong_ontology => \@wrong_ontology,
        ambiguous => \@ambiguous
    };
}

1;
