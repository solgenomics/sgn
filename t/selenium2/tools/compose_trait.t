
use strict;
use lib 't/lib';
use Test::More 'tests' => 21;
use SGN::Test::Fixture;
use SGN::Test::WWW::WebDriver;
use Try::Tiny;
use Selenium::Waiter;

use Data::Dumper;

# Set up the web driver
my $w = SGN::Test::WWW::WebDriver->new();
my $d = $w->driver;

# Retry failing commands every 1 sec for a total of 10 seconds
$d->set_timeout('implicit', 1000);
$d->set_timeout('pageLoad', 10000);

# Lightweight wrapper around Selenium::Waiter::wait_until sets the timeout and
# interval parameters from the driver configuration
sub wait_for {
    my $assert = shift;
    my $timeout  = $d->get_timeouts()->{pageLoad} / 1000 || 30;
    my $interval = $d->get_timeouts()->{implicit} / 1000 || 1;
    return wait_until { $assert->() } timeout => $timeout, interval => $interval;
}

# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

$w->while_logged_in_as("curator", sub {

    # Load the compose trait page
    ok( wait_for sub { $d->navigate('/tools/compose_trait/') }, 'open compose trait page');

    # select components
    ok( wait_for sub { $d->find_element("//option[\@title='alanine|CHEBI:16449']")->click() }, 'select attribute');
    ok( wait_for sub { $d->find_element("//option[\@title='apical branching|CO_334:0000086']")->click() }, 'select trait');
    ok( wait_for sub { $d->find_element("//option[\@title='month 6|TIME:0000065']")->click() }, 'select month');
    ok( wait_for sub { $d->find_element("//option[\@title='year 11|TIME:0000492']")->click() }, 'select year');
    my $trait_name = "apical branching|alanine|month 6|year 11"; 

    # select final trait
    ok( wait_for sub { $d->find_element("//option[\@title='$trait_name']")->click() }, 'select composed trait');  

    # submit
    ok( wait_for sub { $d->find_element_by_id('compose_trait')->click() }, 'click submit button');
    ok( wait_for sub { $d->find_element_by_id('traits_saved_message') }, 'find traits saved message');
    ok( wait_for sub { $d->find_element_by_id('traits_saved_close_button')->click() }, 'click dialog close button');

    # search for new trait
    ok( wait_for sub { $d->navigate('/search/traits') }, 'open search traits page');
    ok( wait_for sub { $d->find_element_by_id('trait_search_name')->send_keys($trait_name) },'search enter trait name');
    ok( wait_for sub { $d->find_element_by_id('submit_trait_search')->click() }, 'submit trait search');
    ok( wait_for sub { $d->find_element_by_link_text($trait_name)->click() }, 'open trait page');

    # open COMP ontology tree
    ok( wait_for sub { $d->find_element_by_link_text('COMP:1') }, 'local COMP tree');
    ok( wait_for sub { $d->find_element_by_id("open_cvterm_77547")->click() }, 'open COMP tree');

    # open trait tree
    my $current_url;
    ok( wait_for sub { $current_url = $d->get_current_url(), 'get current url' });
    my @url_array = split(/\//,  $current_url);
    my $cvterm_id = $url_array[-2];
    ok( wait_for sub { $d->find_element_by_id("open_cvterm_$cvterm_id")->click() }, 'open trait tree');

    # locate all expected components
    ok( wait_for sub { $d->find_element_by_link_text("CHEBI:16449") }, 'locate attribute component');
    ok( wait_for sub { $d->find_element_by_link_text("CO_334:0000086") }, 'locate trait component');
    ok( wait_for sub { $d->find_element_by_link_text("TIME:0000065") }, 'locate month component');
    ok( wait_for sub { $d->find_element_by_link_text("TIME:0000492") }, 'locate year component');

});

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

# Cleanup tests and driver
$d->quit();
done_testing();