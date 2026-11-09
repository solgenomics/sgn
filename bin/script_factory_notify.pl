#!/usr/bin/perl

=head1 NAME

script_factory_notify.pl - email the owner of a Script Factory run when it ends

=head1 SYNOPSIS

  perl -I<sgn>/lib bin/script_factory_notify.pl <run_base> [--dry-run]

Appended to the job command of a Script Factory run (/ajax/script_factory/run)
when the user asks to be notified. Reads <run_base>.meta.json (address, site
URL, script and dataset names), <run_base>.results.json and <run_base>.log, and
sends a short summary with a link to the results dashboard, or the end of the
log when the run failed. --dry-run prints the email instead of sending it.

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

use strict;
use warnings;
use File::Basename qw | basename |;
use File::Slurp qw | read_file |;
use JSON;

my $run_base = shift @ARGV or die "Usage: $0 <run_base> [--dry-run]\n";
my $dry_run = grep { $_ eq '--dry-run' } @ARGV;
my $run_id = basename($run_base);

my $meta = eval { decode_json(read_file("$run_base.meta.json")) } or die "No metadata for $run_id\n";
my $to = $meta->{notify_email} or exit 0;
my $site = $meta->{site_url} // '';
my $name = $meta->{script_name} ? "\"$meta->{script_name}\"" : 'Your analysis';
my $dataset = $meta->{dataset_name} || 'the selected dataset';

my $results = -s "$run_base.results.json" ? eval { decode_json(read_file("$run_base.results.json")) } : undef;
my ($subject, $body);

if ($results && $results->{genotype_values}) {
    my $s = $results->{summary} || {};
    my @h2 = map { sprintf("%s %s", $_->{trait}, defined($_->{h2}) ? sprintf("%.2f", $_->{h2}) : 'n/a') } @{ $results->{stage2} || [] };
    my $engine = ($results->{engine} // '') eq 'blupf90' ? 'BLUPF90+' : 'R';
    my $genetic = { pedigree => ', pedigree (A matrix)', parents => ', mother + father effects' }->{ $results->{genetic_model} // '' } // '';
    my $n_warn = scalar(@{ $results->{warnings} || [] });
    $subject = "Breedbase Script Factory: $name finished";
    $body = join("\n",
        "$name on dataset \"$dataset\" has finished.",
        "",
        "  Model:        " . (($results->{strategy} // '') eq 'two_stage' ? 'two stages' : 'single stage') . ", " . ($results->{value_label} // 'BLUP') . "s, $engine$genetic",
        "  Trials:       " . ($s->{n_trials} // '?') . "    Accessions: " . ($s->{n_accessions} // '?') . "    Plots: " . ($s->{n_plots} // '?'),
        "  Heritability: " . (@h2 ? join(', ', @h2) : 'n/a'),
        ($results->{index} ? "  Selection index: top " . ($results->{index}->{selection_pct} // '?') . "% selected" : ()),
        ($n_warn ? "  Notes:        $n_warn (see the results)" : ()),
        "",
        "See the results, compare and select accessions, and store the analysis:",
        "$site/tools/script_factory/results/$run_id",
        "",
        "-- Breedbase Script Factory",
    );
} else {
    my @log = -e "$run_base.log" ? grep { !/^(CXGN::Contact|Breedbase Script Factory:)/ } split(/\n/, read_file("$run_base.log")) : ();
    my @tail = @log > 15 ? @log[-15 .. -1] : @log;
    $subject = "Breedbase Script Factory: $name did not finish";
    $body = join("\n",
        "$name on dataset \"$dataset\" stopped with an error.",
        "",
        "Last lines of the log:",
        (map { "  $_" } @tail),
        "",
        "Check the settings and run it again from the Script Factory:",
        "$site/tools/script_factory",
        "",
        "-- Breedbase Script Factory",
    );
}

if ($dry_run) {
    print "To: $to\nSubject: $subject\n\n$body\n";
    exit 0;
}

require CXGN::Contact;
CXGN::Contact::send_email($subject, $body, $to);
print STDERR "Script Factory: notification for $to handed to the mailer\n";
