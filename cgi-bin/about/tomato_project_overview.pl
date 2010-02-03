use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html columnar_table_html info_table_html/;

my $page=CXGN::Page->new('tomato_project_overview.html','html2pl converter');
$page->add_style(text => <<EOS);
#seqpeople a.person {}
#seqpeople div.org {padding-left: 1em; white-space: nowrap;}
EOS
$page->header(('International Tomato Sequencing Project Overview') x 2);
print info_section_html( title => 'Abstract',
			 contents => <<EOH);
<p>The tomato genome is comprised
of approximately 950 Mb of DNA - more than 75\% of which
is heterochromatin and largely devoid of genes. The
majority of genes are found in long contiguous stretches
of gene-dense euchromatin located on the distal portions
of each chromosome arm. A minimal tiling path of BAC
clones will be identified through this approximately 220
Mb euchromatin. The starting point for sequencing the
genome will be approximately 1500 "seed" BAC clones
individually anchored to the tomato high density genetic
map based on a single, common L. esculentum x L.
pennellii F2 population (referred to as the F2.2000; view
<a href="/cview/map.pl?map_id=9">
map on SGN</a>). Sequencing will proceed on a BAC-by-BAC
basis. Each sequenced anchor BAC will serve as a seed
from which to radiate out into the minimum tiling path.
Identification of the correct next BACs in the
euchromatin minimum tiling path for sequencing will be
based on the use of a BAC end sequence database that will
be created as part of this project, as well as a
fingerprint contig physical map that is currently being
constructed. A subset of the sequenced BACs will be
localized on pachytene chromosomes via FISH (fluorescence
in situ hybridization) to help guide the extension of the
tiling path through the euchromatic arms of each
chromosome and to determine when the heterochromatin and
telomeric regions have been reached on each arm. A
bioinformatics portal will be created for this project
that will be mirrored at several locations around the
world and provide a mechanism by which researchers in
different locations can develop and contribute
bioinformatics tools and information to the project. A
common set of standards for BAC sequencing and finishing,
and for gene nomenclature, and structural and functional
gene annotation (please refer to the <a href=
"/solanaceae-project/index.pl">Solanaceae Project page</a>).
</p>
EOH

print info_section_html( title => 'Objectives',
			 contents => <<EOH);
The objectives of the tomato sequencing project are to:

<ol>
  <li>produce a contiguous sequence of the gene rich,
  euchromatic arms of each of the 12 tomato
  chromosomes</li>

  <li>process and annotate this sequence in a manner
  consistent and compatible with similar data from
  Arabidopsis, rice and other plant species.</li>

  <li>create an international bioinformatics portal for
  comparative Solanaceae genomics which can store,
  process, and make available to the public the sequence
  data and derived information from this project and
  associated genomics activities in other solanaceous
  plants</li>
</ol>
EOH

print info_section_html( title => 'More Project Documents',
			 contents => <<EOH);
<ul>
<li><a href="/about/tomato_sequencing.pl">International Tomato Genome Sequencing Project Home</a></li>
<li><a href="/about/tomato_sequencing_scope.pl">Tomato Sequencing Scope and Completion Criteria</a></li>
<li><a href="/solanaceae-project/index.pl">SOL Project</a></li>
</ul>
EOH

#given people, agencies, and emails, make html to list them
sub people_list {
  my $last_org;
  my $last_domain;
  join "\n",
    map {
      my ($name, $org, $email) = @$_ == 3 ? @$_ : ($_->[0],$last_org,$_->[1]);
#      $org =~ s/([A-Za-z][a-z]*)/ucfirst($1)/eg;
      $name =~ s/([A-Za-z][a-z]*)/ucfirst($1)/eg;
      $last_org = $org;
      my ($id,$domain) = split /@/,$email;
      $domain ||= $last_domain;
      $last_domain = $domain;
      $email = $id.'@'.$domain;
      qq|<a class="person" href="mailto:$email">$name</a><div class="org">$org</div>|
    } @_;
}

print info_section_html
  ( title => 'Participants and Funding',
    contents => ''
    .qq|<div align="right">\n|
    .info_table_html( __multicol => 2,
		      'Est. Total MBases' => 219, 'Est. Total BACs' => 2276,
		    )
    ."</div>\n"
    .columnar_table_html
    (
     headings => [
		   'Chr.',
		   'Country',
		   'People',
		   'Grant Agency',
		   'Target Deadline',
		   'Est. Euchromatin Size (Mb)',
		   'Est. # BACs',
		  ],
     __border => 1,
     __align => 'ccllccc',
     __tableattrs => 'id="seqpeople" cellspacing="0" cellpadding="0"',
     __alt_freq => 2,
     __alt_offset => 1,
     data => [
	      [1,
	       'USA',
	       people_list(
			   ['J. Giovannoni', 'USDA/ARS','jjg33@cornell.edu'],
		           ['B. Roe', 'University of Oklahoma', 'broe@ou.edu' ],
			   ['J. Van Eck','Boyce Thompson Institute','jv27@cornell.edu'],
			   ['L. Mueller','Boyce Thompson Institute','lam87@cornell.edu'],
			   ['S. Stack','Colorado State U.','sstack@lamar.colostate.edu'],
			  ),
	       'National Science Foundation',
	       'Jan. 2009',
	       24,
	       246,
	      ],
	      [2,
	       'Korea',
	       people_list(['D. Choi','KRIBB Seoul','doil@kribb.re.kr'],
			   ['B.D. Kim','Natl. U.','kimbd@snu.ac.kr'],
			  ),
		
	       'BioGreen21 Project / RDA<br />Frontier 21 Project / CFCG<br />Ministry of Science and Technology (MOST)',
	       'Feb. 2004, July 2004',
	       26,
	       268,
	      ],
	      [3,
	       'China',
	       people_list(['C. Li','Chinese Acad. Sci.','lichu@msu.edu'],
			   ['Y. Xue','ybxue@genetics.ac.cn'],
			   ['Z. Cheng','zkcheng'],
			   ['M. Chen','mschen'],
			   ['H. Ling','hqling'],
			  ),
	       'Chinese Academy of Science<br />Natural Science Foundation',
	       'Mar. 2004',
	       26,
	       274,
	      ],
	      [4,
	       'UK',
	       people_list(['G. Bishop','Imperial College','gdb@aber.ac.uk'],
			   ['G. Seymour','Nottingham University','graham.seymour@hri.ac.uk'],
			   ['G. Bryan', 'SCRI', 'glenn.bryan@scri.ac.uk'],
			  ),
	       'BBSRC/DEFRA, SEERAD',
	       'Jan. 2004',
	       19,
	       193,
	      ],
	      [5,
	       'India',
	       people_list(['R.P. Sharma','U. Hyderabad','rpssl@uohd.ernet.in'],
			   ['J. Khurana,','khurana@genomeindia.org'],
			   ['A. Tyagi','akhilesh'],
			   ['N.K. singh','National Research Centre<br />on Plant Biotech., IARI','nksingh@nrcpb.org'],
			  ),
	       'DBT, Govt. of India',
	       '-',
	       11,
	       111,
	      ],
	      [6,
	       'The Netherlands',
	       people_list(['w. stiekema','Centre for<br />Biosystems Genomics','willem.stiekema@cbsg.nl'],
			   ['p. lindhout','Wageningen U.','Pim.Lindhout@wur.nl'],
			   ['t. jesse','KeyGene','Taco.Jesse@keygene.com'],
			   ['R. Klein Lankhorst','Wageningen U.','rene.kleinlankhorst@wur.nl'],
			  ),
	       'Funded',
	       'in progress',
	       20,
	       213,
	      ],
	      [7,
	       'France',
	       people_list(['m. bouzayen','BMPMF','bouzayen@flora.ensat.fr']),
	       'National Agency for Genome Sequencing',
	       'Mar. 2004',
	       27,
	       277,
	      ],
	      [8,
	       'Japan',
	       people_list(['D. Shibata','Kazusa Inst.','shibata@kazusa.or.jp'],
			   ['S. Tabata','tabata'],
			  ),
	       'Chiba Prefecture',
	       'Sep. 2004',
	       17,
	       175,
	      ],
	      [9,
	       'Spain',
	       people_list(['A. Granell','Inst. de Biologia Molecular<br />y Cellular de Plantas Valencia','agranell@ibmcp.upv.es'],
			   ['M. Botella','U. Malaga','mabotella@uma.es'],
			  ),
	       'Submitted to Genoma Espana',
	       'Pending',
	       16,
	       164,
	      ],
	      [10,
	       'USA',
	       '(see above)',
	      ],
	      [11,
	       'China',
	       people_list(['S. Huang', 'Chinese Academy of Sciences', 'huangsanwen@mac.com']), '', 'Funded',
	      ],
	      [12,
	       'Italy',
	       people_list(['G. Giuliano','ENEA','giovanni.giulianog@enea.it'],
			   ['L. Fruciante','U. Naples','fruscian@unina.it'],
			  ),
	       'Italian Ministry of Agriculture and Italian Ministry of Research',
	       'May 2004',
	       11,
	       113,
	      ],
	     ],
    )
    ,
  );
$page->footer();
