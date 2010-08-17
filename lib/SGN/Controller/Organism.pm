package SGN::Controller::Organism;
use Moose;
use namespace::autoclean;

use Storable;
use Scalar::Util qw/ weaken /;

use CXGN::Chado::Organism;
use CXGN::Login;

with 'Catalyst::Component::ApplicationAttribute';

=head1 ATTRIBUTES

=head2 species_data_summary


=cut

has 'species_data_summary' => (
    is  => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
   ); sub _build_species_data_summary {
       my ($cache_class, $config) = shift->_species_summary_cache_configuration;
       require MLDBM;
       MLDBM->import( $cache_class, 'Storable' );
       my %cache;
       tie %cache, MLDBM => $config;
       return \%cache;
   }

=head2 species_data_summary_cache

L<Cache> object containing species data summaries, as:

  {
    <organism_id> => {
         'Common Name' => common_name,
          ...
    },
    ...
  }

Access with C<$cache->thaw( $organism_id )>, do not use Cache's C<get>
method.

=cut

has 'species_data_summary_cache' => (
    is  => 'ro',
    lazy_build => 1,
   ); sub _build_species_data_summary_cache {
       my ($cache_class, $config) = shift->_species_summary_cache_configuration;
       return $cache_class->new( %$config );
   }

sub _species_summary_cache_configuration {
    my ($self) = @_;

    my $schema   = $self->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' );

    weaken $self;

    return 'Cache::File', {
        cache_root      => $self->_app->path_to( $self->_app->tempfiles_subdir('species_summary_cache') ),
        default_expires => '6 hours',

        load_callback   => sub {
            my $cache_entry = shift;
            my $org = CXGN::Chado::Organism->new( $schema, $cache_entry->key )
                or return;
            no warnings 'uninitialized';
            return Storable::nfreeze({
                'Common Name' => $org->get_group_common_name,
                'Loci' => $org->get_loci_count,
                'Phenotypes' => $org->get_phenotype_count,
                'Maps Available' => $org->has_avail_map,
                'Genome Information' => $org->has_avail_genome,
                'Libraries' => scalar( $org->get_library_list ),
            });
        },
    };
}


=head1 ACTIONS

=head2 sgn_data

Display the sgn data overview page.  Currently at /content/sgn_data.pl

=cut

sub sgn_data {
    my ( $self, $c ) = @_;

    my $schema = $c->dbic_schema('Bio::Chado::Schema','sgn_chado');

    my %species =
        map $self->_species_subtree( $schema, $_),
            qw(
               Solanaceae
               Rubiaceae
               Plantaginaceae
              );

    warn "fetched species, gathering data\n";

    my $stash = {
        schema       => $schema,
        species_data => $self->species_data_summary_cache,
        species      => \%species,
        uri_dir      => $c->tempfiles_subdir( 'sgn_data_pl' ),
        tmp_dir      => $c->path_to(),
    };

    #use Data::Dumper;
    #print "\n\n";
    #print '<pre>'.Dumper( $stash ).'</pre>';

    $c->forward_to_mason_view( "/content/sgn_data.mas", %$stash );
}

=head2 sol100

Display the sol100 organisms page.  Currently at /sequencing/sol100.pl

=cut

sub sol100 {
    my ( $self, $c ) = @_;

    my $dbh = $c->dbc->dbh;
    my ($person_id, $user_type) = CXGN::Login->new($dbh)->has_session();

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $sol100_organisms =
        $schema->resultset( "Cv::Cvterm" )
               ->search({ name => 'sol100' })
               ->search_related( 'organismprops' )
               ->search_related( 'organism' );

    my $stash = {
        species_data => $self->species_data_summary_cache,
        species      => { map { $_->species => $_->organism_id } $sol100_organisms->all },
        user_type => $user_type,
        schema    => $schema,
        uri_dir      => $c->tempfiles_subdir( 'sgn_data_pl' ),
        tmp_dir      => $c->path_to(),
       };

    $c->forward_to_mason_view( "/sequencing/sol100.mas", %$stash );
}

#################################3


# returns list like:
#   'Solanaceae' => { arguments for organism_tree.mas },
sub _species_subtree {
    my ( $self, $schema, $species ) = @_;

    my $organisms = $self->_child_organisms(
        $schema->resultset('Organism::Organism')
            ->find({ species => $species })
    )

      or return;


    my %species;
    while ( my $organism = $organisms->next ) {
        $species{ $organism->species } = $organism->organism_id;
    }

    return $species => \%species;
}

sub _child_organisms {
    my ($self, $organism_rs ) = @_;

    return unless $organism_rs;

    # find the phylonode(s) for this family
    return
        $organism_rs
               ->search_related('phylonode_organisms')
               ->search_related('phylonode',
                    { 'cv.name' => 'taxonomy' },
                    { join => { type => 'cv' } },
                 )
               ->search_related('descendants')
               ->search_related('phylonode_organism')
               ->search_related('organism',
                                { 'cv_2.name'   => 'local',
                                  'type_2.name' => 'web visible',
                                },
                                { join => { organismprops => { type => 'cv' }}},
                                );

}




__PACKAGE__->meta->make_immutable;
1;
