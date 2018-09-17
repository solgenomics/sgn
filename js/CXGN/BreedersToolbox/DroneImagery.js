
function gridDataGenerate(width, height, num_rows, num_cols, div_id) {
    var data = new Array();
    var xpos = 1; //starting xpos and ypos at 1 so the stroke will show when we make the grid below
    var ypos = 1;
    var click = 0;

    for (var row = 0; row < num_rows; row++) {
        data.push( new Array() );
    
        for (var column = 0; column < num_cols; column++) {
            data[row].push({
                x: xpos,
                y: ypos,
                width: width,
                height: height,
                click: click
            })
            xpos += width;
        }
        xpos = 1;
        ypos += height;	
    }
    console.log(data);

    d3.select(div_id).html("");
    var total_width = width*num_cols;
    var total_height = height*num_rows;
    var grid = d3.select(div_id)
        .append("svg")
        .attr("width",total_width.toString()+"px")
        .attr("height",total_height.toString()+"px")
        .style("opacity", 0.25);
    
    var row = grid.selectAll(".row")
        .data(data)
        .enter().append("g")
        .attr("class", "row");
    
    var column = row.selectAll(".square")
        .data(function(d) { return d; })
        .enter().append("rect")
        .attr("class","square")
        .attr("x", function(d) { return d.x; })
        .attr("y", function(d) { return d.y; })
        .attr("width", function(d) { return d.width; })
        .attr("height", function(d) { return d.height; })
        .style("fill", "#fff")
        .style("stroke", "#222")
        .on('click', function(d) {
            d.click ++;
            if ((d.click)%4 == 0 ) { d3.select(this).style("fill","#fff"); }
            if ((d.click)%4 == 1 ) { d3.select(this).style("fill","#2C93E8"); }
            if ((d.click)%4 == 2 ) { d3.select(this).style("fill","#F56C4E"); }
            if ((d.click)%4 == 3 ) { d3.select(this).style("fill","#838690"); }
        });

    return data;
}
