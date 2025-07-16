
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
    my $validator = shift;
    my $context = SGN::Context->new;
    my @missing;
    my @wrong_ids;

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

        print STDERR $db_name."\n";
        print STDERR $trait_name."\n";
        if (!$context->get_conf('list_trait_require_id') && ($db_name eq '' || $db_name eq $trait_name)) {
          $db_name = $context->get_conf('trait_ontology_db_name');
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
            if ( $db_name eq 'COMP' && $validator->{composable_validation_check_name} ) {
                $query->{'me.name'} = $trait_name;
            }
            my $rs = $schema->resultset("Cv::Cvterm")->search($query, {'join' => 'dbxref'});

            my $is_missing = 0;
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
                }
            }

            # Try to find matching id and term by name for missing trait
            if( $is_missing ) {
                my $rs_match = $schema->resultset("Cv::Cvterm")->search(
                    {
                        'dbxref.db_id' => $db->db_id(),
                        'me.name' => $trait_name
                    },
                    {
                        'join' => 'dbxref',
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
        }

    }
    print STDERR Dumper \@missing;
    print STDERR Dumper \@wrong_ids;
    return {
        missing => \@missing,
        wrong_ids => \@wrong_ids
    };
}

1;
