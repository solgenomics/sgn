
=head1 NAME

SGN::Test::WWW::WebDriver - a wrapper around the Selenium::Remote::Driver tailored to the SGN codebase

=head1 SYNOPSYS

Your test script should look somewhat like this:

use strict;
use SGN::Test::WWW::WebDriver;

my $swd = SGN::Test::WWW::WebDriver->new();

$swd->get_ok('/my_favorite_url');
$swd->find_element_ok('frufrubutton', 'id');
# etc...

=head1 DESCRIPTION

This class does not inherit from Selenium::Remote::Driver, because that class is not implemented in Moose. Instead, this class has_a Selenium::Remote::Driver, which is accessible with the driver() accessor.

There are a number of convenience methods:

Perform logins using different account statuses:

* login_as($user_type) # curator, submitter, user

* logout() 

* while_logged_in_as($user_type, sub { ... })


Note that these function require the use of the cxgn_fixture database. The database fixture is loaded from a dump each time the tests are run when using the t/test_fixture.pl script.

Convenience accessors for driver functions:

* get() - same as the driver get, except that the host part of the url is added from the conf

* get_ok() - the get() wrapped around and ok

* find_element() - forwards to the driver find_element() function

* find_element_ok() - wraps the find_element in an ok() test.

For all other driver functions, use the driver() accessor, for example: $swd->driver->get_window_size().

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

 

package SGN::Test::WWW::WebDriver;

use Moose;

use Try::Tiny;
use Test::More;
use File::Spec::Functions;
use Selenium::Remote::Driver;
use Selenium::Waiter qw(wait_until);
use Time::HiRes qw(time);

has 'host' => ( is => 'rw',
	      isa => 'Str',
		default => sub { $ENV{SGN_TEST_SERVER} },
    );

# Configurable implicit wait
has 'implicit_wait' => ( is => 'rw', default => 90 * 1000 );

has 'driver' => ( is => 'rw',
          isa => 'Selenium::Remote::Driver',
          lazy => 1,
          builder => '_build_driver',
          trigger => sub {
              my ($self, $driver) = @_;
              $self->_configure_driver_timeouts($driver);
          },
    );

sub _build_driver {
    my $self = shift;
    my $driver = Selenium::Remote::Driver->new(
        'base_url' => $ENV{SGN_TEST_SERVER},
        'remote_server_addr' => $ENV{SGN_REMOTE_SERVER_ADDR} || 'localhost'
    );
    $self->_configure_driver_timeouts($driver);
    return $driver;
}

sub _configure_driver_timeouts {
    my ($self, $driver) = @_;
    $driver->set_timeout('implicit', $self->implicit_wait);
    $driver->set_timeout('page load', $self->implicit_wait);
}

has 'user_data' => ( is => 'rw',
		     isa => 'Ref',
		     default => sub { 
			 { 
			     curator   => { username => 'janedoe',
					    password => 'secretpw',
			     },
			     user      => { username => 'freddy',
					    password => 'atgc',
			     },
			     submitter => { username => 'johndoe',
					    password => 'secretpw',
			     },
			 }
		     });

sub login_as { 
    my $self = shift;
    my $role = shift;
    $self->login( $self->user_data()->{$role}->{username},
		  $self->user_data()->{$role}->{password},
	);
}

sub login { 
    my $self = shift;
    my $username = shift;
    my $password = shift;
    
    $self->get("/user/login");
    sleep(2);

    $self->send_keys("username", "id", $username);
    $self->send_keys("password", "name", $password);
    $self->click("submit_password", "id");

    sleep(2); # Determined empirically, prevents an "error has occurred" alert
}

sub logout { 
    my $self = shift;
    return $self->get("/user/logout");
}

sub logout_ok { 
    my $self = shift;
    my $test_name = shift || "logout test";
    ok($self->logout(), $test_name);
}

sub while_logged_in_as {
    my ($self, $user_type, $sub) = @_;

    $self->login_as($user_type);
    try {
            $sub->( );
    } catch {
	die $_;
    } finally {
	$self->logout;
    };
}


sub base_url { 
    my $self = shift;
    return $self->host();
}

sub click {
    my $self = shift;
    my $name = shift;
    my $method = shift;

    my $timeout = $self->driver->get_timeouts()->{"implicit"} / 1000; # in seconds
    return wait_until {
        $self->screenshot("click_$name");
        $self->driver->find_element($name, $method)->click();
    } timeout => $timeout;
}

sub click_ok {
    my $self = shift;
    my $name = shift;
    my $method = shift;
    my $test_name = shift || print STDERR "You can provide a test name parameter for click_ok\n";
    ok(my $element = $self->click($name, $method), $test_name);
    return $element;
}

=item click_until_ok($self, $name_btn, $method_btn, $name_sentinel, $method_sentinel, $test_name)
Keeps clicking the button defined by $name_btn and $method_btn every second
until the sentinel element defined by $name_sentinel and $method_sentinel appears.
=cut
sub click_until_ok {
    my ($self, $name_btn, $method_btn, $name_sentinel, $method_sentinel, $test_name) = @_;
    $test_name ||= "Click button $name_btn until sentinel $name_sentinel appears";

    my $timeout = $self->driver->get_timeouts()->{"implicit"} / 1000; # in seconds
    my $sentinel;

    my $success = try {
        wait_until {
            my $found = 0;
            try {
                $sentinel = $self->driver->find_element($name_sentinel, $method_sentinel);
                if ($sentinel && $sentinel->is_displayed()) {
                    $found = 1;
                }
            } catch {
                # Sentinel not found
            };

            if ($found) {
                print STDERR "click_until_ok: Sentinel found and displayed! ($name_sentinel, $method_sentinel)\n";
                return 1;
            }

            print STDERR "click_until_ok: Sentinel not found or not displayed yet. Attempting click on $name_btn ($method_btn)\n";

            try {
                $self->screenshot("click_until_ok_attempt");
                $self->driver->find_element($name_btn, $method_btn)->click();
            } catch {
                print STDERR "click_until_ok: Failed to click $name_btn: $_\n";
            };

            return 0;
        } timeout => $timeout, interval => 1;
    } catch {
        print STDERR "click_until_ok: timed out or error: $_";
        return 0;
    };

    ok($success, $test_name);
    return $sentinel;
}

sub get { 
    my $self = shift;
    my $url = shift;
    my $timeout = $self->driver->get_timeouts()->{"implicit"} / 1000; # in seconds
    my $ok = wait_until {
        $self->driver->get($url);
    } timeout => $timeout;
    $self->wait_for_network_idle();
    return $ok;
}

sub get_ok { 
    my $self = shift;
    my $url = shift;
    my $test_name = shift || "get $url test";
    ok($self->get($url), $test_name);
}
    
sub find_element { 
    my $self = shift;
    my $name = shift;
    my $method = shift;

    my $timeout = $self->driver->get_timeouts()->{"implicit"} / 1000; # in seconds
    return wait_until {
        $self->screenshot("find_element_$name");
        $self->driver->find_element($name, $method);
    } timeout => $timeout;
}

sub find_element_ok { 
    my $self = shift;
    my $name = shift;
    my $method = shift;
    my $test_name = shift || print STDERR "You can provide a test name parameter for find_element_ok\n";
    ok(my $element = $self->find_element($name, $method), $test_name);
    return $element;
}

sub get_attribute {
    my $self = shift;
    my $name = shift;
    my $method = shift;
    my $attribute = shift;

    my $timeout = $self->driver->get_timeouts()->{"implicit"} / 1000; # in seconds
    return wait_until {
        $self->screenshot("get_attribute_$attribute");
        $self->driver->find_element($name, $method)->get_attribute($attribute);
    } timeout => $timeout;
}

sub get_attribute_ok {
    my $self = shift;
    my $name = shift;
    my $method = shift;
    my $attribute = shift;
    my $test_name = shift || print STDERR "You can provide a test name parameter for get_attribute_ok\n";
    ok( my $element = $self->get_attribute($name, $method, $attribute), $test_name);
    return $element;
}

sub get_text {
    my $self = shift;
    my $name = shift;
    my $method = shift;
    my $timeout = $self->driver->get_timeouts()->{"implicit"} / 1000; # in seconds
    return wait_until {
        $self->driver->find_element($name, $method)->get_text();
    } timeout => $timeout;
}

sub get_text_ok {
    my $self = shift;
    my $name = shift;
    my $method = shift;
    my $test_name = shift || print STDERR "You can provide a test name parameter for get_text_ok\n";
    ok( my $element = $self->get_text($name, $method), $test_name);
    return $element;
}

sub send_keys {
    my $self = shift;
    my $name = shift;
    my $method = shift;
    my $input = shift;

    my $timeout = $self->driver->get_timeouts()->{"implicit"} / 1000; # in seconds
    return wait_until {
        $self->screenshot("send_keys_$name");
        $self->driver->find_element($name, $method)->send_keys(_maybe_unwrap($input));
    } timeout => $timeout;
}

sub send_keys_ok {
    my $self = shift;
    my $name = shift;
    my $method = shift;
    my $input = shift;
    my $test_name = shift || print STDERR "You can provide a test name parameter for send_keys_ok\n";
    ok( my $element = $self->send_keys($name, $method, $input), $test_name);
    return $element;
}

sub accept_alert {
    my $self = shift;

    my $timeout = $self->driver->get_timeouts()->{"implicit"} / 1000; # in seconds
    return wait_until {
        $self->screenshot("accept_alert");
        $self->driver->accept_alert();
    } timeout => $timeout;
}

sub accept_alert_ok { 
    my $self = shift;
    my $test_name = shift;
    ok($self->accept_alert(), $test_name);
}

sub get_alert_text {
    my $self = shift;
    my $timeout = $self->driver->get_timeouts()->{"implicit"} / 1000; # in seconds
    return wait_until {
        return $self->driver->get_alert_text();
    } timeout => $timeout;
}

sub download_linked_file {
    my $self = shift;
    my $link_id = shift;

    my $href = $self->get_attribute($link_id, "id", "href");
    my $cookies = $self->driver()->get_all_cookies();
    
    my $token = "";
    foreach my $cookie (@$cookies) { 
	if ($cookie->{name} eq "sgn_session_id") { 
	    $token = $cookie->{value};
	}
    }

    system("wget --header \"Cookie: sgn_session_id=$token\" --directory-prefix=/tmp $href");


}

=item set_value_ok($self, $name, $method, $test_name, $value)
Uses JavaScript to set the value of an input element more reliably
than sending keys.
=cut
sub set_value_ok {
    my ($self, $name, $method, $test_name, $value) = @_;

    my $element = $self->find_element_ok($name, $method, $test_name);
    $self->driver->execute_script("arguments[0].value = arguments[1];", $element, $value);
    $self->driver->execute_script("arguments[0].dispatchEvent(new Event('change'));", $element);

    return $element;
}


=item wait_for_working_dialog($self, $max, $id)
Waits for a working dialog to disappear.  The default id is "working_modal".
=cut
sub wait_for_working_dialog {
    my $self = shift;
    my $max = shift || 300;
    my $id = shift || "working_modal";

    $self->screenshot("wait_for_working_dialog_${id}_start");

    sleep(3);

    $self->screenshot("wait_for_working_dialog_${id}_check");

    my $is_hidden = 0;
    my $count = 0;
    print STDERR "... waiting for working dialog ...\n";
    while ( !$is_hidden && $count < $max ) {
        my $wd = $self->find_element($id, "id");
        $is_hidden = $wd->is_hidden();
        $count++;
        sleep(1);
    }

    $self->screenshot("wait_for_working_dialog_${id}_end");
    print STDERR "... working dialog dismissed ...\n";
}

=item wait_for_spinner($self, $name, $method)
Waits for an element to appear and disappear.
=cut
sub wait_for_spinner {
    my $self = shift;
    my ($name, $method) = @_;

    wait_until {
        print STDERR "Waiting for spinner to appear...\n";
        $self->driver->find_element($name, $method)->is_displayed();
    } and wait_until {
        print STDERR "Waiting for spinner to disappear...\n";
        $self->driver->find_element($name, $method)->is_hidden();
    };
}

=item wait_for_alert_dismissed($self)
Waits for an alert to disappear.
=cut
sub wait_for_alert_dismissed {
    my $self = shift;
    wait_until {
        my $alert_text;

        try {
            $self->screenshot("wait_for_alert_dismissed");
            $alert_text = $self->driver->get_alert_text();
        } catch {
            $alert_text = undef;
        };

        return !defined $alert_text;
    }
}

sub wait_for_network_idle {
    my $self = shift;

    my $timeout = $self->driver->get_timeouts()->{"implicit"} / 1000; # in seconds

    my $last_active_requests = -1;
    my $unchanged_count = 0;
    for (1 .. $timeout) {
        $self->screenshot("wait_for_network_idle");

        my $active_requests = $self->driver->execute_script(
            "return (window.jQuery != null) ? jQuery.active : 0"
        );
        print STDERR "wait_for_network_idle -> Active requests: $active_requests\n";

        if ($active_requests == $last_active_requests) {
            $unchanged_count++;
        } else {
            $unchanged_count = 0;
            $last_active_requests = $active_requests;
        }

        # Cancelled requests can cause active requests to remain non-zero so
        # instead we check for 3 seconds of no change
        if ($unchanged_count >= 3) {
            print STDERR "wait_for_network_idle -> Active requests has been unchanged for $unchanged_count seconds, assuming network is now idle\n";
            return 1;
        }

        # Faster path if active requests are zero for 1 second, network is idle
        if ($active_requests == 0 && $unchanged_count == 1) {
            print STDERR "wait_for_network_idle -> Network is now idle after $unchanged_count seconds of no active requests\n";
            return 1;
        }

        sleep(1);
    }
    die "Network traffic did not stop in time";
}

sub screenshot {
    my $self = shift;
    my $action = shift;

    # Replace non-alphanumeric characters with underscores
    $action =~ s/[^a-zA-Z0-9]+/_/g;
    $action =~ s/^_|_$//g;

    my $dir = '/screenshots';
    mkdir $dir unless -d $dir;

    my $timestamp = time() * 100000;
    my $filename = "${timestamp}_${action}";

    try {
        # Screenshots cannot be taken if an alert is present
        my $alert_text = $self->driver->get_alert_text();

        open my $fh, '>', "$dir/$filename.txt" or die "Could not open file '$dir/$filename.txt' $!";
        print $fh $alert_text;
        close $fh;
    } catch {
        # Otherwise, capture screenshot
        $self->driver->capture_screenshot("$dir/$filename.png", { 'full' => 1 });
    }
}

sub _maybe_unwrap {
    my $param = shift;
    if (ref($param) eq 'ARRAY') {
        return @$param;
    }
    return $param;
}

1;
   
    
