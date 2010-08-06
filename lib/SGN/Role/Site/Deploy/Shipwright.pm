package SGN::Role::Site::Deployment::Shipwright;
use Moose::Role;
use namespace::autoclean;

requires 'path_to';

before 'setup_finalize' => sub {

    my $class = shift;

    # path to the root of the shipwright vessel, if we are in one
    my $vessel = $class->path_to->parent;

    # only set up @INC for shipwright if we are actually in a
    # shipwright vessel
    return unless
        -f $vessel->file('etc','shipwright-perl-wrapper');

    # add the shipwright lib dirs to @INC
    unshift @INC, map $vessel->subdir( @$_ )->stringify,
        [qw[ lib perl5 site_perl ]],
            [qw[ lib perl5 ]];

    $ENV{PATH} = join ':',
        ( map $vessel->subdir(@$_), ['sbin'], ['usr','sbin'], ['usr','bin'] ),
            $ENV{PATH};

    $ENV{PROJECT_NAME} = 'SGN';

};


1;
