package SGN::Test::WWW::Mechanize;

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

    # You can use XPath selectors on $mech to find things
    # see WWW::Mechanize::TreeBuilder and HTML::TreeBuilder::XPath for more info
    my $value = $mech->findvalue( '/html/body//span[@class="sequence"]');

    # do some tests while logged in as a temporary user
    $mech->while_logged_in( { user_type => 'curator' }, sub {

        $mech->get_ok( '/organism/sol100/view' );
        $mech->content_contains( 'Authorized user', 'now says authorized user' );
        $mech->content_contains( 'Add a SOL100 organism', 'now has an adding form' );
        $mech->submit_form_ok({
            form_name => 'sol100_add_form',
            fields    => { species => $test_organism->species },
           }, 'submitted add organism form');

    });

    # run tests that require a certain level of access to the
    # application (see "TEST LEVELS" below)
    $mech->with_test_level( local => sub {

       my $c = $mech->context;
       my $dbh  = $c->dbc->dbh;
       my $check_data = $dbh->selectall_arrayref('....');

       $mech->get_ok( '/organism/sol100/view' );


    });

=head1 TEST LEVELS

This module introduces the concept of B<test levels>, which correspond
to how much access to the app's underlying files, databases, and
program state the test code is expected to have.

The following test levels are defined:

=head2 remote

The app and the tests are running on different hosts.  The only
means of interaction is via remote requests.

This level is in effect if both SGN_TEST_SERVER and SGN_TEST_REMOTE are
set to true values.

=head2 local

The app and the tests are running on the same host, and with the same
configuration data, as this test code.  Facilities under C<remote> are
available, plus files and databases can be accessed via the context
object, given by $mech->context.

This level is in effect if SGN_TEST_SERVER is set, but SGN_TEST_REMOTE
is not set, or false.

=head2 process

The app and the tests are running in the same process.  Facilities under
C<local> are available, plus the app's in-memory state and
configuration can be accessed directly from the context object.

This level is in effect if no SGN_TEST_SERVER environment variable is
set.

=head1 SEE ALSO

This class inherits from all of these:
L<Test::WWW::Mechanize::Catalyst>, L<Test::WWW::Mechanize>,
L<WWW::Mechanize>

It also does the L<WWW::Mechanize::TreeBuilder> role, with a tree_class of L<HTML::TreeBuilder::XPath>.

=head1 ATTRIBUTES

=cut

use Moose;
use namespace::autoclean;

BEGIN {
    $ENV{SGN_TEST_MODE}   = 1;
    $ENV{CATALYST_SERVER} = $ENV{SGN_TEST_SERVER};
}

use Carp;
use Test::More;

use Try::Tiny;

use CXGN::People::Person;
use CXGN::People::Login;

use SGN::Devel::MyDevLibs;

extends 'Test::WWW::Mechanize::Catalyst';

with 'WWW::Mechanize::TreeBuilder' => {
    tree_class => 'HTML::TreeBuilder::XPath'
};


=head2 catalyst_app

The name of the app under test.  Defaults to 'SGN'.

=cut

has '+catalyst_app' => ( default => 'SGN' );

=head2 context

A context object for the app under test.  Only available under
C<local> or C<process> testing levels.

Under the C<process> test level, this will be the Catalyst app class
(same as C<catalyst_app> above).  Under C<local> testing, this will be
an L<SGN::Context>.  Under C<remote> testing, this will throw an
exception.

=cut

has 'context' => (
    is => 'ro',
    lazy_build => 1,
   ); sub _build_context {
       my $self = shift;
       if( $self->can_test_level('process') ) {
           Class::MOP::load_class($self->catalyst_app );
           return $self->catalyst_app;
       } elsif($self->can_test_level('local') ) {
           require SGN::Context;
           return SGN::Context->new;
       } else {
           confess 'context() should not ever be called at remote test level';
       }
   }

# private, holds the user we're using for testing
has 'test_user' => (
    is => 'rw',
    isa => 'HashRef',
    predicate => 'has_test_user',
    clearer   => 'clear_test_user',
   );

=head2 test_level

Read-only attribute to give the current testing level, one of 'remote',
'local', or 'process'.

=cut

sub test_level {
    return 'process' if ! $ENV{SGN_TEST_SERVER};
    return 'remote'  if $ENV{SGN_TEST_REMOTE};
    return 'local';
}

=head1 METHODS

=head2 can_test_level

Takes single test level name, returns true if the current testing
level is at least the given level.

Example:

   if( $mech->can_test_level('local') ) {
     test_local_stuff();
   }

=cut

sub can_test_level {
    my ( $self, $check ) = @_;

    my %val = ( remote => 0, local => 1, process => 2 );
    confess "invalid test level '$check'" unless exists $val{$check};
    return $val{ $self->test_level } >= $val{ $check };

}

=head2 with_test_level

Run the subroutine if the test level is at least the given level, or
output a skip if not.  Takes an optional test count after the sub.

Example:

  $mech->with_test_level( local => sub {

  }, $optional_test_count );

=cut

sub with_test_level {
    my ( $self, $need_level, $sub, $count ) = @_;

    SKIP: {
          skip( "tests that require $need_level-level access, current level is ".$self->test_level, ( $count || 1 ) )
              unless $self->can_test_level( $need_level );

          $sub->( $self );
      }
}

=head2 dbh_leak_ok

Call immediately after a get_ok() to re-fetch the same URL, checking
the database connection count before and after the GET.

If the connection count after the second fetch is greater than before
the fetch, the test fails.

Skips if the current test level does not support a leak check.

=cut

sub dbh_leak_ok {
    my $self = shift;
    my $test_name = shift || '';
    $test_name .= ' ' if $test_name;

    $self->with_test_level( local => sub {
        my $before = $self->_db_connection_count;
        my $url = $self->base;
        $self->get( $url );
        my $after  = $self->_db_connection_count;
        cmp_ok( $after, '<=', $before, "did not leak any database connections: $test_name($url)");
    }, 1 );
}

sub _db_connection_count {
    my ($mech) = @_;
    my $dbh     = DBI->connect( @{ $mech->context->dbc_profile }{qw{ dsn user password attributes }} );
    return $dbh->selectcol_arrayref(<<'')->[0] - 1;
select count(*) from pg_stat_activity

}

sub create_test_user {
    my $self = shift;
    my %props = @_;

    local $SIG{__DIE__} = \&Carp::confess;
    my %u = (
        first_name => 'testfirstname',
        last_name  => 'testlastname',
        user_name  => 'testusername',
        password   => 'testpassword',
        user_type  => $props{user_type} || 'user',
       );

    $self->_delete_user( \%u );

    # generate a new user for testing purposes
    # (to be deleted right afterwards)
    $self->context->dbc->txn( ping => sub {
        my $dbh = $_;

        my $p = CXGN::People::Person->new( $dbh );
        $p->set_first_name( $u{first_name} );
        $p->set_last_name( $u{last_name} );
        my $p_id = $p->store();
        $u{ 'id' } = $p_id
            or die "could not create person $u{first_name} $u{last_name}";

        my $login = CXGN::People::Login->new( $dbh, $p_id );
        $login->set_username( $u{user_name} );
        $login->set_password( $u{password} );
        $login->set_user_type( $u{user_type} );

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
          ->new( $self->context->dbc->dbh, $self->test_user->{id} )
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

    $self->context->dbc->txn( ping => sub {
        my $dbh = $_;
        if ( my $u_id = CXGN::People::Person->get_person_by_username( $dbh, $u->{user_name} ) ) {
            CXGN::People::Person->new( $dbh, $u_id )->hard_delete;
        }
    });
}

=head2 while_logged_in

Execute the given code while logged in.  Takes an optional
hash-style list of parameters to set on the temp user that is created.

  Args:  hash ref of props for the temp user to create,
         followed by a subroutine ref to execute while logged in

         current supported user properties:

           user_type  =>  'curator', 'sequencer', etc.  default 'user'

  Ret: nothing meaningful

In addition, the called subroutine is passed a hashref of user
information of the form:

  {
        first_name => 'testfirstname',
        last_name  => 'testlastname',
        user_name  => 'testusername',
        password   => 'testpassword',
        user_type  =>  $props{user_type} || 'user',
        id         => 34,
  }

  Example:

    $mech->while_logged_in({ user_type => 'curator' }, sub {

        my $user_info_hashref = shift;

        diag "logged in as user id $user_info_hashref->{id}";

        $mech->get_ok( '/organism/sol100/view' );
        $mech->content_contains( 'Authorized user', 'now says authorized user' );

    });

=cut

sub while_logged_in {
    my ($self,$props,$sub) = @_;
    $self->with_test_level( local => sub {
        $self->create_test_user( %$props );
        $self->log_in_ok;
        try {
            $sub->( $self->test_user );
        } catch {
            die $_;
        } finally {
            $self->log_out;
        };
    });
}

=head2 while_logged_in_all

Execute the given code while logged in for each user_type.

  Args:  a subroutine ref to execute while logged in

  Ret: nothing meaningful

  Example:

    $mech->while_logged_in_all(sub {
        $mech->get_ok( '/organism/sol100/view' );
        $mech->content_contains( 'Authorized user', 'now says authorized user' );
    });

=cut

sub while_logged_in_all {
    my ($self,$sub) = @_;
    for ( qw/ user curator submitter sequencer genefamily_editor / ) {
        $self->while_logged_in( { user_type => $_ }, $sub );
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
