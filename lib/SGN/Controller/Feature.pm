package SGN::Controller::Feature;

=head1 NAME

SGN::Controller::Feature - Catalyst controller for pages dealing with
Chado (i.e. Bio::Chado::Schema) features

=cut

use Moose;
use namespace::autoclean;

use HTML::FormFu;
use URI::FromHash 'uri';
use YAML::Any;

has 'default_page_size' => (
    is      => 'ro',
    default => 20,
);


BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

=head1 PUBLIC ACTIONS

=cut

# deprecated old paths are now redirects
sub view_by_name :Path('/feature/view/name') Path('/feature/view/id') Args(1) {
    my ( $self, $c, $id ) = @_;
    $c->res->redirect("/feature/$id/details",301);
}

=head2 search

Interactive search interface for features.

Public path: /feature/search

=cut

sub search :Path('/feature/search') Args(0) {
    my ( $self, $c ) = @_;

    my $req = $c->req;
    my $form = $self->_build_form;

    $form->process( $req );

    my $results;
    if( $form->submitted_and_valid ) {
        $results = $self->_make_feature_search_rs( $c, $form );
    }
    $c->stash(
        template => '/feature/search.mas',
        form                  => $form,
        results               => $results,
        pagination_link_maker => sub {
            return uri( query => { %{$form->params}, page => shift } );
        },
    );
}

#######################################

sub feature_details :PathPart('details') :Chained('get_feature') Args(0) {
    my ( $self, $c ) = @_;

       $c->forward('get_type_specific_data')
    && $c->forward('choose_view');
}

sub choose_view :Private {
    my ( $self, $c ) = @_;
    my $feature   = $c->stash->{feature};
    my $type_name = lc $feature->type->name;
    my $template  = "/feature/types/default.mas";

    $c->stash->{feature}     = $feature;
    $c->stash->{featurelocs} = $feature->featureloc_features;

    # look up site xrefs for this feature
    my @xrefs = map $c->feature_xrefs( $_, { exclude => 'featurepages' } ),
                ( $feature->name, $feature->synonyms->get_column('name')->all );
    unless( @xrefs ) {
        @xrefs = map {
            $c->feature_xrefs( $_->srcfeature->name.':'.($_->fmin+1).'..'.$_->fmax, { exclude => 'featurepages' } )
        }
        $c->stash->{featurelocs}->all
    }
    $c->stash->{xrefs} = \@xrefs;

    if ($c->view('Mason')->component_exists("/feature/types/$type_name.mas")) {
        $template         = "/feature/types/$type_name.mas";
        $c->stash->{type} = $type_name;
    }
    $c->stash->{template} = $template;

    return 1;
}

sub get_feature : Chained('/') CaptureArgs(1) PathPart('feature') {
    my ($self, $c, $id ) = @_;

    $c->stash->{blast_url} = '/tools/blast/index.pl';

    my $identifier_type = $c->stash->{identifier_type}
        || $id =~ /[^-\d]/ ? 'name' : 'feature_id';

    if( $identifier_type eq 'feature_id' ) {
        $id > 0
            or $c->throw_client_error( public_message => 'Feature ID must be a positive integer.' );
    }

    my $matching_features =
        $self->_app->dbic_schema('Bio::Chado::Schema','sgn_chado')
             ->resultset('Sequence::Feature')
             ->search(
                 { 'me.'.$identifier_type => $id },
                 { prefetch => [ 'type', 'featureloc_features' ] },
               );

    if( $matching_features->count > 1 ) {
        $c->throw_client_error( public_message => 'Multiple matching features' );
    }

    my ( $feature ) = $matching_features->all;
    $c->stash->{feature} = $feature
        or $c->throw_404( "Feature not found" );

    return 1;
}

sub get_type_specific_data :Private {
    my ( $self, $c ) = @_;

    my $type_name = $c->stash->{feature}->type->name;

    # look for an action with private path /feature/types/<type>/get_specific_data
    my $action = $c->get_action( 'get_specific_data', $self->action_namespace."/types/$type_name" );
    if( $action ) {
        $c->forward( $action ) or return;
    }

    return 1;
}


sub _build_form {
    my ($self) = @_;

    my $form = HTML::FormFu->new(Load(<<EOY));
      method: POST
      attributes:
        name: feature_search_form
        id: feature_search_form
      elements:
          - type: Text
            name: feature_name
            label: Feature Name
            size: 30

          - type: Select
            name: feature_type
            label: Feature Type

          - type: Select
            name: organism
            label: Organism

        # hidden form values for page and page size
          - type: Hidden
            name: page
            value: 1

          - type: Hidden
            name: page_size
            default: 20

          - type: Submit
            name: submit
EOY

    # set the feature type multi-select choices from the db
    $form->get_element({ name => 'feature_type'})->options( $self->_feature_types );
    $form->get_element({ name => 'organism'})->options( $self->_organisms );

    return $form;
}

# assembles a DBIC resultset for the search based on the submitted
# form values
sub _make_feature_search_rs {
    my ( $self, $c, $form ) = @_;

    my $rs = $self->_app->dbic_schema('Bio::Chado::Schema','sgn_chado')
                        ->resultset('Sequence::Feature');

    if( my $name = $form->param_value('feature_name') ) {
        $rs = $rs->search({ 'lower(name)' => { like => '%'.lc( $name ).'%' }});
    }

    if( my $type = $form->param_value('feature_type') ) {
        $rs = $rs->search({ 'type_id' => $type });
    }

    if( my $organism = $form->param_value('organism') ) {
        $rs = $rs->search({ 'organism_id' => $organism });
    }

    # page number and page size, and order by species name
    $rs = $rs->search( undef,
                       { page => $form->param_value('page') || 1,
                         rows => $form->param_value('page_size') || $self->default_page_size,
                         order_by => 'name',
                       },
                     );

    return $rs;
}

sub _organisms {
    my ($self) = @_;
    return [
        map [ $_->organism_id, $_->species ],
        $self->_app->dbic_schema('Bio::Chado::Schema','sgn_chado')
             ->resultset('Organism::Organism')
             ->search(undef, { order_by => 'species' }),
    ];
}

sub _feature_types {
    my ($self) = @_;

    return [
        map [$_->cvterm_id,$_->name],
        $self->_app->dbic_schema('Bio::Chado::Schema','sgn_chado')
                ->resultset('Sequence::Feature')
                ->search_related(
                    'type',
                    {},
                    { select => [qw[ cvterm_id type.name ]],
                    group_by => [qw[ cvterm_id type.name ]],
                    order_by => 'type.name',
                    },
                )
    ];
}

__PACKAGE__->meta->make_immutable;
