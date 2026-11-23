
# Tests for CXGN::Report::Catalog: report scripts and the inputs detected from their source

use strict;
use warnings;
use Test::More;
use File::Temp qw | tempdir |;
use File::Path qw | make_path |;
use File::Slurp qw | write_file |;

use CXGN::Report::Catalog;

my $base = tempdir(CLEANUP => 1);
make_path("$base/bin/Reports");

# legacy report: dates only
write_file("$base/bin/Reports/legacy_dates.pl", <<'PERL');
#!/usr/bin/env perl
use Getopt::Std;
our %opt;
getopts('H:D:U:P:o:f:s:e:', \%opt);
PERL

# trials, accessions and traits as lists, dates too; POD gives title and description
write_file("$base/bin/Reports/all_inputs.pl", <<'PERL');
#!/usr/bin/env perl

=head1 NAME

all_inputs.pl - Everything at once

=head1 DESCRIPTION

Uses every input B<there> is.

Second paragraph.

=cut

use Getopt::Std;
our %opt;
getopts('H:D:U:P:o:f:s:e:t:a:T:', \%opt);
PERL

# only accession list; a flag without value (-t) and options named in the POD do not count
write_file("$base/bin/Reports/accessions_only.pl", <<'PERL');
#!/usr/bin/env perl

=head1 SYNOPSIS

  accessions_only.pl -t trials.txt   (not really: documented but not read)

=cut

use Getopt::Std;
our %opt;
# getopts('t:T:') in a comment does not count
getopts('H:D:U:P:o:f:a:th', \%opt);
PERL

# dates and accession list, no trial list (like accession_progeny_count)
write_file("$base/bin/Reports/dates_accessions.pl", <<'PERL');
#!/usr/bin/env perl
use Getopt::Std;
my %opt;
getopts('H:p:D:U:P:o:f:s:e:a:h', \%opt) or die "usage\n";
PERL

# Getopt::Long names
write_file("$base/bin/Reports/long_names.pl", <<'PERL');
#!/usr/bin/env perl
use Getopt::Long;
my ($trials, $traits, $other);
GetOptions(
    'H=s' => \my $host,
    'trial_list|trials=s' => \$trials,
    "traits=s" => \$traits,
    'other=s' => \$other,
) or die "usage\n";
PERL

# no input at all
write_file("$base/bin/Reports/whole_db.pl", <<'PERL');
#!/usr/bin/env perl
use Getopt::Std;
our %opt;
getopts('H:D:U:P:o:f:', \%opt);
PERL

my $catalog = CXGN::Report::Catalog->new({
    basepath => $base,
    report_engine => ' legacy_dates; all_inputs;accessions_only ; long_names; whole_db; not_installed; ../bad; legacy_dates; dates_accessions',
});

is_deeply([ $catalog->configured_names() ], [qw(legacy_dates all_inputs accessions_only long_names whole_db not_installed dates_accessions)], 'configured names: trimmed, unique, invalid names dropped');
is(scalar(@{ $catalog->reports() }), 7, 'seven reports');

sub used { my $r = shift; return join(',', grep { $r->{inputs}->{$_} } qw(dates trials accessions traits)); }

my $legacy = $catalog->report('legacy_dates');
is(used($legacy), 'dates', 'legacy report takes dates only');
is($legacy->{title}, 'Legacy dates', 'title from the script name without POD');
ok($legacy->{installed}, 'installed');

my $all = $catalog->report('all_inputs');
is(used($all), 'dates,trials,accessions,traits', 'all inputs detected');
is($all->{title}, 'Everything at once', 'title from POD NAME');
is($all->{description}, 'Uses every input there is.', 'description: first paragraph of DESCRIPTION, POD markup removed');

is(used($catalog->report('accessions_only')), 'accessions', 'flags without value, comments and POD do not count');
is(used($catalog->report('long_names')), 'trials,traits', 'Getopt::Long names and aliases');
is(used($catalog->report('whole_db')), '', 'no inputs');

my $missing = $catalog->report('not_installed');
ok(!$missing->{installed}, 'script not on disk is not installed');
is($catalog->report('../bad'), undef, 'invalid name gives no report');

# rules
is_deeply([ $catalog->validate_inputs('legacy_dates', { dates => 1 }) ], [], 'legacy with dates ok');
like(join('', $catalog->validate_inputs('legacy_dates', { trials => 1 })), qr/needs a date range/, 'legacy needs dates');
is_deeply([ $catalog->validate_inputs('all_inputs', { trials => 1 }) ], [], 'trial list is enough');
is_deeply([ $catalog->validate_inputs('all_inputs', { dates => 1, accessions => 1 }) ], [], 'dates with a filter ok');
like(join('', $catalog->validate_inputs('all_inputs', { accessions => 1, traits => 1 })), qr/needs a date range or a trial list/, 'filters alone are not enough when dates or trials are taken');
like(join('', $catalog->validate_inputs('accessions_only', {})), qr/needs an accession list/, 'list-only report needs its list');
is_deeply([ $catalog->validate_inputs('accessions_only', { accessions => 1 }) ], [], 'list-only report with its list ok');
like(join('', $catalog->validate_inputs('long_names', { traits => 1 })), qr/needs a trial list/, 'trials taken: traits alone not enough');
is_deeply([ $catalog->validate_inputs('whole_db', {}) ], [], 'report without inputs needs nothing');
is(used($catalog->report('dates_accessions')), 'dates,accessions', 'dates and accession list detected');
is_deeply([ $catalog->validate_inputs('dates_accessions', { accessions => 1 }) ], [], 'no trial list taken: the accession list is enough');
is_deeply([ $catalog->validate_inputs('dates_accessions', { dates => 1 }) ], [], 'no trial list taken: the dates are enough');
like(join('', $catalog->validate_inputs('dates_accessions', {})), qr/needs a date range or an accession list/, 'no trial list taken: one of its inputs needed');
like(join('', $catalog->validate_inputs('not_installed', { dates => 1 })), qr/not installed/, 'not installed cannot run');
like(join('', $catalog->validate_inputs('nope', {})), qr/Unknown report/, 'unknown report');

# detection on source text
is_deeply(CXGN::Report::Catalog::detect_inputs("getopts('s:e:T:');"), { dates => 1, traits => 1 }, 'detect_inputs on text');
is_deeply(CXGN::Report::Catalog::detect_inputs("getopt('t:');"), { trials => 1 }, 'getopt also detected');

done_testing();
