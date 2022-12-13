
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
    my $format = $c->req->param("format");

    print STDERR "FORMAT = $format\n";
    
    if ($format eq "vcf") {
	print STDERR "Converting vcf to dosage...\n";
	system("perl ../gtsimsrch/src/vcf2dosage.pl < $filename > $filename.dosage");
	$filename = $filename.".dosage";
    }

    
    
    print STDERR "READING FROM $filename\n";
    my $reference_file = $c->req->param("reference_file");

    my $reference_file_path = $c->config->{simsearch_datadir}."/".$reference_file;
    # do not specify -r option when there is no reference file
    #
    my $ref_option = "";
    if ($reference_file) {
	$ref_option = " -r $reference_file_path ";
    }
    
    my $cmd = "../gtsimsrch/src/simsearch -i $filename $ref_option -o $filename.out";

    print STDERR "running command $cmd...\n";
    system($cmd);


    system("perl ../gtsimsrch/src/agmr_cluster.pl < $filename.out > $filename.out.clusters");

    my $results;
    open(my $F , "<", $filename.".out.clusters") || die "Can't open file $filename.out";

    my @data;
    my @line;
    my $html = "<table cellspacing=\"20\" cellpadding=\"20\" border=\"1\">";
    my $group =1;
    
    while(<$F>) {
	chomp;
	if (/^#/) { next; }
	@line = split /\s+/;
	$html .= '<tr><td>'.$group.'</td><td>'. join('<br />', @line[4..@line-1])."</td></tr>\n";
	push @data, [ $line[0], $line[1], $line[2], $line[3], join("<br />", @line[4..@line-1]) ];
	$group++;
    }
    $html.="</table>\n";
    close($F);
    
    # plot the agmr score distribution histogram using the 6th column in $filename.out
    #
    # (use gnuplot or R)

#    $c->stash->{template} = '/tools/simsearch/results.mas';

    $c->stash->{rest} = { data => \@data };
    
}

1;

