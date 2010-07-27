use strict;
use warnings;

use Cache::File;

use CXGN::Chado::Organism;




my $schema   = $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' );
my @families_to_display = qw( Solanaceae  Rubiaceae  Plantaginaceae );

my $cache = Cache::File->new(
    cache_root      => $c->path_to( $c->tempfiles_subdir('sgn_data') ),
    default_expires => '16000 sec',
    load_callback   => sub {
        my $cache_entry = shift;
        my $org    = CXGN::Chado::Organism->new( $schema, $cache_entry->key );
        $cache_entry->set( join '', map "?$_", (
            "Name: ".$org->get_species(),
            "Common Name: ".$org->get_group_common_name(),
            "Loci Num: ".$org->get_loci_count(),
            "Phenotype Count: ".$org->get_phenotype_count(),
            "Maps Available: ".$org->has_avail_map(),
            "Genome Information: ".$org->has_avail_genome(),
            "Library Num: ".scalar( $org->get_library_list ),
           )
        );
    },
   );

# hash like:
#   'Solanaceae' => { arguments for organism_tree.mas },
#   'Rubiaceae' => (same),
#   .....

my %species;
for my $family ( @families_to_display ) {

    # find the phylonode(s) for this family
    my $family_phylonodes =
        $schema->resultset('Organism::Organism')
               ->search({ 'me.species' => $family })
               ->search_related('phylonode_organisms')
               ->search_related('phylonode',
                    { 'cv.name' => 'taxonomy' },
                    { join => { type => 'cv' } },
                 );

    # find the child organisms of this family that are also web-visible
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
        schema => $schema,
        root   => $family,
        speciesinfo_cache => $cache,
        uri_dir => $c->tempfiles_subdir('sgn_data'),
        tmp_dir => $c->path_to( $c->tempfiles_subdir('sgn_data') ),
    };

    while( my $organism = $organisms->next ) {
        $species{$family}{species_hashref}{ $organism->species } = $organism->organism_id;
    }
}

#use Data::Dumper;
#print "Content-type: text/html\n\n".'<pre>'.Dumper(\%species).'</pre>';

$c->forward_to_mason_view( "/content/sgn_data.mas", species => \%species );

####### helper subs ##########

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

