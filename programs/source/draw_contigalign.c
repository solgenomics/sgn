#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include <getopt.h>

#include <math.h>

#include <gd.h>
#include <gdfontl.h>

extern gdFontPtr gdFontSmall;
extern gdFontPtr gdFontTiny;
extern gdFontPtr gdFontLarge;
extern gdFontPtr gdFontMediumBold;

static gdFontPtr localFont;


#define ARRAY_STEP (10)

/* The sizes of source_id and seq_id ought to be extracted from this
   structure, and also from any place that implicitly depends on
   agreement with these sizes (format string widths, mostly). */
typedef struct {
  char source_id[64]; /* Warning: Marty changed this from 32,
			 2006-03-24. We don't print the source_id
			 verbatim, so all that matters is that the
			 structure is big enough to hold inputs (see
			 the sscanf below for input parsing). */
  char seq_id[32];
  char strand;
  int  start_loc;
  int  end_loc;
  int  start_trim;
  int  end_trim;
  int  highlight;
} contig_align_t;

typedef struct {
  int position;
  int height;
} height_data_t;

typedef struct height_list {
  int position;
  int height;
  struct height_list *next;
} tmp_height_data_t;

static FILE *pngout, *mapfile;
static char *image_name = NULL;
static int use_thumbnail = 0;

static char *link_basename = "/cgi-bin/SGN/search/tomato_est_search_result.pl?esttigr=";

static void usage(char *argv[], int exit_code) {

  fprintf(stderr,"\n  %s: Options\n\n  --link_basename=<url>\n  --imagefile=<filename.png>\n  --mapfile=<filename>\n  --thumbnail\n  --image_name=<string>\n\n  Alignment data is expected on STDIN, as tab delimited text\n\n  EST LABEL,  EST ID,  ASSEMBLY DIRECTION, START, END, START TRIM, END TRIM\n\n  Where EST ID is the ID to be used in the link_basename URL,\n  ASSEMBLY DIRECTION is either + or - for forward or reverse complement\n\n  IF START TRIM and END TIRM are positive, START to START + START TRIM will\n  be considered \"trimmed\" portions of the sequence, like wise with \n  END to END + END TRIM.\n",argv[0]);
  exit(-1);
}

static void comline(int argc, char *argv[]) {
  static struct option long_options[] = {
    { "thumbnail", no_argument, NULL, 't' },
    { "imagefile", required_argument, NULL, 'o' },
    { "mapfile", required_argument, NULL, 'm' },
    { "image_name", required_argument, NULL, 'i' },
    { "link_basename", required_argument, NULL, 'b' }
  };
  const char optstring[] = "to:m:i:l:";
  int done;
  char *image_filename = NULL;
  char *imagemap_filename = NULL;

  opterr = 0;
  done = 1;
  while(done) {
    switch(getopt_long(argc, argv, optstring, long_options, NULL)) {
    case -1:
      done = 0;
      break;
    case 't':
      use_thumbnail = 1;
      break;
    case 'o':
      image_filename = strdup(optarg);
      break;
    case 'm':
      imagemap_filename = strdup(optarg);
      break;
    case 'i':
      image_name = strdup(optarg);
      break;
    case 'b':
      link_basename = strdup(optarg);
      break;
    default:
      fprintf(stderr,"Unknown option %c\n",optopt);
      usage(argv, -1);
      break;
    }
  }

  if (!image_filename) usage(argv, -1);

  if (strcmp(image_filename,"-")==0) {
    pngout = stdout;
  } else {
    pngout = fopen(image_filename,"w");
    if (pngout == NULL) {
      fprintf(stderr,"Fatal Error: Can not open image output file \"%s\""
	      "(%s)\n",image_filename, strerror(errno));
      usage(argv, -1);
    }
  }
  free(image_filename);
  
  if (!use_thumbnail && imagemap_filename) {
    if (strcmp(imagemap_filename,"-")==0) {
      if (pngout == stdout) {
	fprintf(stderr,"Image output and imagemap output cannot both be"
		" stdout\n");
	usage(argv, -1);
      } else {
	mapfile = stdout;
      }
    } else {
      mapfile = fopen(imagemap_filename,"w");
      if (mapfile == NULL) {
	fprintf(stderr,"Fatal Error: Can not open imagemap output file \"%s\""
		" (%s)\n", imagemap_filename, strerror(errno));
	usage(argv, -1);
      }
    }
    free(imagemap_filename);
  } else {
    mapfile = NULL;
  }
  
  if (image_name == NULL) {
    fprintf(stderr,"Warning: Image name not specified\n");
    image_name="(Unspecified)";
  }

}

static void process_arguments(int argc, char *argv[]) {

  if (argc < 4 || argc > 6)  usage(argv,-1);
  if (strcmp(argv[1],argv[2])==0) {
    fprintf(stderr,"Fatal Error: Mapfile and Imagefile cannot be the same.\n");
    usage(argv, -1);
  }
  if (strcmp(argv[1],"-")==0) {
    pngout = stdout;
  } else {
    pngout = fopen(argv[1], "w");
    if (pngout == NULL) {
      fprintf(stderr,"Fatal Error: Can not open output file (%s)\n",
	      strerror(errno));
      usage(argv, -1);
    }
  }

  if (argc == 5) {
    if (strcmp(argv[4],"thumbnail")==0) {
      use_thumbnail = 1;
    } else {
      fprintf(stderr,"Unrecognized option %s\n",argv[4]);
      usage(argv,-1);
    }
  } else {
    use_thumbnail = 0;
  }

  if (!use_thumbnail && strcmp(argv[2],"-")==0) {
    mapfile = stdout;
  } else {
    mapfile = fopen(argv[2], "w");
    if (mapfile == NULL) {
      fprintf(stderr,"Fatal Error: Can not open output file (%s)\n",
	      strerror(errno));
      usage(argv,-1);
    }
  }
  strncpy(image_name, argv[3], 40);
}

/* Function passed to qsort() to sort the height data array by
   position */
static int height_data_compare(const void *a, const void *b) {
  
  return ((height_data_t *)a)->position - ((height_data_t *)b)->position;
}

/* This reads the array of contig alignment information and computes
   the points in the histogram where the hieght changes. Afterwards,
   we end up with "height data" which is a list of positions in the
   contig with corresponding height of the coverage histrogram. The
   histogram height is the same upto but not including the next
   height-position pair in the height data array */
static void compute_heights(height_data_t **return_data, int *return_size,
			    contig_align_t *align_data, int n_sequences)  {
  int i, j, n_heights;
  height_data_t *height_data;


  n_heights = n_sequences*2;
  height_data = calloc(n_heights, sizeof(height_data_t));
  for(i=0;i<n_sequences;i++) {
    height_data[i].position = align_data[i].start_loc + 
      align_data[i].start_trim;
    /* Add one to the end the sequence, so we have the property that the right
       end point is not included in the coverage range for the sequence, thus
       we can use this number as an "event" for decreasing the size of the
       histogram */
    height_data[i + n_sequences].position = 
      align_data[i].end_loc - align_data[i].end_trim + 1;
  }

  /* Sort and eliminate duplicates positions. */
  qsort(height_data, n_heights, sizeof(height_data_t),height_data_compare);
  for(i=1;i<n_heights;i++) {
    if (height_data[i].position == height_data[i-1].position) {
      int start, stop, difference;
      start = i;
      stop = start+1;
      while(stop<n_heights && 
	    height_data[stop].position == height_data[start].position)
	stop++;
      difference = stop - start;
      for(;stop<n_heights;stop++,start++)
	height_data[start].position = height_data[stop].position;
      n_heights -= difference;
    }
  }
  height_data = realloc(height_data, sizeof(height_data_t)*n_heights);
  
  /* For each sequence, increment the hieghts at positions that span the
     region covered by the sequence */
  for(i=0;i<n_sequences;i++) {
    int left, right;
    left = align_data[i].start_loc + align_data[i].start_trim;
    right = align_data[i].end_loc - align_data[i].end_trim;
    for(j=0;j<n_heights;j++) {
      if (height_data[j].position >= left && height_data[j].position < right)
	height_data[j].height++;
    }
  }

  *return_data = height_data;
  *return_size = n_heights;
}


/* This function reads input from the STDIN which is assumed to be
   the contig alignment data read from the database. */
static void read_input(contig_align_t **return_array, int *return_size) {
  char inputline[256];
  contig_align_t *array, *p;
  int array_size;
  char strand;

  array = NULL;
  array_size = 0;

  /* Put the fgets() at the end of the loop as it will need to be called 
     on the last (END OF FILE) character in the file before feof(stdin) will
     be TRUE. */
  fgets(inputline, 256, stdin);
  while(!feof(stdin)) {
    int items;

    if (array_size % ARRAY_STEP == 0) {
      array = realloc(array, (array_size + ARRAY_STEP)*sizeof(contig_align_t));
      if (array == NULL) {
	fprintf(stderr,"FATAL ERROR: Out of memory reading input.\n");
	exit(-1);
      }
    }
    p = &array[array_size++];

    /* Set defaults to guard against any weird non-matching cases */
    p->highlight = 0;
    p->start_loc = p->end_loc = p->start_trim = p->end_trim = 0;
    p->source_id[0] = 0;

    /* Warning: Marty changed the first field width in this sscanf to
       60, 2006-03-24. It was formerly 30, which, given that
       contig_align_t's source_id was 32, made him fear that Koni was
       doing something untoward with the 31st byte of that structure
       member, and for voodoo's sake, Marty provided for twice the
       untowardness in the doubly-large source_id member. */
    items = sscanf(inputline, "%60[^\t]\t%30[^\t]\t%c\t%d\t%d\t%d\t%d\t%d", p->source_id, 
		   &p->seq_id, &p->strand, &p->start_loc, &p->end_loc, 
		   &p->start_trim, &p->end_trim, &p->highlight);
    if (items != 8) {
      fprintf(stdout,"Only matched %d items at (stdin) line %d: Skipping "
	      "line\n",items,array_size);
    }
 
    fgets(inputline, 256, stdin);
  }

  *return_array = array;
  *return_size = array_size;
}

/* This function is passed to qsort() to sort the list of contig
   alignment data by starting position relative to the contig. */
static int start_compare(const void *a, const void *b) {
  contig_align_t *c;
  contig_align_t *d;
  
  c = (contig_align_t *) a;
  d = (contig_align_t *) b;

  if ((c->start_loc+c->start_trim) != (d->start_loc+d->start_trim)) 
    return (c->start_loc+c->start_trim) - (d->start_loc+d->start_trim);
  else
    return (c->end_loc-c->end_trim) - (d->end_loc-d->end_trim);
}

/* Find the maximum height of the histogram, round up. For layout in
   the image. Histogram must be at least 30 pixels high. */
static int compute_histogram_height(height_data_t *height_data, 
				    int n_heights) {
  int i;
  int max_height;

  max_height = 0;
  for(i=0;i<n_heights;i++)
    if (max_height < height_data[i].height)
      max_height = height_data[i].height;

  if (max_height < 60) return 60;

  max_height += (30 - (max_height % 30));
  return max_height;
}

static int compute_ytic(int histogram_height) {
  
  if (histogram_height <= 60) return 15;
  else return 20;
}

static int compute_xmax(height_data_t *height_data, int n_heights) {
  int last_basepair, xmax;

  last_basepair = height_data[n_heights-1].position;
  xmax = last_basepair + (100 - (last_basepair % 100));

  return xmax;
}

/* For the moment, we are going to hard code the number of x axis tics */
#define N_XTICS (10)
static int compute_xtic(int xmax) {
  return xmax / N_XTICS;
}

/* Edges, counterclockwise from the top */
typedef struct {
  int north;
  int west;
  int south;
  int east;
} pane_t;
#define BORDER_WIDTH (3)
#define PAD (10)
#define HIST_WIDTH (350)

enum { HIST_PANE = 0, ALIGN_PANE, INFO_PANE, LEGEND_PANE, N_PANES };

static int compute_panes(pane_t panes[], int n_sequences, 
			 int histogram_height) {
  int font_height;
  int image_height;

  /* Make height of font (for purpose of computing the space needed to write
     the sequence alignment and their names, and odd number so that the 
     mid-point is an integer. */
  font_height = localFont->h;
  if (!(font_height & 0x1)) font_height += 1;

  /* Space needed by the coverage histogram, plus the labeling */
  image_height = histogram_height + font_height*3; 

  /* Space needed by the sequence alignment pane */
  image_height += font_height*n_sequences;

  /* Room for the bevel'd border */
  image_height += BORDER_WIDTH*2;

  /* Padding from the bevel to the content area, plus each pane is padded */
  image_height += PAD*4;

  panes[HIST_PANE].north = BORDER_WIDTH + PAD;
  panes[HIST_PANE].west = BORDER_WIDTH + PAD;
  panes[HIST_PANE].south = panes[HIST_PANE].north + histogram_height + 
    font_height*3 + PAD;
  /* Account for ytics (up to 4 characters) and axis label, 1 line vertical */
  panes[HIST_PANE].east = panes[HIST_PANE].west + HIST_WIDTH + 
    localFont->w*4 + font_height;

  panes[ALIGN_PANE].north = panes[HIST_PANE].south + PAD;
  panes[ALIGN_PANE].west = panes[HIST_PANE].west;
  /* Allocate space for each sequence, but every 5 sequences we'll draw a rule
     so people can align the sequence with the information on the right */
  panes[ALIGN_PANE].south = panes[ALIGN_PANE].north + n_sequences*font_height;
  panes[ALIGN_PANE].east = panes[HIST_PANE].east;

  panes[INFO_PANE].north = panes[ALIGN_PANE].north;
  panes[INFO_PANE].west = panes[ALIGN_PANE].east;
  panes[INFO_PANE].south = panes[ALIGN_PANE].south;
  /* Allow 42 characters maximum in the info PANE */
  panes[INFO_PANE].east = panes[INFO_PANE].west + localFont->w*48;
  
  panes[LEGEND_PANE].north = panes[HIST_PANE].north;
  panes[LEGEND_PANE].west = panes[HIST_PANE].east;
  panes[LEGEND_PANE].east = panes[INFO_PANE].east;
  panes[LEGEND_PANE].south = panes[HIST_PANE].south;

  return image_height;
}

static void histogram_drawgrid(gdImagePtr im, pane_t pane, int xmax, int xtic, 
			       int ymax, int ytic) {
  
  float basis;
  int black, i;
  int x,y;
  char label[15];
 
  /* draw rectange */
  black = gdImageColorResolve(im, 0, 0, 0);
  gdImageRectangle(im, pane.west, pane.north, pane.east, 
		   pane.south, black);
  
  /* Draw gridlines and tic marks */
  basis = (float) xmax/(float) (pane.east - pane.west);
  for(i=0;i<=N_XTICS;i++) {
    x = pane.west;
    x += (int) ((float) ((i*xtic)/basis + 0.5));
    if (i!=0 && i!=N_XTICS)
      for(y=pane.north;y<pane.south;y+=3)
	gdImageSetPixel(im, x, y, black);
    gdImageLine(im, x, pane.north, x, pane.north-3, black);
    gdImageLine(im, x, pane.south, x, pane.south+1, black);

    sprintf(label,"%d",i*xtic);
    x = x - (strlen(label)/2.0)*localFont->w;
    y = pane.north - 4 - localFont->h;
    gdImageString(im, localFont, x, y, label, black); 
  }
  strcpy(label,"position (bp)");
  x = pane.west + (pane.east - pane.west)/2 - (strlen(label)/2.0)*localFont->w;
  y = pane.north - 5 - localFont->h*2;
  gdImageString(im, localFont, x, y, label, black);

  for(i=0;i<=ymax;i+=ytic) {
    y = i + pane.north;
    if (i!=0 && i!=ymax)
      for(x=pane.west;x<pane.east;x+=3)
	gdImageSetPixel(im, x, y, black);
    gdImageLine(im, pane.west, y, pane.west-3, y, black);
    gdImageLine(im, pane.east, y, pane.east+3, y, black);

    sprintf(label,"%d",i);
    x = pane.west - strlen(label)*localFont->w - 4;
    y = y - localFont->h/2;
    gdImageString(im, localFont, x, y, label, black); 
  }
  x = pane.west - localFont->w*4 - localFont->h - 1;
  y = pane.north + (pane.south - pane.north)/2.0 + localFont->w*2.5;
  gdImageStringUp(im, localFont, x, y, "Depth", black);
  
}

static void draw_histogram(gdImagePtr im, pane_t pane, 
			   height_data_t *height_data, int n_heights,
			   int xmax, int xtic, int histogram_height,
			   int ytic) {
  
  pane_t grid_pane;
  int font_height, i, mediumgray;
  float basis;

  font_height = localFont->h;
  if ((font_height & 0x1) == 0) font_height++;

  /* Establish the grid area where we actually draw the histogram. Other
     area is for axis label and tic marks */
  grid_pane.north = pane.north + font_height * 3;
  grid_pane.west = pane.west + localFont->h *1.5 + localFont->w * 4;
  grid_pane.east = pane.east - PAD;
  grid_pane.south = pane.south - PAD;

  histogram_drawgrid(im, grid_pane, xmax, xtic, histogram_height, ytic);
  basis = (float) xmax/(grid_pane.east - grid_pane.west);

  mediumgray = gdImageColorResolve(im, 0x80, 0x80, 0x80);
  for(i=0;i<n_heights-1;i++) {
    int left, right, top, bottom;
    left = grid_pane.west + 
      (int) ((float) height_data[i].position/basis + 0.5);
    right = grid_pane.west + 
      (int) ((float) height_data[i+1].position/basis + 0.5);
    top = grid_pane.north + 1;
    bottom = grid_pane.north + height_data[i].height + 1;

    gdImageFilledRectangle(im, left, top, right, bottom, mediumgray);
  }

}

static void draw_leftarrow(gdImagePtr im, int x, int y, int color) {

  gdImageLine(im,x,y,x-15,y,color);
  gdImageLine(im,x-15,y,x-5,y-2,color);
  gdImageLine(im,x-15,y,x-5,y+2,color);
}

static void draw_rightarrow(gdImagePtr im, int x, int y, int color) {

  gdImageLine(im,x,y,x+15,y,color);
  gdImageLine(im,x+15,y,x+5,y-2,color);
  gdImageLine(im,x+15,y,x+5,y+2,color);
}

static void draw_dottedline(gdImagePtr im, int x, int y, int color) {
  int i;

  for(i=0;i<18;i+=6)
    gdImageLine(im, x + i, y, x + i + 2, y, color);
}

static void draw_alignments(gdImagePtr im, pane_t pane, 
			    contig_align_t *align_data, int n_sequences, 
			    int xmax, int xtic)  {

  int i, x, y;
  float basis;
  int west_edge, east_edge;
  int black, red, blue;
  int font_height;
  int start, covered_start, covered_end, end;
  char label[15];

  /* First, compute the west and east boundary that corresponds to the
     histogram image above our pane */  
  west_edge = pane.west + localFont->h *1.5 + localFont->w * 4;
  east_edge = pane.east - PAD;

  font_height = localFont->h;
  if ((font_height & 0x1) == 0) font_height++;

  basis = (float) xmax/((float) east_edge - west_edge);

  black = gdImageColorResolve(im, 0, 0, 0);
  red = gdImageColorResolve(im, 0xFF, 0, 0);
  blue = gdImageColorResolve(im, 0x33, 0x11, 0xFF);

  for(i=0;i<=N_XTICS;i++) {
    x = west_edge + ((float) ((i*xtic)/basis + 0.5));
    for(y=pane.north;y<pane.south;y+=3) {
      gdImageSetPixel(im, x, y, black);
    }
  }

  for(i=0;i<n_sequences;i++) {
    y = pane.north + (int) ((float) font_height*(i+0.5) + 0.5);

    covered_start = align_data[i].start_loc + align_data[i].start_trim;
    covered_start = west_edge + (int) ((float)covered_start/basis + 0.5);
    covered_end = align_data[i].end_loc - align_data[i].end_trim;
    covered_end = west_edge + (int) ((float)covered_end/basis + 0.5);
    if (align_data[i].strand == '+') {
      gdImageLine(im, covered_start, y, covered_end, y, black);
    } 
    else {
      gdImageLine(im, covered_start, y, covered_end, y, blue);
    }
	
    /* draw leading red segment if trimmed */
    if (align_data[i].start_trim > 0) {
      /* Draw left arrow if untrimmed sequence starts before contig */
      if (align_data[i].start_loc < 0) { 
	//draw_leftarrow(im, west_edge, y, red);
	draw_dottedline(im, west_edge - 18, y, red);
	sprintf(label,"%dbp",-1*align_data[i].start_loc);
	x = west_edge - (strlen(label)+1)*gdFontTiny->w;
	//x = west_edge - 18;
	gdImageString(im, gdFontTiny, x, y - gdFontTiny->h, label, red);
	start = west_edge;
      } else {
	start = west_edge + (int)((float) align_data[i].start_loc/basis + 0.5);
      } 
      gdImageLine(im, start, y, covered_start-1, y, red);
    }
    
    if (align_data[i].end_trim > 0) {
      if (align_data[i].end_loc > xmax) {
	draw_dottedline(im, east_edge, y, red);
	sprintf(label,"%dbp",align_data[i].end_loc - xmax);
	x = east_edge + gdFontTiny->w;
	gdImageString(im, gdFontTiny, x, y - gdFontTiny->h, label, red);
	end = east_edge;
      } else {
	end = west_edge + (int)((float) align_data[i].end_loc/basis + 0.5);
      }
      gdImageLine(im, covered_end + 1, y, end, y, red);
    }
      
  }
}

/* Allocate an image, draw the bevel border */
static gdImagePtr new_image(int width, int height, int gray) {
  gdImagePtr im;
  int bgcolor, frontshade, backshade;
  int i;

  im = gdImageCreate(width+1, height+1);
  
  /* Interlacing allows browsers that support it to show it immedtiately
     upon loading the first portion of it, then update the quality as the rest
     of the image loads */
  //  gdImageInterlace(im, 1);

  if (gray<30) gray = 30;
  bgcolor = gdImageColorAllocate(im, gray, gray, gray);
  frontshade = gdImageColorAllocate(im, gray-35, gray-35, gray-35);
  backshade = gdImageColorAllocate(im, gray-75, gray-75, gray-75);

  /* Draw lighter bevel on north and west sides */
  for(i=0;i<BORDER_WIDTH;i++) {
    gdImageLine(im, i, i, width-(i+1), i, frontshade);
    gdImageLine(im, i, i, i, height-(i+1), frontshade);
  }

  for(i=0;i<BORDER_WIDTH;i++) {
    gdImageLine(im, i, height-i, width-i, height-i, backshade);
    gdImageLine(im, width-i, i, width-i, height-i, backshade);
  }

  return im;
}

static void draw_seqinfo(gdImagePtr im, pane_t pane, 
			 contig_align_t *align_data, int n_sequences) {
  int font_height;
  int black, blue, color;
  int west_edge;
  int y, i;
  char label[80];
  int used, total;
  int source_id_len;
  char short_source_id[32];

  font_height = localFont->h;
  if ((font_height & 0x1) == 0) font_height++;

  west_edge = pane.west + localFont->w*2;

  black = gdImageColorResolve(im, 0, 0, 0);
  blue = gdImageColorResolve(im, 0x00, 0x00, 0xFF);
  
  if (mapfile) fprintf(mapfile,"<map name=\"contigmap_%s\">", image_name);

  for(i=0;i<n_sequences;i++) {
    y = pane.north + i * font_height;
   
    total = align_data[i].end_loc - align_data[i].start_loc;
    used = total - (align_data[i].start_trim + align_data[i].end_trim);

    /* If the source_id is too wide for the display, lop off the right end
       and replace it with dotdotdot.  Marty, 2006-03-24 */
    source_id_len = strlen(align_data[i].source_id);
    if (source_id_len > 29) { /* The width of the image was more or
				 less fixed when I got here.
				 -- Marty. */
      strncpy ((char *)short_source_id, align_data[i].source_id, 26);
      strcpy ((char *)(short_source_id+26), "... "); /* Mind the space! */
    } else 
      strcpy (short_source_id, align_data[i].source_id);

    sprintf(label,"%-30.30s %dbp (%1.0f%%)", short_source_id, total,
	    used/(float) total * 100);
    if (align_data[i].strand == '+') color = black;
    else color = blue;

    if (align_data[i].highlight) {
      /* This used to bold-face here, but it looks silly with the more recent gd
	 versions -- (using gdFontMediumBold) -- leaving the structure here for 
	 experimentation later with other fonts that don't blow out as much */
      gdImageString(im, localFont, west_edge, y, label, color);
    } else {
      gdImageString(im, localFont, west_edge, y, label, color);
    }

    if (mapfile)
      fprintf(mapfile,"<area coords=\"%d,%d,%d,%d\" "
	    "href=\"%s%s\">\n",
	    west_edge,y,west_edge+strlen(label)*localFont->w,y+localFont->h,
	    link_basename, align_data[i].seq_id);
  }
  if (mapfile) {
    fprintf(mapfile,"</map>\n");
    fflush(mapfile);
    fclose(mapfile);
  }
}

static void draw_legend(gdImagePtr im, pane_t pane, int contig_length,
			int cluster, int contig) {
  int line;
  int north_edge, west_edge;
  int black, red, blue;
  char label[80];

  north_edge = pane.north + PAD;
  west_edge = pane.west + PAD*5;

  line = localFont->h;

  black = gdImageColorResolve(im, 0, 0, 0);
  red = gdImageColorResolve(im, 0xCC, 0, 0);
  blue = gdImageColorResolve(im, 0, 0, 0xCC);
  
  sprintf(label,"Alignment Image: %s",image_name);
  gdImageString(im, localFont, west_edge, north_edge, label, black);
  
  strcpy(label,"Reverse Complement Strand");
  gdImageString(im, localFont, west_edge + 20, north_edge + line*1.5, label, blue);
  gdImageLine(im, west_edge, north_edge + line*2, west_edge+15, north_edge + line*2, blue);
  
  strcpy(label,"Given Strand");
  gdImageString(im, localFont, west_edge + 20, north_edge + line*2.5, label, black);
  gdImageLine(im, west_edge, north_edge + line*3, west_edge + 15, north_edge + line*3, black);

  strcpy(label,"Trimmed (non-matching) sequence");
  gdImageString(im, localFont, west_edge + 20, north_edge + line*3.5, label, red);
  gdImageLine(im, west_edge, north_edge + line*4, west_edge + 15, north_edge + line*4, red);
  
  /* Actual contig length is one less the number passed in here, because that
     number is actually the position of the last trimmed EST member, and the
     right position is not inclusive by design. See the height building code. */
  sprintf(label,"Total Length: %d bp", contig_length-1);
  gdImageString(im, localFont, west_edge + 20, north_edge + line*5, label, black);
}


static int gray(int r, int g, int b) {

  r |= 0x1F; g |= 0x1f; b |= 0x1f;
  if (((r<<1) - g - b) == 0) return 1;
   
  return 0;
}

static gdImagePtr build_thumbnail3(gdImagePtr im, pane_t pane, int w_factor, 
				   int h_factor) {
  int width, height, tn_width, tn_height;
  int x_cells, y_cells, x, y, source_x, source_y;
  int basis;
  int *average_red, *average_blue, *average_green;
  gdImagePtr tn_im;
  

  width = gdImageSX(im);
  height = gdImageSY(im);
 
  width -= (width % w_factor);
  height -= (height % h_factor);
  basis = (w_factor) * (h_factor) * 4;

  tn_width = width/w_factor;
  tn_height = height/h_factor;

  average_red = malloc(tn_width*tn_height*sizeof(int));
  average_green = malloc(tn_width*tn_height*sizeof(int));
  average_blue = malloc(tn_width*tn_height*sizeof(int));

  tn_im = gdImageCreate(tn_width, tn_height);
  gdImagePaletteCopy(tn_im, im);

  x_cells = tn_width - 1;
  y_cells = tn_height - 1;

  source_x = source_y = 0;
  for(x=0;x<x_cells;x++) {
    for(y=0;y<y_cells;y++) {
      int red, green, blue, index, i, j, pixel_color;
      red = green = blue = 0;
      source_x = x*w_factor;
      for(i=0;i<w_factor;i++) {
	source_x++;
	source_y = y*h_factor;
	for(j=0;j<h_factor;j++) {
	  source_y++;
	  pixel_color = im->pixels[source_y][source_x];
	  red += gdImageRed(im, pixel_color);
	  green += gdImageGreen(im, pixel_color);
	  blue += gdImageBlue(im, pixel_color);
	}
      }

      index = x*y_cells + y;
      average_red[index] = (red/basis);
      average_green[index] = (green/basis);
      average_blue[index] = (blue/basis);
    }
  }

  for(x=0;x<x_cells;x++) {
    for(y=0;y<y_cells;y++) {
      int red, green, blue, color;
      int index;
      index = x*y_cells + y;
      red = (average_red[index] + average_red[index + y_cells] + 
	average_red[index+1] + average_green[index + y_cells+1]);
      green = (average_green[index] + average_green[index + y_cells] 
	+  average_green[index+1] + average_green[index + y_cells+1]);
      blue = (average_blue[index] + average_blue[index + y_cells] + 
	average_blue[index+1] + average_blue[index + y_cells+1]);
      color = gdImageColorResolve(tn_im, red |0x7, green|0x7, blue|0x7);
      tn_im->pixels[y][x] = color;
    }
  }

  free(average_red);
  free(average_blue);
  free(average_green);
  return tn_im;
}

static void build_image(FILE *pngout, contig_align_t *align_data, 
			int n_sequences, height_data_t *height_data, 
			int n_heights) {
  int histogram_height, image_height, ytic;
  int xtic, xmax;
  int lightgray, i, font_height; 
  gdImagePtr im;
  pane_t panes[N_PANES];

  /* Compute parameters for the vertical aspect of the image */
  histogram_height = compute_histogram_height(height_data, n_heights);
  ytic = compute_ytic(histogram_height);

  /* Compute parameters for the horizontal aspect of the image */
  xmax = compute_xmax(height_data, n_heights);
  xtic = compute_xtic(xmax);

  /* This gives us four panes to draw stuff in, like this

     ---------------------------------------
     |                              |      |
     |                              |      |
     | Coverage Histrogram          |LEGEND|
     |                              |      |
     |                              |      |
     ---------------------------------------
     |                              |      |
     |                              |      |
     |  Sequence Alignment          | Seq  |
     |                              | Info |
     |                              |      |
     |                              |      |
     |                              |      |
     --------------------------------------- */
  image_height = compute_panes(panes, n_sequences, histogram_height);

  im = new_image(panes[LEGEND_PANE].east+PAD+BORDER_WIDTH, image_height, 0xFF);

  /* Draw gray'd bars to disinquish sequences in alignment/info pane */
  lightgray = gdImageColorResolve(im, 0xDD, 0xDD, 0xDD);
  font_height = localFont->h;
  if (n_sequences > 6) {
    if (! (font_height & 0x1)) font_height ++;
    for(i=0;i<n_sequences-3;i+=6) {
      int y1, y2;
      y1 = panes[ALIGN_PANE].north + i*font_height;
      y2 = panes[ALIGN_PANE].north + (i+3)*font_height;
      gdImageFilledRectangle(im, panes[ALIGN_PANE].west, y1, 
			     panes[INFO_PANE].east, y2, lightgray);
    }
    if (n_sequences % 6 > 0 && n_sequences % 6 <= 3) {
      int y1, y2;
      y1 = panes[ALIGN_PANE].north + i*font_height;
      y2 = panes[ALIGN_PANE].north + (n_sequences)*font_height;
      gdImageFilledRectangle(im, panes[ALIGN_PANE].west, y1, 
			     panes[INFO_PANE].east, y2, lightgray);
    }      
  }
  for(i=0;i<n_sequences;i++) {
    if (align_data[i].highlight) {
      int pink; 
      int y1,y2;
      pink = gdImageColorAllocate(im,0xFF,0x00,0x00);
      
      y1 = panes[ALIGN_PANE].north + i*font_height;
      y2 = panes[ALIGN_PANE].north + (i+1)*font_height;
      gdImageRectangle(im, panes[ALIGN_PANE].west, y1, 
		       panes[INFO_PANE].east, y2, pink);
    }
  }
  
  draw_histogram(im, panes[HIST_PANE], height_data, n_heights, xmax, xtic, 
		 histogram_height, ytic);

  draw_alignments(im, panes[ALIGN_PANE], align_data, n_sequences, xmax, xtic);

  draw_seqinfo(im, panes[INFO_PANE], align_data, n_sequences);

  draw_legend(im, panes[LEGEND_PANE], height_data[n_heights-1].position, 0, 0);

  if (use_thumbnail) {
    gdImagePtr im_thumbnail;

    im_thumbnail = build_thumbnail3(im, panes[HIST_PANE], 4, 4);
    gdImagePng(im_thumbnail, pngout);
    gdImageDestroy(im_thumbnail);
  } else {
    gdImagePng(im, pngout);
  }
  fflush(pngout);
  gdImageDestroy(im);
}

int main(int argc, char *argv[]) {
  contig_align_t *align_data;
  height_data_t *height_data;
  int n_sequences, n_heights;

  comline(argc, argv);

  localFont = gdFontSmall;

  read_input(&align_data, &n_sequences);
  if (n_sequences == 0) return -1;

  qsort(align_data, n_sequences, sizeof(contig_align_t), start_compare);

  compute_heights(&height_data, &n_heights, align_data, n_sequences);

  build_image(pngout, align_data, n_sequences, height_data, n_heights);
  
  fclose(pngout);

  /*fclose(pngout);*/
  return 0;
}

