
=head1 NAME

t/unit/CXGN/Tools/ShellQuote.t - shell_quote() keeps every value one literal argument in bash

=cut

use strict;
use warnings;
use Test::More;
use CXGN::Tools::ShellQuote qw(shell_quote);

my @values = ('plain', 'two words', "it's", q{'}, q{''}, '$(echo injected)', '`echo injected`', 'x;echo injected', 'a&b|c', "line\nbreak", 'trait|CO_334:0000049', '');

for my $value (@values) {
    my $command = 'printf %s ' . shell_quote($value);
    open(my $bash, '-|', 'bash', '-c', $command) or die "Cannot run bash: $!";
    my $output = do { local $/; <$bash> };
    close($bash);
    is($output, $value, 'bash gets the literal value ' . shell_quote($value));
}

is(shell_quote(undef), q{''}, 'undef becomes an empty argument');
is_deeply([ shell_quote('a', 'b c') ], [ q{'a'}, q{'b c'} ], 'list context returns one quoted value per argument');
is(scalar(shell_quote('a', 'b c')), q{'a' 'b c'}, 'scalar context joins them with spaces');

done_testing();
