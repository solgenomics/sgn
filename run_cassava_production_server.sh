#!/bin/bash

unset PERL5LIB

echo "PERL5LIB is now $PERL5LIB";

export PERL5LIB=/usr/local/share/sgn/cassava/lib:/usr/local/share/sgn/bio-chado-schema/lib:/usr/local/share/sgn/local-lib:/usr/local/share/sgn/sgn/lib/:/usr/local/share/sgn/cxgn-corelibs/lib/:/usr/local/share/sgn/Phenome/lib/:/usr/local/share/sgn/tomato_genome/lib/:/usr/local/share/sgn/Cview/lib/:/usr/local/share/sgn/biosource/lib/:/usr/local/share/sgn/local-lib/lib/perl5

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
