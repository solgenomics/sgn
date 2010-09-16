package SGN::Controller::Feature;

=head1 NAME

SGN::Controller::Organism - Catalyst controller for pages dealing with
features

=cut

use Moose;
use namespace::autoclean;

use HTML::FormFu;
use URI::FromHash 'uri';
use YAML::Any;

has 'schema' => (
is => 'rw',
isa => 'DBIx::Class::Schema',
required => 0,
);

has 'default_page_size' => (
is => 'ro',
default => 20,
);


BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

sub delegate_component
{
    my ($self, $c, $matching_features) = @_;
    my $feature   = $matching_features->next;
    my @children  = $feature->child_features;
    my @parents   = $feature->parent_features;
    my $type_name = $feature->type->name;

    eval {
        $c->forward_to_mason_view(
            "/feature/$type_name.mas",
            type    => $type_name,
            feature => $feature,
            children=> \@children,
            parents => \@parents,
        );
    };
    if ($@) {
        $c->forward_to_mason_view(
            "/feature/dhandler",
            feature => $feature,
            children=> \@children,
            parents => \@parents,
        );
    }
}

sub validate
{
    my ($self, $c,$matching_features,$key, $val) = @_;
    my $count = $matching_features->count;
#   EVIL HACK: We need a disambiguation process
#   $c->throw( message => "too many features where $key='$val'") if $count > 1;
    $c->throw( message => "feature with $key = '$val' not found") if $count < 1;
}

sub view_name :Path('/feature/view/name') Args(1) {
    my ( $self, $c, $feature_name ) = @_;
    $self->schema( $c->dbic_schema('Bio::Chado::Schema','sgn_chado') );
    $self->_view_feature($c, 'name', $feature_name);
}

sub _validate_pair {
    my ($self,$c,$key,$value) = @_;
    $c->throw( message => "$value is not a valid value for $key" )
        if ($key =~ m/_id$/ and $value !~ m/\d+/);
}

sub _view_feature {
    my ($self, $c, $key, $value) = @_;

    if ( $value =~ m/\.fasta$/ ) {
        $value =~ s/\.fasta$//;
        $self->_validate_pair($c,$key,$value);
        my $matching_features = $self->schema
                                    ->resultset('Sequence::Feature')
                                    ->search({ $key => $value });
        my $feature = $matching_features->next;
        $c->throw( message => "feature with $key = '$value' not found") unless $feature;
        print $self->render_fasta($feature);
    } else {
        $self->_validate_pair($c,$key,$value);
        my $matching_features = $self->schema
                                    ->resultset('Sequence::Feature')
                                    ->search({ $key => $value });

        $self->validate($c, $matching_features, $key => $value);
        $self->delegate_component($c, $matching_features);
    }
}

sub view_id :Path('/feature/view/id') Args(1) {
    my ( $self, $c, $feature_id ) = @_;
    $self->schema( $c->dbic_schema('Bio::Chado::Schema','sgn_chado') );
    $self->_view_feature($c, 'feature_id', $feature_id);
}

sub search :Path('/feature/search') Args(0) {
    my ( $self, $c ) = @_;
    $self->schema( $c->dbic_schema('Bio::Chado::Schema','sgn_chado') );

    my $req = $c->req;
    my $form = $self->_build_form;

    $form->process( $req );

    my $results;
    if( $form->submitted_and_valid ) {
        $results = $self->_make_feature_search_rs( $c, $form );
    }

    $c->forward_to_mason_view(
        '/feature/search.mas',
        form => $form,
        results => $results,
        pagination_link_maker => sub {
            return uri( query => { %{$form->params}, page => shift } );
        },
    );
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

    my $rs = $self->schema->resultset('Sequence::Feature');

    if( my $name = $form->param_value('feature_name') ) {
        $rs = $rs->search({ 'lower(name)' => { like => '%'.lc( $name ).'%' }});
    }

    if( my $type = $form->param_value('feature_type') ) {
        $self->_validate_pair($c,'type_id',$type);
        $rs = $rs->search({ 'type_id' => $type });
    }

    if( my $organism = $form->param_value('organism') ) {
        $self->_validate_pair( $c, 'organism_id', $organism );
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
        $self->schema
             ->resultset('Organism::Organism')
             ->search(undef, { order_by => 'species' }),
    ];
}

sub _feature_types {
    my ($self) = @_;

    return [
        map [$_->cvterm_id,$_->name],
        $self->schema
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

sub render_fasta {
    my ($self, $feature) = @_;

    my $matching_features = $self->schema
                                ->resultset('Sequence::Feature')
                                ->search({ name => $feature->name });

    my $sequence  = Bio::PrimarySeq->new(
                    -id  => $feature->name,
                    -seq => $feature->residues,
                    );
    my $fh = Bio::SeqIO->new(
            -format => 'fasta',
            -fh     => \*STDOUT)
            ->write_seq( $sequence );
    my $output = CGI->new->header( -type => 'text/txt' );
    $output   .= $_ while <$fh>;
    return $output;
}

__PACKAGE__->meta->make_immutable;
1;

