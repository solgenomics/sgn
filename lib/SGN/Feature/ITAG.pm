package SGN::Feature::ITAG;
use Moose;

use MooseX::Types::Path::Class;

use CXGN::ITAG::Pipeline;

extends 'SGN::Feature';

has 'pipeline_base' => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
    coerce   => 1,
);

has 'releases_base' => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
    coerce   => 1,
);

sub pipeline {
    my $self = shift;
    CXGN::ITAG::Pipeline->open( @_, basedir => $self->pipeline_base );
}

sub list_pipelines {

    sort {$b <=> $a}
        CXGN::ITAG::Pipeline->list_pipelines( shift->pipeline_base );

}

# around apache_conf => sub {
#     my ($orig,$self) = @_;

#     my $cgi_url = '/sequencing/itag';
#     my $cgi_bin = $self->path_to('cgi-bin');

#     return $self->$orig().<<EOC;
# Alias $cgi_url  $cgi_bin
# EOC

# }


1;
