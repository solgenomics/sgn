#!/bin/bash

unset PERL5LIB

echo "PERL5LIB is now $PERL5LIB";

export PERL5LIB=/usr/local/share/cassava-site/cassava/lib:/usr/local/share/cassava-site/sgn/lib/:/usr/local/share/cassava-site/cxgn-corelibs/lib/:/usr/local/share/cassava-site/Phenome/lib/:/usr/local/share/cassava-site/tomato_genome/lib/:/usr/local/share/cassava-site/Cview/lib/:/usr/local/share/cassava-site/biosource/lib/:/usr/local/share/cassava-site/local-lib/lib/perl5:/usr/local/share/cassava-site/ITAG/lib/

echo "Starting catalyst server...";
    
echo "PERL5LIB is $PERL5LIB";

mkdir /tmp/sgn-tmp

screen ./bin/sgn_server.pl -r --fork

exit;


########

=head1 NAME

./run_cassava_production_server.sh

=head1 DESCRIPTION

Use this script to run the cassavabase production server. It sets the PERL5LIB correctly for the production server environment, and then starts the Catalyst server. It does not restart the nginx server (maybe in the future). It also does not stop a running server.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut
