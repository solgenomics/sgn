
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::List;

my $t = SGN::Test::Fixture->new();


my $lists = CXGN::List::available_lists($t->dbh(), 41);

my @lists_sorted = sort { $a->[0] <=> $b->[0] } @$lists;

print STDERR Dumper \@lists_sorted;
 is_deeply(\@lists_sorted,  [
	       [
            '3',
            'test_stocks',
            undef,
            '5',
            '76451',
            'accessions',
	    '0'
          ], 
          [
            '5',
            'accessions_for_solgs_tests',
            undef,
            '374',
            '76451',
            'accessions',
	    '0'
          ],
          [
            '6',
            'accessions_for_trial2',
            undef,
            '307',
            '76451',
            'accessions',
	    '0'
          ],
          [
            '7',
            'selection_acc',
            undef,
            '20',
            undef,
            undef,
	    '0'
          ],
          [
            12,
            'desynonymize_test_list',
            undef,
            6,
            76451,
            'accessions',
            0
          ],
	  [
            '809',
            'janedoe_1_public',
            undef,
            '2',
            undef,
            undef,
	    '1'
          ],
	  [
            '811',
            'janedoe_1_private',
            undef,
            '2',
            undef,
            undef,
	    '0'
          ],
	   ], "check available lists initially");

my $list_id = CXGN::List::create_list($t->dbh(), 'test_list2', 'test_desc', 41);

#print STDERR "CREATED LIST WITH ID $list_id\n";

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

#print STDERR Dumper($lists);
@lists_sorted = sort { $a->[0] <=> $b->[0] } @$lists;
print STDERR Dumper \@lists_sorted;
is_deeply(\@lists_sorted, [
          [
            3,
            'test_stocks',
            undef,
            5,
            76451,
            'accessions',
            0
          ],
          [
            5,
            'accessions_for_solgs_tests',
            undef,
            374,
            76451,
            'accessions',
            0
          ],
          [
            6,
            'accessions_for_trial2',
            undef,
            307,
            76451,
            'accessions',
            0
          ],
          [
            7,
            'selection_acc',
            undef,
            20,
            undef,
            undef,
            0
          ],
          [
            12,
            'desynonymize_test_list',
            undef,
            6,
            76451,
            'accessions',
            0
          ],
          [
            13,
            'new_test_name',
            'new description',
            1,
            76451,
            'accessions',
            0
          ],
          [
            809,
            'janedoe_1_public',
            undef,
            2,
            undef,
            undef,
            1
          ],
          [
            811,
            'janedoe_1_private',
            undef,
            2,
            undef,
            undef,
            0
          ]
        ],
        "check available lists after additions");



$error = CXGN::List::delete_list($t->dbh(), 5);

my $lists = CXGN::List::available_lists($t->dbh(), 41);

#print STDERR Dumper($lists);

@lists_sorted = sort { $a->[0] <=> $b->[0] } @$lists;
print STDERR Dumper \@lists_sorted;

is_deeply(\@lists_sorted, [
          [
            3,
            'test_stocks',
            undef,
            5,
            76451,
            'accessions',
            0
          ],
          [
            6,
            'accessions_for_trial2',
            undef,
            307,
            76451,
            'accessions',
            0
          ],
          [
            7,
            'selection_acc',
            undef,
            20,
            undef,
            undef,
            0
          ],
          [
            12,
            'desynonymize_test_list',
            undef,
            6,
            76451,
            'accessions',
            0
          ],
          [
            13,
            'new_test_name',
            'new description',
            1,
            76451,
            'accessions',
            0
          ],
          [
            809,
            'janedoe_1_public',
            undef,
            2,
            undef,
            undef,
            1
          ],
          [
            811,
            'janedoe_1_private',
            undef,
            2,
            undef,
            undef,
            0
          ]
        ]
	  , "check available lists after deletion");



my $list = CXGN::List->new( { dbh => $t->dbh(), list_id => $list_id });
my $items = $list->retrieve_elements_with_ids($list_id);
$error = $list->update_element_by_id($items->[0]->[0], 'updated name');
ok(!$error, 'test update item');
$items = $list->retrieve_elements_with_ids($list_id);
#print STDERR Dumper $items;
is_deeply($items, [
          [
            725,
            'updated name'
          ]
        ], 'check updated list item');

my $space1 = $list->add_element(" bla1");
ok($list->exists_element("bla1"), 'remove leading space element check');
ok(!$list->exists_element(" bla1"), 'leading space removed from element');


my $space2 = $list->add_element("bla2 ");
ok($list->exists_element("bla2"), 'remove trailing space element check');
ok(!$list->exists_element("bla2 "), 'trailing space removed from element');

my $space3 = $list->add_element(" bla3 ");
ok($list->exists_element("bla3"), 'remove trailing and leading spaces element check');
ok(!$list->exists_element(" bla3 "), 'trailing and leading spaces removed from element');

my $space4 = $list->add_element("    ");
ok($space4 eq "Empty list elements are not allowed", 'element with only spaces cannot be added'); 


done_testing();
