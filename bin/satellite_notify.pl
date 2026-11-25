#!/usr/bin/env perl

=head1 NAME

satellite_notify.pl - email the owner of a Satellite page model run when it ends

=head1 SYNOPSIS

  perl -I<sgn>/lib bin/satellite_notify.pl <run base> [--dry-run]

=head1 DESCRIPTION

Appended to the job command of a run (/ajax/satellite/run) when the user asks
to be told. Reads <run base>.meta.json (address taken from the account, site
url, name), <run base>.results.json and <run base>.log, and sends a short
summary with a link to the results, or the end of the log when the run
failed. --dry-run prints the email instead of sending it.

=head1 AUTHOR

Chris Simoes

=cut

use strict;
use warnings;
use JSON;
use File::Basename qw(basename);

my $base = shift @ARGV or die "usage: satellite_notify.pl <run base> [--dry-run]\n";
my $dry_run = grep { $_ eq '--dry-run' } @ARGV;
my $run_id = basename($base);

sub slurp { my $f = shift; open my $fh, '<', $f or return; local $/; return scalar <$fh> }

my $meta = eval { decode_json(slurp("$base.meta.json") // '') } or die "No metadata for $run_id\n";
my $to = $meta->{notify_email} or exit 0;
my $site = $meta->{site_url} // '';
my $name = $meta->{name} || 'Your satellite analysis';
my $results = -s "$base.results.json" ? eval { decode_json(slurp("$base.results.json")) } : undef;
my $exit = slurp("$base.exit") // '';
my $list = sub { my $x = shift; return !defined $x ? [] : ref $x eq 'ARRAY' ? $x : [ $x ] };
my $num = sub { my ($v, $d) = @_; return defined $v && $v =~ /^-?[\d.eE+-]+$/ ? sprintf("%.${d}f", $v) : '-' };

my ($subject, @body);
if ($results && $exit =~ /^\s*0\s*$/) {
    $subject = "Breedbase satellite: $name is ready";
    push @body, "$name has finished (" . ($results->{dates}{start} // '') . " to " . ($results->{dates}{end} // '') . ").", '';
    foreach my $s (@{ $list->($results->{sites}) }) {
        my $line = "  $s->{name}: " . ($s->{dates_used} // 0) . " image dates used of " . ($s->{dates_found} // 0);
        my ($crop) = grep { ($_->{id} // '') eq ($results->{crop_class} // '') } @{ $list->($s->{classes}) };
        $line .= ", " . $num->($crop->{ha}, 1) . " ha of $crop->{name} on the map" if $crop;
        push @body, $line;
    }
    if (my $y = $results->{yield}) {
        if ($y->{metrics}) {
            push @body, '', "  Yield model: R2 " . $num->($y->{metrics}{r2}, 2) . ", error " . $num->($y->{metrics}{rmse}, 1) . " ($y->{metrics}{n} calibration fields)";
        } elsif (($y->{mode} // '') eq 'index') {
            push @body, '', '  Yield: relative index' . (@{ $list->($y->{references}) } ? ', approximate kg/ha from the regional average (not a calibration)' : '');
        }
        foreach my $t (@{ $list->($y->{totals}) }) {
            push @body, "  $t->{site}: $t->{fields} field(s), " . $num->($t->{area_ha}, 1) . ' ha'
                . (defined $t->{production} && $t->{production} ne '' ? ', about ' . $num->($t->{production} / 1000, 1) . ' t' : '');
        }
    }
    my $n_notes = scalar @{ $list->($results->{notes}) };
    push @body, '', "  Notes: $n_notes (see the results)" if $n_notes;
    push @body, '', (($meta->{kind} // '') eq 'train' ? ('See the validation and save the model:', "$site/breeders/satellite/train?run=$run_id")
                                                    : ('See the map, the fields and the downloads:', "$site/breeders/satellite?run=$run_id"));
} else {
    my @log = grep { /\S/ } split /\n/, (slurp("$base.log") // '');
    my @tail = @log > 15 ? @log[-15 .. -1] : @log;
    $subject = "Breedbase satellite: $name did not finish";
    push @body, "$name stopped with an error" . ($exit =~ /^\s*137/ ? ' (the system stopped it, probably out of memory: try a smaller area or period)' : '') . '.', '',
        'Last lines of the log:', (map { "  $_" } @tail), '', 'Change the settings and run it again:', "$site/breeders/satellite" . (($meta->{kind} // '') eq 'train' ? '/train' : '');
}
push @body, '', '-- Breedbase satellite images';
my $body = join("\n", @body) . "\n";

if ($dry_run) { print "To: $to\nSubject: $subject\n\n$body"; exit 0 }
require CXGN::Contact;
CXGN::Contact::send_email($subject, $body, $to);
print "[satellite] notification for the run handed to the mailer\n";
