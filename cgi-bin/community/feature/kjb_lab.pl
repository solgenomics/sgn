use strict;
use CXGN::Page;
my $page=CXGN::Page->new('kjb_lab.html','html2pl converter');
$page->header('Bradford Lab');
print<<END_HEREDOC;

  <div>
    <p dir="ltr" style="text-align: center"><span style=
    "font-weight: bold"><span style="font-size: 14pt">The Bradford
    Lab</span></span></p>

    <p dir="ltr" style="text-align: center"><img src=
    "/static_content/community/feature/kjb_lab_people.jpg" alt="" /></p>

    <p dir="ltr" style="text-align: center">Dr. Bradford's group as
    of fall 2003.<br />
    From left to right: Sunitha Gurusinghe (postdoc), Andres
    Schwember (MS student), Dr. Kent Bradford, Jason Aryris (Ph.D.
    student), Peetambar Dahal (Staff Research Associate), and Derek
    Bewley (sabbatical visitor).</p>

    <p dir="ltr" style="text-align: left">&nbsp;</p>

    <p dir="ltr" style="text-align: left">Dr. Kent J. Bradford is a
    professor of the Department of Vegetable Crops and Weed
    Science, founder and director of the Seed Biotechnology Center,
    UC Davis.</p>

    <p dir="ltr" style="text-align: left">Dr. Bradford's research
    interests are focused on seed biology, including:</p>

    <ol>
      <li>modeling of germination in seed populations,</li>

      <li>genetics, molecular biology and biochemistry of seed
      germination and dormancy,</li>

      <li>seed quality, enhancement and longevity, and</li>

      <li>Seed Biotechnology Center.</li>
    </ol>

    <p dir="ltr" style="text-align: left">Dr. Bradford's group uses
    tomato seeds as their experimental system to investigate the
    biochemical and molecular mechanisms controlling germination
    and dormancy. Their research has focused on cell wall
    hydrolases that might degrade the endosperm cell walls. They
    have found and investigated a number of genes involved in this
    process, such as LeMAN2, LeMAN1, LeXET4, GluB, Chi9, and
    LeEXP4, LeXPG1, LVA-P1, LeEXP8 and LeEXP10. An intriguing
    recent discovery was the gene LeSNF4 &mdash; a subunit of a
    protein kinase, regulated by ABA &mdash; which is involved in
    sugar-sensing and metabolic regulation. Work in this area is
    continuing with the support of NSF and USDA-NRICGP grants.</p>

    <p dir="ltr" style="text-align: left">For more information,
    please visit the Dr. Bradford's <a href=
    "http://www.plantsciences.ucdavis.edu/bradford/bradford.htm">website</a>
    at UC Davis.</p>
  </div>
END_HEREDOC
$page->footer();
