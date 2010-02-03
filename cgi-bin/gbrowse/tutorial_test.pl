#!/usr/bin/perl -w
use strict;
use CGI qw/:standard *table start_td start_TR/;

$/ = "||\n";

print header,
      start_html("Retinal regression test"),
      h2("Retinal-based regression testing for GBrowse"),
      p("In order for this to work, the tutoral data and confiles must
         be installed; that is, the volvox_final.conf file (renamed to
         'volvox.conf') must be in the gbrowse conf directory and the
         volvox_all.gff and volvox_all.fa files must be in the volvox
         database directory."),
      start_table({border=>2, cellpadding=>25});

my $line_count = 0;

while (my $line = <DATA>) {
    next if ($line =~ /^#/);

    chomp $line;
    my $bgcolor = ($line_count % 2 == 0) ? "#DDDDDD" : "#BBBBBB" ;

    print start_TR({bgcolor => $bgcolor}),start_td;

    my @stuff = split /\n/, $line;

    print b("From GBrowse"),br,
          img( {src=>$stuff[0]} ),br,br;

     print b("Standard coming from the tutorial"),br,
           img( {src=>$stuff[1]} );


    print end_td(),end_TR;

    $line_count++;
}
print end_TR(),end_table(),end_html(); 
exit(0);

__DATA__
/cgi-bin/gbrowse_img/volvox/?name=ctgA;type=ExampleFeatures+%3Aregion+Motifs%3Aoverview;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=1
/gbrowse/tutorial/figures/basics1.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:27000..47000;type=ExampleFeatures+Motifs+%3Aregion+Motifs%3Aoverview;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/descriptions1.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:8000..27000;type=ExampleFeatures+Motifs+Alignments+%3Aregion+Motifs%3Aoverview;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/segmented_features2.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:1..10000;type=Transcripts+%3Aregion+Motifs%3Aoverview;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/canonical_gene2.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:1..9000;type=Transcripts+CDS+%3Aregion+Motifs%3Aoverview;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/cds1.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:1..24000;type=ExampleFeatures+Clones;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/custom_aggregators1.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:8000..26000;type=Motifs+Alignments+TransChip;width=800;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/graph1.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:3098..8097;type=Transcripts+CDS+DNA+Translation;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/dna1.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:5348..5447;type=Transcripts+CDS+DNA+Translation;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/dna2.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:1..10000;type=EST;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/multiple_alignments3.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:1065..1165;type=EST+DNA;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/adding_dna_to_alignments1.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:32001..50000;type=Traces+ExampleFeatures+DNA;width=800;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/trace1.png
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:44665..44765;type=Traces+ExampleFeatures+DNA;width=800;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/trace2.png
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:1..4500;type=Transcripts;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on;plugin=RestrictionAnnotator;plugin_do=EcoRI+KpnI+HhaI+ClaI
/gbrowse/tutorial/figures/plugins1.gif
||
/cgi-bin/gbrowse_img/volvox/?name=ctgA:10001..40000;type=Alignments+;width=640;id=82c3cfeee52b61f81ef9cad20b76d7b1;keystyle=between;grid=on
/gbrowse/tutorial/figures/semantic_zooming1.gif
||
