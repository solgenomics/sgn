
package SGN::Controller::SimSearch;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub simsearch : Path('/tools/simsearch') {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/tools/simsearch/index.mas';
}

sub process_file : Path('/tools/simsearch/processfile') {
    my $self = shift;
    my $c = shift;

    my $upload = $c->request->upload('upload_vcf_file');

    my $filename = $upload->filename();
    $c->stash->{filename} = $filename;
    $c->stash->{template} = '/tools/simsearch/process_file.mas';


    # -i required input file -r reference file (with -i only, input is also used as reference)
    # need to add a pull down with current genotypes for each protocol
    
    my $cmd = "../gtsimsrch/src/simsearch -i $filename -o $filename.out";

    print STDERR "running command $cmd...\n";
    system($cmd);


    system("perl ../gtsimsrch/src/agmr_cluster.pl < $filename.out > $filename.out.clusters");

    my $results;
    open(my $F , "<", $filename.".out.clusters") || die "Can't open file $filename.out";
    while(<$F>) {
	$results .= $_;
    }

    # plot the agmr score distribution histogram using the 6th column in $filename.out
    #
    # (use gnuplot or R)
    
    
    $c->body($results);
    
}

1;

