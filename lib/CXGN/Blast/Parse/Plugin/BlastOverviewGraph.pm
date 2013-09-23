
package CXGN::Blast::Parse::Plugin::BlastOverviewGraph;

use Moose;
use Bio::GMOD::Blast::Graph;
use File::Basename qw | basename |;
use File::Slurp qw | read_file |;

sub name { 
    return "Overview graph";
}

# at what point to display it... preferably on the top
sub priority { 
    1;
}

sub prereqs { 

}

sub parse { 
    my $self = shift;
    my $c = shift;
    my $raw_report_file = shift;
    my $bdb = shift;
    
    return 'No report found.' unless -e $raw_report_file;
    
    return 'graphical display not available for BLAST reports larger than 1 MB' if -s $raw_report_file > 1_000_000;
    
    open(STDOUT, ">", $raw_report_file.".blast_graph.html");

#    my $inc_str = join ',', map qq|"$_"|, @INC;
#    my $cmd = <<EOP;
#    @INC = ( $inc_str );
#    require Bio::GMOD::Blast::Graph;
    my $graph = Bio::GMOD::Blast::Graph->new(-outputfile => $raw_report_file,
					     -dstDir => $c->config->{basepath}."/".$c->config->{tempfiles_subdir},
                                              -dstURL => $c->config->{tempfiles_subdir},
                                              -imgName=> $raw_report_file.".blast_graph.png",
	);
    
    die unless $graph;
    
    $graph->showGraph();
#EOP
	
 #   my $html = `perl -e '$cmd'`;
    select STDOUT;

    my $html = read_file($raw_report_file.".blast_graph.html");
    
    return $html;
}

1;
