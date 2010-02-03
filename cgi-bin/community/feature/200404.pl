use strict;
use CXGN::Page;
my $page=CXGN::Page->new('200404.html','html2pl converter');
$page->header('The Kuhlemeier Lab');
print<<END_HEREDOC;

  <center>
    <h1>The Li Lab</h1>

    <div style="text-align: center; width: 650">
      <img src="/static_content/community/feature/200404-1.jpg" width="640" height="480" border="0"
      alt="The Li Lab" /><br />
      <strong>Dr. Li's group as of spring 2004</strong><br />
      From left to right: Zhongxin Guo (Ph.D. student), Jinhuan
      Chen (MS student), Dr. Chuanyou Li, Jing Qi (Ph.D. student),
      Wenguang Zheng (Ph.D. student), Fang Liu (Ph.D. student) and
      Lei Zhang (M.S. student).
    </div>
  </center>

  <div style="text-align: justify">
    <p>Our laboratory is mainly interested in jasmonic acid (JA)
    signaling and regulation of JA-mediated plant responses to
    insects.</p>

    <p><strong>Genetic dissection of the JA signaling
    pathway</strong><br />
    The fatty acid-derived plant hormone JA plays a key role in the
    regulation of development, reproduction and systemic induced
    resistance to herbivore attack. Compared to the five classic
    plant hormones, relatively little is known about the molecular
    mechanisms governing the JA action, especially in the area of
    JA-mediated defense responses to insects. Using tomato as a
    genetic model, we have been able to identify several mutants
    that are deficient in systemic defense responses.
    Interestingly, map-based cloning of these mutants identified
    genes that are involved in JA biosynthesis and signaling.
    Grafting experiments using a JA biosynthesis mutant
    (<em>spr2</em>) and a JA signaling mutant (<em>jai1</em>)
    demonstrated that JA or a derivative, rather than the
    18-amino-acid peptide systemin is the long-distance mobile
    "wound signal" for systemic defense responses and that the
    biosynthesis of JA is regulated by systemin. A long-term goal
    of our research is to identify most, if not all, of the genes
    that are involved in systemin/JA-mediated wound response
    pathway and elucidate how these genes are regulated.</p>

    <p><strong>Identification of agriculturally important genes in
    rice and tomato</strong><br />
    Another aspect of our research is to identify agriculturally
    important genes in the model system of rice and tomato, using a
    map-based cloning approach.</p>
  </div><strong>Selected Publications:</strong>

  <ol style="1">
    <li>Li C, Liu G, Xu C, Lee G, Bauer P, Ganal M, Ling, H and
    Howe GA (2003) The tomato <em>Suppressor of
    prosystemin-mediated response2</em> gene encodes a fatty acid
    desaturase required for the biosynthesis of jasmonic acid and
    the production of a systemic wound signal for defense gene
    expression. The Plant Cell. 15, 1646-1661</li>

    <li>Li L, Li C, Lee GI and Howe GA (2002) Distinct roles for
    jasmonate synthesis and action in the systemic wound response
    of tomato. Proc Natl Acad Sci USA. 99, 6416-6421</li>

    <li>Li C, Williams MM, Loh Y-T, Lee GI and Howe GA (2002)
    Resistance of cultivated tomato to cell content-feeding
    herbivores is regulated by the octadecanoid-signaling pathway.
    Plant Physiology. 130, 494-503</li>

    <li>Li L, Li C and Howe GA (2001) Genetic analysis of wound
    signaling in tomato: evidence for a dual role of jasmonic acid
    in defense and female fertility. Plant Physiology 127,
    1414-1417</li>

    <li>Howe GA, Li L, Lee GI, Li C and Shaffer D (2002) Genetic
    dissection of induced resistance in tomato. In, "Induced
    resistance in plants against insects and diseases". A. Schmitt
    &amp; B. Mauch-Mani, Eds. Vol. 26, pp.47-52</li>

    <li>Jia J, Zhang D, Li C, Qu X, Wang S, Chamarerk V, Nguyen HT
    and Wang B (2001) Molecular mapping of a rice thermo-sensitive
    genic male sterile gene using AFLP, RFLP and SSR techniques.
    Theor Appl Genet 103, 607-612</li>
  </ol>

  <p>For more information, please visit Dr. Li's web page at
  <a href=
  "http://www.genetics.ac.cn/xywwz/Faculty/LiChuanyou.htm">http://www.genetics.ac.cn/xywwz/Faculty/LiChuanyou.htm</a>.</p><br />


  <p style="font-family: monospace">Chuanyou Li<br />
  Institute of Genetics and Developmental Biology,<br />
  5 Datun Road, Chaoyang District, Beijing 100101, China<br />
  Tel: 8610-64865313<br />
  Fax: 8610-64873428<br /></p>
END_HEREDOC
$page->footer();