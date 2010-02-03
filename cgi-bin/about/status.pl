#!/usr/bin/perl
use strict;
use GD::Graph::lines;
use SGN;
my $page;

# get from url
my $deg = $cgi->param('deg') || 'F';


# assemble the array and make the graph
my $data = [\@times, \@temps];
my $gd = $graph->plot($data) or barf($graph->error());
# print "Content-type: text/html\n\nASDFASDFADSF";
print "Content-type: image/png\n\n".$gd->png();
# Add extra html stuff here.

sub barf {

    my $message = shift;

    print "Content-type: text/plain\n\n$message\n";

    if(defined(@times)){
	use Data::Dumper;
	print Dumper \@times;
    }

    if(defined(@temps)){
	use Data::Dumper;
	print Dumper \@temps;
    }

    exit;

}

sub readFileAndMakeGraph{
    my $numOfLines = shift(@_);
    my $data_file = '/data/shared/website/digitemp.out'b;
    if($numOfLines eq "all"){
        # Get the digitemp data
	open (my $fh, $data_file) or barf("Can't open file $data_file: $!");
	my @lines = <$fh>;
	close $fh;
    }
    
    else{
	open (my $fh, "tail $data_file -n $numOfLines |");
	my @lines = <$fh>;
	close $fh;
    }
    
# Parse it into something we can graph
    my (@times, @temps);
#from 0 to index of the last element in $lines
    for my $i (0..$#lines){
	my @fields = split(/ /,$lines[$i]);
	$times[$i] = $fields[2];
	
	# Look, we're international!
	if ($deg eq 'C'){
	    $temps[$i] = $fields[6];
	} else {
	    $temps[$i] = $fields[8];
	}

    }
    
    barf("Hey, where's the data?") unless @times && @temps;
    
# graph settings
    my $graph = GD::Graph::lines->new(1000,300);
    $graph->set(
		'x_label' => 'time',
		'y_label' => "degrees $deg",
		'title' => 'Temperature in the server room',
		'y_max_value' => ($deg eq 'C' ? 32 : 90),
		'y_min_value' => ($deg eq 'C' ? 21 : 70),
		'x_label_skip' => @times/5,
		'transparent' => 0
		) or barf($graph->error());
    return $graph;
}
