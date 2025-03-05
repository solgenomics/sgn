
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;

use_ok('CXGN::Stock');

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

print STDERR "Create new stock... ";
my $new_s = CXGN::Stock->new(schema => $schema);
$new_s->uniquename("aniceuniquename");
$new_s->name("anicename");
$new_s->type("accession");
$new_s->description("blablabla");
my $new_s_id = $new_s->store();

my $copy_s = CXGN::Stock->new(schema => $schema, stock_id => $new_s_id);
is($copy_s->name(), $new_s->name(), "name save check");
is($copy_s->uniquename(), $new_s->uniquename(), "uniquename save check");
is($copy_s->type(), $new_s->type(), "type save check");
is($copy_s->type_id(), $new_s->type_id(), "type_id save check");
is($copy_s->description(), $new_s->description(), "description save check");
is($copy_s->is_obsolete(), $new_s->is_obsolete(), "obsolete save check");
is($copy_s->organism_id(), $new_s->organism_id(), "organism_id save check");
is($copy_s->stock_id(), $new_s->stock_id(), "stock_id save check");

$new_s->name("new_name");
$new_s->uniquename("new_uniquename");
$new_s->type("plot");
$new_s->description("blablabla 2");
$new_s->is_obsolete(1);
$new_s->store();

my $update_s = CXGN::Stock->new(schema => $schema, stock_id => $new_s_id);
is($update_s->name(), "new_name", "update name check");
is($update_s->uniquename(), "new_uniquename", "update uniquename check");
is($update_s->description(), "blablabla 2", "update description check");
is($update_s->is_obsolete(), 1, "update obsolete check");

my $s = CXGN::Stock->new( schema => $schema, stock_id => 38846 );

print STDERR "OBJECTS: ".Dumper($s->objects());
print STDERR "SUJECTS: ".Dumper($s->subjects());

is($s->name(), "new_test_crossP001", "name check");
is($s->uniquename(), "new_test_crossP001", "uniquename check");
is($s->type_id(), 76392, 'type_id check');
is($s->description(), "", "description check");
is($s->is_obsolete(), 0, "obsolete check");
is($s->get_species(), "Solanum lycopersicum", "species check");
my @image_ids = $s->get_image_ids();
is_deeply(\@image_ids, [], "image ids check");
print STDERR Dumper(\@image_ids);
my @trait_list = $s->get_trait_list();
is_deeply(\@trait_list, [], "trait list check");
print STDERR Dumper(\@trait_list);
my @trial_list = $s->get_trials();
is_deeply(\@trial_list, [], "trials check");
print STDERR Dumper(\@trial_list);
my $pedigree = $s->get_parents(1);

# test a stock with trial data
my $t_s = CXGN::Stock->new(schema => $schema, stock_id => 38880);
@trial_list = $t_s->get_trials();
print STDERR Dumper(\@trial_list);
is_deeply(\@trial_list,
[
    [
        139,
        'Kasese solgs trial',
        '23',
        'test_location'
    ],
    [
        141,
        'trial2 NaCRRI',
        '23',
        'test_location'
    ],
    [
        144,
        'test_t',
        '23',
        'test_location'
    ]
], "trial list check");

$f->clean_up_db();

done_testing();
