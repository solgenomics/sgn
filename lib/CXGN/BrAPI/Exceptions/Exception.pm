package CXGN::BrAPI::Exceptions::Exception;
use Moose;

with 'Throwable';

has message => (
    isa => 'Maybe[Str]',
    is => 'ro'
);

1;