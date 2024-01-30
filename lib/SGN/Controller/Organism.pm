=head1 NAME

SGN::Controller::Organism - Catalyst controller for dealing with
organism data

=cut

package SGN::Controller::Organism;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use Storable;

use Cache::File;
use HTTP::Status;
use JSON::Any; my $json = JSON::Any->new;
use List::MoreUtils qw/ any /;
use YAML::Any;

use CXGN::Chado::Organism;
use CXGN::Login;
use CXGN::Phylo::OrganismTree;
use CXGN::Page::FormattingHelpers qw | tooltipped_text |;
use CXGN::Tools::Text;
use SGN::Image;
use Data::Dumper;

with 'Catalyst::Component::ApplicationAttribute';

=head1 ACTIONS

=head2 view_all

Public Path: /organism/all/view

Display the sgn data overview page.

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
    foreach my $v (values %{ $c->stash->{organism_trees} }) { 
	$v->{image_uri} = $c->uri_for( $self->action_for('organism_tree_image'), [ $v->{set_name} ])->relative();
   }


    $c->stash({
        template => '/content/sgn_data.mas',
    });
}




# /organism/set/<set_name>
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

=head2 organism_tree_image

Public Path: /organism/tree/<set_name>/image

Get a PNG organism tree image

=cut

sub organism_tree_image :Chained('get_organism_tree') :PathPart('image') {
    my ( $self, $c ) = @_;

    my $image = $c->stash->{organism_tree_cache_entry}->thaw
        or $c->throw_404;

    $image->{png} or die "no png data for organism set '".$c->stash->{organism_set_name}."'! cannot serve image.  Dump of cache entry: \n".Data::Dumper::Dumper( $image );

    $c->res->body( $image->{png} );
    $c->res->content_type( 'image/png' );
}

=head2 clear_organism_tree

Public Path: /organism/tree/<set_name>/flush

Flush a cached organism tree image, so that the next call to serve the
organism tree image or html will regenerate it.

=cut

# /organism/tree/<set_name>/flush
sub clear_organism_tree :Chained('get_organism_tree') :PathPart('flush') {
    my ( $self, $c ) = @_;

    $c->stash->{organism_tree_cache_entry}->remove;
    $c->res->content_type('application/json');
    $c->res->body(<<'');
{ status: "success" }

}


=head2 view_sol100

Public Path: /organism/sol100/view

Display the sol100 organisms page.

=cut

sub view_sol100 :Path('sol100/view') :Args(0) {
    my ( $self, $c ) = @_;

    my ($person_id, $user_type) = CXGN::Login->new( $c->dbc->dbh )->has_session();
    print STDERR "ACTION: ".$self->action_for('organism_tree_image')."\n";

    print STDERR "IMAGE URI: ".$c->uri_for( $self->action_for('organism_tree_image'), ['sol100'] )->relative()."\n";
    
    $c->stash({
        template => "/sequencing/sol100.mas",



        organism_tree => {
            %{ $self->rendered_organism_tree_cache->thaw( 'sol100' ) },

	    
	    
            image_uri => $c->uri_for( $self->action_for('organism_tree_image'), ['sol100'] )->relative(),
        },

        show_org_add_form         => ( $user_type && any {$user_type eq $_} qw( curator submitter sequencer ) ),
        organism_add_uri          => '/organism/sol100/add_organism', #$self->action_for('add_sol100_organism')),
        organism_autocomplete_uri => $c->uri_for( 'autocomplete'),#$self->action_for('autocomplete')), #, ['Solanaceae'])->relative(),

    });
}

=head2 add_sol100_organism

Public Path: /organism/sol100/add_organism

POST target to add an organism to the set of sol100 organisms.  Takes
one param, C<species>, which is the exact string species name in the
DB.

After adding, redirects to C<view_sol100>.

=cut

sub add_sol100_organism :Path('sol100/add_organism') :Args(0) {
    my ( $self, $c ) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $organism = $c->dbic_schema('Bio::Chado::Schema','sgn_chado', $sp_person_id)
                     ->resultset('Organism::Organism')
                     ->search({ species => { ilike => $c->req->body_parameters->{species} }})
                     ->single;

    ## validate our conditions
    my @validate = ( [ RC_METHOD_NOT_ALLOWED,
                       'Only POST requests are allowed for this page.',
                       sub { $c->req->method eq 'POST' }
                     ],
                     [ RC_BAD_REQUEST,
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
    $c->res->redirect( $c->uri_for( $self->action_for('view_sol100'))->relative());
}


sub invalidate_organism_tree_cache :Args(0) {
    my ($self, $c) = @_;
    $self->rendered_organism_tree_cache->remove( 'sol100' ); #< invalidate the sol100 cached image tree
    return;
}


#Chaining base to fetch a particular organism, chaining onto this like
#/organism/<org_id>/<more_stuff>
sub find_organism :Chained('/') :PathPart('organism') :CaptureArgs(1) {
    my ( $self, $c, $organism_id ) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $rs =
        $c->dbic_schema('CXGN::Biosource::Schema','sgn_chado', $sp_person_id)
          ->resultset('Organism::Organism');

    if( $organism_id =~ /\D/ ) {
        (my $species = $organism_id) =~ s/_/ /g;
        $rs = $rs->search_rs({ 'lower(me.species)' => lc $species });
    } else {
        $rs = $rs->search_rs({ organism_id => $organism_id });
    }

    my ( $organism ) = my @organisms = $rs->all;
    $c->throw_client_error('Multiple matching organisms') if @organisms > 1;
    $c->throw_404('Organism not found') unless $organism;

    $c->stash(
        organism_rs => $rs,
        organism_id => $organism->organism_id,
        organism    => $organism,
        );
}

=head2 view_organism

Public Path: /organism/<organism_id>/view

Action for viewing an organism detail page.  Currently just redirects
to the legacy /chado/organism.pl.

=cut

sub view_organism :Chained('find_organism') :PathPart('view') :Args(0) {
    my ( $self, $c ) = @_;

    return unless $c->stash->{organism_id};

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $organism = CXGN::Chado::Organism->new($schema, $c->stash->{organism_id});
    $c->stash->{organism} = $organism;
    $c->stash->{na}= qq| <span class="ghosted">N/A</span> |;
    $c->stash->{genus} = $c->stash->{organism_rs}->first()->genus();
    $c->stash->{taxon} = $organism->get_taxon();
    $c->stash->{organism_name} = $c->stash->{organism_rs}->first()->species();

    my $common_name = $c->stash->{organism_rs}->first()->common_name();
    $c->stash->{common_name} = lc($common_name);
    $common_name = ucfirst($common_name);
    $c->stash->{comment} = $c->stash->{organism_rs}->first()->comment();

    my $organismprop_rs = $schema->resultset('Organism::Organismprop')->search( { organism_id=>$c->stash->{organism_id} });

    $c->stash->{description} = CXGN::Tools::Text::format_field_text($organism->get_comment());

    @{$c->stash->{synonyms}} = $organism->get_synonyms();

    $c->stash->{loci} = "<a href=\"/search/locus\">".$organism->get_loci_count().'</a>';

    $c->stash->{taxonomy} = join ", ", reverse(get_parentage($organism));

    my $accessions;
    my @dbxrefs = $organism->get_dbxrefs();
    my $solcyc_link;

    foreach my $dbxref (@dbxrefs) {
        my $accession = $dbxref->accession();
        my ($db)      = $dbxref->search_related("db");
        my $db_name   = $db->name();
        my $full_url  = $db->urlprefix . $db->url();

        if ( $db_name =~ m/(DB:)(.*)/ ) {
            $db_name = $2;
            $db_name =~ s/_/ /g;

            $accessions .=
                qq|<a href= "$full_url$accession">$db_name ID: $accession</a ><br />|;
        }
        if ( $db_name eq 'SolCyc_by_species' ) {
            my $solcyc = $accession;
            $solcyc =~ s/\///g;
            $solcyc =~ s/$solcyc/\u\L$solcyc/g;
            $solcyc      = $solcyc . "Cyc";
            $solcyc_link = "See <a href=\"$full_url$accession\">$solcyc</a>";
        }
    }

    my $logged_user = $c->user;
    my $person_id = $logged_user->get_object->get_sp_person_id if $logged_user;
    my $privileged_user =  ($logged_user && ( $logged_user->check_roles('curator') || $logged_user->check_roles('sequencer') || $logged_user->check_roles('submitter') ) )  ;

    $c->stash->{privileged_user} = $privileged_user;

    $c->stash->{solcyc_link} = $solcyc_link;
    $c->stash->{accessions} = $accessions;
    my $na      = qq| <span class="ghosted">N/A</span> |;
    $c->stash->{ploidy} = $organism->get_ploidy() || $na;
    $c->stash->{genome_size} = $organism->get_genome_size() || $na;
    $c->stash->{chromosome_number} = $organism->get_chromosome_number() || $na;
    my @image_ids = $organism->get_image_ids();
    $c->stash->{images} = \@image_ids;
    $self->map_data($c);
    $self->transcript_data($c);
    $self->phenotype_data($c);
    $self->qtl_data($c);

}

sub map_data {
    my $self = shift;
    my $c = shift;
    my $maps;
    my @map_data = $c->stash->{organism}->get_map_data();
    foreach my $info (@map_data) {
        my $map_id     = $info->[1];
        my $short_name = $info->[0];
        $maps .= "<a href=\"/cview/map.pl?map_id=$map_id\">$short_name</a><br />";
    }
    $c->stash->{maps} = $maps;
}

sub transcript_data {
    my $self = shift;
    my $c = shift;

    my @libraries = $c->stash->{organism}->get_library_list();

    my $attribution = $c->stash->{organism}->get_est_attribution();

    $c->stash->{libraries} = \@libraries;
    $c->stash->{est_attribution}  = $attribution;

}

sub qtl_data {
    my $self = shift;
    my $c = shift;


    ####################### QTL DISPLAY #############
    my $common_name = $c->stash->{common_name};
    my @qtl_data = qtl_populations($common_name);
    unless (@qtl_data) { @qtl_data = ['N/A', 'N/A'];}


    $c->stash->{qtl_data} = \@qtl_data;
}

sub phenotype_data {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema','sgn_chado', $sp_person_id);
    my $organism = $c->stash->{organism};
    my $organism_id = $organism->get_organism_id;
    my $pheno_count = $organism->get_phenotype_count();
    my $onto_count  = $schema->resultset("Stock::StockCvterm")->search_related('stock', {
        organism_id => $organism_id } )->count;
    my $trait_count = $schema->resultset("NaturalDiversity::NdExperimentPhenotype")->search_related('nd_experiment')->search_related('nd_experiment_stocks')->search_related('stock', { organism_id => $organism_id } )->count;

    my $pheno_list =
        qq|<a href= "/search/stocks?organism=$organism_id">$pheno_count</a>|;
    $c->stash->{phenotypes}  = $pheno_list;
    my $onto_list =
        qq|<a href= "/search/stocks?organism=$organism_id">$onto_count</a>|;
    $c->stash->{onto_count}  = $onto_list;
    my $trait_list =
        qq|<a href= "/search/stocks?organism=$organism_id">$trait_count</a>|;
    $c->stash->{trait_count} = $trait_list;

}


=head1 ATTRIBUTES

=head2 organism_sets

a hashref of organism sets (DBIC resultsets) as:

  { set_name => {
           description => 'user-visible description string for the set',
           resultset => DBIC resultset of organisms in that set,
         },
  }

currently defined sets are:

=head3 sol100

the SOL100 organisms, which are organisms in solanaceae that have a
'web visible' organismprop set

=head3 Solanaceae

all organisms in the Solanaceae family

=head3 Rubiaceae

all organisms in the Rubiaceae family

=head3 Plantaginaceae

all organisms in the Plantaginaceae family

=head3 web_visible_Solanaceae

organisms in Solanaceae that have their 'web visible' organismprop set

=head3 web_visible_Rubiaceae

organisms in Rubiaceae that have their 'web visible' organismprop set

=head3 web_visible_Plantaginaceae

organisms in Plantaginaceae that have their 'web visible' organismprop set

=cut

has 'organism_sets' => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
   ); sub _build_organism_sets {
        my $self = shift;
        my $c = shift;
        my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
        my $schema = $self->_app->dbic_schema('Bio::Chado::Schema','sgn_chado', $sp_person_id);
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
    }

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


=head2 species_data_summary_cache

L<Cache> object containing species data summaries, as:

  {
    <organism_id> => {
         'Common Name' => common_name,
          ...
    },
    ...
  }

Access with  C<$controller-E<gt>species_data_summary_cache->thaw($organism_id )>,
do not use Cache's C<get> method.

=cut

has 'species_data_summary_cache' => (
    is  => 'ro',
    lazy_build => 1,
   ); sub _build_species_data_summary_cache {
       my ($cache_class, $config) = shift->_species_summary_cache_configuration;
       return $cache_class->new( %$config );
   }

sub _species_summary_cache_configuration {
    my ( $self, $c ) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema   = $self->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado', $sp_person_id);

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
                'Genome Information' => $org->has_avail_genome ? 'yes': 'no',
                'Libraries' => scalar( $org->get_library_list ),
            });
        },
    };
}

=head2 rendered_organism_tree_cache

A cache of rendered organism trees, as

   set_name  =>
    {
       newick         => 'newick string',
       png            => 'png data',
       image_map      => 'html image map',
       image_map_name => 'name of the image map for <img usemap="" ... />',
     }

=cut

has 'rendered_organism_tree_cache' => (
    is => 'ro',
    lazy_build => 1,
   ); sub _build_rendered_organism_tree_cache {
        my ( $self, $c ) = @_;
        my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

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
                        $self->_app->dbic_schema('Bio::Chado::Schema','sgn_chado', $sp_person_id),
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
	
	my $cache = $self->species_data_summary_cache();
	foreach my $n (@$species_names) { 
	    my $ors = CXGN::Chado::Organism::get_organism_by_species($n, $schema);
	    # $o is a resultset
	    if ($ors) { 
		my $genome_info = $cache->thaw($ors->organism_id())->{'Genome Information'};
		if ($genome_info =~ /y/i) { 
		    $tree->hilite_species([170,220,180], [$n]);
		}
	    }
	}
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


=head2 qtl_populations

 Usage: my @qtl_data = qtl_populations($common_name);
 Desc:  returns a list of qtl populations (hyperlinked to the pop page)
        and counts of traits assayed for QTL for the corresponding population
 Ret: an array of array of populations and trait counts or undef
 Args: organism group common name
 Side Effects:
 Example:

=cut



sub qtl_populations {
    my $gr_common_name = shift;
    my $qtl_tool       = CXGN::Phenome::Qtl::Tools->new();

    my @org_pops       = $qtl_tool->qtl_pops_by_common_name($gr_common_name);
    my @pop_data;

    if (@org_pops) {
        foreach my $org_pop (@org_pops) {
            my $pop_id   = $org_pop->get_population_id();
            my $pop_name = $org_pop->get_name();
            my $pop_link = qq |<a href="/qtl/view/$pop_id">$pop_name</a>|;
            my @traits   = $org_pop->get_cvterms();
            my $count    = scalar(@traits);

            push @pop_data, [ map { $_ } ( $pop_link, $count ) ];
        }

    }
    return @pop_data;
}

sub get_parentage {

    my $organism = shift;
    my $parent   = $organism->get_parent();

    my @taxonomy;
    if ($parent) {
        my $species = $parent->get_species();
        my $taxon   = $parent->get_taxon();

        push @taxonomy,  tooltipped_text( $species, $taxon );
        @taxonomy = (@taxonomy, get_parentage($parent));
    }
    return @taxonomy;
}

__PACKAGE__->meta->make_immutable;

1;
