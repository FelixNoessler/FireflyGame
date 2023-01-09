module FireflyGame

using LibSerialPort
using GLMakie

set_theme!(fontsize=16,
           GLMakie = (title="FireflyGame", ))


######## Observables
## general
playerspeed_start = 0.3
gamespeed_start = 0.01
difficulty_start = 2.0
playerspeed = Observable(playerspeed_start; ignore_equal_values=true)
gamespeed = Observable(gamespeed_start; ignore_equal_values=true)
difficulty = Observable(difficulty_start; ignore_equal_values=true)

stop_prog = Observable(true; ignore_equal_values=true)
playercolor = Observable("#f0d135"; ignore_equal_values=true)
barriercounter = Observable(0; ignore_equal_values=true)

## barriers
xorigins = Observable([1.0, 2.0, 3.0]; ignore_equal_values=true)
yorigins = Observable([-10, 10, -10]; ignore_equal_values=true)
heights = Observable([3.2, -3.4, 5.0]; ignore_equal_values=true)
isvisible = Observable([true, true, true]; ignore_equal_values=false)
barriers_rects = @lift Makie.Rect.(
    [$xorigins[$isvisible], $yorigins[$isvisible]]..., 
    [fill(0.3, sum($isvisible)), $heights[$isvisible]]...)

## player
playerxcenter = Observable(0.0; ignore_equal_values=true)
playerycenter = Observable(0.0; ignore_equal_values=true)
player_circ = @lift Makie.Circle(Point($playerxcenter, $playerycenter), 0.25)


ms_since_movement = Observable(0; ignore_equal_values=true)
lastx = Observable(repeat([0.0], 100); ignore_equal_values=true)
lasty = Observable(repeat([0.0], 100); ignore_equal_values=true)
last_visibility = Observable(repeat([true], 100); ignore_equal_values=false)
last_circs = @lift Makie.Circle.(
    Point.($lastx[$last_visibility], $lasty[$last_visibility]), 0.25)
last_colors = @lift [("#f0d135", x) for x in ((0.808:-0.008:0.01) ./ 9)[$last_visibility]]


######## Functions

function create_fig()
    GLMakie.set_window_config!(;float=true)
    
    fig = Figure(resolution=(800,900))
    ax = Axis(fig[1,1];
              aspect=DataAspect(),
              limits=(-10.0, 10.0, -10, 10.0),
              xzoomlock=true,
              yzoomlock=true,
              xrectzoom=false,
              yrectzoom=false,
              backgroundcolor=(:black, 1.0))
    hidedecorations!(ax)
    hidespines!(ax)
    sls = SliderGrid(fig[2,1],
                    (label="Game speed (slow to fast)", range = 0.001:0.001:0.04, startvalue = gamespeed_start, format = "{}"),
                    (label="Player speed (slow to fast)", range = 0:0.01:0.8, startvalue = playerspeed_start, format = "{:.1f}"),
                    (label="Difficulty (easy to hard)", range = 3:-0.01:1, startvalue = difficulty_start, format = "{}")) 
    
    gamespeed_slider = sls.sliders[1]
    connect!(gamespeed, gamespeed_slider.value)
    
    playerspeed_slider = sls.sliders[2]
    connect!(playerspeed, playerspeed_slider.value)  
    
    difficulty_slider = sls.sliders[3]  
    connect!(difficulty, difficulty_slider.value)
    
    ############ Buttons
    fig[3, 1] = buttongrid = GridLayout(tellwidth = false)
    b_reset = Button(buttongrid[1,1];
           label="reset")
    b_stop = Button(buttongrid[1,2];
           label="stop")
    b_start = Button(buttongrid[1,3];
                    label="start")
           
    on(b_reset.clicks) do n
        @info "Reset!"
        reset_start()
    end
    on(b_stop.clicks) do n
        if ! stop_prog.val 
            @info "Stop!"
            stop_prog[] = true
        end
    end
    
    on(b_start.clicks) do n
        if stop_prog.val && ! was_catched()
            @info "Start!"
            stop_prog[] = false
        end
    end
    
    poly!(last_circs;
        color=last_colors)
    
    poly!(player_circ;
          color=playercolor)
    
    new_lines()
    poly!(barriers_rects;
          color=("#048217", 1.0))
    
    str_counter = @lift string($barriercounter)
    text!(9,9; text=str_counter,color="#f0d135")
    
    screen = display(fig)
    
    return screen
end


function game_loop(screen)
    portname = "/dev/ttyACM0"
    baudrate = 9600
    LibSerialPort.open(portname, baudrate) do sp
    
        while isopen(screen)
            sleep(0.0001)
            
            if stop_prog.val
                continue
            end
            
            if was_catched()
                @info "Catched!"
                playercolor[] = "#fa440c"
                stop_prog[] = true
            end
            
            
            move_barriers_player()
            update_counter()
            
            update_lastposition()
            
            if bytesavailable(sp) > 0
            
                data = Int16.(read(sp))
                
                if length(data) == 2
                    xraw, yraw = data
                    x, y = 0.5 .- (Float64.([xraw, yraw]) ./ 255) .- 0.009803921568627472
                    
                    newx = playerspeed.val*x + playerxcenter.val
                    newy = playerspeed.val*y + playerycenter.val
                    playersize = player_circ.val.r
                    
                    is_mowing = false
                    
                    if x > 1e-10
                        if (newx + playersize) < 10.0
                            playerxcenter[] += playerspeed.val*x*0.5
                            is_mowing = true
                        end    
                    elseif x < -1e-10
                        if newx > (-10.0 + playersize)
                            playerxcenter[] += playerspeed.val*x*0.5
                            is_mowing = true
                        end
                    end
                    
                    
                    if y > 1e-10
                        if (newy + playersize) < 10.0
                            playerycenter[] += playerspeed.val*y
                            is_mowing = true
                        end    
                    elseif y < -1e-10
                        if newy > (-10.0 + playersize)
                            playerycenter[] += playerspeed.val*y
                            is_mowing = true
                        end
                    end
                    
                    if ! is_mowing
                        ms_since_movement[] += 1
                    else
                        ms_since_movement[] = 0
                    end

                end
            end
        end
    end
end


function reset_start()
    stop_prog[] = false
    
    playerxcenter[] = 0.0
    playerycenter[] = 0.0
    playercolor[] = "#f0d135"
    
    barriercounter[] = 0 
    
    lastx[] = repeat([0.0], 100)
    lasty[] = repeat([0.0], 100)
    
    new_lines()
end


function move_barriers_player()
    xorigins[] = xorigins.val .- gamespeed.val
    isvisible[] = update_visibility(xorigins.val)
    
    if  playerxcenter.val > (-10 + player_circ.val.r)
        playerxcenter[] = playerxcenter.val - gamespeed.val
    end
end


function update_visibility(xpos)
    return -10 .< (xpos .+ 0.3) .< 10
end



function update_counter()
    player_x = playerxcenter.val
    barrier_x = xorigins.val
    passed_barriers = findlast(player_x .> barrier_x)
    
    if ! isnothing(passed_barriers)
        barriercounter[] = passed_barriers
    end 
end


function update_lastposition()
    lastx.val = [player_circ.val.center[1], lastx.val[1:end-1]...]
    lasty.val = [player_circ.val.center[2], lasty.val[1:end-1]...]

    vis = repeat([true], 100)
    vis[max(1, Int(round(100-50*ms_since_movement.val))):1:100] .= false
    
    last_visibility[] = vis
end


function generate_x_barriers()
    n = 5000
    x_coords = rand(1:0.1:500, 1)
    accepted = 1

    for i in 1:10_000
        if accepted == n
            break 
        end
        
        new_xcoord = rand(1:0.1:500)
        
        accept_coord = all( abs.(x_coords .- new_xcoord) .> difficulty.val)
        
        if accept_coord
            accepted += 1
            push!(x_coords, new_xcoord)
        end
    end
    sort!(x_coords)
    
    @info "Generated $accepted barriers!"
    
    return accepted, x_coords
end


function new_lines(;)
    nvals, xorigins.val = generate_x_barriers()
    yorigins.val = rand([-10, 10], nvals)
    heights.val = rand(0.1:0.1:15, nvals) .*  - yorigins.val ./ 10
    isvisible[] = update_visibility(xorigins.val)
end


function was_catched()
    if ! isempty(barriers_rects.val)
        player = player_circ.val
        r = player.r
        
        r_adj = [r, r*0.75, r*0.5, r*0.25, 0, -r*0.25, -r*0.5, -r*0.75, -r]
        x = player.center[1] .+ r_adj
        y = player.center[2] .+ r_adj
        
        player_x = x[[5,4,3,2,1,2,3,4,5,6,7,8,9,8,7,6]]
        player_y = y[[1,2,3,4,5,6,7,8,9,8,7,6,5,4,3,2]]
        
        for i in eachindex(barriers_rects.val)
            bx1, by1 = barriers_rects.val[i].origin
            bx2, by2 = barriers_rects.val[i].origin .+ barriers_rects.val[i].widths
            
            if by1 > by2
                by1_st =  by1
                by1 = by2
                by2 = by1_st
            end
            
            for u in eachindex(player_x)
                if (bx1 <= player_x[u] <= bx2) &&  (by1 <= player_y[u] <= by2)
                    return true
                end 

            end
        end
    end
    
    return false  
end

end # of module