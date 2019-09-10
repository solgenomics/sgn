package SGN::Script::Server;
use Moose;
use SGN::Devel::MyDevLibs;

use SGN::Exception;

extends 'Catalyst::Script::Server';

if (@ARGV && "-r" ~~ @ARGV) {
    $ENV{SGN_WEBPACK_WATCH} = 1;
    system("cd js && npm run build-watch &");
} 

1;
