#!/usr/bin/perl
# 'transpose' swaps rows and columns in the given tab-delimited table.
# syntax perl transpose.pl input.txt > output.txt

while (<>) {
  chomp;
  @line = split /\t/;
  $oldlastcol = $lastcol;
  $lastcol = $#line if $#line > $lastcol;
  for (my $i=$oldlastcol; $i < $lastcol; $i++) {
    $outline[$i] = "\t" x $oldlastcol;
  }
  for (my $i=0; $i <=$lastcol; $i++) {
    if ($outline[$i] =~ /\w/) {
        $outline[$i] .= "\t$line[$i]";
    } else {
	$outline[$i] = $line[$i];
    }
  }
}
for (my $i=0; $i <= $lastcol; $i++) {
  $outline[$i] =~ s/[\f\n\r]*$//g;
  print $outline[$i]."\n";
}
