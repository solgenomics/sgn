#!/usr/bin/perl

use strict;
use warnings;

my $schema = $c->dbic_schema('Bio::Chado::Schema');
$c->forward_to_mason_view('/tomato_gen_pub/tomato_gen_pub.mas', schema => $schema);

1;
