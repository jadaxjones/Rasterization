module main
import os
import math
import gfx
import rand

const (
    size       = Size2i{  512, 512 }
    center     = Point2i{ 256, 256 }
    radius     = 192
    radcols    = [ RadiusColor{ 64, gfx.red }, RadiusColor{ 128, gfx.green }, RadiusColor{ 192, gfx.blue } ]
    num_points = 36
    num_sides  = 15
)

struct RadiusColor {
    radius int
    color Color
}
struct ColoredLineSegment {
    lineseg LineSegment2i
    color   Color
}

// convenience type aliases
type Image         = gfx.Image
type Point2        = gfx.Point2
type Point2i       = gfx.Point2i
type Size2i        = gfx.Size2i
type LineSegment2i = gfx.LineSegment2i
type Color         = gfx.Color

type Rasterizer = fn (mut Image)


//////////////////////////////////////////////////////////////////////////////////////////////////
// Simple rasterizer functions


// ALREADY COMPLETE
// Rasterize a _simple_ line segment, which must: have coincident endpoints, be horizontal, or be vertical
fn (mut image Image) raster_simple_line_segment(p0 Point2i, p1 Point2i, color Color) {
    assert p0.x == p1.x || p0.y == p1.y

    /*
        set pixel colors in image along horizontal or vertical line between p0 and p1
    */

    if p0.y == p1.y {
        // horizontal line segment
        y := p0.y
        x_min := math.min(p0.x, p1.x)
        x_max := math.max(p0.x, p1.x)
        for x in x_min .. (x_max+1) {
            image.set_xy(x, y, color)
        }
    } else {
        // vertical line segment
        x := p0.x
        y_min := math.min(p0.y, p1.y)
        y_max := math.max(p0.y, p1.y)
        for y in y_min .. (y_max+1) {
            image.set_xy(x, y, color)
        }
    }
}

// ALREADY COMPLETE
// Rasterizes a rectangle into image
fn (mut image Image) raster_rectangle(center Point2i, size Size2i, color Color) {
    top_left     := Point2i{ center.x - size.width, center.y - size.height }
    bottom_left  := Point2i{ center.x - size.width, center.y + size.height }
    bottom_right := Point2i{ center.x + size.width, center.y + size.height }
    top_right    := Point2i{ center.x + size.width, center.y - size.height }

    // NOTE: can replace raster_simple_line_segment with raster_line_segment once implemented
    image.raster_simple_line_segment(top_left,     bottom_left,  color)  // left side
    image.raster_simple_line_segment(bottom_left,  bottom_right, color)  // bottom side
    image.raster_simple_line_segment(bottom_right, top_right,    color)  // right side
    image.raster_simple_line_segment(top_right,    top_left,     color)  // top side
}


//////////////////////////////////////////////////////////////////////////////////////////////////
// More interesting rasterizer functions


// COMPLETE
// Rasterizes an arbitrary line segment (general form of raster_simple_line_segment)
fn (mut image Image) raster_line_segment(p0 Point2i, p1 Point2i, color Color) {
    
    /*
        Implement Bresenham's Line Algorithm
        https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm#Algorithm
        https://gfx.cse.taylor.edu/courses/cos350/slides/31_ImageFormation_Rasterization.md.html?scale#sect005

        Suggestion: implement the integer arithmetic algorithm

        Note: Pseudocode below is modified version of Wikipedia's listing,
              but it only handles case where x0 <= x1, y0 <= y1, and dy <= dx!
        --->  You will need to generalize it to handle other conditions.  <----
    */


    mut x0 := p0.x
    mut y0 := p0.y
    x1 := p1.x
    y1 := p1.y

    dx := math.abs(x1 - x0)
    sx := if x0 < x1 { 1 } else { -1 }
    dy := -math.abs(y1 - y0)
    sy := if y0 < y1 { 1 } else { -1 }
    mut err := dx + dy


    for {
        if x0 >= 0 && x0 < size.width && y0 >= 0 && y0 < size.height {
            image.set_xy(x0, y0, color)
        }
        if x0 == x1 && y0 == y1 {
            break

        }
        e2 := 2 * err
        if e2 >= dy {
            err += dy
            x0 += sx
        }
        if e2 <= dx {
            err += dx
            y0 += sy
        }
    }
}


//COMPLETE
// Rasterizes a list of line segments
fn (mut image Image) raster_line_segments (collinesegs []ColoredLineSegment) {
    for collineseg in collinesegs {
        image.raster_line_segment(
            collineseg.lineseg.p0,
            collineseg.lineseg.p1,
            collineseg.color,
        )
    }
}

//COMPLETE
// Rasterizes a simple star (asterisk) shape
fn (mut image Image) raster_star(center Point2i, radius int, num_points int, color Color) {
    cx, cy := center.x, center.y
    for i in 0 .. num_points {
        radians := math.radians(f64(i) * 360.0 / f64(num_points))
        point := Point2i{ int(math.cos(radians) * radius + cx), int(math.sin(radians) * radius + cy) }
        image.raster_line_segment(center, point, color)
    }
}

//COMPLETE
// Rasterizes a simple, fixed, closed polygon (rotated square)
fn (mut image Image) raster_fixed_polygon(center Point2i, radius int, color Color) {
    cx, cy := center.x, center.y
    cr, sr := int(0.5403023059 * f64(radius)), int(0.8414709848 * f64(radius))
    points := [
        Point2i{ cx + cr, cy + sr },
        Point2i{ cx - sr, cy + cr },
        Point2i{ cx - cr, cy - sr },
        Point2i{ cx + sr, cy - cr },
    ]
    image.raster_line_segment(points[0], points[1], color)
    image.raster_line_segment(points[1], points[2], color)
    image.raster_line_segment(points[2], points[3], color)
    image.raster_line_segment(points[3], points[0], color)
}

//COMPLETE
// Rasterize the perimeter of a regular closed polygon
fn (mut image Image) raster_regular_polygon(center Point2i, radius int, num_sides int, color Color) {
    /*
        for each side
            compute corner points for each side (tip: use math.cos, math.sin, math.pi)
            rasterize that side as line segment
    */
    assert num_sides >= 3 // has to have at least 3 sides 

    cx, cy := center.x, center.y
    angle_step := 2.0 * math.pi / f64(num_sides)

    mut points := []Point2i{len: num_sides}

    // Compute corner points
    for i in 0 .. num_sides {
        angle := f64(i) * angle_step
        x := int(math.cos(angle) * radius + cx)
        y := int(math.sin(angle) * radius + cy)
        points[i] = Point2i{x, y}
    }

    // Rasterize each side as a line segment
    for i in 0 .. num_sides {
        p0 := points[i]
        p1 := points[(i + 1) % num_sides]
        image.raster_line_segment(p0, p1, color)
    }
}


// COMPLETE
// Rasterize the perimeter of a circle into a list of points
fn (mut image Image) raster_circle(center Point2i, radius int, color Color) {
    /*
        Implement Midpoint Circle Algorithm found on Wikipedia
        https://en.wikipedia.org/wiki/Midpoint_circle_algorithm
        https://gfx.cse.taylor.edu/courses/cos350/slides/31_ImageFormation_Rasterization.md.html?scale#sect016
    */

    cx, cy := center.x, center.y
    mut x := radius
    mut y := 0
    mut dx := 1
    mut dy := 1
    mut err := dx - (2 * radius)

    for x >= y {
        // Reflect the points to all octants
        image.set_xy(cx + x, cy + y, color)
        image.set_xy(cx + y, cy + x, color)
        image.set_xy(cx - y, cy + x, color)
        image.set_xy(cx - x, cy + y, color)
        image.set_xy(cx - x, cy - y, color)
        image.set_xy(cx - y, cy - x, color)
        image.set_xy(cx + y, cy - x, color)
        image.set_xy(cx + x, cy - y, color)
        
       if err <= 0 {
            y += 1
            err += dy
            dy += 2
        }
        if err > 0 {
            x -= 1
            dx += 2
            err += dx - (2 * radius)
        }
    }
}


//COMPLETE
// Generate a simple, fixed, closed polygon (rotated square)
fn generate_fixed_polygon(center Point2i, radius int, color Color) []ColoredLineSegment {
    mut collinesegs := []ColoredLineSegment{}

    cx, cy := center.x, center.y
    cr, sr := int(0.5403023059 * f64(radius)), int(0.8414709848 * f64(radius))
    points := [
        Point2i{ cx + cr, cy + sr },
        Point2i{ cx - sr, cy + cr },
        Point2i{ cx - cr, cy - sr },
        Point2i{ cx + sr, cy - cr },
    ]
    collinesegs << ColoredLineSegment{
        lineseg: LineSegment2i{ points[0], points[1] }
        color: color
    }
    collinesegs << ColoredLineSegment{
        lineseg: LineSegment2i{ points[1], points[2] }
        color: color
    }
    collinesegs << ColoredLineSegment{
        lineseg: LineSegment2i{ points[2], points[3] }
        color: color
    }
    collinesegs << ColoredLineSegment{
        lineseg: LineSegment2i{ points[3], points[0] }
        color: color
    }

    return collinesegs
}


//COMPLETE
// Generate fractal tree as list of line segments
//     parameter        description
//    --------------- -------------------------------------------------------
//     start:          position of where the current branch starts
//     length:         length of current branch
//     direction:      direction of branch (specified in radians)
//     length_factor:  factor of shortening for each child branch
//                     ex: 0.5 --> child branches are half as long
//     spread:         how much each child branch should deviate from direction (specified in radians)
//     spread_factor:  factor of spreading for each child branch
//     count:          how many branch generations (recursion depth) left to generate
//     max_count:      maximum branch generations (recursion depth) to generate
fn generate_fractal_tree(start Point2, length f64, direction f64, length_factor f64, spread f64, spread_factor f64, count int, max_count int) []ColoredLineSegment {
    mut collinesegs := []ColoredLineSegment{}

    /*
        compute endpoint by:
            vector = (cos(direction) * length, sin(direction) * length)
            end = start + vector
        append line segment with start and end to collinsegs list
        if count greater than zero (meaning, create children branches)
            append what is returned from 2x recursive calls to generate_fractal_tree, where:
                - start parameter is end computed above                (use end for both children)
                - length parameter is length*length_factor             (use for both children)
                - direction parameter has spread added and subtracted  (1 each)
                - length_factor is passed unchanged to children
                - spread for child is spread*spread_factor             (use for both children)
                - spread_factor is passed unchanged to children
                - count parameter is decreased by 1                    (use for both chilrden)

        Note: You can append the contents of one list onto another list using the << operator
        Note: The type of start is Point2, but LineSegment2i uses Point2i.
              Use Point2's as_point2i "method" to convert a Point2 to Point2i.
        Note: setting color for each line segment to LERP from gfx.brown to gfx.green by
              1.0 - math.pow(f64(count) / f64(max_count), 0.25) will create a more interesting colored tree
    */

    // Create the endpoint of the current branch, that will then seperate into two branches
    end_x := start.x + length * math.cos(direction)
    end_y := start.y + length * math.sin(direction)
    end := Point2{end_x, end_y}

    // Convert Point2 to Point2i
    start_i := start.as_point2i()
    end_i := end.as_point2i()

    // Compute color 
    t := 1.0 - math.pow(f64(count) / f64(max_count), 0.25)
    color := gfx.brown.lerp(gfx.white, t)


    // Append line segment 
    collinesegs << ColoredLineSegment {
        lineseg: LineSegment2i{start_i, end_i},
        color: color
    }

    //Recursive Call to check for more branches and then produce them 
    if count > 0 {
        new_length := length * length_factor
        new_spread := spread * spread_factor
        collinesegs << generate_fractal_tree(end, new_length, direction + spread, length_factor, new_spread, spread_factor, count - 1, max_count)
        collinesegs << generate_fractal_tree(end, new_length, direction - spread, length_factor, new_spread, spread_factor, count - 1, max_count)
    }
    return collinesegs
}





//ELECTIVE

fn (mut image Image) raster_filled_triangle(p0 Point2i, p1 Point2i, p2 Point2i, fill_color Color, image_width int, image_height int) {
    // Calculate the bounding box of the triangle
    mut min_x := math.min(p0.x, math.min(p1.x, p2.x))
    mut max_x := math.max(p0.x, math.max(p1.x, p2.x))
    mut min_y := math.min(p0.y, math.min(p1.y, p2.y))
    mut max_y := math.max(p0.y, math.max(p1.y, p2.y))


    // Compute the area of the main triangle
    area := 0.5 * math.abs(f64(p0.x * (p1.y - p2.y) + p1.x * (p2.y - p0.y) + p2.x * (p0.y - p1.y)))

    // Iterate over each pixel in the bounding box
    for x in min_x .. max_x + 1 {
        for y in min_y .. max_y + 1 {
            // Compute the barycentric coordinates
            p := Point2i{x, y}
            alpha := 0.5 * math.abs(f64(p.x * (p1.y - p2.y) + p1.x * (p2.y - p.y) + p2.x * (p.y - p1.y))) / area
            beta := 0.5 * math.abs(f64(p0.x * (p.y - p2.y) + p.x * (p2.y - p0.y) + p2.x * (p0.y - p.y))) / area
            gamma := 0.5 * math.abs(f64(p0.x * (p1.y - p.y) + p1.x * (p.y - p0.y) + p.x * (p0.y - p1.y))) / area



            
            if alpha >= -1e-9 && beta >= -1e-9 && gamma >= -1e-9 && alpha + beta + gamma <= 1.0 + 1e-9 {
                image.set_xy(x, y, fill_color)
            }
        }
    }
}
//END OF ELECTIVE


//FOR CREATIVE ARTIFACT
// Rasterizes a filled rectangle into the image
fn (mut image Image) raster_filled_rectangle(center Point2i, size Size2i, color Color) {
    top_left := Point2i{center.x - size.width, center.y - size.height}
    bottom_right := Point2i{center.x + size.width, center.y + size.height}

    for y in top_left.y .. bottom_right.y + 1 {
        for x in top_left.x .. bottom_right.x + 1 {
            if x >= 0 && x < image.size.width && y >= 0 && y < image.size.height {
                image.set_xy(x, y, color)
            }
        }
    }
}

//CREATIVE ARTIFACT
fn (mut image Image) raster_creative_artifact(size Size2i) {

    // Define colors for everything
    field_color := Color{0.2, 0.6, 0.2} // Green
    star_color := Color{1, 1, 1}
    snow_color := Color{1, 1, 1}
    snow_top_color := Color{1, 1, 1}

    //Create a mountain
    p0 := Point2i{150, 150}
    p1 := Point2i{300, 480}
    p2 := Point2i{10, 480}
    image_width := 100
    image_height := 100

    // Calculate the bounding box of the triangle
    mut min_x := math.min(p0.x, math.min(p1.x, p2.x))
    mut max_x := math.max(p0.x, math.max(p1.x, p2.x))
    mut min_y := math.min(p0.y, math.min(p1.y, p2.y))
    mut max_y := math.max(p0.y, math.max(p1.y, p2.y))


    // Compute the area of the main triangle
    area := 0.5 * math.abs(f64(p0.x * (p1.y - p2.y) + p1.x * (p2.y - p0.y) + p2.x * (p0.y - p1.y)))

    fill_color := Color{0.184, 0.412, 0.027}

    // Iterate over each pixel in the bounding box
    for x in min_x .. max_x + 1 {
        for y in min_y .. max_y + 1 {
            // Compute the barycentric coordinates
            p := Point2i{x, y}
            alpha := 0.5 * math.abs(f64(p.x * (p1.y - p2.y) + p1.x * (p2.y - p.y) + p2.x * (p.y - p1.y))) / area
            beta := 0.5 * math.abs(f64(p0.x * (p.y - p2.y) + p.x * (p2.y - p0.y) + p2.x * (p0.y - p.y))) / area
            gamma := 0.5 * math.abs(f64(p0.x * (p1.y - p.y) + p1.x * (p.y - p0.y) + p.x * (p0.y - p1.y))) / area

            
            if alpha >= -1e-9 && beta >= -1e-9 && gamma >= -1e-9 && alpha + beta + gamma <= 1.0 + 1e-9 {
                image.set_xy(x, y, fill_color)
            }
        }
    }image.raster_filled_triangle(p0, p1, p2, fill_color, image_width, image_height)

    //Draw snow top on mountain
    v0 := Point2i{150, 150}
    v1 := Point2i{219, 300}
    v2 := Point2i{86, 300}
    tri_width := 100
    tri_height := 100
    image.raster_filled_triangle(v0, v1, v2, snow_top_color, tri_width, tri_height)


    //snowman
    place := Point2i{450, 455}
    image.raster_circle(place, 35, gfx.white)
    mid := Point2i{450, 395}
    image.raster_circle(mid, 25, gfx.white)
    head := Point2i{450, 355}
    image.raster_circle(head, 15, gfx.white)


    // Generate a fractal tree
    tree_start := Point2{330.0, 500.0}
    tree_length := 75
    tree_direction := math.radians(270) // Pointing upwards
    tree_length_factor := 0.75
    tree_spread := math.radians(25)
    tree_spread_factor := 0.85
    tree_count := 10
    tree_max_count := 10

    tree_segments := generate_fractal_tree(tree_start, tree_length, tree_direction, tree_length_factor, tree_spread, tree_spread_factor, tree_count, tree_max_count)

    // Rasterize the fractal tree
    image.raster_line_segments(tree_segments)


    //Draw the snow layer
    snow_center := Point2i{400, 470}
    snow_size := Size2i{400, 15}
    image.raster_filled_rectangle(snow_center, snow_size, snow_color)

    // Draw the green field
    field_center := Point2i{400, 500}
    field_size := Size2i{400, 30}
    image.raster_filled_rectangle(field_center, field_size, field_color)

    // Draw stars in the sky
    num_stars := 150
    for _ in 0 .. num_stars {
        center := Point2i{gfx.int_in_range(0, size.width), gfx.int_in_range(0, size.height / 2)}
        radius := gfx.int_in_range(1, 8)
        image.raster_star(center, radius, 8, star_color)
    }
}
//END OF CREATIVE ARTIFACT


//EXTRA CREDIT
fn (mut image Image) raster_extra_credit(){

    // Draw balls randomly
    num_circles := 30
    radius := 50 // Define the radius of the circles
    width := image.size.width
    height := image.size.height

    for _ in 0 .. num_circles {
        cx := rand.int_in_range(0, width) or { 0 }
        cy := rand.int_in_range(0, height) or { 0 }
        ball_color := Color{
            r: rand.f32_in_range(0, 1) or { 0.0 }
            g: rand.f32_in_range(0, 1) or { 0.0 }
            b: rand.f32_in_range(0, 1) or { 0.0 }
        }
        
        mut x := radius
        mut y := 0
        mut dx := 1
        mut dy := 1
        mut err := dx - (2 * radius)

        for x >= y {
            // Reflect the points to all octants
            image.set_xy(cx + x, cy + y, ball_color)
            image.set_xy(cx + y, cy + x, ball_color)
            image.set_xy(cx - y, cy + x, ball_color)
            image.set_xy(cx - x, cy + y, ball_color)
            image.set_xy(cx - x, cy - y, ball_color)
            image.set_xy(cx - y, cy - x, ball_color)
            image.set_xy(cx + y, cy - x, ball_color)
            image.set_xy(cx + x, cy - y, ball_color)
            
            if err <= 0 {
                y += 1
                err += dy
                dy += 2
            }
            if err > 0 {
                x -= 1
                dx += 2
                err += dx - (2 * radius)
            }
        }
    }
}
// EXTRA CREDIT END


//////////////////////////////////////////////////////////////////////////////////////////////////
// General render function

// creates an image, calls each of the passed rasterizer functions, then returns final image
fn render_image(rasterizers []Rasterizer) Image {
    mut image := gfx.Image.new(size)
    for rasterizer in rasterizers {
        rasterizer(mut image)
    }
    return image
}

//////////////////////////////////////////////////////////////////////////////////////////////////

fn main() {
    // Make sure images folder exists, because this is where all
    // generated images will be saved
    if !os.exists('output') {
        os.mkdir('output') or { panic(err) }
    }

    //Extra CREDIT
    render_image([
        fn (mut image Image) { image.raster_extra_credit() }
    ]).save_png('output/Extra_Credit.png')


    //Creative ARTIFACT
    render_image([ 
        fn (mut image Image) { image.raster_creative_artifact( Size2i{ size.width, size.height }) }
    ]).save_png('output/creative_artifact.png')


    //Elective
    p0 := Point2i{215, 150}
    p1 := Point2i{350, 400}
    p2 := Point2i{100, 400}
    image_width := 100
    image_height := 100

    println('Rendering filled triangle...')
    render_image([
        fn [p0, p1, p2, image_width, image_height] (mut image Image) { 
            image.raster_filled_triangle(p0, p1, p2, gfx.blue, image_width, image_height)
        },
    ]).save_png('output/Elective_filled_triangle.png')


    println('Rendering rectangle...')
    render_image([
        fn (mut image Image) { image.raster_rectangle(center, Size2i{ radius, radius }, gfx.white) },
    ]).save_png('output/P01_00_rectangle.png')

    println('Rendering star...')
    render_image([
        fn (mut image Image) { image.raster_star(center, radius, num_points, gfx.yellow) },
    ]).save_png('output/P01_01_star.png')

    println('Rendering fixed polygon...')
    render_image([
        fn (mut image Image) { image.raster_fixed_polygon(center, radius, gfx.cyan) },
    ]).save_png('output/P01_02_fixed_polygon.png')

    println('Rendering regular polygon...')
    render_image([
        fn (mut image Image) { image.raster_regular_polygon(center, radius, num_sides, gfx.red) },
    ]).save_png('output/P01_03_regular_polygon.png')

    println('Rendering circle...')
    render_image([
        fn (mut image Image) { image.raster_circle(center, radius, gfx.green) },
    ]).save_png('output/P01_04_circle.png')

    println('Rendering circles...')
    render_image(
        radcols.map(fn (radcol RadiusColor) Rasterizer {
            return fn [radcol] (mut image Image) { image.raster_circle(center, radcol.radius, radcol.color) }
        })
    ).save_png('output/P01_05_circles.png')

    println('Rendering fixed polygon using generator...')
    shape_fixed_polygon := generate_fixed_polygon(center, radius, gfx.magenta)
    render_image([
        fn [shape_fixed_polygon] (mut image Image) { image.raster_line_segments(shape_fixed_polygon) },
    ]).save_png('output/P01_06_fixed_polygon.png')

    println('Rendering fractal tree using generator...')
    shape_fractal_tree := generate_fractal_tree(
        Point2{ 256, 500 },  // start
        100,                 // length
        math.radians(270),   // direction
        0.75,                // length_factor
        math.radians(30),    // spread
        0.85,                // spread_factor
        10,                  // count
        10,                  // max_count
    )
    render_image([
        fn [shape_fractal_tree] (mut image Image) { image.raster_line_segments(shape_fractal_tree) },
    ]).save_png('output/P01_07_fractal_tree.png')


    println('Done!')
}