
package CXGN::Blast::Parse::Plugin::Table;

use Moose;
use File::Slurp qw | read_file |;

sub name { 
    return "Table";
}

sub priority { 
    return 12;
}

sub prereqs { 
}

sub parse { 
  my $self = shift;
  my $c = shift;
  my $file = shift;
  my $bdb = shift;
  
  my $db_id = $bdb->blast_db_id();
  
  my $query = "";
  my $subject = "";
  my $id = 0.0;
  my $aln = 0;
  my $mm = 0;
  my $gaps = 0;
  my $qstart = 0;
  my $qend = 0;
  my $sstart = 0;
  my $send = 0;
  my $evalue = 0.0;
  my $score = 0;
  my $desc = "";

  my $one_hsp = 0;
  
  my $blast_table_file = $file."_tabular.txt";
  my $blast_table_html = $file."_tabular.html";
  
  open (my $blast_fh, "<", $file);
  open (my $table_fh, ">", $blast_table_file);
  open (my $table_html_fh, ">", $blast_table_html);
  
  # print $table_html_fh "<style>\n#blast_table_div {\nwidth:900px;\noverflow: scroll;\nborder:solid #ccf 1px;\n}\n#blast_table {\ntext-align:right;\nwhite-space: nowrap;\npadding:5px\n}\n#blast_table td {\npadding-left: 5px;\n}\n.aln_l {\ntext-align:left;\n}\n</style>\n";
  print $table_html_fh "<center><table id=\"blast_table\" class=\"table\">\n";
  # print $table_html_fh "<div id=\"blast_table_div\">\n<center><table id=\"blast_table\" border=\"0\"><tr>\n";
  print $table_html_fh "<tr><th>QueryId</th><th>SubjectId</th><th>id%</th><th>Aln</th><th>Mm</th><th>Gaps</th><th>qstart</th><th>qend</th><th>sstart</th><th>send</th><th>evalue</th><th>Score</th><th>Description</th></tr>\n";
  
  while (my $line = <$blast_fh>) {
    chomp($line);

    $line =~ s/lcl\|//g; # remove lcl tags
    
    if ($line =~ /Query\=\s*(\S+)/) {
      $query = $1;
    }

    if ($line =~ /^>/) {
  
      if ($subject) {
        print $table_fh "$query\t$subject\t$id\t$aln\t$mm\t$gaps\t$qstart\t$qend\t$sstart\t$send\t$evalue\t$score\t$desc\n";
        print $table_html_fh "<tr><td>$query</td><td><a href=\"/tools/blast/show_match_seq.pl?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send\" target=\"_blank\">$subject</a></td><td>$id</td><td>$aln</td><td>$mm</td><td>$gaps</td><td>$qstart</td><td>$qend</td><td>$sstart</td><td>$send</td><td>$evalue</td><td>$score</td><td class=\"aln_l\">$desc</td></tr>\n";
      }
      $subject = "";
      $id = 0.0;
      $aln = 0;
      $mm = 0;
      $gaps = 0;
      $qstart = 0;
      $qend = 0;
      $sstart = 0;
      $send = 0;
      $evalue = 0.0;
      $score = 0;
      $desc = "";
      $one_hsp = 0;
  
      if ($line =~ /^>(\S+)\s*(.*)/) {
        $subject = $1;
        $desc = $2;

	if ($subject =~ /lcl\|(.*)/) { # remove lcl prefix
	    $subject = $1;
	}

      }
    }

    if ($line =~ /Score\s*=/ && $one_hsp == 1) {
      print $table_fh "$query\t$subject\t$id\t$aln\t$mm\t$gaps\t$qstart\t$qend\t$sstart\t$send\t$evalue\t$score\t$desc\n";
      print $table_html_fh "<tr><td>$query</td><td><a href=\"/tools/blast/show_match_seq.pl?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send\" target=\"_blank\">$subject</a></td><td>$id</td><td>$aln</td><td>$mm</td><td>$gaps</td><td>$qstart</td><td>$qend</td><td>$sstart</td><td>$send</td><td>$evalue</td><td>$score</td><td class=\"aln_l\">$desc</td></tr>\n";
      
      $id = 0.0;
      $aln = 0;
      $mm = 0;
      $gaps = 0;
      $qstart = 0;
      $qend = 0;
      $sstart = 0;
      $send = 0;
      $evalue = 0.0;
      $score = 0;
    }
    if ($line =~ /Score\s*=\s*([\d\.]+)/) {
      $score = $1;
      $one_hsp = 1;
    }
    if ($line =~ /Expect\s*=\s*([\d\.\-e]+)/) {
      $evalue = $1;
    }

    if ($line =~ /Identities\s*=\s*(\d+)\/(\d+)/) {
      $aln = $2;
      $mm = $aln - $1;
      $id = sprintf("%.2f", $1*100/$aln);
    }
    if ($line =~ /Gaps\s*\=\s*(\d+)\/\d+/) {
      $gaps = $1;
      $mm = $mm - $gaps;
    }

    if (($line =~ /^Query:\s+(\d+)/) && ($qstart == 0)) {
      $qstart = $1;
    }
    if (($line =~ /^Sbjct:\s+(\d+)/) && ($sstart == 0)) {
      $sstart = $1;
    }

    if (($line =~ /^Query:/) && ($line =~ /(\d+)\s*$/)) {
      $qend = $1;
    }
    if (($line =~ /^Sbjct:/) && ($line =~ /(\d+)\s*$/)) {
      $send = $1;
    }

  }
  print $table_fh "$query\t$subject\t$id\t$aln\t$mm\t$gaps\t$qstart\t$qend\t$sstart\t$send\t$evalue\t$score\t$desc\n";
  print $table_html_fh "<tr><td>$query</td><td><a href=\"/tools/blast/show_match_seq.pl?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send\" target=\"_blank\">$subject</a></td><td>$id</td><td>$aln</td><td>$mm</td><td>$gaps</td><td>$qstart</td><td>$qend</td><td>$sstart</td><td>$send</td><td>$evalue</td><td>$score</td><td class=\"aln_l\">$desc</td></tr>\n";
  print $table_html_fh "</table>\n</center>\n";
  # print $table_html_fh "</tr></table>\n</center></div>\n";
  
  close ($table_fh);
  close ($table_html_fh);
  
  return read_file($blast_table_html);
}

1;
