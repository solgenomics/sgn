require CGI;
print CGI->new->redirect(
    -status => 301,
    -uri => '/genomes/Solanum_lycopersicum/genome_data.pl',
);
