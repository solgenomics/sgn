/*  Last edited: Dec 11 14:02 2000 (rd) */
/*  CVS info: $Id: readseq.h,v 1.1 2003/04/15 20:30:39 lstein Exp $ */

extern int readSequence (FILE *fil, int *conv,
			 char **seq, char **id, char **desc, int *length) ;
				/* read next sequence from file */
extern int writeSequence (FILE *fil, int *conv, 
			  char *seq, char *id, char *desc, int len) ;
				/* write sequence to file, using convert */
extern int seqConvert (char *seq, int *length, int *conv) ;
				/* convert in place - can shorten */
extern int readMatrix (char *name, int *conv, int** *mat) ;

extern int dna2textConv[] ;
extern int dna2textAmbig2NConv[] ;
extern int dna2indexConv[] ;
extern int dna2binaryConv[] ;
static const char index2char[] = "acgtn" ;
extern int aa2textConv[] ;
extern int aa2indexConv[] ;
static const char index2aa[] = "ACDEFGHIKLMNPQRSTVWYX*" ;

/***** end of file *****/
