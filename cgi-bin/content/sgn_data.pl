use strict;
use warnings;

use Cache::File;
use Storable ();

use CXGN::Chado::Organism;


my $schema   = $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' );
my @families_to_display = qw( Solanaceae  Rubiaceae  Plantaginaceae );

my $cache = Cache::File->new(

    cache_root      => $c->path_to( $c->tempfiles_subdir('sgn_data_pl') ),
    default_expires => '6 hours',

    load_callback   => sub {
        my $cache_entry = shift;

        # we will store the species hash in the cache also, under a special key
        if( $cache_entry->key eq 'species_data' ) {
            my $species =  _make_species_hashref( $schema, @families_to_display );
            return Storable::nfreeze( $species );
        } else {
            my $org = CXGN::Chado::Organism->new( $schema, $cache_entry->key );
            no warnings 'uninitialized';
            my $info = join '?', (
                "Common Name: ".$org->get_group_common_name(),
                "Loci Num: ".$org->get_loci_count(),
                "Phenotype Count: ".$org->get_phenotype_count(),
                "Maps Available: ".$org->has_avail_map(),
                "Genome Information: ".$org->has_avail_genome(),
                "Library Num: ".scalar( $org->get_library_list ),
               );
            return $info;
        }
    },

   );


$c->forward_to_mason_view( "/content/sgn_data.mas",
    schema  => $schema,
    cache   => $cache,
    species => $cache->thaw('species_data'),
);

####### helper subs ##########

# returns hashref like:
#   'Solanaceae' => { arguments for organism_tree.mas },
#   'Rubiaceae' => (same),
#   .....
sub _make_species_hashref {
    my ( $schema, @families ) = @_;

    my %species;

    for my $family ( @families ) {

        # find the phylonode(s) for this family
        my $family_phylonodes =
            $schema->resultset('Organism::Organism')
                   ->search({ 'me.species' => $family })
                   ->search_related('phylonode_organisms')
                   ->search_related('phylonode',
                        { 'cv.name' => 'taxonomy' },
                        { join => { type => 'cv' } },
                     );

        # use the family phylonode to find the child organisms of this
        # family (that are also web-visible)
        my $organisms =
            _child_phylonodes( $family_phylonodes )
                ->search_related('phylonode_organism')
                ->search_related('organism',
                                 { 'cv.name' => 'local',
                                   'type.name' => 'web visible',
                                 },
                                 { join => { organismprops => { type => 'cv' }}},
                                );

        $species{$family} = {
            root   => $family,
            uri_dir => $c->tempfiles_subdir('sgn_data_pl'),
            tmp_dir => $c->path_to(),
        };

        while( my $organism = $organisms->next ) {
            $species{$family}{species_hashref}{ $organism->species } = $organism->organism_id;
        }
    }

    return \%species;
}

# take a resultset of phylonodes, construct a resultset of the child
# phylonodes.  this method should be integrated into
# Bio::Chado::Schema.
sub _child_phylonodes {
    my $phylonodes = shift;

    my %child_phylonode_conditions;
    while( my $pn = $phylonodes->next ) {
        push @{ $child_phylonode_conditions{ '-or' }} => {
            'left_idx'  => { '>' => $pn->left_idx  },
            'right_idx' => { '<' => $pn->right_idx },
        };
    }

    return $phylonodes->result_source->resultset
        ->search( \%child_phylonode_conditions );
}

