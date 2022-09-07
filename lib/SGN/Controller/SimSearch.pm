
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


    my $cmd = "../gtsimsrch/src/simsearch -i $filename -o $filename.out";

    print STDERR "running command $cmd...\n";
    system($cmd);

    my $results;
    open(my $F , "<", $filename.".out") || die "Can't open file $filename.out";
    while(<$F>) {
	$results .= $_;
    }
    
    $c->body($results);
    
}

1;

