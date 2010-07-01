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


cmp_ok ( $f->as_table_string(), '=~' , qr!<table>.*test1 contents!, "as_table_string");
