use Test::Most;

use lib 't/lib';

use URI::Escape;

use SGN::Test::WWW::Mechanize skip_cgi => 1;
use SGN::Test::Data qw/ CXGN::Biosource::Schema create_test /;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->with_test_level( local => sub {

   my $org = create_test( 'Organism::Organism' );

   $mech->get( '/organism/'.uri_escape($org->species).'/genome' );
   is $mech->status, 404, 'got a 404 if the organism has no genome_page organismprop';

   # this prop will get cascade-deleted afterward
   $org->create_organismprops({ genome_page => 1 }, { autocreate => 1 });

   $mech->get_ok( '/organism/'.uri_escape($org->species).'/genome' );
   $mech->content_contains( $org->species );
   $mech->content_lacks( 'BLARG1', 'no assembly listed yet' );

   my $genome_assembly_cvt = get_genome_assembly_cvt( $org->result_source->schema );

   my $assembly = create_test('BsSample', {
       sample_name => 'BLARG1',
       description => 'First assembly of the Blargopodus genome',
       type_id     => $genome_assembly_cvt->cvterm_id,
       organism_id => $org->organism_id,
   });

   $mech->get_ok( '/organism/'.uri_escape($org->species).'/genome' );
   $mech->content_contains('BLARG1', 'BLARG1 assembly is listed');

   my $annotation = create_test('BsSample', {
       sample_name => 'ITAGblarg1',
       description => 'annotation of the BLARG1 assembly by ITAG',
       type_id     => $genome_assembly_cvt->cvterm_id,
       organism_id => $org->organism_id,
   });

   create_test('BsSampleRelationship', {
       object => $annotation,
       subject => $assembly,
       type => { name => 'annotates' },
   });

   $mech->get_ok( '/organism/'.uri_escape($org->species).'/genome' );
   $mech->content_contains( 'BLARG1',     'BLARG1 assembly is listed');
   $mech->content_contains( 'ITAGblarg1', 'ITAGblarg1 annotation is listed');

   $mech->get_ok( '/genomes', 'got genome index page' );
   $mech->content_contains( $org->species, 'genome index page contains the test species' );

});

$mech->get_ok( '/genomes', 'got genome index page ok' );

done_testing;


sub get_genome_assembly_cvt {
    my $schema = shift;

    my $genome_assembly_cvt = $schema
        ->resultset('Cv::Cv')
        ->search({ 'me.name' => 'sequence' })
        ->search_related('cvterms', {
            'cvterms.name' => 'reference_genome',
        });

   is $genome_assembly_cvt->count, 1;
   $genome_assembly_cvt = $genome_assembly_cvt->first;

   ok( $genome_assembly_cvt,  "got reference_genome cvt ".eval {$genome_assembly_cvt->cvterm_id});

   return $genome_assembly_cvt;
}

