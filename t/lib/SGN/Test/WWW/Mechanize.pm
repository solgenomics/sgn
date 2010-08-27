=head1 NAME

SGN::Test::WWW::Mechanize - subclass of
L<Test::WWW::Mechanize::Catalyst> with some SGN-specific convenience

=head1 SYNOPSIS

    my $mech = SGN::Test::WWW::Mechanize->new;

    # look at some pages
    $mech->get_ok( '/organism/sol100/view' );
    $mech->content_contains('SOL100 Organisms');
    $mech->content_contains('presents a summary');
    $mech->content_contains('click on an organism name');
    $mech->content_lacks('Add to Tree','not logged in, does not have a form for adding an organism');

    # do some tests while logged in as a temporary user
    $mech->while_logged_in( user_type => 'curator', sub {

        $mech->get_ok( '/organism/sol100/view' );
        $mech->content_contains( 'Authorized user', 'now says authorized user' );
        $mech->content_contains( 'Add a SOL100 organism', 'now has an adding form' );
        $mech->submit_form_ok({
            form_name => 'sol100_add_form',
            fields    => { species => $test_organism->species },
           }, 'submitted add organism form');

    });

=head1 SEE ALSO

This class has the methods from all of these:
  L<Test::WWW::Mechanize::Catalyst>, L<Test::WWW::Mechanize>, L<WWW::Mechanize>


=head1 METHODS

Plus the following:

=cut

package SGN::Test::WWW::Mechanize;
use Moose;

use SGN;

use CXGN::People::Person;
use CXGN::People::Login;

extends 'Test::WWW::Mechanize::Catalyst';

has '+catalyst_app' => ( default => 'SGN' );

has 'test_user' => (
    is => 'rw',
    isa => 'HashRef',
    predicate => 'has_test_user',
    clearer   => 'clear_test_user',
   );

sub create_test_user {
    my $self = shift;
    my %props = @_;

    local $SIG{__DIE__} = \&Carp::confess;
    my %u = qw(
               first_name  testfirstname
               last_name   testlastname
               user_name   testusername
               password    testpassword
              );

    $self->_delete_user( \%u );

    # generate a new user for testing purposes
    # (to be deleted right afterwards)
    $self->catalyst_app->dbc->txn( ping => sub {
        my $dbh = $_;

        my $p = CXGN::People::Person->new( $dbh );
        $p->set_first_name( $u{first_name} );
        $p->set_last_name( $u{last_name} );
        my $p_id = $p->store();
        $u{ sp_person_id } = $p_id
            or die "could not create person $u{first_name} $u{last_name}";

        my $login = CXGN::People::Login->new( $dbh, $p_id );
        $login->set_username( $u{user_name} );
        $login->set_password( $u{password} );
        $login->set_user_type( $props{user_type} || 'user' );

        $login->store();
    });

    $self->test_user(\%u);
}


sub DEMOLISH {
    shift->delete_test_user;
}

sub set_test_user_type {
    my $self = shift;

    CXGN::People::Login
          ->new( $self->catalyst_app->dbc->dbh, $self->test_user->{sp_person_id} )
          ->set_user_type(shift);
}

sub delete_test_user {
    my $self = shift;

    # delete our test user from the database if one has been created
    if( $self->has_test_user ) {
        my $u = $self->test_user;
        $self->_delete_user( $u );
    }

    $self->clear_test_user;
}

sub _delete_user {
    my ( $self, $u ) = @_;

    $self->catalyst_app->dbc->txn( ping => sub {
        my $dbh = $_;
        if ( my $u_id = CXGN::People::Person->get_person_by_username( $dbh, $u->{user_name} ) ) {
            CXGN::People::Person->new( $dbh, $u_id )->hard_delete;
        }
    });
}

=head2 while_logged_in

Execute the given code while logged in.  Takes an optional
hash-style list of parameters to set on the temp user that is created.

  Args:  hash-style list of props for the temp user to create,
         followed by a subroutine ref to execute while logged in

         current supported user properties:

           user_type  'curator', 'sequencer', etc.  default 'user'
  Ret: nothing meaningful

  Example:

    $mech->while_logged_in( user_type => 'curator', sub {

        $mech->get_ok( '/organism/sol100/view' );
        $mech->content_contains( 'Authorized user', 'now says authorized user' );

    });

=cut

sub while_logged_in {
    my $self = shift;
    my $sub  = pop;
    my %props = @_;
    $self->create_test_user( %props );
    $self->log_in_ok;
    $sub->();
    $self->log_out;
}

sub while_logged_in_all {
    my ($self,$sub) = @_;
    my @users = qw/user curator submitter sequencer/;
    for my $user_type (@users) {
        $self->create_test_user( user_type => $user_type );
        $self->log_in_ok;
        $sub->($user_type);
        $self->log_out;
    }
}

sub log_in_ok {
    my ($self) = @_;

    $self->get_ok("/solpeople/top-level.pl");
    $self->content_contains("Login");

    my %form = (
	form_name => 'login',
	fields    => {
	    username => $self->test_user->{user_name},
	    pd       => $self->test_user->{password},
	},
       );

    $self->submit_form_ok( \%form, "submitted login form" );
    $self->content_lacks('Incorrect username', 'did not get "Incorrect username"')
        or Test::More::diag $self->content;
    $self->content_lacks('Incorrect password','did not get "Incorrect password"')
        or Test::More::diag $self->content;
}

sub log_out {
    my ($self) = @_;
    $self->get_ok( "/solpeople/login.pl?logout=yes", 'logged out' );
}


__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
1;
