/*  File: readseq.c
 *  Author: Richard Durbin (rd@sanger.ac.uk)
 *  Copyright (C) R Durbin, 1994
 *-------------------------------------------------------------------
 * Description: generic code to read Pearson format files (fasta)
 		>header line
		conv[x] is the internal code for char 'x'
		conv[x] == -1 or -2 means ignore. 
                conv[x] < -2 means error.
		will work on fil == stdin
 * Exported functions: readSequence, writeSequence, seqConvert
 * HISTORY:
 * Last edited: Dec 11 14:00 2000 (rd)
 * * Dec 29 23:35 1993 (rd): now works off FILE*, returns id and desc
 * Created: Tue Jan 19 21:14:35 1993 (rd)
 * CVS info: $Id: readseq.c,v 1.1 2003/04/15 20:30:39 lstein Exp $
 *-------------------------------------------------------------------
 */

#include "stdio.h"
#include "stdlib.h"
#include "string.h"
#include "ctype.h"

#pragma inline(add)
static char *messalloc (int n)
{
  char *result ;

  if (!(result = (char*) malloc (n)))
    { fprintf (stderr, "MALLOC failure reqesting %d bytes - aborting\n", n) ;
      exit (-1) ;
    }
  return result ;
}

#define messfree(x) free(x)

static void add (char c, char* *buf, int *buflen, int n)
{
  if (n >= *buflen)
    { 
      int blen = *buflen;
      if (blen < 0)
	{ blen = -blen ;
	  *buf = (char*) messalloc (blen) ;
	}
      else
	{ blen *= 2 ;
	  if ((*buf = realloc(*buf,blen)) == NULL)
             { fprintf (stderr, "REALLOC failure reqesting %d bytes - aborting\n", blen) ;
               exit (-1) ;
             }
	}
      *buflen = blen; 
    }
  (*buf)[n] = c;
}

int readSequence (FILE *fil, int *conv, 
                  char **seq, char **id, char **desc, int *length)
{
  char c ;
  int n ;
  static FILE *oldFil = 0 ;
  static int line ;
  int buflen ;

  if (fil != oldFil)
    { line = 1 ;
      oldFil = fil ;
    }
  
/* get id, descriptor */
  c = getc (fil) ;
  if (c == '>')			/* header line */
    { c = getc(fil) ;

      n = 0 ;			/* id */
      buflen = -32;
      while (!feof (fil) && c != ' ' && c != '\n' && c != '\t')
	{ if (id) add (c, id, &buflen, n++) ;
	  c = getc (fil) ;
	}
      if (id) add (0, id, &buflen, n) ;

				/* white space */
      while (!feof (fil) && (c == ' ' || c == '\t'))
	c = getc (fil) ;

      n = 0 ;			/* desc */
      buflen = -32 ;
      while (!feof (fil) && c != '\n')
	{ if (desc) add (c, desc, &buflen, n++) ;
	  c = getc (fil) ;
	}
      if (desc) add (0, desc, &buflen, n) ;

      ++line ;
    }
  else
    { ungetc (c, fil) ;		/* no header line */
      if (id) 
	*id = "" ;
      if (desc)
	*desc = "" ;
    }

  /* ensure whitespace ignored */

  conv[' '] = conv['\t'] = -1 ;
  conv['\n'] = -3 ;

  n = 0 ;			/* sequence */
  buflen = -1024 ;


  while (!feof (fil))
    { 
      c = getc (fil) ;
      if (c == '>')
	{ ungetc (c, fil) ;
	  break ;
	}

      if (c == EOF || c == EOF + 256) /* satisfies all compilers */
	break ;

    
      switch (conv[c]) {
        case -2:
          { if (id) 
              fprintf (stderr, "Bad char 0x%x = '%c' at line %d, base %d, sequence %s\n",
          	     c, c, line, n, *id) ;
            else
              fprintf (stderr, "Bad char 0x%x = '%c' at line %d, base %d\n",
          	     c, c, line, n) ;
            return 0 ;
          }
          break;
        case -3:
          ++line;
        case -1:
          break;
        default:
	  add (conv[c], seq, &buflen, n++) ;
      }
    }
  add (0, seq, &buflen, n) ;

  if (length)
    *length = n ;

  return n ;
}

/*****************************************************/

int seqConvert (char *seq, int *length, int *conv)
{
  int i, n = 0 ;
  int c ;

  for (i = 0 ; seq[i] ; ++i)
    { c = seq[i] ;
      if (length && i >= *length)
	break ;
      if (conv[c] < -2)
	{ fprintf (stderr, "Bad char 0x%x = '%c' at base %d in seqConvert\n", c, c, n) ;
	  return 0 ;
	}
      if (conv[c] >= 0)
	seq[n++] = conv[c] ;
    }
  if (n < i)
    seq[n] = 0 ;

  if (length)
    *length = n ;
  return n ;
}

/*****************************************************/

int writeSequence (FILE *fil, int *conv, 
		   char *seq, char *id, char *desc, int len)
{
  int i ;

  if (!id || !*id)
    { fprintf (stderr, "ERROR: writeSequence requires an id\n") ;
      return 0 ;
    }
  if (!fil)
    { fprintf (stderr, "ERROR: writeSequence requires a file\n") ;
      return 0 ;
    }
    
  fprintf (fil, ">%s", id) ;
  if (desc)
    fprintf (fil, " %s", desc) ;

  for (i = 0 ; i < len ; ++i)
    { if (!(i%60))
	fputc ('\n', fil) ;
      if (conv[seq[i]] > 0)
	fputc (conv[seq[i]], fil) ;
      else
	{ fprintf (stderr, "ERROR in writeSequence: %s[%d] = %d does not convert\n",
		   id, i, seq[i]) ;
	  return 0 ;
	}
    }
  fputc ('\n', fil) ;
  return len ;
}

/*********** read a matrix, using conv ************/

int readMatrix (char *name, int *conv, int** *mat)
{
  char matdirname[256] ;
  char fullname[512] ;
  FILE *fil ;
  char line[1024] = "#", *p;
  int i, j, nsymb, smax = 0 ;
  int symb[128] ;
  extern char* strtok (char*, const char*) ;

  if (getenv ("BLASTMAT")) 
    strcpy (matdirname, getenv ("BLASTMAT")) ;
  else
    strcpy (matdirname, "/nfs/disk100/pubseq/blastdb/") ;
  strcpy (fullname, matdirname) ;
  strcat (fullname, name) ;

  if (!(fil = fopen (name, "r")) && !(fil = fopen (fullname, "r")))
    { fprintf (stderr, "ERROR in readMatrix: could not open %s or %s\n",
	       name, matdirname) ;
      return 0 ;
    }
    
  while (!feof(fil) && *line == '#') /* comments */
    fgets (line, 1023, fil) ;

				/* character set */
  p = line ; while (*p == ' ' || *p == '\t' || *p == '\n') ++p ;
  for (i = 0 ; *p && i < 128 ; ++i)
    { symb[i] = conv[*p] ;
      if (symb[i] < -2)
	{ fprintf (stderr, "ERROR in readMatrix: illegal symbol %c\n", *p) ;
	  fclose (fil) ;
	  return 0 ;
	}
      if (symb[i] > smax)
	smax = symb[i] ;
      ++p ; while (*p == ' ' || *p == '\t' || *p == '\n') ++p ;
    }
  nsymb = i ;

  ++smax ;
  *mat = (int**) messalloc (smax * sizeof (int*)) ;
  for (i = 0 ; i < smax ; ++i)
    (*mat)[i] = (int*) messalloc (smax * sizeof (int)) ;

  for (i = 0 ; fgets(line, 1023, fil) && i < nsymb ; ++i)
    { p = line ; while (*p == ' ' || *p == '\t' || *p == '\n') ++p ;
      if (p && conv[*p] == symb[i])
	{ ++p ; while (*p == ' ' || *p == '\t' || *p == '\n') ++p ; }
      for (j = 0 ; *p && j < 128 ; ++j)
	{ if (symb[i] >= 0 && symb[j] >= 0) 
	    (*mat)[symb[i]][symb[j]] = atoi(p) ;
	  if (*p == '-') ++p ;
	  while (p && *p >= '0' && *p <= '9') ++p ;
	  while (*p == ' ' || *p == '\t' || *p == '\n') ++p ;
	}
      if (j != nsymb)
	{ fprintf (stderr, "ERROR in readMatrix: bad line: %s\n", line) ;
	  fclose (fil) ;
	  return 0 ;
	} 
    }

  fclose (fil) ;
  return 1 ;
}

/*********** standard conversion tables **************/

int dna2textConv[] = {
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2, 'A',  -2, 'C',  -2,  -2,  -2, 'G',  -2,  -2,  -2,  -2,  -2,  -2, 'N',  -2,
  -2,  -2,  -2,  -2, 'T',  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,
  -2, 'A',  -2, 'C',  -2,  -2,  -2, 'G',  -2,  -2,  -2,  -2,  -2,  -2, 'N',  -2,
  -2,  -2,  -2,  -2, 'T',  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,
} ;

int dna2textAmbig2NConv[] = {
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2, 'A', 'N', 'C', 'N',  -2,  -2, 'G', 'N',  -2,  -2, 'N',  -2, 'N', 'N',  -2,
  -2,  -2, 'N', 'N', 'T',  -2, 'N', 'N',  -2, 'N',  -2,  -2,  -2,  -2,  -2,  -2,
  -2, 'A', 'N', 'C', 'N',  -2,  -2, 'G', 'N',  -2,  -2, 'N',  -2, 'N', 'N',  -2,
  -2,  -2, 'N', 'N', 'T',  -2, 'N', 'N',  -2, 'N',  -2,  -2,  -2,  -2,  -2,  -2,
} ;

int dna2indexConv[] = {
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,   0,  -2,   1,  -2,  -2,  -2,   2,  -2,  -2,  -2,  -2,  -2,  -2,   4,  -2,
  -2,  -2,  -2,  -2,   3,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,
  -2,   0,  -2,   1,  -2,  -2,  -2,   2,  -2,  -2,  -2,  -2,  -2,  -2,   4,  -2,
  -2,  -2,  -2,  -2,   3,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,
} ;

int dna2binaryConv[] = {
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,   1,  -2,   8,  -2,  -2,  -2,   4,  -2,  -2,  -2,  -2,  -2,  -2,  15,  -2,
  -2,  -2,  -2,  -2,   2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,
  -2,   1,  -2,   8,  -2,  -2,  -2,   4,  -2,  -2,  -2,  -2,  -2,  -2,  15,  -2,
  -2,  -2,  -2,  -2,   2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,
} ;

int aa2textConv[] = {
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2, 'A', 'X', 'C', 'D', 'E', 'F', 'G', 'H', 'I',  -2, 'K', 'L', 'M', 'N',  -2,
 'P', 'Q', 'R', 'S', 'T',  -2, 'V', 'W', 'X', 'Y', 'X',  -2,  -2,  -2,  -2,  -2,
  -2, 'A', 'X', 'C', 'D', 'E', 'F', 'G', 'H', 'I',  -2, 'K', 'L', 'M', 'N',  -2,
 'P', 'Q', 'R', 'S', 'T',  -2, 'V', 'W', 'X', 'Y', 'X',  -2,  -2,  -2,  -2,  -2,
} ;

int aa2indexConv[] = {
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2,  -2, 
  -2,   0,  20,   1,   2,   3,   4,   5,   6,   7,  -2,   8,   9,  10,  11,  -2,
  12,  13,  14,  15,  16,  -2,  17,  18,  20,  19,  20,  -2,  -2,  -2,  -2,  -2,
  -2,   0,  20,   1,   2,   3,   4,   5,   6,   7,  -2,   8,   9,  10,  11,  -2,
  12,  13,  14,  15,  16,  -2,  17,  18,  20,  19,  20,  -2,  -2,  -2,  -2,  -2,
} ;

/**************** end of file ***************/
