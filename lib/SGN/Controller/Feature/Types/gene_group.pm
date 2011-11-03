package SGN::Controller::Feature::Types::gene_group;
use Moose;

use SGN::View::Feature qw/ mrna_cds_protein_sequence /;

BEGIN { extends 'Catalyst::Controller' }

# # /feature/gene_group/get_specific_data
sub get_specific_data : Private {
    my ( $self, $c ) = @_;

#    $c->forward('protein_sequence_fasta');

#     $c->stash->{organism_representation} =
#         $schema->resultset('Organism::Organism')
#                ->search( {
#                    'feature_relationship_subjects.object_id' => $group_feature->feature_id,
#                    }, {
#                    join     => { 'features' => 'feature_relationship_subjects' } ,
#                    select   => [ 'me.organism_id', 'species', { count => '*' } ],
#                    as       => [ 'me.organism_id', 'species', 'member_count' ],
#                    group_by => [ 'me.organism_id', 'species' ],
#                    order_by => 'species',
#                  });

}

sub protein_sequence_fasta : Chained('/feature/get_feature') PathPart('gene_group_protein_fasta') Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('get_protein_sequences')
    && $c->forward('View::SeqIO');
}

sub get_protein_sequences : Private {
    my ( $self, $c ) = @_;

    my $group_feature = $c->stash->{feature} or die "no feature in stash??";
    my $schema = $group_feature->result_source->schema;

    # get all the mrnas from our member genes
    my $member_mrnas =
        $group_feature
            ->search_related( 'feature_relationship_objects', {
                                   'me.type_id' =>
                                       $schema->get_cvterm_or_die('sequence:member_of')->cvterm_id,
                              })
            ->search_related( 'subject', {
                                   'subject.type_id' =>
                                       $schema->get_cvterm_or_die('sequence:gene')->cvterm_id,
                              })
            ->search_related( 'feature_relationship_objects', {
                                    'feature_relationship_objects.type_id' =>
                                       $schema->get_cvterm_or_die('relationship:part_of')->cvterm_id,
                               })
            ->search_related( 'subject', {
                                    'subject_2.type_id' =>
                                       $schema->get_cvterm_or_die('sequence:mRNA')->cvterm_id,
                               },
                              { prefetch => { feature_relationship_objects => { 'subject' => {'featureloc_features' => 'srcfeature'} } } },
                            )
               ;

    my @proteins;
    while( my $mrna = $member_mrnas->next ) {
        if( my $seqs = mrna_cds_protein_sequence( $mrna ) ) {
            my ( undef, undef, $protein_seq ) = @$seqs;
            if( $protein_seq ) {
                push @proteins, $protein_seq;
            } else {
                $c->log->error( "no protein seq available for feature ".$mrna->name." (".$mrna->feature_id.")" );
                next;
            }
        } else {
            $c->log->error( "could not get mrna_and_protein_sequence for feature ".$mrna->name." (".$mrna->feature_id.")" );
            next;
        }
    }

    $c->stash->{protein_sequences} = $c->stash->{sequences} = \@proteins;
    return 1;
}

1;
