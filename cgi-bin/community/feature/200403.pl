use strict;
use CXGN::Page;
my $page=CXGN::Page->new('200403.html','html2pl converter');
$page->header('The Kuhlemeier Lab');
print<<END_HEREDOC;

  <center>
    <h1>The Kuhlemeier Lab</h1>
  </center>

  <p>Our long-term interest has been the regulation of phyllotaxis.
  We want to understand at the molecular level, how plants position
  their lateral organs in specific spatial patterns, in particular
  spirals. We use tomato, because its shoot meristem can be grown
  in sterile culture and is amenable to micromanipulation.</p>

  <center>
    <div style=
    "width:650px; text-align:left; font-size: smaller; font-style: italic">
    <img src="/static_content/community/feature/200403-1.jpg" border="0" width="640" height="480"
      alt="" /><br />
      Figure 1 Tomato vegetative shoot apical meristem with central
      zone removed by infrared laser ablation (Reinhardt et al
      Development (2003) 130, 4073
    </div>
  </center>

  <div align="right" style=
  "width:250px; float:right; text-align:left; font-size: smaller; font-style: italic">
  <img src="/static_content/community/feature/200403-2.png" border="0" width="234" height="278"
    alt="" /><br />
    Figure 2 Recombinant inbreds between P. <i>hybrida</i> W138 and
    P. <i>integrifolia</i>
  </div>

  <p>A recently started project deals with the molecular ecology of
  wild Petunia species. P. axillaris is pollinated by hawkmoths,
  while P. integrifolia is pollinated by bees. The two species
  differ in flower architecture, color, odor and nectar production.
  We have made recombinant inbred lines between each of these
  species and the high transposition line Petunia hybrida W138 and
  are now in the process of molecular, physiological and ecological
  characterization of the material.</p><br clear="all" />
  You can find us at <a href=
  "http://www.botany.unibe.ch">http://www.botany.unibe.ch</a> click
  development
END_HEREDOC
$page->footer();