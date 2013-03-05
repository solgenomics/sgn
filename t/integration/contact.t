#!/usr/bin/perl
use strict;
use warnings;

# Note: this test depends on the env variable $SGN_TEST_MODE 
# being set to 1 in the server process

use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $form_url = '/contact/form';
my $mech = SGN::Test::WWW::Mechanize->new;

form_basic_ok( $mech, $form_url );
submit_form_ok( $mech, $form_url );

$mech->while_logged_in(
    { user_type => 'user' },
    sub {
        my $user = shift;
        form_basic_ok( $mech, $form_url );
        form_has_user_defaults( $mech, $user );
        submit_form_ok( $mech, $form_url );
    },
    );

done_testing;
exit;

# check contact form displays OK
sub form_basic_ok {
    my ( $mech, $form_url ) = @_;
    $mech->get_ok( $form_url );
    $mech->content_contains( $_ ) for (
      'Name',
      'Email',
      'Subject',
      'Body',
      'name="name"',
      'name="subject"',
      'name="body"',
      '<textarea',
      );
}
sub form_has_user_defaults {
    my ( $mech, $user ) = @_;
    $mech->form_name('contactForm');
    like $mech->value('name'), qr/$user->{first_name}/;
    like $mech->value('name'), qr/$user->{last_name}/;
}
sub submit_form_ok {
    my ( $mech, $form_url ) = @_;
    $mech->get_ok( $form_url );
    # submit a blank form and check for 'required' messages'
    my @fieldnames = qw( name email subject body );
    $mech->submit_form_ok({
        form_name => 'contactForm',
        fields => {
            map { $_ => ''}
            @fieldnames
            },
         },
    );
    $mech->content_like(qr/$_ is required/i) for @fieldnames;

    # submit a form with with stuff in it and check was OK
    $mech->submit_form_ok({
        form_name => 'contactForm',
        fields => {
            name    => 'Test Tester',
            email   => 'test@example.com',
            subject => 'Testing contact form',
            body     => 'this is a test of the SGN contact form',
	    contact_form_human_answer => $mech->context->get_conf("contact_form_human_answer"),
        },
    });
    $mech->content_like(qr/your message has been sent/i);
}
