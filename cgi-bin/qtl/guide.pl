#!/usr/bin/perl -w


use strict;
use warnings;

use CatalystX::GlobalContext qw( $c );

$c->res->redirect('/qtl/submission/guide');
$c->detach();

