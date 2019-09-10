
  function draw_blast_graph(sgn_graph_array,seq_length) {

    var img_height = 2000;
    var img_width = 920;
    var canvas_width = 1000;

    var xscale = +(img_width/seq_length); // to transform sequence length to pixels

    //Create canvas stage
    var kjs_canvas = new Kinetic.Stage({
      container: "myCanvas",
      width: canvas_width,
      height: 700
    });

    var ksj_layer = new Kinetic.Layer();

    var query_length_text = new Kinetic.Text({
      x: 0,
      y: 35,
      text: "Query length ("+seq_length+")",
      fill: "#333",
      fontSize: 20,
      width: canvas_width,
      align: "center",
      fontFamily: 'Helvetica'
    });

    ksj_layer.add(query_length_text);

    // print score legend on top_line
    var score_legend_0 = new Kinetic.Rect({
      x: 0,
      y: 0,
      width: canvas_width/5 +5,
      height: 30,
      fill: "#000",
    })

    var score_legend_40 = new Kinetic.Rect({
      x: canvas_width/5 +1,
      y: 0,
      width: canvas_width/5 +5,
      height: 30,
      fill: "#0047c8",
    })

    var score_legend_50 = new Kinetic.Rect({
      x: 2*canvas_width/5 +1,
      y: 0,
      width: canvas_width/5 +5,
      height: 30,
      fill: "#77de75",
    })

    var score_legend_80 = new Kinetic.Rect({
      x: 3*canvas_width/5 +1,
      y: 0,
      width: canvas_width/5 +5,
      height: 30,
      fill: "#e967f5",
    })

    var score_legend_200 = new Kinetic.Rect({
      x: 4*canvas_width/5 +1,
      y: 0,
      width: canvas_width/5 +5,
      height: 30,
      fill: "#e83a2d",
    })

    ksj_layer.add(score_legend_0);
    ksj_layer.add(score_legend_40);
    ksj_layer.add(score_legend_50);
    ksj_layer.add(score_legend_80);
    ksj_layer.add(score_legend_200);

    var score_text_0 = new Kinetic.Text({
      x: 0,
      y: 10,
      text: "<40",
      fill: "#fff",
      fontSize: 16,
      width: (canvas_width/5),
      align: "center",
      fontFamily: 'Helvetica'
    });

    var score_text_40 = new Kinetic.Text({
      x: canvas_width/5,
      y: 10,
      text: "40-50",
      fill: "#fff",
      fontSize: 16,
      width: (canvas_width/5),
      align: "center",
      fontFamily: 'Helvetica'
    });

    var score_text_50 = new Kinetic.Text({
      x: 2*canvas_width/5,
      y: 10,
      text: "50-80",
      fill: "#fff",
      fontSize: 16,
      width: (canvas_width/5),
      align: "center",
      fontFamily: 'Helvetica'
    });

    var score_text_80 = new Kinetic.Text({
      x: 3*canvas_width/5,
      y: 10,
      text: "80-200",
      fill: "#fff",
      fontSize: 16,
      width: (canvas_width/5),
      align: "center",
      fontFamily: 'Helvetica'
    });

    var score_text_200 = new Kinetic.Text({
      x: 4*canvas_width/5,
      y: 10,
      text: ">=200",
      fill: "#fff",
      fontSize: 16,
      width: (canvas_width/5),
      align: "center",
      fontFamily: 'Helvetica'
    });

    ksj_layer.add(score_text_0);
    ksj_layer.add(score_text_40);
    ksj_layer.add(score_text_50);
    ksj_layer.add(score_text_80);
    ksj_layer.add(score_text_200);



    // print horizontal line under ticks
    var top_line = new Kinetic.Line({
      points: [0, 80,canvas_width, 80],
      stroke: "#000",
      strokeWidth: 2,
    });

    //print vertical lines and tick values
    var tick_dist = 100;

    if (seq_length > 2450) {tick_dist = 150;}
    if (seq_length > 3900) {tick_dist = 200;}
    if (seq_length > 5000) {tick_dist = 300;}
    if (seq_length > 7500) {tick_dist = seq_length/5;}

    var vline_tag = tick_dist;

    for (var l=tick_dist; l+tick_dist/2<seq_length; l+=tick_dist) {
      var i = l*xscale;

      var vline = new Kinetic.Line({
        points: [i, 75,i, img_height],
        stroke: "#ccc",
        // stroke: "#efefef",
        strokeWidth: 1,
      });
      ksj_layer.add(vline);

      var tick_text = new Kinetic.Text({
        x: i-14,
        y: 60,
        text: vline_tag,
        fill: "black",
        fontSize: 16,
        fontFamily: 'Helvetica'
      });
      ksj_layer.add(tick_text);

      vline_tag+=tick_dist;
    }

    var id_text = new Kinetic.Text({
      x: img_width+25,
      y: 60,
      text: "ID%",
      fill: "black",
      fontSize: 16,
      fontFamily: 'Helvetica'
    });
    ksj_layer.add(id_text);


    ksj_layer.add(top_line);
    kjs_canvas.add(ksj_layer);

    //print the rectangles
    off_set = printRectangles(kjs_canvas,sgn_graph_array,seq_length,img_width);

    // $("#myCanvas").css("height",off_set+"px");
    kjs_canvas.height(off_set);
  }


  function printRectangles(kjs_canvas,sgn_graph_array,seq_length,img_width) {

    var xscale = +(img_width/seq_length); // to transform sequence length to pixels
    var off_set = 80; //just under the horizontal line
    var coord_y = 0;
    var sqr_height = 16;
    var before_block = 20;

    var description;
    var canvas_width = kjs_canvas.width();
    var prev_subject = "grjhg";

    var rectangle_layer = new Kinetic.Layer();
    kjs_canvas.add(rectangle_layer);

    var popup_layer = new Kinetic.Layer();
    kjs_canvas.add(popup_layer);

    var row = 1;

    // each track
    for (var t=0; t<sgn_graph_array.length; t++) {

      var subject_name = sgn_graph_array[t]["name"];
      var subject_desc = sgn_graph_array[t]["description"];
      var subject_start = sgn_graph_array[t]["qstart"];
      var subject_end = sgn_graph_array[t]["qend"];
      var subject_score = sgn_graph_array[t]["score"];
      var subject_id_percent = sgn_graph_array[t]["id_percent"];
      var s_description = subject_name+" "+subject_start+"-"+subject_end+" "+subject_desc
      var next_subject = "null"

      if (sgn_graph_array[t+1]) {
        next_subject = sgn_graph_array[t+1]["name"]
      } else {
        next_subject = "null"
      }

      if (prev_subject != subject_name) {
        row = 1;
      }


      m_width = +((+subject_end - +subject_start +1)*xscale); //rectangle width in pixels
      m_start = +(+subject_start*xscale); //rectangle start in pixels
      score = +subject_score;

      // var strokeColor = "#dfdfdf";
      var fillColor = "rgba(255, 50, 40, 0.8)";

      //set color
      if (score >= 200) {
        fillColor = "rgba(255, 50, 40, 0.8)";
      } else if (score < 200 && score >= 80) {
        fillColor ='rgba(235,96,247, 0.8)';
      } else if (score < 80 && score >= 50) {
        fillColor ='rgba(119,222,117, 0.8)';
      } else if (score < 50 && score >= 40) {
        fillColor ='rgba(0,62,203, 0.8)';
      } else if (score < 40) {
        fillColor ='rgba(10,10,10, 0.8)';
      }


      coord_y = off_set + row*(sqr_height+2);

      var blastHit = new Kinetic.Rect({
        id: subject_name,
        x: m_start,
        y: coord_y-15,
        width: m_width,
        height: sqr_height,
        // strokeWidth: 1,
        cornerRadius: 1,
        fill: fillColor,
        // stroke: strokeColor
      });
      rectangle_layer.add(blastHit);



      if (prev_subject != subject_name) {
        //print subject names
        var subject_text = new Kinetic.Text({
          x: 3,
          y: off_set+4,
          text: subject_name,
          fill: "#000",
          // fill: "#4f4f4f",
          fontSize: 16,
          fontFamily: 'Helvetica'
        });

        var gene_bg = new Kinetic.Rect({
          id: 'bg'+subject_name,
          x: 0-subject_text.width()-5,
          y: off_set,
          width: subject_text.width()+5,
          height: 22,
          fill: 'rgba(255,255,255, 0.5)',
        });
        

        rectangle_layer.add(gene_bg);
        rectangle_layer.add(subject_text);
        
        // clicking on gene names
        subject_text.on('mousedown', function() {
          var gene_name = this.text();
          document.getElementById(gene_name).click();
        });
        
        // clicking on hit boxes
        blastHit.on('mousedown', function() {
          var hit_id = this.id();
          document.getElementById(hit_id).click();
        });
        
        
        //over gene names
        subject_text.on('mouseover', function() {
          
          document.body.style.cursor = 'pointer';
          var gene_name = this.text();
          var bg_rect = rectangle_layer.find("#bg"+gene_name);
          var rect_width = this.width()-5;
          
          bg_rect.fill('rgba(255,255,255, 0.5)');
          
          var anim = new Kinetic.Animation(function(frame) {
            
            bg_rect.setX(0 -rect_width -5 + frame.time);
            // bg_rect.setX(amplitude * Math.sin(frame.time * 2 * Math.PI / period) + 2);
            
            if (frame.time >= rect_width) {
               anim.stop();
               bg_rect.setX(0);
            }
            
          }, rectangle_layer);

          anim.start();
        });
        
        subject_text.on('mouseout', function() {
          document.body.style.cursor = 'default';
          var gene_name = this.text();
          var bg_rect = rectangle_layer.find("#bg"+gene_name);
          var rect_width = this.width()-5;
          
          var anim = new Kinetic.Animation(function(frame) {
            bg_rect.setX(0 - frame.time);

            if (frame.time >= rect_width) {
               anim.stop();
               bg_rect.setX(0 -rect_width -5);
            }

          }, rectangle_layer);

          anim.start();
        });
        
        //off_set += before_block; //add some space after the names
      }

      //to allow as many rows as the n-mer size
      row++;

      draw_popup(canvas_width,blastHit,popup_layer,s_description);

      //print id %
      var id_100 = canvas_width - img_width -5;
      var id_width = subject_id_percent*id_100/100;

      var id_rect = new Kinetic.Rect({
        x: img_width+5,
        y: coord_y-15,
        width: id_width,
        height: 15,
        strokeWidth: 1,
        fill: "#cfcfcf"
      });
      rectangle_layer.add(id_rect);

      var id_text = new Kinetic.Text({
        x: img_width+7,
        y: coord_y-15,
        text: subject_id_percent,
        fill: "black",
        // width: id_100,
        align: "left",
        fontSize: 16,
        fontFamily: 'Helvetica'
      });
      rectangle_layer.add(id_text);
      
      
      if (subject_name != next_subject) {

        // distance between tracks
        var track_height = (row-1)*(sqr_height+2)+5;
        off_set += track_height; //add space for next track

        // print horizontal line under tracks
        var hline = new Kinetic.Line({
          points: [0, off_set,canvas_width, off_set],
          stroke: "#ccc",
          strokeWidth: 1,
        });
        rectangle_layer.add(hline);
        hline.moveToTop();
        rectangle_layer.draw();

      }

      prev_subject = subject_name;
    } // close for subjects


    return off_set;

  } // close printSquares


  function move_bg_rect(pos) {
    
    pos += 1;
    
    return pos;
  }


  function draw_popup(canvas_width,blastHit,popup_layer,desc) {

    blastHit.on('mouseover', function() {
      
      
       var desc_group = new Kinetic.Group();
      
      document.body.style.cursor = 'pointer';
      var hit_x = this.getAbsolutePosition().x + this.width()/2;
      var hit_y = this.getAbsolutePosition().y-26;

      //print subject descriptions
      var subject_desc = new Kinetic.Text({
        x: hit_x,
        y: hit_y-5,
        text: desc,
        fill: "black",
        fontSize: 16,
        fontFamily: 'Helvetica'
      });

       subject_desc.x(hit_x - subject_desc.width()/2);

      var desc_width = subject_desc.width();

      var hit_popup = new Kinetic.Rect({
         x: subject_desc.x()-5,
         y: subject_desc.y()-5,
         fill: '#fff',
         stroke: "#aaa",
         opacity: 1,
         width: subject_desc.width()+10,
         height: 30,
         cornerRadius: 2,
         strokeWidth: 1
       });

       var x_arrow = hit_popup.x() + hit_popup.width()/2;
       var y_arrow = hit_popup.y()+12;


       var down_arrow = new Kinetic.Line({
         points: [x_arrow-15,y_arrow,    x_arrow+15,y_arrow,    x_arrow,y_arrow+30,    x_arrow-15,y_arrow],
         stroke: "#aaa",
         strokeWidth: 1,
         closed: true,
         fill: '#fff',
         lineCap: 'round',
         cornerRadius: 2,
         tension: 0
      });

       var arrow_junction = new Kinetic.Line({
         points: [x_arrow-13,y_arrow,    x_arrow+13,y_arrow,    x_arrow,y_arrow+28,    x_arrow-13,y_arrow],
         stroke: "#fff",
         strokeWidth: 1,
         closed: true,
         fill: '#fff',
         lineCap: 'round',
         cornerRadius: 2,
         tension: 0
      });

       if (desc_width + hit_x > canvas_width) {
         subject_desc.x(canvas_width - desc_width -10);
         hit_popup.x(subject_desc.x()-5);

         if (desc_width > canvas_width) {
           subject_desc.x(10);
           subject_desc.y(hit_y-15);
           subject_desc.width(canvas_width-20);

           hit_popup.x(subject_desc.x()-5);
           hit_popup.y(subject_desc.y()-5);
           hit_popup.height(40);
           hit_popup.width(canvas_width-10);

           x_arrow = hit_popup.x() + hit_popup.width()/2;
           y_arrow = hit_popup.y()+15;

         }
       }
       
       desc_group.add(down_arrow);
       desc_group.add(hit_popup);
       desc_group.add(arrow_junction);
       desc_group.add(subject_desc);
       
       popup_layer.add(desc_group);
       popup_layer.draw();
       
    });

    //on mouseout remove popups
     blastHit.on('mouseout', function() {
       document.body.style.cursor = 'default';

       popup_layer.removeChildren();
       popup_layer.draw();
     });

  }
