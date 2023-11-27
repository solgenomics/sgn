
package SGN::Controller::AJAX::SimSearch;

use Moose;
use File::Temp "tempdir";
use File::Basename;

BEGIN { extends 'Catalyst::Controller::REST'; }


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );



sub process_file :Path('/ajax/tools/simsearch/process_file') :Args(0) {
    my $self = shift;
    my $c = shift;

    
    my $filename = $c->config->{basepath}."/".$c->config->{tempfiles_subdir}."/simsearch/".$c->req->param("filename");
    my $fileurl = '/simsearch/'.$c->req->param("filename");
    my $format = $c->req->param("format");

    print STDERR "FORMAT = $format\n";
    
#    if ($format eq "vcf") {
#	print STDERR "Converting vcf to dosage...\n";
#	system("perl ../gtsimsrch/src/vcf2dosage.pl < $filename > $filename.dosage");
#	$filename = $filename.".dosage";
 #   }

    
    
    print STDERR "READING FROM $filename\n";
    my $reference_file = $c->req->param("reference_file");

    my $reference_file_path = $c->config->{simsearch_datadir}."/".$reference_file;
    # do not specify -r option when there is no reference file
    #
    my $ref_option = "";
    if ($reference_file) {
	$ref_option = " -ref $reference_file_path ";
    }
    
#    my $cmd = "../gtsimsrch/src/simsearch -i $filename $ref_option -o $filename.out";

    my $cmd = "../gtsimsrch/src/duplicate_finder.pl -alt_marker_ids -nofull_cluster_output -max_distance 0.5 -in $filename $ref_option -output $filename.out -graphics GD -histogram_filename $filename.out_distances_histogram.png -histogram_path /home/production/cxgn/gtsimsrch/src/histogram.pl";
    print STDERR "running command $cmd...\n";
    system($cmd);


    my $results;
    open(my $F , "<", $filename.".out_clusters") || die "Can't open file $filename.out_clusters";

    my @data;
    my @line;

    my $group =1;

    print STDERR "Parsing output file...\n";
    while(<$F>) {
	print STDERR "Processing group $group...\n";
	chomp;
	if (/^#/) { next; }
	@line = split " ";
	my @members = @line[9..@line-1];
		
	push @data, [ $group, $line[0], $line[3], $line[2], join("<br />", @members) ];
	$group++;
    }
    close($F);
    print STDERR "Done.\n";
    
    # plot the agmr score distribution histogram using the 6th column in $filename.out
    #
    # (use gnuplot or R)

    $c->stash->{rest} = { data => \@data,
                          histogram => '/documents/tempfiles/'.$fileurl.".out_distances_histogram.png"   };
    
}

1;

