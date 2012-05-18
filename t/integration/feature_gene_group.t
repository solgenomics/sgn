use strict;
use warnings;

use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize skip_cgi => 1;
use SGN::Test::Data qw/create_test/;

# set up test gene groups
my $group = create_test('Sequence::Feature');
my @orgs = map create_test('Organism::Organism'), 0..2;
my $schema = $group->result_source->schema;
for ( [ $orgs[0], 4 ], [ $orgs[1], 2 ], [ $orgs[2], 5 ] ) {
    my ( $org, $count ) = @$_;
    for( 1..$count ) {
        my $gene = create_test('Sequence::Feature',{
            type     => $schema->get_cvterm_or_die('sequence:gene'),
            organism => $org,
        });
        add_relationship( $gene, 'sequence:member_of', $group );

        my $mrna = create_test('Sequence::Feature', {
            type => $schema->get_cvterm_or_die('sequence:mRNA'),
            organism => $org,
            residues => 'CATCATCATCAT',
        });
        add_relationship( $mrna, 'relationship:part_of', $gene );

        my $poly = create_test('Sequence::Feature', {
            type => $schema->get_cvterm_or_die('sequence:polypeptide'),
            organism => $org,
            residues => 'MMMMMMMMMMMMMM',
        });
        add_relationship( $poly, 'relationship:derives_from', $mrna );
    }
}

my $mech = SGN::Test::WWW::Mechanize->new;
$mech->get_ok('/feature/'.$group->name.'/details');
$mech->get_ok('/feature/'.$group->name.'/gene_group_protein_fasta');
$mech->content_contains('>feature_');
$mech->content_contains('MMMMMMMMMM');
#diag $mech->content;

done_testing;

exit;

#####################################################

sub add_relationship {
    my ( $subject, $relationship, $object ) = @_;

    $subject->add_to_feature_relationship_subjects(
        { type   => $schema->get_cvterm_or_die( $relationship ),
          object => $object,
        },
    );

}
