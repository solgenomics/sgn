use Test::Most tests => 5;
use Path::Class;

use lib 't/lib';
use aliased 'SGN::Test::WWW::Mechanize';
my $mech = Mechanize->new;

$mech->with_test_level( local => sub {
    my $c = $mech->context;

    my $message_file = $c->config->{system_message_file}
        or die "must have a system_message_file conf var defined";

  SKIP: {
        skip "system message file $message_file already exists, not overwriting for test", 5
            if -f $message_file;

        $mech->get_ok('/');
        $mech->content_lacks('system message active', 'no system message if no message file');

        file($message_file)->openw->write('Testing site-wide message system');

        $mech->get_ok('/');
        $mech->content_contains('system message active', 'system message file, now have system message');
        $mech->content_contains('Testing site-wide message system', 'got actual message');

        unlink $message_file;
    }

}, 5);

