
=head1 NAME

t/unit_mech/AJAX/BreedersToolbox/StoreBreedingProgram.t - storing a breeding program needs a role; Database stats keeps program names as data

=head1 DESCRIPTION

/breeders/program/store must refuse a user without the submitter or curator
role (and store nothing), and keep working for a submitter. The public
/breeders/dbstats page puts the program list into a script: an apostrophe or
"</script>" in a program name must stay part of the name.

=cut

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $server = 'http://localhost:3010';

sub browser {
    my $username = shift;
    my $password = $username && $username eq 'freddy' ? 'atgc' : 'secretpw'; # fixture passwords
    my $mech = Test::WWW::Mechanize->new(autocheck => 0);
    $mech->post("$server/ajax/user/login", { username => $username, password => $password });
    my $r = eval { decode_json($mech->content) } || {};
    is($r->{message} || '', 'Login successful', "$username signs in");
    return $mech;
}

sub program_id {
    my $name = shift;
    my $program = $schema->resultset('Project::Project')->find({ name => $name });
    return $program ? $program->project_id() : undef;
}

# a user without the submitter role
my $freddy = browser('freddy');
$freddy->post("$server/breeders/program/store", { name => 'store_program_plain_user', desc => 'x' });
my $r = eval { decode_json($freddy->content) } || {};
ok($r->{error}, 'a plain user gets an error') or diag explain $r;
ok(!program_id('store_program_plain_user'), 'a plain user stores no program');

my $existing = $schema->resultset('Project::Project')->find({ project_id => 134 }); # a fixture breeding program
my $existing_name = $existing ? $existing->name() : undef;
if ($existing) {
    $freddy->post("$server/breeders/program/store", { id => $existing->project_id(), name => 'store_program_renamed', desc => 'x' });
    is($schema->resultset('Project::Project')->find({ project_id => $existing->project_id() })->name(), $existing_name, 'a plain user cannot rename a program');
}

# a submitter still can; the name carries an apostrophe and a closing script tag
my $tricky_name = q{O'Neil </script><b id="dbstats_probe">x</b>};
my $johndoe = browser('johndoe');
$johndoe->post("$server/breeders/program/store", { name => $tricky_name, desc => 'x' });
$r = eval { decode_json($johndoe->content) } || {};
ok(!$r->{error}, 'a submitter stores a program') or diag explain $r;
my $tricky_id = program_id($tricky_name);
ok($tricky_id, 'the program exists');

my $visitor = Test::WWW::Mechanize->new(autocheck => 0);
$visitor->get("$server/breeders/dbstats");
is($visitor->status, 200, 'Database stats answers without a login');
my $page = $visitor->content;
unlike($page, qr{</script><b id="dbstats_probe">}, 'the name cannot close the script block');
unlike($page, qr{JSON\.parse\('}, 'the program list is not put inside a quoted string');
like($page, qr{O'Neil \\u003c/script\\u003e\\u003cb id=\\"dbstats_probe\\"\\u003ex\\u003c/b\\u003e}, 'the name is in the page as JSON data');

# clean up
browser('janedoe')->get("$server/breeders/program/delete/$tricky_id") if $tricky_id;

done_testing();
