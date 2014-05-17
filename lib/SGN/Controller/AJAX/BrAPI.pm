
package SGN::Controller::AJAX::BrAPI;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' };

sub brapi : Chained('/') PathPart('brapi') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $version = shift;
    $c->stash->{api_version} = $version;
    print STDERR "PROCESSING /...\n";
}

sub genotype : Chained('brapi') PathPart('genotype') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $id = shift;
    print STDERR "PROCESSING /brapi/0.1/genotype...\n";
    $c->stash->{genotype_id} = $id;

}

sub genotype_count : Chained('genotype') PathPart('count') Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR "PROCESSING genotype/count...\n";
    $c->res->body("The count for ".$c->stash->{genotype_id}." is 42!");
}

sub genotype_fetch : Chained('genotype') PathPart('fetch') Args(0){ 
    my $self = shift;
    my $c = shift;
    $c->res->body("The genotype is ATGC!");
    

}




1;
