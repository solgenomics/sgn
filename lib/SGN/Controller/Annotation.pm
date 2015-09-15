package SGN::Controller::Annotation;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

SGN::Controller::Annotation - show annotation pages for CG.org. add subroutines for other pages in annotation menu


=cut


sub annotation_index :Path('/annotation/index') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    $c->stash->{template} = '/annotation/index.mas';
}

sub annotation_updates :Path('/annotation/updates') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    $c->stash->{template} = '/annotation/updates.mas';
}

1;
