use strict;
use warnings;

use Test::More tests => 1;
use CXGN::Page::Form::Static;

my $f = CXGN::Page::Form::Static->new();

$f->add_field(
    screen_name => 'test1',
    field_name  => 'test1',
    contents    => 'test1 contents',
    length      => 10,
);

#print STDERR $f->as_table_string();
cmp_ok($f->as_table_string(), '=~', '<br/><div class="panel panel-default"><table class="table table-hover"> <tr><td></td><td><b>test1 contents', "test as_table_string");
