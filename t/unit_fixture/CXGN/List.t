
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::List;

my $t = SGN::Test::Fixture->new();


my $lists = CXGN::List::available_lists($t->dbh(), 41);
is_deeply($lists, [
	  [
            '3',
            'test_stocks',
            undef,
            '5',
            '76451',
            'accessions'
          ]
        ]
, "check available lists initially");

my $list_id = CXGN::List::create_list($t->dbh(), 'test_list2', 'test_desc', 41);

print STDERR "CREATED LIST WITH ID $list_id\n";

my $list = CXGN::List->new( { dbh => $t->dbh(), list_id => $list_id } );

my $name = $list->name();
is($name, "test_list2", "get list name");

$list->name("new_test_name");
is($list->name(), "new_test_name");

$list->description("new description");
is($list->description(), "new description", "description change");

$list->type("accessions");
is($list->type(), 'accessions', "list type test");

# check if name is actually stored
my $list2 = CXGN::List->new( { dbh => $t->dbh(), list_id => $list_id });
is($list2->name(), "new_test_name", "list name store test");
is($list2->description(), "new description", "description store change");
is($list2->type(), "accessions", "list type store");
is($list2->type_id(), 76451, "list type_id");
is($list2->owner(), 41, "list owner");
my $error = $list->add_element("bla");
ok(!$error, "adding an element to the list");

$error = $list->add_element("blabla");
ok(!$error, "adding another element");

$error = $list->add_element("blabla");
ok($error, "adding a duplicate element to the list");

is($list->list_size(), 2, "list size check 1");

ok($list->exists_element("blabla"), 'exists element check');

my $elements = $list->elements();
is_deeply($elements, [ 'bla', 'blabla' ], "retrieve list elements after add");

$error = $list->remove_element('blabla');
ok(!$error, "delete element from list");

$elements = $list->elements();
is_deeply($elements, [ 'bla' ], "retrieve list elements after delete");

is($list->list_size(), 1, "list size check after delete");
ok(!$list->exists_element("blabla"), 'exists element after delete');

my $lists = CXGN::List::available_lists($t->dbh(), 41);

is_deeply($lists, [
          [
            '5',
            'new_test_name',
            'new description',
            '1',
            '76451',
            'accessions',
          ],
          [
            '3',
            'test_stocks',
            undef,
            '5',
            '76451',
            'accessions'
          ]
        ], "check available lists after additions");



$error = CXGN::List::delete_list($t->dbh(), 5);

my $lists = CXGN::List::available_lists($t->dbh(), 41);

is_deeply($lists, [
          [
            '3',
            'test_stocks',
            undef,
            '5',
            '76451',
            'accessions'
          ]
        ], "check available lists after deletion");



done_testing();
