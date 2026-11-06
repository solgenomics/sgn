use strict;
use warnings;
use utf8;
use Test::More;
use JSON;
use SGN::Controller::AJAX::FieldBook;

my $values=['Висота, "А"','0'];
my $characters=JSON->new->encode($values);
my $bytes=JSON->new->utf8->encode($values);
my $escaped=JSON->new->ascii->encode($values);
for my $json ($characters,$bytes,$escaped) {
    my $parsed=eval{SGN::Controller::AJAX::FieldBook::_parse_list_from_json($json)};
    is_deeply($parsed,$values,'trait lists accept decoded Unicode, UTF-8 bytes and ASCII JSON escapes') or diag($@);
}
for my $json ('{}','null','"one trait"','[[1]]','[null]','not JSON') {
    my $ran=eval{SGN::Controller::AJAX::FieldBook::_parse_list_from_json($json);1};
    ok(!$ran,'invalid list shape or JSON cannot become trait rows');
}
done_testing;
