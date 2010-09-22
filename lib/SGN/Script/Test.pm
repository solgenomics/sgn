package SGN::Script::Test;
use Moose;
use Try::Tiny;
BEGIN {
    try {
        Class::MOP::load_class('MyDevLibs');
    }
    catch {
        unless ( /Can't locate MyDevLibs\.pm/ ) {
            warn $_;
            die $_;
        }
    }
}

use SGN::Exception;

extends 'Catalyst::Script::Test';

1;
