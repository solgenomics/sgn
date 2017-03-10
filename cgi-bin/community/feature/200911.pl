use strict;

use CXGN::Page;

my $page = CXGN::Page->new("SGN Featured Lab: The Rose Lab, School of integrative plant science", "Adri");
# my $page = CXGN::Page->new("SGN Featured Lab: The Rose Lab, Department of Plant Biology, Cornell University", "Adri");

$page->header("The Rose Lab, School of integrative plant science", "The Rose Lab, School of integrative plant science");
# $page->header("The Rose Lab, Department of Plant Biology, Cornell University", "The Rose Lab, Department of Plant Biology, Cornell University");

print <<HTML;

<center>
<br>
<br>
<p style="font-size:20px">
  Please visit the <a href="http://labs.plantbio.cornell.edu/rose/index.html" target="blank">Rose Lab official website</a>
</p>

<br>
<br>
</center>

<!-- <p>Research in the Rose lab broadly spans the structure, function and practical uses of plant cell walls. We have a long standing interest in cell wall metabolism as it relates to plant growth, development and interactions with pathogens, but additionally, cellulosic cell walls represent a central component of the biofuels industry, as well as providing the building blocks for a many plant-derived products.</p>

<center><img src="/static_content/community/feature/200911-group.jpg" /></center>

<p><em>Pictured left to right standing: Sang Jik Lee, Yonghua He, Raphael Carneiro, Trevor Yeats, Joss Rose, Greg Buda, Gloria Lopez Casado, Laetitia Martin, Amit Levy, Ana Letitia Bertolo;  left to right kneeling/sitting: Dhruv Desai, Tal Isaacson, Antonio Matas, Zhiying Zhao. Not pictured: Brynda Beeman and Sam Mullin</em></p>

<p><strong>The plant cell wall proteome ("secretome"):</strong> We are applying high throughput genomics and proteomics techniques to identify and characterize novel cell wall proteins with currently unknown and unexploited functions. These strategies include both functional screens for, and computational prediction of, the genes encoding secreted proteins, as well as the isolation and structural characterization of extracellular proteins. Through an NSF Plant Genome Research grant, we are developing a more comprehensive catalog and functional inventory of the plant cell wall proteome, or "secretome" (<a href="http://solgenomics.net/secretom">http://solgenomics.net/secretom</a>), based on two principal experimental systems.</p>

<p><strong>Fruit Development and Ripening:</strong> Tomato fruit development provides an opportunity to study cell wall metabolism associated with both cell expansion and fruit softening. In addition to investigating the dynamics of the polysaccharide extracellular matrix we have several ongoing projects studying the importance of the cuticle, a highly specialized lipidic cell wall, to fruit physiology and quality traits.</p>
<p>The cuticle appears to have a critical, and yet poorly understood, influence on fruit texture, and plays an important role in regulating the rate of desiccation and tissue collapse, as well as limiting microbial infection. We have been developing tools to better understand the processes that underly cuticle synthesis, assembly and restructuring. These include a new 3D imaging technique, which has revealed several previously undescribed architectural features of the tomato fruit cuticle. We are now characterizing the composition and structural development of the cuticle in wild and domesticated tomato species, as well analyzing as a number of recently identified cuticle associated and long shelf-life mutants.</p>

<p><strong>Plant-Pathogen Interactions:</strong> The plant cell wall provides the first line of defense against microbial pathogens and the cocktails of proteins that are secreted into the plant apoplast by the host and pathogen play critical roles in the initiation and progression of infection. However, insights into the identity, function and regulation of these secreted protein populations ("secretomes") is still rudimentary, particularly in the case in the case of eukaryotic pathogens. To better understand the qualitative and quantitative changes in the cell wall proteome during pathogenesis, we have developed and applied a suite of analytical tools to study the tomato-<em>Phytophthora infestans</em> pathosystem, focusing particularly interested on the co-evolution of the host and pathogen secretomes. Our data provide evidence for a molecular arms race between suites of cell wall hydrolases, from plants and microbes, and cognate inhibitor proteins that are secreted by the other partner.</p>

<p><strong>Biofuels and Bioenergy Crops:</strong> The hemicellulose-cellulose matrix of plant walls provides a major source of carbon to the biofuel industry and demand for research in this area is increasing dramatically, given current concerns regarding energy security and global climate change. We are currently characterizing new families of wall-associated proteins and gaining a better understanding of plant wall dynamics, which is suggesting strategies to generate plants with enhanced potential as bioenergy crops. For example, plant glycosyl hydrolases (GHs) are thought to play a central role in many aspects of cell wall assembly, architectural remodeling and disassembly during cell growth and differentiation. However, given the structural diversity and large sizes of the GH families, the specific biological functions of relatively few genes have been characterized to date. In this regard, we have targeted several GH families that contain discrete divergent subclasses with a modular structure, and have focused on characterizing the biochemical and biological functions of representative isozymes from tomato and Arabidopsis.</p>

<hr>

<h4>Selected Publications</h4>

<p>Isaacson, T., Kosma, D.K., Buda, G.J., He, Y., Yu, B., Pravitasari, A., Batteas, J.D., Stark, R.E., Jenks, M.A. and Rose, J.K.C. (2009) Cutin deficiency in the tomato fruit cuticle consistently affects resistance to microbial infection and biomechanical properties, but not transpirational water loss. <em>The Plant Journal</em> 60: 363-377.</p>

<p>Buda, G.J., Isaacson, T., Matas, A.J., Paolillo, D.J. and Rose, J.K.C. (2009) Three dimensional imaging of plant cuticle architecture using confocal scanning laser microscopy. <em>The Plant Journal</em> 60: 378-385.</p>

<p>Matas, A.J., Gapper, N., Chung, M.-Y., Giovannoni, J.J. and Rose, J.K.C. (2009) Biology and genetic engineering of fruit maturation for enhanced quality and shelf-life. <em>Current Opinion in Biotechnology</em> 20: 197-203.</p>

<p>Damasceno, C.M.B., Bishop, J.G., Ripoll, D.R., Win, J., Kamoun, S. and Rose, J.K.C. (2008) The structure of the glucanase inhibitor protein (GIP) family from <em>Phytophthora</em> species and co-evolution with plant endo-&beta;-1,3-glucanases. <em>Molecular Plant-Microbe Interactions</em> 21: 820-830.</p>

<p>Yeats, T.H. and Rose, J.K.C. (2008) The biochemistry and biology of extracellular plant lipid-transfer proteins (LTPs) <em>Protein Science</em> 17: 191-198.</p>

<p>Lopez-Casado, G., Urbanowicz, B.R., Damasceno C.M.B. and Rose J.K.C. (2008) Plant glycosyl hydrolases and biofuels: a natural marriage. <em>Current Opinion in Plant Biology</em> 11: 329-337.</p>

<p>Saladié, M., Matas, A.J., Isaacson, T.  Jenks, M.A., Goodwin, S.M., Niklas, K.J., Xiaolin, R., Labavitch, J.M., Shackel, K.A., Fernie, A.R., Lytovchenko, A., O'Neill, M.A., Watkins, C.B. and Rose, J.K.C. (2007) A re-evaluation of the key factors that contribute to tomato fruit softening and integrity. <em>Plant Physiology</em> 144: 1012-1028.</p>

<p>Vicente, A.R., Saladié, M., Rose, J.K.C. and Labavitch, J.M. (2007) The linkage between cell wall metabolism and the ripening-associated softening of fruits: looking to the future. <em>Journal of the Science of Food and Agriculture</em> 87: 1435-1448.</p>

<p>Urbanowicz, B.R., Catalá, C., Irwin, D., Wilson, D.B., Ripoll, D.R. and Rose, J.K.C. (2007) A tomato endo-&beta;-1,4-glucanase, SlCel9C1, represents a distinct subclass with a new family of carbohydrate binding modules (CBM49). <em>Journal of Biological Chemistry</em> 282: 12066-12074.</p>

<p>Urbanowicz, B.R., Bennett, A.B., Catalá, C., del Campillo, E., Hayashi, T., Henrissat, B., Höfte, H., McQueen-Mason, S., Patterson, S., Shoseyov, O., Teeri, T. and Rose, J.K.C. (2007) Structural organization and a standardized nomenclature for plant endo-1,4-&beta;-glucanases of glycosyl hydrolase family 9. <em>Plant Physiology</em> 144: 1693-1696.</p>

<h4>Contact Information</h4>
Dr. Jocelyn Rose<br />
Associate Professor<br />
Department of Plant Biology,<br />
412 Mann Library Building<br />
Cornell University, Ithaca, NY 14853 USA<br />
<br />
Telephone: (+1) 607-255-4781<br />
Fax: (+1) 607-255-5407<br />
<br />
<a href="http://labs.plantbio.cornell.edu/rose">http://labs.plantbio.cornell.edu/rose</a><br />
<a href="http://solgenomics.net/secretom">http://solgenomics.net/secretom</a><br />
<a href="http://cisbc.net">http://cisbc.net</a> -->

HTML

    $page->footer();
