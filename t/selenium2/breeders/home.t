
use strict;

use lib 't/lib';

use Test::More 'tests' => 11;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    sleep(1);
    
    $t->get_ok("/breeders/home");
    sleep(3);

    $t->find_element_ok('//a[contains(@href, "/breeders/manage_programs")]', 'xpath', 'find on breeder home page link to breeding programs');
    $t->find_element_ok('//a[contains(@href, "/breeders/accessions")]', 'xpath', 'find on breeder home page link to breeding programs');
    $t->find_element_ok('//a[contains(@href, "/breeders/trials")]', 'xpath', 'find on breeder home page link to breeding programs');
    $t->find_element_ok('//a[contains(@href, "/breeders/genotyping")]', 'xpath', 'find on breeder home page link to breeding programs');
    $t->find_element_ok('//a[contains(@href, "/breeders/locations")]', 'xpath', 'find on breeder home page link to breeding programs');
    $t->find_element_ok('//a[contains(@href, "/breeders/crosses")]', 'xpath', 'find on breeder home page link to crosses');
    $t->find_element_ok('//a[contains(@href, "/breeders/phenotyping")]', 'xpath', 'find on breeder home page link to phenotyping');
    $t->find_element_ok('//a[contains(@href, "/fieldbook")]', 'xpath', 'find on breeder home page link to fieldbook');
    $t->find_element_ok('//a[contains(@href, "/barcode")]', 'xpath', 'find on breeder home page link to barcode');
    $t->find_element_ok('//a[contains(@href, "/breeders/download")]', 'xpath', 'find on breeder home page link to breeding programs');

    });

$t->driver()->close();
done_testing();
