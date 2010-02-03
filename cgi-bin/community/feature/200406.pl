use strict;
use CXGN::Page;
my $page=CXGN::Page->new('200406.html','html2pl converter');
$page->header('The Van Der Knaap Lab');
print<<END_HEREDOC;

  <center>
    <h1>The van der Knaap lab</h1>

    <p class="footnote"><img src="/static_content/community/feature/200406-1.jpg" width="720" height=
    "540" border="0" alt="Members of the van der Knaap lab" /> From
    Left: Marin Brewer, Amy Barrett, Maria Stillitano, Nic Welty,
    Erin Schaffner, Jenny Moyseenko; Esther van der Knaap, Jason
    Dickey, and Han Xiao</p>
  </center>

  <p><img src="/static_content/community/feature/200406-3.jpg" width="377" height="300" border="0"
  align="right" hspace="15" vspace="10" alt="rectangle fruit" />
  Breeding and mutation analysis in tomato have resulted in a
  diverse germplasm collection, providing a rich resource for
  studies on fruit morphology. Fruit morphological changes often
  occur during ovary development prior to pollination or during
  maturation of the fruit after pollination and fertilization.
  Therefore, tomato varieties displaying altered fruit shape
  provide unique insights into developmental processes controlling
  ovary and fruit growth and maturation. Understanding the
  molecular genetic basis of diversity in fruit form will allow
  insights into evolutionary processes in tomato as well as other
  fruit-bearing crops, and modification of developmental processes
  regulating ovary and fruit formation.</p>

  <p>In our laboratory, the basis of variation in tomato fruit
  shape is studied by taking on a multi-tiered approach. Firstly,
  we are performing a <span style="color:red">genetic</span>
  analysis to identify loci that control variation in fruit shape
  (<a href=
  "http://www.oardc.ohio-state.edu/vanderknaap/documents/longjohn.pdf">van
  der Knaap et al., 2002</a>; <a href=
  "http://www.oardc.ohio-state.edu/vanderknaap/documents/stufferms.pdf">
  van der Knaap and Tanksley 2003</a>). Selected loci will be
  fine-mapped to allow identification of the genes underlying the
  trait (<a href=
  "http://www.oardc.ohio-state.edu/vanderknaap/documents/sun.pdf">van
  der Knaap and Tanksley, 2001</a>; van der Knaap et al, manuscript
  in preparation). Secondly, we are conducting <span style=
  "color:red">developmental</span> analyses to describe when
  changes in fruit shape occur during ovary and/or fruit growth. In
  addition, we want to know which tissues(s) in the ovary or fruit
  display altered growth characteristics to allow changes in final
  fruit shape. Thirdly, we are taking a <span style=
  "color:red">molecular</span> approach to identify genes with
  altered expression levels during ovary and fruit growth. Also, we
  are identifying genes with different levels of expression due to
  allelic variation at fruit shape loci. This information will
  allow insights into networks of genes and biochemical processes
  potentially downstream from fruit shape loci, and how fruit
  morphology is regulated. Lastly, we are taking a <span style=
  "color:red">bioinformatic</span> approach by developing software
  to semi-automatically quantify fruit morphological
  characteristics and integrating analysis of these shape
  characteristics with gene expression and genotype
  information.</p>

  <p><img src="/static_content/community/feature/200406-2.jpg" width="720" height="486" border="0"
  alt="circle fruit" /></p>

  <h2>Contact Information</h2>

  <p>Esther van der Knaap<br />
  Department of Horticulture and Crop Science<br />
  204A Williams Hall, The Ohio State University/OARDC<br />
  Wooster OH 44691<br />
  Tel:330-263-3822; FAX:330-263-3887; email: <a href=
  "mailto:vanderknaap.l\@osu.edu">vanderknaap.1\@osu.edu</a><br />
  <a href=
  "http://www.oardc.ohio-state.edu/vanderknaap/">http://www.oardc.ohio-state.edu/vanderknaap</a><br />
  </p>
END_HEREDOC
$page->footer();