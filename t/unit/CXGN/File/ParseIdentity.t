use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempfile);
use Encode qw(encode_utf8);
use Excel::Writer::XLSX;
use CXGN::File::Parse;

sub parse_file {
    return CXGN::File::Parse->new(
        file => $_[0], required_columns => [qw(plot_name accession_name)],
        optional_columns => [qw(new_plot_name free_text trial_name)],
        column_aliases => {plot_name => ['plot name'], accession_name => ['accession name']},
        unique_only_columns => [qw(plot_name new_plot_name)],
    )->parse;
}
sub csv {
    my ($content) = @_;
    my ($fh, $name) = tempfile(SUFFIX => '.csv', UNLINK => 1);
    binmode $fh; print $fh encode_utf8($content); close $fh;
    return parse_file($name);
}
sub xlsx {
    my ($rows) = @_;
    my ($fh, $name) = tempfile(SUFFIX => '.xlsx', UNLINK => 1); close $fh;
    my $book = Excel::Writer::XLSX->new($name);
    my $sheet = $book->add_worksheet;
    for my $r (0 .. $#$rows) {
        for my $c (0 .. $#{ $rows->[$r] }) {
            $sheet->write_string($r, $c, $rows->[$r][$c]) if defined $rows->[$r][$c];
        }
    }
    $book->close;
    return parse_file($name);
}

subtest 'Blank separators do not discard later corrections' => sub {
    my @rows = ([qw(plot_name accession_name)], [qw(P1 A1)], (map { [] } 1..6), [qw(P2 A2)]);
    for my $parsed (csv("plot_name,accession_name\nP1,A1\n".("\n" x 6)."P2,A2\n"), xlsx(\@rows)) {
        is_deeply($parsed->{errors}, [], 'valid file');
        is_deeply([map { [$_->{plot_name}, $_->{accession_name}, $_->{_row}] } @{$parsed->{data}}],
            [['P1','A1',2], ['P2','A2',9]], 'both corrections and physical row numbers retained');
    }
};
subtest 'Internal Unicode whitespace is part of stock identity and free text' => sub {
    my $name = "A\x{a0}B";
    my $reason = "затоплено\x{a0}після сходів";
    for my $parsed (csv("plot_name,accession_name,free_text\nP1,$name,$reason\n"),
                    xlsx([[qw(plot_name accession_name free_text)], ['P1',$name,$reason]])) {
        is_deeply($parsed->{errors}, [], 'valid Unicode file');
        is($parsed->{data}[0]{accession_name}, $name, 'distinct accession identity retained');
        is($parsed->{data}[0]{free_text}, $reason, 'free-text spacing retained');
    }
};
subtest 'Uploaded row labels cannot hide conflicting plot corrections' => sub {
    for my $parsed (csv("plot_name,accession_name,_row\nP1,A1,1\nP1,A2,1\n"),
                    xlsx([[qw(plot_name accession_name _row)], [qw(P1 A1 1)], [qw(P1 A2 1)]])) {
        like(join(' ', @{$parsed->{errors}}), qr/appears more than once in rows 2,3/, 'physical duplicate rows refused');
        is_deeply([map {$_->{_row}} @{$parsed->{data}}], [2,3], 'internal metadata remains trustworthy');
        ok(!(grep {$_ eq '_row'} @{$parsed->{columns}}), 'reserved metadata is not imported as a column');
    }
};
subtest 'Unknown headers are literal text' => sub {
    my $parsed = csv("plot_name,accession_name,notes (original,.*\nP1,A1,note,extra\n");
    is_deeply($parsed->{errors}, [], 'header punctuation does not compile a regular expression');
    is_deeply($parsed->{required_columns}, [qw(plot_name accession_name)], 'regex-looking extra header is not required');
    is_deeply($parsed->{additional_columns}, ['notes (original','.*'], 'extra columns classified literally');
};
subtest 'BOM, quoted identity and multiline text remain supported' => sub {
    my $parsed = csv("\x{feff}Plot Name,Accession Name,free_text\r\n\"P,1\",\"зразок \"\"А\"\"\",\"rain, then\nwind\"\r\n");
    is_deeply($parsed->{errors}, [], 'valid quoted CSV');
    is_deeply($parsed->{data}[0], {_row=>2,plot_name=>'P,1',accession_name=>'зразок "А"',free_text=>"rain, then\nwind"}, 'all cell boundaries preserved');
};
done_testing;
