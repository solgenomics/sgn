use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html info_table_html columnar_table_html/;
my $page=CXGN::Page->new('us_tomato_sequencing.html','html2pl converter');
$page->header(('About the US Tomato Sequencing Project') x 2);

print <<EOH;
<p>The US Tomato Sequencing project is part of the larger <a href="/about/tomato_sequencing.pl">International Tomato Sequencing Project</a>, which is in turn part of the broad <a href="/solanaceae-project/index.pl">International Solanaceae Genome (SOL) Project</a>.</p>
<!-- <p class="boxbgcolor5"><b>Note:</b> Summer 2010 Internship Positions are available!
Please see <a href="#internships">below</a>!<br /></p> -->

EOH

print info_section_html( title => 'Principal Investigators',
			 contents =>
			 info_table_html(__border => 0,
					 'Project PIs' =>
					 columnar_table_html( headings => ['PI','Contact','Organization'],
							      data =>
							      [ 
								['Jim Giovannoni','jjg33@cornell.edu','Boyce Thompson Institute for Plant Research (BTI)'],
								['Bruce Roe', 'broe@ou.edu', 'University of Oklahoma'],
								['Lukas Mueller','lam87@cornell.edu','Boyce Thompson Institute for Plant Research (BTI)'],
								['Stephen Stack','sstack@lamar.colostate.edu','Colorado State University'],
								['Joyce Van Eck','jv27@cornell.edu','Boyce Thompson Institute for Plant Research (BTI)'],
							      ],
							    ),
					 'Project Manager and Educational Outreach Coordinator' => <<EOH,
          <p>Joyce Van Eck<br />
          The Boyce Thompson Institute for Plant Research<br />
          Tower Rd.<br />
          Ithaca, NY 14853-1801<br />
          USA<br />
          e-mail: <a href="mailto:jv27\@cornell.edu">jv27\@cornell.edu</a><br />
          Phone: 607-254-1284<br />
          Fax: 607-254-1284</p>
EOH
					 'Funding' => <<EOH,
          The US Project is funded by the <a href="http://www.nsf.gov">National Science Foundation</a>,
          Plant Genome Research Program, Grant <a href="http://www.nsf.gov/awardsearch/showAward.do?AwardNumber=0421634">#0421634</a>.
EOH
					),
		       );

print info_section_html( title => 'Project Summary',
			 contents => <<EOH,

       <h4>Scientific objectives and approaches</h4>

          <p>The tomato genome is comprised of approximately 950 Mb of
          DNA -- more than 75\% of which is heterochromatin and
          largely devoid of genes. The majority of genes are found
          in long contiguous stretches of gene-dense euchromatin
          located on the distal portions of each chromosome arm. As
          part of an international consortium, these gene rich
          regions of the tomato genome will be sequenced using a
          minimal tiling path approach. The US project is geared
          towards establishing the foundations for sequencing by
          establishing 2 additional BAC libraries, obtaining BAC
          end sequence (400,000 reads) and sequencing a sheared
          library. The Sol Genomics Network (<a href="/">SGN</a>),
          an organism database devoted to the genomics of solanaceous species,
          will be expanded to accommodate and incorporate all of
          the sequencing, annotation and mapping information for
          all 12 tomato chromosomes and begin integrating SGN with
          other databases through a series of shared, common
          software and algorithms so as to create a network of
          plant genomic information. Currently, the US has been
          assigned chromsomes 1, 10 and 11 for full sequencing in a
          follow-up project.</p>

        <h4>Broader impact of the project</h4>

          <p>Sequencing the tomato genome is the cornerstone of a
          larger international effort: "The International
          Solanaceae Genome Project". The goal is to establish a
          network of information, resources and scientists to
          tackle two of the most significant questions in plant
          biology/agriculture:</p>
          <ol>
          <li>How can a common set of
          genes/proteins give rise to a wide range of
          morphologically and ecologically distinct organisms that
          occupy our planet?</li>
          <li>How can a deeper understanding of
          the genetic basis of plant diversity be harnessed to
          better meet the needs of society in an
          environmentally-friendly and sustainable manner?</li>
          </ol>
          <p>The family Solanaceae is ideally suited to answer both of
          these questions for reasons that will be enumerated in
          this proposal. Immediate application of the tomato genome
          sequence to other solanaceous species is possible since
          the tomato genome is connected to these other species by
          comparative genetic maps and the level of microsynteny
          appears to be well conserved with respect to gene content
          and order. Finally, because the Solanaceae represents a
          distinct and divergent sector of flowering plants,
          distant from Arabidopsis, Medicago and rice, the tomato
          genome sequence will provide a rich resource for
          investigating the forces of gene and genome evolution
          over long periods of evolutionary time.</p>
EOH
		       );

print info_section_html(title => 'Educational Outreach',
			contents => <<EOH
          <p>The mission of our
          educational outreach program is to provide
          research-training opportunities in computational genomics
          to undergraduates and high school students. By offering
          hands-on training in computational genomics to these
          students, we hope to expose them to the nature of
          genomics information/datasets and the myriad of
          fascinating biological questions that can be addressed
          through the application of computational tools to
          genomics information.</p>

          <p>The introduction of high capacity DNA sequencing has
          changed forever the nature of life sciences research. No
          longer are biologists limited by the ability to collect
          genetic information, but rather they are limited by the
          ability to turn this information into discovery.
          Organizing, storing, curating and extracting biological
          insights from these data is the central challenge facing
          biology today. To meet this challenge, we must attract
          and train students who are mathematically and
          computationally savvy and yet have attained a level
          of biological intuition that can lead them to tackling
          important biological questions. These students will have
          as part of their undergraduate training hands-on
          experience in computational genomics. Their research
          experience will also be supplemented through a number of
          new course offerings in computational biology now being
          offered at Cornell (or to be offered soon) as well as a
          genomics minor that is now being developed at
          Cornell.</p>

    <h4>Student Research Opportunities</h4>
    <a name="internships"></a>
          <p>Undergraduate positions are available at the <a href="/">SOL
          Genomics Network</a>, a database for
          genomic information of the nightshade plant family, which
          includes important crop species such as tomato, potato
          and eggplant.</p>

          <p>We are seeking highly motivated individuals with strong
          interests in computers and biology to work on different
          bioinformatics problems, including web-programming of new
          tools for plant scientists and designing and implementing
          relational databases for genomics applications.</p>

          <p>Knowledge of Perl, SQL, and Linux, BSD or other UNIX-like
          operating systems are desirable, but not required.</p>

          <p>Hourly paid positions and honor student positions are
          available. Work-study students are encouraged to apply.
          To apply, please send a summary of prior
          experience/interests, list of relevant course work and
          names/e-mail addresses of at least 2 references by e-mail
          to: Joyce Van Eck, <a href="mailto:jv27\@cornell.edu">jv27\@cornell.edu</a>.</p>
			
<!--    <h4>Summer 2010 Internships</h4>

<p>Summer internships will be available at the <a href="/">Sol Genomics Network</a> for college undergraduates.</p>

<p>Additional information regarding the internship is available in the flyer. <a href="/documents/help/about/internships_2010/internship_poster_2010.pdf">[pdf]</a></li></p>

   <ul>
    <li>Application form <a href="/documents/help/about/internships_2010/undergrad_app_internship_2010.pdf">[pdf]</a> </li>
    <li>Recommendation form <a href="/documents/help/about/internships_2010/2010_recommendation_form.pdf">[pdf]</a></li>
	
</ul>	  
<p>Application materials are due by March 08, 2010.</p> -->

EOH
		       );

$page->footer();
