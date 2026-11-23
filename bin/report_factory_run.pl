#!/usr/bin/env perl

=head1 NAME

report_factory_run.pl - run the report scripts of one Report Factory run

=head1 SYNOPSIS

  perl -I<sgn>/lib bin/report_factory_run.pl <run_dir> [--no-email]

=head1 DESCRIPTION

Started as a background job by /ajax/report/run. The run directory holds:

  meta.json      the run: owner, reports and their arguments, email address, site URL
  dbconf.json    database connection (read, then deleted; it never goes in the job command)
  trials.txt     trial ids of the trial list, when one was given
  accessions.txt accession ids of the accession list, when one was given
  traits.txt     trait (cvterm) ids of the trait list, when one was given

Each report script is called as

  perl bin/Reports/<name>.pl -U user -H host -P pass -D db -o <run_dir>/ -f <prefix>
       [-s YYYY-MM-DD -e YYYY-MM-DD] [-t trials.txt] [-a accessions.txt] [-T traits.txt]

with only the inputs detected in its source code (see CXGN::Report::Catalog). Its
output goes to <prefix>.log. A script that writes no <prefix>.results.json
gets one built here from its xlsx / csv files, so the page can show a preview.

While it works the runner keeps status.json up to date; at the end it zips the
files of all reports into <run_id>.zip, writes the exit status to run.exit
and, when asked, emails the owner a summary with a link to the results.

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

use strict;
use warnings;
use File::Basename qw | basename |;
use File::Slurp qw | read_file write_file |;
use JSON;
use POSIX qw | strftime WIFSIGNALED WTERMSIG WEXITSTATUS |;
use Archive::Zip qw | :ERROR_CODES :CONSTANTS |;
use Time::HiRes qw | time |;

my $run_dir = shift @ARGV or die "Usage: $0 <run_dir> [--no-email]\n";
my $no_email = grep { $_ eq '--no-email' } @ARGV;
$run_dir =~ s{/+$}{};
die "No run directory $run_dir\n" if !-d $run_dir;

my $json = JSON->new->utf8->canonical;
my $meta = eval { decode_json(read_file("$run_dir/meta.json", binmode => ':raw')) } or die "No meta.json in $run_dir\n";
my $run_id = $meta->{run_id} // basename($run_dir);
my $basepath = $meta->{basepath} or die "No basepath in meta.json\n";

my $db = eval { decode_json(read_file("$run_dir/dbconf.json", binmode => ':raw')) } || {};
unlink("$run_dir/dbconf.json");

# report scripts load Breedbase modules
$ENV{PERL5LIB} = join(':', "$basepath/lib", grep { defined && length } $ENV{PERL5LIB});

my %status = (
    run_id  => $run_id,
    state   => 'running',
    started => time(),
    reports => [ map { { name => $_->{name}, title => $_->{title}, state => 'waiting' } } @{ $meta->{reports} || [] } ],
);
write_status();

my $failures = 0;
for my $i (0 .. $#{ $meta->{reports} || [] }) {
    my $r = $meta->{reports}->[$i];
    my $st = $status{reports}->[$i];
    my $name = $r->{name} // '';
    my $prefix = $r->{prefix} // '';
    if ($name !~ /^[A-Za-z0-9_]+$/ || $prefix !~ /^[A-Za-z0-9_.-]+$/) {
        @$st{qw(state error)} = ('failed', 'Invalid report name.');
        $failures++;
        next;
    }
    my $script = "$basepath/bin/Reports/$name.pl";
    if (!-f $script) {
        @$st{qw(state error)} = ('failed', "The report script $name.pl is not installed on this server.");
        $failures++;
        write_status();
        next;
    }

    my $args = $r->{args} || {};
    my @cmd = ($^X, $script,
        '-U', $db->{dbuser} // '', '-H', $db->{dbhost} // '', '-P', $db->{dbpass} // '', '-D', $db->{dbname} // '',
        '-o', "$run_dir/", '-f', $prefix);
    push @cmd, '-s', $args->{start_date} if defined($args->{start_date});
    push @cmd, '-e', $args->{end_date} if defined($args->{end_date});
    push @cmd, '-t', "$run_dir/$args->{trials_file}" if $args->{trials_file};
    push @cmd, '-a', "$run_dir/$args->{accessions_file}" if $args->{accessions_file};
    push @cmd, '-T', "$run_dir/$args->{traits_file}" if $args->{traits_file};

    $st->{state} = 'running';
    $st->{started} = time();
    $status{current} = $name;
    write_status();

    my $log = "$run_dir/$prefix.log";
    my $pid = fork();
    die "Cannot fork: $!\n" if !defined($pid);
    if ($pid == 0) {
        chdir($run_dir);
        open(STDOUT, '>', $log) or die "Cannot write $log: $!\n";
        open(STDERR, '>&', \*STDOUT) or die "Cannot redirect STDERR: $!\n";
        exec { $cmd[0] } @cmd or die "Cannot start $script: $!\n";
    }
    waitpid($pid, 0);
    my $code = WIFSIGNALED($?) ? 128 + WTERMSIG($?) : WEXITSTATUS($?);

    $st->{exit_code} = $code;
    $st->{seconds} = sprintf('%.1f', time() - $st->{started}) + 0;
    my @files = report_files($prefix);
    if ($code == 0 && !-e "$run_dir/$prefix.results.json") {
        build_preview($prefix, $r->{title} // $name, \@files);
    }
    $st->{files} = [ map { basename($_) } grep { !/\.(results\.json|log)$/ } report_files($prefix) ];
    $st->{has_results} = -e "$run_dir/$prefix.results.json" ? 1 : 0;
    if ($code != 0) {
        $st->{state} = 'failed';
        $st->{error} = error_text($log, $code);
        $failures++;
    } elsif (!@{ $st->{files} }) {
        $st->{state} = 'finished';
        $st->{warning} = 'The report ran but wrote no file (it may have found nothing to report).';
    } else {
        $st->{state} = 'finished';
    }
    write_status();
}

# all files of all reports in one archive
my @all = map { "$run_dir/$_" } map { @{ $_->{files} || [] } } @{ $status{reports} };
if (@all) {
    my $zip = Archive::Zip->new();
    $zip->addFile($_, basename($_)) for grep { -f } @all;
    if ($zip->writeToFileNamed("$run_dir/$run_id.zip") == AZ_OK) {
        $status{zip} = "$run_id.zip";
    }
}

delete $status{current};
$status{finished} = time();
my $n = scalar(@{ $status{reports} });
$status{state} = $failures == 0 ? 'finished' : ($failures == $n ? 'failed' : 'partial');
write_status();
write_file("$run_dir/run.exit", ($failures ? 1 : 0) . "\n");

notify() if !$no_email && $meta->{notify_email};
exit($failures == $n && $n ? 1 : 0);

# ---------------------------------------------------------------------------

sub write_status {
    my $tmp = "$run_dir/status.json.tmp";
    write_file($tmp, { binmode => ':raw' }, $json->encode(\%status));
    rename($tmp, "$run_dir/status.json");
}

sub report_files {
    my $prefix = shift;
    opendir(my $dh, $run_dir) or return ();
    my @f = sort map { "$run_dir/$_" } grep { index($_, $prefix) == 0 && -f "$run_dir/$_" } readdir($dh);
    closedir($dh);
    return @f;
}

sub error_text {
    my ($log, $code) = @_;
    my @lines = -e $log ? grep { /\S/ } split(/\n/, read_file($log)) : ();
    my @err = grep { /error|died|die |cannot|can't|failed|not found| at .* line \d+/i } @lines;
    @err = @lines if !@err;
    @err = @err[-8 .. -1] if @err > 8;
    my $msg = join("\n", @err);
    if ($code >= 128) {
        my $sig = $code - 128;
        $msg = "The report was stopped by the system (signal $sig" . ($sig == 9 ? ', most often because it ran out of memory' : '') . ").\n$msg";
    }
    return $msg || "The report script ended with exit code $code.";
}

# preview of the files written by a script that does not write a results file
sub build_preview {
    my ($prefix, $title, $files) = @_;
    my @tables;
    my $max = 1000;
    foreach my $file (@$files) {
        my $kind = file_kind($file);
        if ($kind eq 'xlsx') {
            my $book = eval { require Spreadsheet::ParseXLSX; Spreadsheet::ParseXLSX->new->parse($file) };
            next if !$book;
            foreach my $sheet ($book->worksheets()) {
                my ($rmin, $rmax) = $sheet->row_range();
                my ($cmin, $cmax) = $sheet->col_range();
                next if $rmax < $rmin || $cmax < $cmin;
                my @rows;
                for my $r ($rmin .. $rmax) {
                    my @row = map { my $cell = $sheet->get_cell($r, $_); defined($cell) ? $cell->value() : '' } ($cmin .. $cmax);
                    push @rows, \@row;
                    last if @rows > $max;
                }
                my $columns = shift(@rows) || [];
                my $total = $rmax - $rmin;
                push @tables, table_entry(basename($file) . ($book->worksheet_count() > 1 ? ' - ' . $sheet->get_name() : ''), $columns, \@rows, $total, $max);
            }
        }
        elsif ($kind eq 'json') {
            # an array of records (or {key: [records]}) becomes a table
            my $data = eval { decode_json(scalar(read_file($file, binmode => ':raw'))) } or next;
            my @sets = ref($data) eq 'ARRAY' ? ([ basename($file), $data ])
                : ref($data) eq 'HASH' ? (map { [ basename($file) . " - $_", $data->{$_} ] } grep { ref($data->{$_}) eq 'ARRAY' } sort keys %$data)
                : ();
            foreach my $set (@sets) {
                my ($name, $records) = @$set;
                my @recs = grep { ref($_) eq 'HASH' } @$records;
                next if !@recs;
                my (%seen, @columns);
                foreach my $rec (@recs[0 .. ($#recs > 199 ? 199 : $#recs)]) {
                    push @columns, grep { !$seen{$_}++ } sort keys %$rec;
                }
                my @rows = map { my $rec = $_; [ map { my $v = $rec->{$_}; ref($v) ? encode_json($v) : $v } @columns ] } @recs[0 .. ($#recs >= $max ? $max - 1 : $#recs)];
                push @tables, table_entry($name, \@columns, \@rows, scalar(@recs), $max);
            }
        }
        elsif ($kind eq 'csv' || $kind eq 'tsv') {
            my $sep = $kind eq 'csv' ? ',' : "\t";
            my $csv = eval { require Text::CSV; Text::CSV->new({ binary => 1, sep_char => $sep }) } or next;
            open(my $fh, '<', $file) or next;
            my $columns = $csv->getline($fh) || [];
            my (@rows, $total);
            $total = 0;
            while (my $row = $csv->getline($fh)) {
                $total++;
                push @rows, $row if @rows < $max;
            }
            close($fh);
            push @tables, table_entry(basename($file), $columns, \@rows, $total, $max);
        }
    }
    return if !@tables;
    my $results = {
        title   => $title,
        summary => [ map { { label => "Rows in $_->{name}", value => $_->{total_rows} } } @tables[0 .. ($#tables > 3 ? 3 : $#tables)] ],
        charts  => [],
        notes   => [ 'Preview built from the files written by the report.' ],
        tables  => \@tables,
    };
    write_file("$run_dir/$prefix.results.json", { binmode => ':raw' }, $json->encode($results));
}

# type of an output file, from its extension or, without one, from its content
sub file_kind {
    my $file = shift;
    return lc($1) eq 'txt' ? 'tsv' : lc($1) if $file =~ /\.(xlsx|csv|tsv|txt|json)$/i;
    return '' if $file =~ /\.[A-Za-z0-9]{2,5}$/;
    open(my $fh, '<:raw', $file) or return '';
    read($fh, my $head, 4096);
    close($fh);
    return 'xlsx' if $head =~ /^PK\x03\x04/;
    return 'json' if $head =~ /^\s*[\[{]/;
    my ($line) = split /\r?\n/, ($head // '');
    return '' if !defined($line) || $line =~ /[^\x09\x20-\x7e\x80-\xff]/;
    return 'tsv' if $line =~ /\t/;
    return 'csv' if $line =~ /,/;
    return '';
}

sub table_entry {
    my ($name, $columns, $rows, $total, $max) = @_;
    my @r = @$rows > $max ? @$rows[0 .. $max - 1] : @$rows;
    return { name => $name, columns => $columns, rows => \@r, total_rows => $total, truncated => ($total > $max ? JSON::true : JSON::false) };
}

sub notify {
    my $to = $meta->{notify_email};
    my $site = $meta->{site_url} // '';
    my $label = $meta->{title} || 'Your report';
    my @lines;
    foreach my $r (@{ $status{reports} }) {
        my $line = sprintf('  %-40s %s', $r->{title} // $r->{name}, $r->{state});
        $line .= " - " . (split /\n/, $r->{error})[0] if $r->{error};
        push @lines, $line;
    }
    my $ok = $status{state} eq 'finished';
    my $subject = "Breedbase Report Factory: $label " . ($ok ? 'is ready' : ($status{state} eq 'partial' ? 'finished with errors' : 'failed'));
    my $zip = $status{zip} ? "$run_dir/$status{zip}" : undef;
    my $attach = ($zip && -s $zip && -s $zip < 15 * 1024 * 1024) ? $zip : undef;
    my $body = join("\n",
        "Dear user,",
        "",
        "$label (" . strftime('%Y-%m-%d %H:%M', localtime($status{started})) . "):",
        "",
        @lines,
        "",
        "See the results and download the files:",
        "$site/tools/report?run_id=$run_id",
        ($zip && !$attach ? ("", "The files are too large to attach; download them from the page above.") : ()),
        "",
        "-- Breedbase Report Factory",
    );
    my $sent = eval {
        require CXGN::Contact;
        CXGN::Contact::send_email($subject, $body, $to, undef, $attach);
        1;
    };
    print STDERR $sent ? "Report Factory: notification for $to handed to the mailer\n" : "Report Factory: could not send the notification: $@\n";
}
