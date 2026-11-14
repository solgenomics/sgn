package CXGN::File::Spreadsheet;

use strict;
use warnings;
use Exporter 'import';
use Spreadsheet::ParseExcel::Utility qw(ExcelFmt);

our @EXPORT_OK = qw(cell_value);

sub cell_value {
    my ($cell, $workbook) = @_;
    my $type = $cell->type() // '';
    my $raw = $cell->unformatted();

    # ODS keeps office:date-value as ISO text, separate from the displayed value. Fractions of a second
    # are dropped, as they are for Excel cells below.
    if ($type eq 'date' && defined($raw) && $raw =~ m/^(\d{4}-\d{2}-\d{2})(?:T(\d{2}:\d{2}:\d{2})(?:\.\d+)?)?$/) {
        my ($date, $time) = ($1, $2);
        return defined($time) && $time ne '00:00:00' ? "$date $time" : $date;
    }

    # Excel dates are day counts, so use the workbook's epoch instead of its display format. The cell's
    # number format decides whether it holds a date, because Spreadsheet::ParseExcel types a cell with
    # a custom date and time format as Numeric. A time of day or a duration is returned as displayed.
    if (($type ne 'Date' && $type ne 'Numeric') || !defined($raw) || $raw !~ m/^\d+(?:\.\d+)?(?:[eE][-+]?\d+)?$/) {
        return $cell->value();
    }
    return $cell->value() if !_format_shows_date($cell, $workbook, $type eq 'Date' && $raw >= 1);
    my $is_1904 = $workbook->can('using_1904_date') ? $workbook->using_1904_date() : 0;
    return ExcelFmt('yyyy-mm-dd', $raw, $is_1904) if $raw == int($raw);
    return ExcelFmt('yyyy-mm-dd hh:mm:ss', $raw, $is_1904);
}

# True when the cell's number format shows a year, a month or a day. The format decides it, not the
# size of the day count, because in a 1904 workbook a count below 1 is a date (1904-01-01). Without a
# format string the caller's default applies.
sub _format_shows_date {
    my ($cell, $workbook, $default) = @_;
    my $format = eval { $workbook->{FmtClass}->FmtString($cell, $workbook) };
    return $default ? 1 : 0 if !defined($format) || $format eq '';
    $format =~ s/"[^"]*"|\\.|_.|\*.//g;    # quoted text, escapes, spacing (_x) and fill (*x) directives
    return 0 if $format =~ m/\[[<>=]/;    # a condition chooses the section by value; leave it as displayed
    ($format) = split /;/, $format;    # a date is a positive number, so the first section applies
    $format =~ s/\[([hms]+)\]/$1/gi;    # elapsed hours, minutes or seconds
    $format =~ s/\[[^\]]*\]//g;    # colors and locales
    return 1 if $format =~ m/[yd]/i;
    return $format =~ m/m/i && $format !~ m/[hs]/i ? 1 : 0;    # m is a month unless hours or seconds are shown
}

1;
