package TomatoGenomePageProp;
use Moose;

extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'');
Adds an organismprop to the tomato organism turning on its genome page.

has '+sql' => ( default => <<EOS );

INSERT INTO dbxref
           ( db_id, accession,                 version )
    VALUES ( 71,    'autocreated:genome_page', 1       );


INSERT INTO cvterm
        (cv_id, name, definition, dbxref_id )
 VALUES (  2733
          ,'genome_page'
          ,'attribute for an organism indicating whether an SGN genome page should be displayed for it'
          ,
          ( SELECT dbxref_id FROM dbxref WHERE accession = 'autocreated:genome_page' )
        );

INSERT INTO organismprop
          (organism_id,type_id,value)
   VALUES (1,(select cvterm_id from cvterm where name = 'genome_page'),1);

EOS



1;
