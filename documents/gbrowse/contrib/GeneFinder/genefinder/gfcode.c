/*  File: gfcode.c
 *  Author: Richard Durbin (rd@mrc-lmb.cam.ac.uk)
 * -------------------------------------------------------------------
 * Acedb is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 * or see the on-line version at http://www.gnu.org/copyleft/gpl.txt
 * -------------------------------------------------------------------
 * This file is part of the ACEDB genome database package, written by
 * 	Richard Durbin (MRC LMB, UK) rd@mrc-lmb.cam.ac.uk, and
 *	Jean Thierry-Mieg (CRBM du CNRS, France) mieg@kaa.cnrs-mop.fr
 *
 * Description:
 	This file is entirely derived from GENEFINDER code from Phil
	Green and LaDeana Hillier from Washington University Medical
	School.  Phil Green's email is pg@genome.wustl.edu
	I concatenated a number of files, deleted unused routines,
	and wrote my own interface (at end).

 * Exported functions:
 * HISTORY: Jun 5 00:18 1996 (rbrusk): WIN32 to 4.3
 *	-	Remove char*getenv() declaration in geneFinderAce() (defined in mystdlib.h)
 * Last edited: Apr 15 11:03 2002 (klh)
 * * Dec 20 12:55 1999 (rd): provide #ifdef ACEDB switches to allow
 	standalone version that produces GFF.
 * * Jul 23 14:24 1998 (edgrif): Remove redeclarations of fmap functions
 *      and instead include fmap.h public header.
 * * Sep 13 12:35 1992 (rd): added code to preserve coding score for
 	dynamic programming.
 * Created: Sun Aug 16 23:19:45 1992 (rd)
 *-------------------------------------------------------------------
 */

/* $Id: gfcode.c,v 1.1 2003/04/15 20:30:37 lstein Exp $ */


#ifdef ACEDB

#include "regular.h"
#include <ctype.h>
#include "dbpath.h"
#if defined (applec)
#include "Math.h"
#endif
#include "fmap.h"

#else

#include <stdio.h>
#include <math.h>
#ifdef FALSE
  typedef int BOOL ;
#else
  typedef enum {FALSE=0,TRUE=1} BOOL ;
#endif
#define messalloc(z) malloc(z)
#define messfree(z) free(z)
#define filclose(x) fclose(x)
static void fMapAddGfSite (int type, int pos, float score, BOOL comp) ;
static void fMapAddGfCodingSeg (int pos1, int pos2, float score, BOOL comp) ;

#endif

static  BOOL localGf = TRUE ;

/********** start with the header file: genes.h *****************/

#define MAXSTRLEN 128
#define MAXNUMFORCED 40
#define BIGNEGATIVE -100000.0
#define MAXNUMCLASSES 50
#define MAXCLASSSIZE 20
#define MAXSEQLEN 200000
/* change convTable to char *? */
/* need to remove extraneous sequences */
/* need ability to have gene be on complementary strand */
/* change MAXSTRLEN allocations to variable length */

/* linked list of DNA sequences; first node is dummy */
typedef struct SequenceStruct {
  char name[MAXSTRLEN];
  int length; /* length of sequence */
  char *letters; /* letters representing the sequence */ 
  char *workLetts; /* workspace; allocated to same length as letters */
  int *nums; /* numbers to represent the sequence (not initially allocated):
		each group of currNumSymbs consecutive letters is converted
		to a number, and stored in position of the first letter in
		the group */
  int currNumSymbs; /* numSymbs (cf. table, below) used to make exising nums
		       (0 if nums not yet computed) */
  char use; /* indicates whether sequence is to be used for analyses */
  struct sequence *next;
  char complement; /* 1 if complement, 0 if not (positional info. in output
		      for complements is converted to original numbering) */
  struct orf ***orfPtrs; /* linked list of orf structures (first node NOT dummy) */
} Sequence;

typedef struct GfTableStruct {
  char siteType[MAXSTRLEN]; /* type of site: e.g. atg, intron5, intron3, polya */
  char refSeqs[MAXSTRLEN]; /* reference sequences used to compute score table;
     current possible values are "all", "genes", "introns" or "spliced" */
  char freqType[MAXSTRLEN]; /* "within" or "between"; specifies how
	    frequencies are calculated (with respect to ntuple classes); when
            classDef is  "unique" or "overlap", "within" is
	    automatically assumed */			
  char classDef[MAXSTRLEN]; 
  /* "unique","overlap",or "defined":
     specifies how ntuple classes are defined. For ordinary (non-overlapping)
     tuples, freqType is "within", and classDef is "unique" (for unique class). 
     For overlapping tuples, choose "overlap" and "within". For codon tables
     (using classes corresponding to the amino acids), choose "defined", and
     "within" for relative codon frequencies, "between" for amino acid frequencies 
     */
  int numClasses; /* the number of ntuple classes */
  int classes[MAXNUMCLASSES][MAXCLASSSIZE]; /* the numerical codes for
					       the classes */
  int startOff, endOff;
           /*starting,ending offset (relative to site position)*/
  int jump;  /* jump: usually 1; 3 for codon tables */
  int numSymbs, maxSymb; /* number of consecutive positions used;
			    no. of symbols */
  int numCols, numRows, modNum; 
/*
     numCols = (endOff-startOff-numSymbs+1)/jump + 1
     numRows = maxSymb^numSymbs
     modNum = maxSymb^(numSymbs - 1)   
*/
  int forcedPos[MAXNUMFORCED]; /* positions in table (relative to the site
    position) which are forced to their actual frequencies (i.e. no small 
    sample bias correction) */
  int numForced; /* no. of forced positions */
  int *convTable; /* table to convert chars to nums */
  float **nucFreqs, **logNucFreqs; 
       /* by frequencies I mean observed probabilities */
  int **nucCounts; /* observed counts (used to compute frequencies) */
  int *numTuples; /* array of number of tuples in each column */
} GfTable;

/* keeps relevant tables in a single structure */

typedef struct GfTableVecStruct {
  GfTable *codonTable,*intron5Table,*intron3Table,*intronTable,*atgTable,*stopTable;
} GfTableVec;

/*****************************************************/

static void lettsToNums (Sequence *sequence, GfTable *table) ;
static void countsToFreqs (GfTable *table, int selfSample) ;
static void cleanNucCounts (GfTable *table) ;
static void makeNucFreqs (GfTable *table, int selfSample) ;
static float tPower (float x) ;
static float lRatio (float nCounts, float nTotal, int selfSample) ;
static void makeClassNucFreqs (GfTable *table, int selfSample) ;
static void logDiffs (GfTable *table1, GfTable *table2) ;
static GfTable *readTableFile (char *tableFile, int initial, int selfSample) ;
static GfTable *initTable (void) ;
static void expandTable (GfTable *table) ;
static int **allocIntMat (GfTable *table) ;
static float **allocFloatMat (GfTable *table) ;
static int *makeConvTable (void) ;
static void aceFeatures (Sequence *seq, GfTableVec *tVec, float *fp) ;
static int aceSites (Sequence *sequence, GfTable *table, float cutoff, int type) ;
static void aceMaxSegs (double *cumVec, int start, int end) ;
 
/*****************************************************/

static void lettsToNums (Sequence *sequence, GfTable *table)
{
  int modNum, i, aNum, pos;
  
  if (sequence->currNumSymbs == table->numSymbs) return;
  if (!sequence->currNumSymbs)
    sequence->nums = (int *)messalloc(sequence->length * sizeof(int));
/* NOTE: should really test that maxSymb hasn't changed, either */

  modNum = table->modNum;
  aNum = table->convTable[(int)sequence->letters[0]];
  for (i = 1; i < table->numSymbs; i++) 
    aNum = table->maxSymb * aNum  + table->convTable[(int)sequence->letters[i]];
  sequence->nums[0] = aNum;
  for (pos = 1; i  < sequence->length; pos++, i++) {
    aNum = (table->maxSymb * (aNum % modNum)) + table->convTable[(int)sequence->letters[i]];
    sequence->nums[pos] = aNum;
  }
  for (; pos  < sequence->length; pos++)
    sequence->nums[pos] = 0;
  sequence->currNumSymbs = table->numSymbs;
}

/*****************************************************/

static void countsToFreqs (GfTable *table, int selfSample)
{
  cleanNucCounts(table);
  if (!strcmp(table->classDef,"defined"))
      makeClassNucFreqs(table,selfSample);
  else makeNucFreqs(table,selfSample);
}

static void cleanNucCounts (GfTable *table)
{
  int i,j,k,iMod,dMod,maxSymb;

  maxSymb = table->maxSymb;
  dMod = pow((float)maxSymb,(float)(table->numSymbs - table->jump)) + .1;
  for (j = 0; j < table->numCols; j++) { 
    table->numTuples[j] = 0;
    for (i = 0; i < table->numRows; i++) {
      if ( !strcmp(table->siteType, "codon")  
	  && (i/dMod == 106 || i/dMod == 108 || i/dMod == 116)
	  )
	table->nucCounts[i][j] = 0;
      for (k = 0, iMod = i; k < table->numSymbs; k++, iMod /= maxSymb) 
	if (!(iMod % maxSymb)) {
	  table->nucCounts[i][j] = 0;
	  break;
	}
      table->numTuples[j] += table->nucCounts[i][j];
    }
  }
/* note: the above sets counts = 0 for any n-tuple containing an
  unrecognized nucleotide (which is always assigned a number = 0 by
  lettsToNums. It also sets stop codon counts = 0 
  assuming that "codon tables" have properties that
   letter groups start on codon boundary, and have offset = three,
   and that numSymbs = 5 (and usual nucleotide numbering is used)
*/

}

static void makeNucFreqs (GfTable *table, int selfSample)
/* 
 selfSample is 1 if the scores are to be applied to the original gene list,
 otherwise 0
N.B. This function assumes cleanNucCounts has been run first! 
 so freq for aberrant symbols is set = 0; may need to change this later !
N.B. currently this function only set up to handle "within" classDef
*/
{
  int i,j,m;
  float siteSum,nCounts;
  int classSize,classOffset,numClasses;

  for (i = 0; i < table->numRows; i++) 
    for (j = 0; j < table->numCols; j++) {
      table->nucFreqs[i][j] = 0.0;
      table->logNucFreqs[i][j] = BIGNEGATIVE;
    }
  for (j = 0; j < table->numCols; j++) {
    numClasses = j ? table->numClasses : 1;
    classSize = table->numRows / numClasses;
/* treat first column differently: because it leads off the Markov chain */    
    for (classOffset = 0; classOffset < table->numRows; classOffset += classSize) {
      for (i = 0, siteSum = 0.0; i < classSize; i++) 
           siteSum += table->nucCounts[classOffset+i][j];
      for (i = 0; i < classSize; i++) {
/* old version, incorporating small sample correction; no longer used; here
 trows = (table->maxSymb-1)^numRemainingLetts, where
  numRemainingLetts = !strcmp(table->classDef,"unique") ?
    table->numSymbs : table->jump;

	if (smallSample) {
	  adjEntry = 1.0; 
	  adjTotal = trows;
	}
	else adjEntry = adjTotal = 0.0; 
	for (m = 0; m < table->numForced; m++) 
	  if (table->forcedPos[m] - table->startOff == j) {
	    adjEntry = adjTotal = 0.0;
	    break;
	  }
	if (siteSum + adjTotal)
	  table->nucFreqs[classOffset+i][j] =
	    (table->nucCounts[classOffset+i][j] + adjEntry)/
	      (siteSum + adjTotal);
*/
	nCounts = table->nucCounts[classOffset+i][j];
	table->logNucFreqs[classOffset+i][j] =
	  lRatio(nCounts,siteSum,selfSample);
	if (nCounts) table->nucFreqs[classOffset+i][j] = nCounts / siteSum;
	else {               /* nCounts == 0 */
	  for (m = 0; m < table->numForced; m++) 
	    if (table->forcedPos[m] - table->startOff == j) {
	      table->logNucFreqs[classOffset+i][j] = BIGNEGATIVE;
	      break;
	    };
	}
      }
    }
  }
}

/* following is used in lRatio */
static float tPower (float x)
{
  return (x ? x * log10(1.0 + 1.0/x) : 0.0);
}

/* following calculates log likelihood ratio used in scores */

static float lRatio (float nCounts, float nTotal, int selfSample)
{
  if (selfSample && nCounts) {
    /* This correction is needed when apply score to same genes from which
       tables were generated */
    nCounts--; 
    nTotal--; 
  }
  return (tPower(nCounts) - tPower(nTotal) +
	      log10((nCounts + 1.0)/(nTotal + 1.0))
	  );
}

static void makeClassNucFreqs (GfTable *table, int selfSample)
/* 
This function is used (instead of makeNucFreqs) if table->classDef == "defined". 
selfSample is 1 if the scores are to be applied to the original gene list,
 otherwise 0
N.B. This function assumes cleanNucCounts has been run first (to set
table->numTuples[j]) 
 so freq for aberrant symbols is set = 0; may need to change this later !
*/
{
  int i,j,m,trows,ientry;
  float siteSum,nCounts,nTotal;
  int class;

  for (i = 0; i < table->numRows; i++) 
    for (j = 0; j < table->numCols; j++) {
      table->nucFreqs[i][j] = 0.0; 
      table->logNucFreqs[i][j] = BIGNEGATIVE;
    }
  for (j = 0; j < table->numCols; j++) {
    for (class = 0; class < table->numClasses; class++) {
      siteSum = 0.0;
      trows = 0;
      for (i = 0; (ientry = table->classes[class][i]); i++) {
	siteSum += table->nucCounts[ientry][j];
	trows++;
      }
      for (i = 0; (ientry = table->classes[class][i]); i++) {
/* old version, incorporating small sample correction; no longer used
	if (smallSample) {
	  adjEntry = 1.0; 
	  adjTotal = !strcmp(table->freqType,"within") ?
	    trows : table->numClasses;
	}
	else adjEntry = adjTotal = 0.0; 
	for (m = 0; m < table->numForced; m++) 
	  if (table->forcedPos[m] - table->startOff == j) {
	    adjEntry = adjTotal = 0.0;
	    break;
	  }
	if (siteSum + adjTotal)
	  table->nucFreqs[ientry][j] = !strcmp(table->freqType,"within") ?
	    (table->nucCounts[ientry][j] + adjEntry)/ (siteSum + adjTotal)
	      : (siteSum + adjEntry)/(table->numTuples[j] + adjTotal);
*/
	if (!strcmp(table->freqType,"within")) {
	  nCounts = table->nucCounts[ientry][j];
	  table->logNucFreqs[ientry][j] = lRatio(nCounts,siteSum,selfSample);
	  if (nCounts) table->nucFreqs[ientry][j] = nCounts / siteSum;
	  else {
	    for (m = 0; m < table->numForced; m++) 
	      if (table->forcedPos[m] - table->startOff == j) {
		table->logNucFreqs[ientry][j] = BIGNEGATIVE;
		break;
	      };
	  }
	}
	else {
	  nTotal = table->numTuples[j];
	  table->logNucFreqs[ientry][j] = lRatio(siteSum,nTotal,selfSample);
	  if (siteSum) table->nucFreqs[ientry][j] = siteSum / nTotal;
	  else {
	    for (m = 0; m < table->numForced; m++) 
	      if (table->forcedPos[m] - table->startOff == j) {
		table->logNucFreqs[ientry][j] = BIGNEGATIVE;
		break;
	      };
	  }
	}
      }
    }
  }
}

static void logDiffs (GfTable *table1, GfTable *table2)
{
  int i,j;

  for (i = 0; i < table1->numRows; i++)
    for (j = 0; j < table1->numCols; j++) 
      if (table1->logNucFreqs[i][j] != BIGNEGATIVE) {
	if (!table2->nucCounts[i][j]) table1->logNucFreqs[i][j] = 0;

	/* above is necessary to ensure that N's in a site give 0 score at that position;
	   also, need to check that the sequence on which table2 is based doesn't
	   have any N's ! */

	else table1->logNucFreqs[i][j] -= table2->logNucFreqs[i][j];
      }
} 

static GfTable *readTableFile (char *tableFile, int initial, int selfSample)
/* initial = 1 if only the initial information (not counts) is to be
   read, and = 0 otherwise;
   selfSample = 1 if the original genes are to be scored (as in hist),
   = 0 otherwise */
{
  GfTable *table;
  int  i, j, d, iclass;
  FILE *fp;
  char string[MAXSTRLEN],string2[MAXSTRLEN];
  char c;

#ifdef ACEDB      
  if (localGf)
    {
      char *filename = dbPathStrictFilName("wgf", tableFile, "", "r", 0);
      if (!filename || !(fp = filopen (filename, "", "r")))
	{ 
	  messout ("Sorry, I failed to open %s",tableFile) ;
	  if (filename)
	    messfree(filename);
	  return 0 ;
	}
      messfree(filename);
    }
  else
    {
      if (!(fp = filopen (tableFile, "", "r")))
	{ messout ("Sorry, I failed to open %s",tableFile) ;
	  return 0 ;
	}
    }
#else 
  if (!(fp = fopen (tableFile, "r")))
    { 
      fprintf(stderr, "Sorry, I failed to open %s\n",tableFile) ;
      return 0 ;
    }
#endif

  table = initTable();
  iclass = 0;
  while (EOF != fscanf(fp,"%s",string)) { 
  begin:
    if (!strcmp(string, "//")) 
      do { c = fgetc(fp); } while (c != '\n' && c != EOF);
    else if(!strcmp(string,"siteType:")) fscanf(fp,"%s",table->siteType); 
    else if(!strcmp(string,"refSeqs:")) fscanf(fp,"%s",table->refSeqs); 
    else if(!strcmp(string,"freqType:")) fscanf(fp,"%s",table->freqType); 
    else if(!strcmp(string,"classDef:")) fscanf(fp,"%s",table->classDef); 
    else if(!strcmp(string,"startOff:")) fscanf(fp,"%d",&table->startOff); 
    else if(!strcmp(string,"endOff:")) fscanf(fp,"%d",&table->endOff); 
    else if(!strcmp(string,"numSymbs:")) fscanf(fp,"%d",&table->numSymbs); 
    else if(!strcmp(string,"maxSymb:")) fscanf(fp,"%d",&table->maxSymb); 
    else if(!strcmp(string,"jump:")) fscanf(fp,"%d",&table->jump); 
/* diffs is no longer necessary */
    else if(!strcmp(string,"numForced:")) fscanf(fp,"%d",&table->numForced); 
    else if(!strcmp(string,"forcedPos:"))
      for (i = 0; i < table->numForced; i++)
	fscanf(fp,"%d",&table->forcedPos[i]); 
    else if(!strcmp(string,"class:")) {
      i = -1;
      do {
	i++;
	fscanf(fp,"%s",string2);
      } while(1 == sscanf(string2,"%d",&table->classes[iclass][i]));
      strcpy(string,string2);
      table->classes[iclass][i] = 0;
      iclass++;
      goto begin;
    }
    else if(!strcmp(string,"*")) break; 
    else {
#ifdef ACEDB
      messcrash ("ERROR in tableFile %s: unknown field %s",
		 tableFile, string);
#else
      fprintf(stderr, "ERROR in tableFile %s: \"%s\" unknown field\n",
	      tableFile, string);
      exit(1);
#endif
    }
  };
  table->classes[iclass][0] = 0;
  table->numClasses = iclass;
  expandTable(table);

  if (!initial) {
    for (i = 0; i < table->numRows; i++)
      for (j = 0; j < table->numCols; j++) {
	d = fscanf(fp, "%d", &table->nucCounts[i][j]);
	if (!d || d == EOF) {
#ifdef ACEDB
	  messcrash ("scoreTable %s incomplete", tableFile);
#else
	  fprintf(stderr, "scoreTable %s incomplete", tableFile);
	  exit(1);
#endif
	}
      }	 
/* Following no longer applies.
    if (!strcmp(table->siteType,"codon")
	|| !strcmp(table->siteType,"intron")
	|| !strcmp(table->siteType,"exon"))
      smallSample = 0;
    else smallSample = 1; 
*/
    countsToFreqs(table,selfSample);
  }
  filclose(fp);
  return table;
}

/*initialize table structure */
static GfTable *initTable (void)
{
  GfTable *table;

  table = (GfTable *)messalloc(sizeof(GfTable));
  table->jump = 1; /*default jump size: for ordinary tables */
  table->numForced = 0; /*default is no positions forced */
  strcpy(table->refSeqs,"all"); /*default reference sequences*/
  strcpy(table->freqType,"within"); 
  strcpy(table->classDef,"unique"); /*default frequency calculations:
       single class, frequencies are relative to it */
  return table;
}

/* fill in additional (derivative) values in the table structure */
static void expandTable (GfTable *table)
{
  int modNum, i;

  table->convTable = makeConvTable();
  table->numCols = (table->endOff - table->startOff - table->numSymbs + 1)/table->jump + 1;
  modNum = 1;
  for (i = 1; i < table->numSymbs; i++) modNum *= table->maxSymb;
  table->modNum = modNum;
  table->numRows = modNum * table->maxSymb;
  if (strcmp(table->classDef,"defined")){ 
/* this computes numClasses when classes are NOT defined */
    if (!strcmp(table->classDef,"unique")) table->numClasses = 1;
    else for (i = 0, table->numClasses = 1;
	      i < table->numSymbs - table->jump;
	      i++, table->numClasses *= table->maxSymb
	     );
  }
  table->nucCounts = allocIntMat(table);
  table->nucFreqs = allocFloatMat(table);
  table->logNucFreqs = allocFloatMat(table);
  table->numTuples = (int *)messalloc(table->numCols * sizeof(int));
}

static int **allocIntMat (GfTable *table)
{
  int **mtable;
  int i, j;

  mtable = (int **)messalloc(table->numRows * sizeof(int *));
  for (i = 0; i < table->numRows; i++) {
    mtable[i] = (int *)messalloc(table->numCols * sizeof(int));
    for (j = 0; j < table->numCols; j++) mtable[i][j] = 0;
  }
  return(mtable);
}

static float **allocFloatMat (GfTable *table)
{
  float **stable;
  int i, j;

  stable = (float **)messalloc(table->numRows * sizeof(float *));
  for (i = 0; i < table->numRows; i++) {
    stable[i] = (float *)messalloc(table->numCols * sizeof(float));
    for (j = 0; j < table->numCols; j++) stable[i][j] = 0;
  }
  return(stable);
}

static int *makeConvTable (void)
{

  int *convTable;
  int i;

  convTable = (int *)messalloc(256 * sizeof(int));
  for (i = 0; i < 256; i++) convTable[i] = 0;
  convTable['A'] = convTable['a'] = 1;
  convTable['C'] = convTable['c'] = 2;
  convTable['G'] = convTable['g'] = 3;
  convTable['T'] = convTable['t'] = 4;
  return (convTable);
}

/*****************************************************************************/

/* severely edited version of segments.c for featace
   Richard Durbin 1/8/92 from Phil Green's original genefinder code
   aceFeatures() from orfMaster()
   aceSites() from findSites()
   aceMaxSegs() from processGaps()
*/

static float segScoreCutoff = 1.0;  /*cutoff for scores of maximal "coding-like"
				      segments (used aceMaxSegs) */

/* CHECK BOUNDARIES ... */

static Sequence *sequence ;	/* global to this module */

#ifdef ACEDB
extern float intron3Cutoff,intron5Cutoff,atgCutoff;
#else
static float intron3Cutoff = -2.0;
static float intron5Cutoff = 0.0;
static float atgCutoff = 0.0;
static float stopCutoff = -2.0;
#endif

static void aceFeatures (Sequence *seq, GfTableVec *tVec, float *cum)
{
  int i, frame, length ;
  double diff, *diffVec;
  int nSites;

  sequence = seq ;

  length = sequence->length;

  nSites = aceSites(sequence,tVec->intron3Table,intron3Cutoff, '3') ;
  nSites = aceSites(sequence,tVec->intron5Table,intron5Cutoff, '5') ;
  nSites = aceSites(sequence,tVec->atgTable,atgCutoff, 'a') ;
#ifndef ACEDB
  nSites = aceSites(sequence,tVec->stopTable,stopCutoff, 's') ;
#endif

  if (tVec->codonTable != NULL) { 
    lettsToNums(sequence,tVec->codonTable); 
    /* NOTE: assumes sequence->nums  IS SAME FOR BOTH INTRONTABLE AND CODONTABLE!!) */
    diffVec = (double *)messalloc((length+3) * sizeof(double));
    for (frame = 0; frame < 3; frame++)
      { diffVec[0] = diffVec[1] = diff = 0;
        for (i = frame; i < length; i+=3)
	  diffVec[i] = diffVec[i+1] = diffVec[i+2] = diff +=
	    (( ! strncmp( sequence->letters + i, "TAA", 3) 
	       || ! strncmp( sequence->letters + i, "TAG", 3) 
	       || ! strncmp( sequence->letters + i, "TGA", 3) )
	     ? -100.0
	     : tVec->codonTable->logNucFreqs[sequence->nums[i]][0] );
	aceMaxSegs (diffVec, frame, length-1) ;
      }
    messfree (diffVec);
    
    if (cum) 
      { cum[0] = cum[1] = cum[2] = 0 ;
        for (i = 0 ; i <= length-3 ; ++i)
	  cum[i+3] = cum[i] + tVec->codonTable->logNucFreqs[sequence->nums[i]][0] ;
      }
  }
}

static int aceSites (Sequence *sequence, GfTable *table, float cutoff, int type)
{
  int length, pos, stPos, endPos, index, i, numSites, m;
  float score;

  numSites = 0;

  if (table != NULL) {
    lettsToNums(sequence,table); 
    length = sequence->length;
    stPos = (table->startOff >= 0) ? 0 : -table->startOff; 
    endPos = (table->endOff <= 0) ? sequence->length : 
      sequence->length - table->endOff; 
    for (pos = stPos ; pos < endPos ; pos++)
      { 
	for (m = 0; m < table->numForced; m++)
	  { 
	    i = pos + table->forcedPos[m];
	    if (table->logNucFreqs[sequence->nums[i]][table->forcedPos[m] - table->startOff]
		== BIGNEGATIVE) goto nextpos;
	  }
      /* eliminate sites which don't match at forced positions */
      
	score = 0;
	for (index = 0, i = pos + table->startOff; index < table->numCols; 
	     index++, i += table->jump)
	  score += table->logNucFreqs[sequence->nums[i]][index];
	
#ifndef ACEDB
	/* need to check that the site matches at consensus position 
	   - only an issue for stops */
	if ( !strcmp(table->siteType, "stop")) 
	  if ( strncmp( sequence->letters + pos, "TAA", 3) 
	       && strncmp( sequence->letters + pos, "TAG", 3) 
	       && strncmp( sequence->letters + pos, "TGA", 3) ) 
	    score = BIGNEGATIVE;
#endif
	if (score >= cutoff) 
	  { numSites++;
	  if (sequence->complement)
	    fMapAddGfSite (type, length - pos, score, TRUE) ;
	  else
	    fMapAddGfSite (type, pos, score, FALSE) ;
	  }
      nextpos:
	;
      }
  }

  return numSites;
}

/********** gap package *********/
  
/* linked list of gaps (regions of sequence remaining to be processed)
   (dummy head node)*/
typedef struct gap {
  int start, end;
  struct gap *next;
} Gap;

static Gap *allocGap (void)
{
  Gap *gap;
  static int numGaps;
  static Gap *headGap;

  if (!(numGaps%500)) headGap = (Gap *)messalloc(500 * sizeof(Gap));
  gap = headGap + numGaps%500;
  numGaps++;
  gap->next = 0;
  return gap;
}

/* appends gap at head of list (with dummy head node) */
static Gap *appendGap (int left, int right, Gap *oldgap)
{
  Gap *gap;

  gap = allocGap();
  gap->start = left;
  gap->end = right;
  gap->next = oldgap->next;
  oldgap->next = gap;
  return gap;
}

/**********/

static void aceMaxSegs(double *cumVec, int start, int end)
{
  int maxi,minj,i,j,numGaps;
  double max,min,diff;
  Gap *gapHead, *gap;
  int *maxPos;
  double cutOff;
  int length = sequence->length ;
  BOOL comp = sequence->complement ;

  cutOff = segScoreCutoff;
  maxPos = (int *)messalloc((end+1) * sizeof(int));
  numGaps = 0;
  gapHead = allocGap();
  gap = appendGap (start, end, gapHead);
  for (; gap; gap = gap->next) 
    {
      max = cumVec[gap->end];
      maxi = gap->end;
      for (i = gap->end; i >= gap->start; i--)
	{ if (cumVec[i] > max)
	    { max = cumVec[i];
	      maxi = i;
	    }
	  maxPos[i] = maxi;
	}
      for (i = gap->start; i <= gap->end; i++)
	if ((maxi = maxPos[i]) > i)
	  { min = cumVec[i];
	    minj = i;
	    for (j = i + 1; j < maxi; j++) 
	      if (cumVec[j] < min)
		{ min = cumVec[j];
		  minj = j;
		}
	    if ((diff = cumVec[maxi] - cumVec[minj]) >= cutOff)
	      { if (comp)
		  fMapAddGfCodingSeg (length - maxi, length - (minj + 3), diff, TRUE) ;
		else
		  fMapAddGfCodingSeg (minj + 1 + 3, maxi + 1, diff, FALSE) ;
		if (minj - 1 > i)
		  { appendGap(i, minj - 1,gap); 
		    numGaps++;
		  }
		/* diff does not actually include the score for the codon at
		   minj itself. the minj codon should therefore not be in the 
		   segment, hence the + 3 */
	      }
	    i = maxi;
	  }
    }
  messfree (maxPos);
}
  
/************************** master interface = featace.c code ***************/

#ifndef TRUE
#define TRUE 1
#define FALSE 0
#endif

/****************************/

static Sequence *sequenceAllocate (int length, char *name, BOOL comp)
{
  Sequence *seq ;

  seq = (Sequence *)messalloc(sizeof(Sequence)) ;
  seq->next = NULL ;
  seq->use = 0 ;
  seq->currNumSymbs = 0 ;
  seq->complement = comp ;
  strcpy (seq->name, name) ;
  seq->length = length  ;
  seq->letters = (char *)messalloc(length) ;
  seq->workLetts = (char *)messalloc(length) ;
  return seq ;
}

static void sequenceDestroy (Sequence *seq)
{
  messfree (seq->letters) ;
  messfree (seq->workLetts) ;
  if (seq->currNumSymbs)
    messfree (seq->nums) ;
  messfree (seq) ;
}

static void createSequences (char *dna, Sequence **ps, Sequence **pc)
{
  Sequence *seq, *comp ;
  int i, length, top, nbad = 0, ibad = 0 ;

#define A_ 1
#define T_ 2
#define G_ 4
#define C_ 8
#define N_ (A_ | T_ | G_ | C_)

  length = strlen (dna) ;
  *ps = seq = sequenceAllocate (length, "forward", 0) ;
  *pc = comp = sequenceAllocate (length, "backward", 1) ;
  top = length-1 ;
  for (i = 0 ; i < length ; ++i)
    switch (dna[i])
      {
      case 'A': case A_:
	seq->letters[i] = 'A' ; comp->letters[top-i] = 'T' ; break ;
      case 'T': case T_:
	seq->letters[i] = 'T' ; comp->letters[top-i] = 'A' ; break ;
      case 'G': case G_:
	seq->letters[i] = 'G' ; comp->letters[top-i] = 'C' ; break ;
      case 'C': case C_:
	seq->letters[i] = 'C' ; comp->letters[top-i] = 'G' ; break ;
      case 'N': case N_:
	seq->letters[i] = 'N' ; comp->letters[top-i] = 'N' ; break ;
      default:
	if (!ibad) ibad = i ;
	++nbad ;
	seq->letters[i] = 'N' ; comp->letters[top-i] = 'N' ; break ;
      }
  if (nbad)
#ifdef ACEDB
    messout("%d bad characters in sequence, 1st at %d", nbad, ibad) ;
#else
    fprintf (stderr, "%d bad characters in sequence, 1st at %d", nbad, ibad) ;
#endif
}

/******************************/

#ifdef ACEDB

/************************************************************/
/********* ACEDB initialisation and interface ***************/

static GfTableVec *geneFinderInit (char *filename)
{
  FILE *fp ;
  static GfTableVec tvec ;
  GfTableVec *tableVec ;
  GfTable *table ;
  char *cp, fileName[MAXSTRLEN] ;
  int i ;

  if (!(fp = fopen (filename, "r")))
    { messout ("Can't open %s, sorry", filename) ;
      return 0 ;
    }

  tableVec = &tvec ;
      
  tableVec->codonTable = tableVec->intron5Table = tableVec->intron3Table = tableVec->atgTable = 0 ;
  for (i = 0; i < 8; i++)
    if (freeread(fp) && (cp = freeword()))
      { strncpy(fileName, cp, MAXSTRLEN - 1) ;
        table = readTableFile (fileName, 0, 0) ;
        if (!table)
          { fclose(fp) ; return 0 ; }  /* mieg, table = 0 crashes */
        if (!strcmp(table->siteType,"intron5"))
          {
            if (!tableVec->intron5Table) tableVec->intron5Table = table;
            else logDiffs(tableVec->intron5Table,table); /* normalize logNucFreqs using
                                                            "reference" table */
          }
        if (!strcmp(table->siteType,"intron3"))
          {
            if (!tableVec->intron3Table) tableVec->intron3Table = table;
            else logDiffs(tableVec->intron3Table,table);
          }
        if (!strcmp(table->siteType,"atg"))
          {
            if (!tableVec->atgTable) tableVec->atgTable = table;
            else logDiffs(tableVec->atgTable,table);
          }
        if (!strcmp(table->siteType,"codon"))
          tableVec->codonTable = table;
        if (!strcmp(table->siteType,"intron"))
          { tableVec->intronTable = table;
            logDiffs(tableVec->codonTable,table); 
            /* normalize codontable against intronTable */
          }
      }
    else  /* mieg */
      { messout("I can't scan line %d of the GF_TABLES file: %s", i, getenv("GF_TABLES")) ;
        fclose(fp) ; return 0 ; 
      }  
  fclose(fp);

  return tableVec ;
}

typedef struct {
  int min, max ;
  float *cum, *revCum ;
} *GfInfo ;

BOOL geneFinderAce (char *seq, GfInfo gf)
{     
  Sequence *sequence, *compSequence ;
  static GfTableVec *tableVec = 0 ;

  if (!seq || !*seq)
    {
      messout ("No sequence for genefinder to work on.") ;
      return FALSE ;
    }

  if (!tableVec)
    { 
      char *filename = dbPathFilName("wgf", "tables", "", "r", 0);
      if (!filename)
	{ 
	  messout ("can't find wgf/tables") ;
	  return FALSE ;
	}
      else if (!(tableVec = geneFinderInit (filename)))
	{ messfree (filename) ;
	  return FALSE ;
	}
      messfree(filename);

      messout ("The splice site, coding potential and ATG "
	       "predictions use algorithms and code from the "
	       "Genefinder package of Phil Green "
	       "(phg@u.washington.edu)") ;
    }      

  createSequences (seq, &sequence, &compSequence) ;
  aceFeatures (sequence, tableVec, gf->cum) ;
  aceFeatures (compSequence, tableVec, gf->revCum) ;
  sequenceDestroy (sequence) ;
  sequenceDestroy (compSequence) ;
  return TRUE ;
}
 
#else

/************************************************************/
/******** stand alone initialisation and interface **********/

static GfTableVec *geneFinderInit (char *filename)
{
  FILE *fp ;
  static GfTableVec tvec ;
  GfTableVec *tableVec ;
  GfTable *table ;
  char *cp, fileName[MAXSTRLEN], lastFileName[MAXSTRLEN] ;
  int i,c;
  int haveReadFilename = 0;

  if (!(fp = fopen (filename, "r")))
    { fprintf (stderr, "Can't open %s, sorry", filename) ;
      return 0 ;
    }

  tableVec = &tvec ;
      
  tableVec->codonTable = tableVec->intron5Table = tableVec->intron3Table = tableVec->atgTable = 0 ;
  tableVec->stopTable = 0;

  while (fscanf(fp,"%s ",fileName) != EOF) 
    {	  
      if (!strcmp(fileName, "//")) {
	do { 
	  c = fgetc(fp); 
	} while (c != '\n' && c != EOF);
	i--; 
	continue;
      }

      /* need to skip the last entry in the file because it is not a table */
      if (haveReadFilename) 
	{
	  table = readTableFile (lastFileName, 0, 0) ;

	  if (!table)
	    { 
	      fclose(fp) ; 
	      return 0 ; 
	    }  /* mieg, table = 0 crashes */
	  if (!strcmp(table->siteType,"intron5"))
	    {
	      if (!tableVec->intron5Table) tableVec->intron5Table = table;
	      else logDiffs(tableVec->intron5Table,table); /* normalize logNucFreqs using
							  "reference" table */
	    }
	  if (!strcmp(table->siteType,"intron3"))
	    {
	      if (!tableVec->intron3Table) tableVec->intron3Table = table;
	      else logDiffs(tableVec->intron3Table,table);
	    }
	  if (!strcmp(table->siteType,"atg"))
	    {
	      if (!tableVec->atgTable) tableVec->atgTable = table;
	      else logDiffs(tableVec->atgTable,table);
	    }
	  if (!strcmp(table->siteType,"stop"))
	    {
	      if (!tableVec->stopTable) tableVec->stopTable = table;
	      else logDiffs(tableVec->stopTable,table);
	    }
	  if (!strcmp(table->siteType,"n-mer"))
	    {
	      if (!tableVec->codonTable) tableVec->codonTable = table;
	      else logDiffs(tableVec->codonTable,table);
	    }
	  if (!strcmp(table->siteType,"codon"))
	    tableVec->codonTable = table;
	  if (!strcmp(table->siteType,"intron"))
	    { 
	      tableVec->intronTable = table;
	      logDiffs(tableVec->codonTable,table); 
	      /* normalize codontable against intronTable */
	    }
	}
      strcpy( lastFileName, fileName );
      haveReadFilename = 1;
    }
      
  fclose(fp);
  
  return tableVec ;
}


#include "readseq.h"

static char *seqName ;

void usage (void)
{
  fprintf (stdout, "Usage: gfcode [opts] <tableFile> <seqFile>\n") ;
  fprintf (stdout, "  -segs <n>    : cutoff for segment scores (default %.1f)\n", segScoreCutoff);
  fprintf (stdout, "  -splice3 <n> : cutoff for splice3 scores (default %.1f)\n", intron3Cutoff);
  fprintf (stdout, "  -splice5 <n> : cutoff for splice5 scores (default %.1f)\n", intron5Cutoff);
  fprintf (stdout, "  -atg <n>     : cutoff for ATG scores (default %.1f)\n", atgCutoff);
  fprintf (stdout, "  -stop <n>    : cutoff for stop scores (default %.1f)\n", stopCutoff);
  exit (-1) ;
}

static void fMapAddGfSite (int type, int pos, float score, BOOL comp) 
{
  static char *featName[] = { "splice3", "splice5", "atg", "stop"} ;
  int start, end, idx;
 
  switch (type)
    {
    case '3':
      start  = pos; 
      end = pos + 1;
      idx = 0;
      break;
    case '5':
      start = comp ? pos - 1 : pos + 1;
      end = comp ? pos : pos + 2;
      idx = 1;
      break;
    case 'a': 
      start = comp ? pos - 2 : pos + 1;
      end = comp ? pos : pos + 3;
      idx = 2;
      break ;
    case 's' :
      start = comp ? pos - 2 : pos + 1;
      end = comp ? pos : pos + 3;
      idx = 3;
      break ;
    }
  
  printf ("%s\tGenefinder\t%s\t%d\t%d\t%.4f\t%c\t%c\n", 
	  seqName, featName[idx], start, end, 
	  score, comp ? '-' : '+', '.') ;
}

static void fMapAddGfCodingSeg (int pos1, int pos2, float score, BOOL comp)
{

  printf ("%s\t%s\t%s\t%d\t%d\t%.4f\t%c\t%c\n", 
	  seqName, "Genefinder", "coding_seg", pos1, pos2, 
	  score, comp ? '-' : '+', '0') ;
}


int main (int argc, char **argv)
{
  Sequence *sequence, *compSequence;
  char *tableName ;
  FILE *seqFile ;
  GfTableVec *tableVec = 0 ;
  char *seq ;
  int len ;

  --argc ; ++argv ;		/* remove program name */

				/* parse command line options */

  while (argc > 2) {
    if (!strcmp (*argv, "-splice3"))
      { intron3Cutoff = atof (argv[1]) ;
        argc -= 2 ; argv += 2 ;
      }
    else if (!strcmp (*argv, "-splice5"))
      { intron5Cutoff = atof (argv[1]) ;
        argc -= 2 ; argv += 2 ;
      }
    else if (!strcmp (*argv, "-atg"))
      { atgCutoff = atof (argv[1]) ;
        argc -= 2 ; argv += 2 ;
      }
    else if (!strcmp (*argv, "-stop"))
      { stopCutoff = atof (argv[1]) ;
        argc -= 2 ; argv += 2 ;
      }
    else if (!strcmp (*argv, "-segs"))
      { segScoreCutoff = atof (argv[1]) ;
        argc -= 2 ; argv += 2 ;
      }
    else if (**argv == '-')
      { fprintf (stderr, "Unrecognised option %s\n", *argv) ;
        usage() ;
      }
    else
      usage() ;
  }

  if (argc != 2)
    usage() ;

  tableName = *argv ; --argc ; ++argv ;
  if (!(tableVec = geneFinderInit (tableName)))
      usage () ;

  if (!strcmp (*argv, "-"))
    seqFile = stdin ;
  else if (!(seqFile = fopen (*argv, "r")))
    { fprintf (stderr, "Failed to open sequence file %s\n") ;
      usage() ;
    }

  if (!readSequence (seqFile, dna2textConv, 
		     &seq, &seqName, 0, &len))
    { fprintf (stderr, "Errors reading sequence %s\n") ;
      usage() ;
    }

  createSequences (seq, &sequence, &compSequence) ;

  printf("##gff-version 2\n");
  printf("##sequence-region %s 1 %d\n", seqName, sequence->length );
  aceFeatures (sequence, tableVec, 0) ;
  aceFeatures (compSequence, tableVec, 0) ;
  sequenceDestroy (sequence) ;
  sequenceDestroy (compSequence) ;
}

#endif
