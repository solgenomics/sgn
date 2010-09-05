=head1 NAME

SGN::Controller::Organism - Catalyst controller for pages dealing with
organisms

=cut

package SGN::Controller::Organism;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use Storable;
use Scalar::Util qw/ weaken /;

use Cache::File;
use HTTP::Status ':constants';
use JSON::Any; my $json = JSON::Any->new;
use List::MoreUtils qw/ any /;

use CXGN::Chado::Organism;
use CXGN::Login;
use CXGN::Phylo::OrganismTree;

with 'Catalyst::Component::ApplicationAttribute';

=head1 ATTRIBUTES

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
            my $org_id = $cache_entry->key;
            my $org = CXGN::Chado::Organism->new( $schema, $org_id )
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

# a hashref of organism sets as
# { set_name => {
#      description => 'user-visible description of the set',
#      resulset => DBIC resultset of organisms in that set,
#     },
# }
has 'organism_sets' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {
        my $self = shift;
        my $schema = $self->_app->dbic_schema('Bio::Chado::Schema','sgn_chado');
        my %org_sets;

        # define a set of SOL100 organisms
        $org_sets{'sol100'} = {
            description => 'SOL100 Organisms',
            root_species => 'Solanaceae',
            resultset => $schema->resultset( "Cv::Cvterm" )
                           ->search({ name => 'sol100' })
                           ->search_related( 'organismprops' )
                           ->search_related_rs( 'organism' )
        };

        # define sets of web-visible organisms, by family
        for my $family (qw( Solanaceae  Rubiaceae  Plantaginaceae )) {
            my $pns = $schema->resultset('Organism::Organism')
                            ->search({ 'me.species' => $family })
                            ->search_related('phylonode_organisms')
                            ->search_related('phylonode',
                                             { 'cv.name' => 'taxonomy' },
                                             { join => { type => 'cv' }},
                                            );

            $pns = $self->_child_phylonodes( $pns )
                        ->search_related_rs('phylonode_organism');

            # set of all organisms in that family
            $org_sets{$family} = {
                description  => $family,
                root_species => $family,
                resultset    => $pns->search_related_rs('organism'),
            };

            # set of only web-visible organisms in that family
            $org_sets{"web_visible_$family"} = {
                description  => $family,
                root_species => $family,
                resultset    => $pns->search_related_rs(
                    'organism',
                    { 'cv.name'   => 'local',
                      'type.name' => 'web visible',
                    },
                    { join => { organismprops => { type => 'cv' }}},
                   )
               };
        }
        return \%org_sets;
    },
   );

# take a resultset of phylonodes, construct a resultset of the child
# phylonodes.  temporary workaround until the extended_rels branch is
# merged into DBIx::Class and DBIx::Class::Tree::NestedSet is ported
# to use it
sub _child_phylonodes {
    my ( $self, $phylonodes ) = @_;

    my %child_phylonode_conditions;
    while( my $pn = $phylonodes->next ) {
        push @{ $child_phylonode_conditions{ '-or' }} => {
            'left_idx'     => { '>' => $pn->left_idx  },
            'right_idx'    => { '<' => $pn->right_idx },
            'phylotree_id' => $pn->phylotree_id,
        };
    }

    return $phylonodes->result_source->resultset
        ->search( \%child_phylonode_conditions );
}


=head1 ACTIONS

=head2 view_all

Display the sgn data overview page.  Currently at /organism/all/view

=cut

sub view_all :Path('/organism/all/view') :Args(0) {
    my ( $self, $c ) = @_;

    while( my ( $set_name, $set_callback ) = each %{ $self->organism_sets } ) {
        next unless $set_name =~ /^web_visible_(.+)/;
        my $family_name = $1;

        my $tree = $self->rendered_organism_tree_cache->thaw( $set_name );
        $tree->{set_name} = $set_name;
        $c->stash->{organism_trees}->{$family_name} = $tree;

    }

    # add image_uris to each of the organism tree records
    $_->{image_uri} = $c->uri_for( $self->action_for('organism_tree_image'), [ $_->{set_name} ] )
        for values  %{ $c->stash->{organism_trees} };

    $c->stash({
        template => '/content/sgn_data.mas',
    });
}

sub get_organism_set :Chained('/') :PathPart('organism/set') :CaptureArgs(1) {
    my ( $self, $c, $set_name ) = @_;

    $c->stash->{organism_set_name} = $set_name;
    $c->stash->{organism_set} = $self->organism_sets->{ $set_name }
        or $c->debug && $c->log->debug("no set found called '$set_name'");
}

# /organism/tree/<set_name>
sub get_organism_tree :Chained('/') :PathPart('organism/tree') :CaptureArgs(1) {
    my ( $self, $c, $set_name ) = @_;

    $c->stash->{organism_set_name} = $set_name;
    # the Cache::Entry for the slot in the cache for this organism tree
    $c->stash->{organism_tree_cache_entry} = $self->rendered_organism_tree_cache->entry( $set_name );
}

# /organism/tree/<set_name>/image
sub organism_tree_image :Chained('get_organism_tree') :PathPart('image') {
    my ( $self, $c ) = @_;

    my $image = $c->stash->{organism_tree_cache_entry}->thaw
        or $c->throw_404;

    $image->{png} or die "no png data for organism set '".$c->stash->{organism_set_name}."'! cannot serve image.";

    $c->res->body( $image->{png} );
    $c->res->content_type( 'image/png' );
}

# /organism/tree/<set_name>/flush
sub clear_organism_tree :Chained('get_organism_tree') :PathPart('flush') {
    my ( $self, $c ) = @_;

    $c->stash->{organism_tree_cache_entry}->remove;
    $c->res->content_type('application/json');
    $c->res->body(<<'');
{ status: "success" }

}



=head2 view_sol100

Display the sol100 organisms page.

=cut

sub view_sol100 :Path('sol100/view') :Args(0) {
    my ( $self, $c ) = @_;

    my ($person_id, $user_type) = CXGN::Login->new( $c->dbc->dbh )->has_session();

    $c->stash({
        template => "/sequencing/sol100.mas",

        organism_tree => {
            %{ $self->rendered_organism_tree_cache->thaw( 'sol100' ) },
            image_uri => $c->uri_for( $self->action_for('organism_tree_image'), ['sol100'] ),
        },

        show_org_add_form         => ( $user_type && any {$user_type eq $_} qw( curator submitter sequencer ) ),
        organism_add_uri          => $c->uri_for( $self->action_for('add_sol100_organism')),
        organism_autocomplete_uri => $c->uri_for( $self->action_for('autocomplete'), ['Solanaceae']),

    });
}

=head2 add_sol100_organism

Add an organism to the set of sol100 organisms.

=cut

sub add_sol100_organism :Path('sol100/add_organism') :Args(0) {
    my ( $self, $c ) = @_;

    my $organism = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
                     ->resultset('Organism::Organism')
                     ->search({ species => { ilike => $c->req->body_parameters->{species} }})
                     ->single;

    ## validate our conditions
    my @validate = ( [ HTTP_METHOD_NOT_ALLOWED,
                       'Only POST requests are allowed for this page.',
                       sub { $c->req->method eq 'POST' }
                     ],
                     [ HTTP_BAD_REQUEST,
                       'Organism not found',
                       sub { $organism },
                     ],
                    );
    for (@validate) {
        my ( $status, $message, $test ) = @$_;
        unless( $test->() ) {
            $c->throw( http_status => $status, public_message => $message );
            return;
        }
    }

    # if this fails, it will throw an acception and will (probably
    # rightly) be counted as a server error
    $organism->create_organismprops(
        { 'sol100' => 1 },
        { autocreate => 1 },
       );

    $self->rendered_organism_tree_cache->remove( 'sol100' ); #< invalidate the sol100 cached image tree
    $c->res->redirect( $c->uri_for( $self->action_for('view_sol100')));
}


=head2 autocomplete

Autocomplete an organism name.

=cut

sub autocomplete :Chained('get_organism_set') :PathPart('autocomplete') :Args(0) {
  my ( $self, $c ) = @_;

  my $term = $c->req->param('term');
  # trim and regularize whitespace
  $term =~ s/(^\s+|\s+)$//g;
  $term =~ s/\s+/ /g;

  my $s = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
                  ->resultset('Organism::Organism');
#  my $s = $c->stash->{organism_set};

  my @results = $s->search({ species => { ilike => '%'.$term.'%' }},
                           { rows => 15 },
                          )
                  ->get_column('species')
                  ->all;

  $c->res->content_type('application/json');
  $c->res->body( $json->encode( \@results ));
}


=head2 find_organism

Chaining base to fetch a particular organism, chaining onto this like
/organism/<org_id>/<more_stuff>

=cut

sub find_organism :Chained('/') :PathPart('organism') :CaptureArgs(1) {
    my ( $self, $c, $organism_id ) = @_;

    # TODO: add capability to search by organism name as well

    $c->stash->{organism_id} = $organism_id;

    $c->stash->{organism_rs} =
        $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
            ->resultset('Organism::Organism')
            ->search_rs({ organism_id => $organism_id });
}

=head2 view_organism

Action for viewing an organism detail page.  Currently just redirects
to the legacy /chado/organism.pl.

=cut

sub view_organism :Chained('find_organism') :PathPart('view') {
    my ( $self, $c ) = @_;

    if( my $id = $c->stash->{organism_id} ) {
        $c->res->redirect("/chado/organism.pl?organism_id=$id", 302 );
    }
}


############## organism tree caching

has 'rendered_organism_tree_cache' => (
    is => 'ro',
    lazy_build => 1,
   ); sub _build_rendered_organism_tree_cache {
        my ( $self ) = @_;

        Cache::File->new(
            cache_root      => $self->_app->path_to( $self->_app->tempfiles_subdir('cache','rendered_organism_tree_cache') ),
            default_expires => 'never',

            load_callback => sub {
                my $set_name = shift->key;
                my $set = $self->organism_sets->{ $set_name };
                my $root_species  = $set->{root_species} or die "no root species defined for org set $set_name";
                my $species_names = [ $set->{resultset}->get_column('species')->all ];

                if( @$species_names ) {
                    my $orgtree = $self->_render_organism_tree(
                        $self->_app->dbic_schema('Bio::Chado::Schema','sgn_chado'),
                        $root_species,
                        $species_names,
                       );
                    return Storable::nfreeze( $orgtree );
                }
                else {
                    return Storable::nfreeze( {} );
                }
            },
           );
    }

# takes dbic schema, root species name, arrayref of species names to
# render returns hashref of newick string, png data, and an HTML image
# map
# returns hashref of
# {
#    newick         => 'newick string',
#    png            => 'png data',
#    image_map      => 'html image map',
#    image_map_name => 'name of the image map for <img usemap="" ... />',
# }
sub _render_organism_tree {
    my ( $self, $schema, $root_species, $species_names ) = @_;

    $self->_app->log->debug( "rendering org for root species '$root_species'" ) if $self->_app->debug;

    my $tree = CXGN::Phylo::OrganismTree->new( $schema );

    try {
        my $newick_string = $tree->build_tree(
            $root_species,
            $species_names,
            $self->species_data_summary_cache,
           );

        my $image_map_name = $root_species.'_map';
        my $image_map = $tree->get_renderer
            ->get_html_image_map( $image_map_name );
        my $image_png = $tree->render_png( undef, 1 );

        return {
            newick    => $newick_string,
            png       => $image_png,
            image_map => $image_map,
            image_map_name => $image_map_name,
        };
    } catch {
        warn $_;
        return;
    }
}

__PACKAGE__->meta->make_immutable;
1;
