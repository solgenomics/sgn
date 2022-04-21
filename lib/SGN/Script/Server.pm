package SGN::Script::Server;
use Moose;
use SGN::Devel::MyDevLibs;

use SGN::Exception;

extends 'Catalyst::Script::Server';

if (@ARGV && "-r" ~~ @ARGV) {
    $ENV{SGN_WEBPACK_WATCH} = 1;
    my $uid = (lstat("js/package.json"))[4];
   my $user_exists = `id $uid 2>&1`;    
    if ($user_exists =~ /no such user/) {
        `useradd -u $uid -m devel`;        
    }    
    print STDERR "\n\nSGN_WEBPACK_WATCH: USING USER ID $uid FOR npm...\n\n\n";
    system("cd js && sudo -u $uid npm run build-watch &");
} 

1;
