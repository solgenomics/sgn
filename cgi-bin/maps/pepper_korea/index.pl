use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('Pepper SNU2 map');
print<<END_HEREDOC;

  <center>
    

    <h3 align="center"><em>Pepper SNU2 map</em></h3>The SNU2 map was
    submitted by JM Lee, SH Nahm, YM Kim and BD Kim of the
    Department of Plant Science, College of Agriculture and Life
    Sciences and Center for Plant Molecular Genetics and Breeding
    Research, Seoul National University, Seoul, Korea. The map is
    described in the following article: Theor Appl Genet (2004)
    108:619-627, "Characterization and molecular genetic mapping of
    microsatellite loci in pepper". Forty six microsatellite loci
    were placed on the SNU-RFLP linkage map, which had been derived
    from the interspecific cross between Capsicum annuum "TF68" and
    Capsicum chinense "Habanero". The current "SNU2" pepper map
    with 333 markers in 15 linkage groups contains 46 SSR and 287
    RFLP markers covering 1,761.5cM with an average distance of
    5.3cM between markers. The following links provide static
    images of the different linkage groups. We are working to
    integrate these map data into the dynamic comparative viewer.

    <ul>
      <li><a href="lg1.pl">Linkage Group 1</a></li>
      <li><a href="lg2.pl">Linkage Group 2</a></li>
      <li><a href="lg3.pl">Linkage Group 3</a></li>
      <li><a href="lg4.pl">Linkage Group 4</a></li>
      <li><a href="lg5.pl">Linkage Group 5</a></li>
      <li><a href="lg6.pl">Linkage Group 6</a></li>
      <li><a href="lg7.pl">Linkage Group 7</a></li>
      <li><a href="lg9.pl">Linkage Group 9</a></li>
      <li><a href="lg10.pl">Linkage Group 10</a></li>
      <li><a href="lg11.pl">Linkage Group 11</a></li>
      <li><a href="lg12.pl">Linkage Group 12</a></li>
      <li><a href="lg13.pl">Linkage Group 13</a></li>
      <li><a href="lg14.pl">Linkage Group 14</a></li>
      <li><a href="lg15.pl">Linkage Group 15</a></li>
      <li><a href="lg16.pl">Linkage Group 16</a></li>
    </ul>
    
  </center>
END_HEREDOC
$page->footer();
