
package CXGN::Blast::Parse::Plugin::CoverageGraph;

use Moose;
use File::Basename;
use File::Slurp;

sub name { 
    return "Coverage";
    # return "Coverage graph";
}

sub prereqs { 
}

sub parse { 
    my $self = shift;
    my $c = shift;
    my $raw_report_file = shift;
    
    my $basename = basename($raw_report_file);

      if (no_hits($raw_report_file)) { 
     	return "<b>Coverage Graph:</b> Not shown, because no hits were found.<br /><br />";
     }

    #graph variables for just Evan's graph package
    my $graph_img_fileurl = $c->tempfile(TEMPLATE=> "blast/blast_coverage_XXXXXX", UNLINK=>0);
    my $graph_img_filepath = $c->path_to($graph_img_fileurl);
    
    my $graph2 = CXGN::Graphics::BlastGraph->new( blast_outfile => $raw_report_file,
                                                graph_outfile => $graph_img_filepath,
                                              );

  return { error => "BLAST report too large for this parse method", } if -s $raw_report_file > 1_000_000;

  my $errstr = $graph2->write_img();
  if ($errstr) { 
      #return "<b>Sorry, and error occurred.</b> $errstr";
  }

 

  return join '',
    ( <<EOH,
<center><b>Conservedness Histogram</b></center>
<p>The histogram shows a count of hits <i>for each base</i> in the query sequence,
but counts <i>only the domains BLAST finds</i>, meaning this is really more a function of region than of individual base.
Within the graph, green shows exact base matches within conserved regions; blue shows non-matching bases within conserved regions. Gaps introduced into the query by BLAST are ignored; gaps introduced into target sequences are not.</p>
EOH
      qq|<center>|,
      $graph2->get_map_html(), #code for map element (should have the name used below in the image)
      qq|<div align="center" style="color: #777777">|,
      qq|<img src="$graph_img_fileurl" border="2" usemap="#graph2map" alt="" />|,
      qq|</div>|,
      qq|</center>|,
    );

}


sub no_hits { 
    my $file = shift;
    my $contents = read_file($file);
    
    if ($contents =~ /No hits found/) { 
	return 1;
    }
    return 0;
}



1;
