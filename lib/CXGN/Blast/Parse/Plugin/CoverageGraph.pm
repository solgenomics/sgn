
package CXGN::Blast::Parse::Plugin::CoverageGraph;

use Moose;
use File::Basename;


sub name { 
    return "Coverage graph";
}

sub prereqs { 
}

sub parse { 
    my $self = shift;
    my $c = shift;
    my $raw_report_file = shift;
    
    my $basename = basename($raw_report_file);

    #graph variables for just Evan's graph package
    my $graph_img_fileurl = $c->tempfile(TEMPLATE=> "blast/blast_coverage_XXXXXX", UNLINK=>0);
    my $graph_img_filepath = $c->path_to($graph_img_fileurl);
    
    my $graph2 = CXGN::Graphics::BlastGraph->new( blast_outfile => $raw_report_file,
                                                graph_outfile => $graph_img_filepath,
                                              );

  return { error => "BLAST report too large for this parse method", } if -s $raw_report_file > 1_000_000;

  my $errstr = $graph2->write_img();
  $errstr and die "<b>ERROR:</b> $errstr";


  return join '',
    ( <<EOH,
<center><b>Conservedness Histogram</b></center>
<p>The histogram shows a count of hits <i>for each base</i> in the query sequence,
but counts <i>only the domains BLAST finds</i>, meaning this is really more a function of region than of individual base.
Within the graph, green shows exact base matches within conserved regions; blue shows non-matching bases within conserved regions. Gaps introduced into the query by BLAST are ignored; gaps introduced into target sequences are not.</p>
EOH
      $graph2->get_map_html(), #code for map element (should have the name used below in the image)
      qq|<div align="center" style="color: #777777">|,
      qq|<img src="$graph_img_fileurl" border="2" usemap="#graph2map" alt="" />|,
      qq|</div>\n\n|,
    );

}




1;
