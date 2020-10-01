=head1 NAME

SGN::Controller::Profile - Catalyst controller for the profile page


=cut

package SGN::Controller::Profile;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);


sub _build_schema {
  shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

sub profile_detail : Path('/profile') Args(1) {
    my $self = shift;
    my $c = shift;
    my $profile_id = shift;
    my $schema = $self->schema;
    my $profile_json_type_id = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), 'product_profile_json', 'project_property')->cvterm_id();
    my $profile_rs = $schema->resultset("Project::Projectprop")->search({ projectprop_id => $profile_id, type_id => $profile_json_type_id });

    if (!$profile_rs) {
        $c->stash->{message} = 'The requested profile does not exist.';
    }

#    $c->stash->{profile_name} = $profile_name;
    $c->stash->{user_id} = $c->user ? $c->user->get_object()->get_sp_person_id() : undef;
    $c->stash->{profile_id} = $profile_id;
    $c->stash->{template} = '/breeders_toolbox/program/profile_detail.mas';

}


__PACKAGE__->meta->make_immutable;

1;
