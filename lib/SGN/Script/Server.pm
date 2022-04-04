package SGN::Script::Server;
use Moose;
use SGN::Devel::MyDevLibs;

use SGN::Exception;

extends 'Catalyst::Script::Server';

if (@ARGV && "-r" ~~ @ARGV) {
    $ENV{SGN_WEBPACK_WATCH} = 1;
    my $uid = (lstat("js/node_modules"))[4];
    print STDERR "\n\nSGN_WEBPACK_WATCH: USING USER ID $uid FOR npm...\n\n\n";
    system("cd js && sudo -u $uid npm run build-watch &");
} 

1;
